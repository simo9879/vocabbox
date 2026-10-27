extends "res://modules/speech/Core/Ports/Driven/TranscriptionPort.gd"

const Contracts = preload("res://modules/speech/Core/Domain/SpeechContracts.gd")
const Endpoint = preload("res://modules/speech/Adapters/Http/HttpEndpoint.gd")
const WaveEncoder = preload("res://modules/speech/Adapters/Http/WaveEncoder.gd")

var _endpoint: Node
var _session_id := 0
var _sample_rate := 0
var _pcm := PackedByteArray()

func _ready() -> void:
	_endpoint = Endpoint.new()
	add_child(_endpoint)
	_endpoint.completed.connect(_on_completed)

func configure(url: String, token: String) -> bool:
	return _endpoint.configure(url, token)

func start_session(session_id: int, sample_rate: int) -> void:
	cancel()
	_session_id = session_id
	_sample_rate = sample_rate

func push_audio(session_id: int, pcm: PackedByteArray) -> void:
	if session_id == _session_id:
		_pcm.append_array(pcm)

func finish_session(session_id: int) -> void:
	if session_id != _session_id:
		return
	var audio := {"pcm": _pcm, "sample_rate": _sample_rate, "channels": 1}
	_endpoint.post_bytes(session_id, WaveEncoder.encode(audio), "audio/wav")
	_pcm.clear()

func cancel() -> void:
	_endpoint.cancel()
	_session_id = 0
	_pcm.clear()

func _on_completed(session_id: int, result: Dictionary) -> void:
	if not result.ok:
		completed.emit(session_id, result)
		return
	var data: Dictionary = result.value
	if not data.get("transcript") is String or data.transcript.length() > Contracts.MAX_TRANSCRIPT:
		completed.emit(session_id, Contracts.failure("invalid_response", "Speech checking returned an unusable response."))
		return
	completed.emit(session_id, Contracts.success(data.transcript))
