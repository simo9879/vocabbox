extends "res://modules/speech/Core/Ports/Driven/EvaluationPort.gd"

const Endpoint = preload("res://modules/speech/Adapters/Http/HttpEndpoint.gd")
const Codec = preload("res://modules/speech/Adapters/DeepSeek/DeepSeekAssessmentCodec.gd")
const CHAT_URL := "https://api.deepseek.com/chat/completions"

var _endpoint: Node

func _ready() -> void:
	_endpoint = Endpoint.new()
	add_child(_endpoint)
	_endpoint.completed.connect(_on_completed)

func configure(api_key: String, url: String = CHAT_URL) -> bool:
	if api_key.strip_edges().is_empty():
		return false
	return _endpoint.configure(url, api_key.strip_edges())

func evaluate(session_id: int, transcript: String, lesson: Dictionary) -> void:
	_endpoint.post_json(session_id, Codec.request_body(transcript, lesson))

func cancel() -> void:
	_endpoint.cancel()

func _on_completed(session_id: int, result: Dictionary) -> void:
	if not result.ok:
		completed.emit(session_id, result)
		return
	completed.emit(session_id, Codec.parse_response(result.value))
