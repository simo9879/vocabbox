extends "res://modules/speech/Core/Ports/Driven/SpeechSynthesisPort.gd"

const Contracts = preload("res://modules/speech/Core/Domain/SpeechContracts.gd")
# Previous Pip voice, kept for quick rollback:
# const VOICE_ID := "bTrXJpbeuC5KgriLhQeC"
const VOICE_ID := "pFZP5JQG7iQjIQuC4Bku"
const VOICE_URL := "https://api.elevenlabs.io/v1/text-to-speech/" + VOICE_ID + "?output_format=mp3_44100_128"
const MODEL := "eleven_v4"

var _api_key := ""
var _url := VOICE_URL
var _request: HTTPRequest

func configure(api_key: String, url: String = VOICE_URL) -> bool:
	if api_key.strip_edges().is_empty() or api_key.contains("\r") or api_key.contains("\n"):
		return false
	if not _is_allowed_url(url):
		return false
	_api_key = api_key.strip_edges()
	_url = url
	return true

func synthesize(request_id: int, text: String) -> void:
	cancel()
	if text.strip_edges().is_empty() or text.length() > Contracts.MAX_PIP_RESPONSE:
		completed.emit(request_id, Contracts.failure("invalid_text", "Pip's spoken review could not be prepared."))
		return

	# Keep the provider request separate from dialogue playback and use bounded memory.
	_request = HTTPRequest.new()
	_request.timeout = 30.0
	_request.max_redirects = 0
	_request.body_size_limit = 2 * 1024 * 1024
	add_child(_request)
	_request.request_completed.connect(_on_completed.bind(_request, request_id))
	var headers := PackedStringArray(["xi-api-key: " + _api_key, "Content-Type: application/json"])
	var body := JSON.stringify({"text": text, "model_id": MODEL})
	var error := _request.request(_url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		cancel()
		completed.emit(request_id, Contracts.failure("service_unavailable", "Could not start TTS request (Godot error %d)." % error))

func cancel() -> void:
	if is_instance_valid(_request):
		_request.cancel_request()
		_request.queue_free()
	_request = null

func _on_completed(result: int, status: int, _headers: PackedStringArray, body: PackedByteArray,
		request: HTTPRequest, request_id: int) -> void:
	if request != _request:
		return
	_request = null
	request.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS:
		completed.emit(request_id, Contracts.failure("service_unavailable", _transport_error(result, status)))
		return
	if status < 200 or status >= 300:
		completed.emit(request_id, Contracts.failure("service_unavailable", _http_error(status, body)))
		return
	if not _looks_like_mp3(body):
		completed.emit(request_id, Contracts.failure("invalid_audio", "HTTP %d returned non-MP3 audio (%d bytes)." % [status, body.size()]))
		return
	var stream := AudioStreamMP3.load_from_buffer(body)
	if stream == null or stream.get_length() <= 0.0:
		completed.emit(request_id, Contracts.failure("invalid_audio", "HTTP %d MP3 could not be decoded (%d bytes)." % [status, body.size()]))
		return
	completed.emit(request_id, Contracts.success(stream))

static func _transport_error(result: int, status: int) -> String:
	var reason := "transport error"
	match result:
		HTTPRequest.RESULT_CANT_RESOLVE:
			reason = "DNS lookup failed"
		HTTPRequest.RESULT_CANT_CONNECT:
			reason = "could not connect"
		HTTPRequest.RESULT_CONNECTION_ERROR:
			reason = "connection dropped"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			reason = "TLS handshake failed"
		HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
			reason = "audio exceeded 2 MiB limit"
		HTTPRequest.RESULT_TIMEOUT:
			reason = "timed out after 30 seconds"
	return "TTS %s (Godot result %d, HTTP %d)." % [reason, result, status]

func _http_error(status: int, body: PackedByteArray) -> String:
	var message := "ElevenLabs HTTP %d" % status
	var detail: Variant = JSON.parse_string(body.get_string_from_utf8())
	if detail is Dictionary:
		detail = detail.get("detail", detail)
	if detail is Dictionary:
		var code: Variant = detail.get("code", detail.get("type", ""))
		var description: Variant = detail.get("message", "")
		if code is String and not code.is_empty():
			message += " · " + _safe_detail(code)
		if description is String and not description.is_empty():
			message += ": " + _safe_detail(description)
	elif detail is String and not detail.is_empty():
		message += ": " + _safe_detail(detail)
	return message

func _safe_detail(value: String) -> String:
	# Provider details are useful in this prototype, but never repeat the API key.
	return value.replace(_api_key, "[redacted]").replace("\n", " ").replace("\r", " ").left(180)

static func _looks_like_mp3(body: PackedByteArray) -> bool:
	return (body.size() >= 3 and body[0] == 73 and body[1] == 68 and body[2] == 51) \
		or (body.size() >= 2 and body[0] == 255 and body[1] & 224 == 224)

static func _is_allowed_url(url: String) -> bool:
	if url == VOICE_URL:
		return true
	# A local fixture URL is accepted only for tests.
	return url.begins_with("http://127.0.0.1:") and not url.contains("@") \
		and not url.contains("\r") and not url.contains("\n")
