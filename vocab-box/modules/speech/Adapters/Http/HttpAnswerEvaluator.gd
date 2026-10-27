extends "res://modules/speech/Core/Ports/Driven/EvaluationPort.gd"

const Endpoint = preload("res://modules/speech/Adapters/Http/HttpEndpoint.gd")

var _endpoint: Node

func _ready() -> void:
	_endpoint = Endpoint.new()
	add_child(_endpoint)
	_endpoint.completed.connect(_on_completed)

func configure(url: String, token: String) -> bool:
	return _endpoint.configure(url, token)

func evaluate(session_id: int, transcript: String, lesson: Dictionary) -> void:
	_endpoint.post_json(session_id, {
		"transcript": transcript,
		"encounter_id": lesson.encounter_id,
		"prompt": lesson.prompt,
		"rubric": lesson.rubric,
		"target_vocabulary": lesson.target_vocabulary,
		"examples": lesson.examples,
	})

func cancel() -> void:
	_endpoint.cancel()

func _on_completed(session_id: int, result: Dictionary) -> void:
	# The workflow validates the assessment against the lesson and transcript.
	completed.emit(session_id, result)
