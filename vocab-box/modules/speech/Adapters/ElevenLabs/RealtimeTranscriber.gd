extends "res://modules/speech/Core/Ports/Driven/TranscriptionPort.gd"

const Contracts = preload("res://modules/speech/Core/Domain/SpeechContracts.gd")
const Endpoint = preload("res://modules/speech/Adapters/Http/HttpEndpoint.gd")
const SCRIBE_URL := "wss://api.elevenlabs.io/v1/speech-to-text/realtime"
const SUPPORTED_RATES := [8000, 16000, 22050, 24000, 44100, 48000]
const MAX_QUEUED_BYTES := 48000 * 2 * 30
const MAX_OUTBOUND_BYTES := 256 * 1024

var _socket: WebSocketPeer
var _api_key := ""
var _session_id := 0
var _sample_rate := 0
var _chunk_bytes := 0
var _pending := PackedByteArray()
var _connected := false
var _finishing := false
var _commit_sent := false
var _streaming_started := false
var _deadline_ms := 0
var _scribe_url := SCRIBE_URL

func configure(api_key: String, realtime_url: String = SCRIBE_URL) -> bool:
	if api_key.strip_edges().is_empty() or api_key.contains("\r") or api_key.contains("\n"):
		return false
	var equivalent_http := ""
	if realtime_url.begins_with("wss://"):
		equivalent_http = "https://" + realtime_url.substr(6)
	elif realtime_url.begins_with("ws://"):
		equivalent_http = "http://" + realtime_url.substr(5)
	else:
		return false
	if not Endpoint.is_allowed_endpoint(equivalent_http):
		return false
	_api_key = api_key.strip_edges()
	_scribe_url = realtime_url
	return true

func start_session(session_id: int, sample_rate: int) -> void:
	cancel()
	if sample_rate not in SUPPORTED_RATES:
		completed.emit(session_id, Contracts.failure("invalid_audio", "This microphone sample rate is not supported."))
		return
	_session_id = session_id
	_sample_rate = sample_rate
	_chunk_bytes = int(sample_rate * 2 / 10)
	_deadline_ms = Time.get_ticks_msec() + 10000
	# Authenticate in the WebSocket handshake so capture can stream as soon as it connects.
	_socket = WebSocketPeer.new()
	_socket.outbound_buffer_size = 512 * 1024
	_socket.handshake_headers = PackedStringArray(["xi-api-key: " + _api_key])
	activity.emit(_session_id, "connecting")
	var url := "%s?model_id=scribe_v2_realtime&audio_format=pcm_%d&language_code=en&commit_strategy=manual" % [
		_scribe_url, _sample_rate
	]
	if _socket.connect_to_url(url) != OK:
		_fail("service_unavailable", "Speech checking is unavailable. Please try again.")

func push_audio(session_id: int, pcm: PackedByteArray) -> void:
	if session_id != _session_id or _finishing or pcm.is_empty():
		return
	_pending.append_array(pcm)
	if _pending.size() > MAX_QUEUED_BYTES:
		_fail("audio_overflow", "Speech checking could not keep up with the microphone.")
		return
	_flush_audio()

func finish_session(session_id: int) -> void:
	if session_id != _session_id:
		return
	_finishing = true
	_deadline_ms = Time.get_ticks_msec() + 20000
	_flush_audio()

func cancel() -> void:
	_session_id = 0
	if _socket != null:
		_socket.close()
	_socket = null
	_pending.clear()
	_connected = false
	_finishing = false
	_commit_sent = false
	_streaming_started = false
	_deadline_ms = 0

func _process(_delta: float) -> void:
	if _session_id == 0:
		return
	if (not _connected or _finishing) and Time.get_ticks_msec() > _deadline_ms:
		_fail("service_unavailable", "Speech checking timed out. Please try again.")
		return
	if _socket == null:
		return
	_socket.poll()
	# A server may close just after sending its committed transcript; drain queued frames first.
	while _session_id != 0 and _socket.get_available_packet_count() > 0:
		_read_message(_socket.get_packet())
	if _session_id == 0:
		return
	if _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_flush_audio()
	elif _socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		_fail("service_unavailable", "Speech checking disconnected. Please try again.")

func _read_message(packet: PackedByteArray) -> void:
	if not _socket.was_string_packet():
		_fail("invalid_response", "Speech checking returned an unusable response.")
		return
	var data: Variant = JSON.parse_string(packet.get_string_from_utf8())
	if not data is Dictionary:
		_fail("invalid_response", "Speech checking returned an unusable response.")
		return
	var kind: String = str(data.get("message_type", ""))
	match kind:
		"session_started":
			_socket.set_no_delay(true)
			_connected = true
			activity.emit(_session_id, "connected")
			_flush_audio()
		"partial_transcript":
			var partial: Variant = data.get("text")
			if partial is String and partial.length() <= Contracts.MAX_TRANSCRIPT:
				if not partial.strip_edges().is_empty():
					activity.emit(_session_id, "receiving_words")
				partial_transcript.emit(_session_id, partial)
		"committed_transcript":
			if _commit_sent:
				var text: Variant = data.get("text")
				var id := _session_id
				cancel()
				completed.emit(id, Contracts.success(text))
		"warning":
			pass
		_:
			if data.has("error") or kind.ends_with("_error"):
				_fail("service_unavailable", "Speech checking failed. Please try again.")

func _flush_audio() -> void:
	if not _connected or _socket == null or _commit_sent:
		return
	# Keep one short chunk until release so the final chunk can carry the manual commit.
	while _pending.size() > _chunk_bytes or (_finishing and not _pending.is_empty()):
		if _socket.get_current_outbound_buffered_amount() > MAX_OUTBOUND_BYTES:
			return
		var size := mini(_chunk_bytes, _pending.size())
		var chunk := _pending.slice(0, size)
		var final_chunk := _finishing and size == _pending.size()
		var message := {
			"message_type": "input_audio_chunk",
			"audio_base_64": Marshalls.raw_to_base64(chunk),
			"sample_rate": _sample_rate,
		}
		if final_chunk:
			message.commit = true
		if _socket.send_text(JSON.stringify(message)) != OK:
			_fail("service_unavailable", "Speech checking is unavailable. Please try again.")
			return
		_pending = _pending.slice(size)
		if not _streaming_started:
			_streaming_started = true
			activity.emit(_session_id, "streaming")
		if final_chunk:
			_commit_sent = true
			return

func _fail(code: String, message: String) -> void:
	var id := _session_id
	cancel()
	if id != 0:
		completed.emit(id, Contracts.failure(code, message))
