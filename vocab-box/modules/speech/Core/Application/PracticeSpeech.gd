extends "res://modules/speech/Core/Ports/Driving/PracticeSpeechPort.gd"

const Contracts = preload("res://modules/speech/Core/Domain/SpeechContracts.gd")

var _recorder: Node
var _transcriber: Node
var _evaluator: Node
var _next_id := 0
var _active_id := 0
var _lesson: Dictionary = {}
var _transcript := ""

func configure(recorder: Node, transcriber: Node, evaluator: Node) -> void:
	_recorder = recorder
	_transcriber = transcriber
	_evaluator = evaluator
	_transcriber.completed.connect(_on_transcribed)
	_transcriber.partial_transcript.connect(_on_partial_transcript)
	_transcriber.activity.connect(_on_transcription_activity)
	_evaluator.completed.connect(_on_evaluated)

func begin_answer(lesson: Dictionary) -> int:
	if state in ["recording", "transcribing", "evaluating"]:
		failed.emit("busy", "An answer is already in progress.")
		return 0
	var checked := Contracts.validate_lesson(lesson)
	if not checked.ok:
		failed.emit(checked.code, checked.message)
		return 0
	var started: Dictionary = _recorder.start_capture()
	if not started.ok:
		_recorder.cancel_capture()
		failed.emit(started.code, started.message)
		return 0
	_next_id += 1
	_active_id = _next_id
	_lesson = checked.value
	_set_state("recording")
	_transcriber.start_session(_active_id, started.value)
	return _active_id if state == "recording" else 0

func finish_answer() -> void:
	if state != "recording":
		return
	var stopped: Dictionary = _recorder.stop_capture()
	if not stopped.ok:
		_fail(stopped)
		return
	var checked := Contracts.validate_audio(stopped.value)
	if not checked.ok:
		_fail(checked)
		return
	_transcriber.push_audio(_active_id, checked.value.pcm)
	if state != "recording":
		return
	_set_state("transcribing")
	_transcriber.finish_session(_active_id)

func cancel_answer() -> void:
	# Invalidate identity before cancelling I/O so late callbacks cannot publish an answer.
	_active_id = 0
	_lesson.clear()
	_transcript = ""
	if _recorder != null:
		_recorder.cancel_capture()
	if _transcriber != null:
		_transcriber.cancel()
	if _evaluator != null:
		_evaluator.cancel()
	_set_state("idle")

func pump() -> void:
	if state != "recording":
		return
	var result: Dictionary = _recorder.pump()
	if not result.ok:
		_fail(result)
		return
	if result.value is PackedByteArray and not result.value.is_empty():
		_transcriber.push_audio(_active_id, result.value)

func recording_timed_out() -> void:
	if state == "recording":
		_fail(Contracts.failure("recording_too_long", "Please try a shorter answer."))

func _on_transcribed(session_id: int, result: Dictionary) -> void:
	if session_id != _active_id or state not in ["recording", "transcribing"]:
		return
	if not result.ok:
		_fail(result)
		return
	if state != "transcribing":
		return
	var checked := Contracts.validate_transcript(result.value)
	if not checked.ok:
		_fail(checked)
		return
	_transcript = checked.value
	transcript_ready.emit(_active_id, _transcript)
	_set_state("evaluating")
	_evaluator.evaluate(_active_id, _transcript, _lesson)

func _on_partial_transcript(session_id: int, text: String) -> void:
	if session_id == _active_id and state == "recording":
		partial_transcript.emit(text)

func _on_transcription_activity(session_id: int, status: String) -> void:
	if session_id == _active_id and state in ["recording", "transcribing"]:
		transcription_status.emit(status)

func _on_evaluated(session_id: int, result: Dictionary) -> void:
	if session_id != _active_id or state != "evaluating":
		return
	if not result.ok:
		_fail(result)
		return
	var checked := Contracts.validate_assessment(result.value, _transcript, _lesson)
	if not checked.ok:
		_fail(checked)
		return
	var assessment: Dictionary = checked.value
	var answer := {
		"session_id": _active_id,
		"encounter_id": _lesson.encounter_id,
		"transcript": _transcript,
		"quality": assessment.quality,
		"allowed": assessment.quality >= 1,
		"feedback": assessment.feedback,
		"pip_response": assessment.pip_response,
		"suggested_wording": assessment.suggested_wording,
		"vocabulary_used": assessment.vocabulary_used,
	}
	_active_id = 0
	_set_state("completed")
	answer_ready.emit(answer)

func _fail(result: Dictionary) -> void:
	_active_id = 0
	_recorder.cancel_capture()
	_transcriber.cancel()
	_evaluator.cancel()
	_set_state("failed")
	failed.emit(result.code, result.message)

func _set_state(next_state: String) -> void:
	if state == next_state:
		return
	state = next_state
	state_changed.emit(state)
