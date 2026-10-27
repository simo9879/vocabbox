extends Node

const Microphone = preload("res://modules/speech/Adapters/Godot/GodotMicrophone.gd")
const Transcriber = preload("res://modules/speech/Adapters/ElevenLabs/RealtimeTranscriber.gd")
const Evaluator = preload("res://modules/speech/Adapters/DeepSeek/DeepSeekAnswerEvaluator.gd")
const PracticeSpeech = preload("res://modules/speech/Core/Application/PracticeSpeech.gd")

signal state_changed(state: String)
signal answer_ready(result: Dictionary)
signal failed(code: String, message: String)
signal partial_transcript(text: String)
signal transcription_status(status: String)
signal transcript_ready(session_id: int, text: String)

var state: String:
	get:
		return _workflow.state if is_instance_valid(_workflow) else "idle"

var is_configured: bool:
	get:
		return is_instance_valid(_workflow)

var configuration_reason := ""
var _workflow: Node
var _recorder: Node
var _transcriber: Node
var _evaluator: Node
var _recorded_seconds := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func configure(elevenlabs_key: String, deepseek_key: String) -> bool:
	_release_parts()
	configuration_reason = _configuration_issue(elevenlabs_key, deepseek_key)
	if not configuration_reason.is_empty():
		failed.emit("configuration", configuration_reason)
		return false

	# Construct replaceable adapters once; only this node is visible to the game.
	_recorder = Microphone.new()
	_transcriber = Transcriber.new()
	_evaluator = Evaluator.new()
	_workflow = PracticeSpeech.new()
	for part in [_recorder, _transcriber, _evaluator, _workflow]:
		add_child(part)
	if not _transcriber.configure(elevenlabs_key) or not _evaluator.configure(deepseek_key):
		_release_parts()
		configuration_reason = "Speech adapter setup failed"
		failed.emit("configuration", configuration_reason)
		return false
	_workflow.configure(_recorder, _transcriber, _evaluator)
	_workflow.state_changed.connect(_forward_state)
	_workflow.answer_ready.connect(_forward_answer)
	_workflow.failed.connect(_forward_failure)
	_workflow.partial_transcript.connect(_forward_partial)
	_workflow.transcription_status.connect(_forward_transcription_status)
	_workflow.transcript_ready.connect(_forward_transcript)
	return true

func begin_answer(lesson: Dictionary) -> int:
	if not is_configured:
		failed.emit("not_configured", "Speech checking is not configured.")
		return 0
	var id: int = _workflow.begin_answer(lesson)
	if id > 0:
		_recorded_seconds = 0.0
	return id

func finish_answer() -> void:
	if is_configured:
		_workflow.finish_answer()

func cancel_answer() -> void:
	if is_configured:
		_workflow.cancel_answer()

func _process(delta: float) -> void:
	if state != "recording":
		return
	_workflow.pump()
	if state != "recording":
		return
	_recorded_seconds += delta
	if _recorded_seconds >= 30.0:
		_workflow.recording_timed_out()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		cancel_answer()

func _exit_tree() -> void:
	cancel_answer()

func _release_parts() -> void:
	cancel_answer()
	for part in [_workflow, _evaluator, _transcriber, _recorder]:
		if is_instance_valid(part):
			remove_child(part)
			part.queue_free()
	_workflow = null
	_evaluator = null
	_transcriber = null
	_recorder = null

func _configuration_issue(elevenlabs_key: String, deepseek_key: String) -> String:
	if elevenlabs_key.strip_edges().is_empty() or elevenlabs_key.contains("\r") or elevenlabs_key.contains("\n"):
		return "Invalid ElevenLabs API key"
	if deepseek_key.strip_edges().is_empty() or deepseek_key.contains("\r") or deepseek_key.contains("\n"):
		return "Invalid DeepSeek API key"
	return ""

func _forward_state(value: String) -> void:
	state_changed.emit(value)

func _forward_answer(result: Dictionary) -> void:
	answer_ready.emit(result)

func _forward_failure(code: String, message: String) -> void:
	failed.emit(code, message)

func _forward_partial(value: String) -> void:
	partial_transcript.emit(value)

func _forward_transcription_status(value: String) -> void:
	transcription_status.emit(value)

func _forward_transcript(session_id: int, value: String) -> void:
	transcript_ready.emit(session_id, value)
