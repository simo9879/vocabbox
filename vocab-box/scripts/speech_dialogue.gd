extends Node

const SpeechEnvironment = preload("res://scripts/speech_environment.gd")

signal answer_ready(result: Dictionary)
signal recording_started
signal state_changed(state: String)
signal failed(message: String)
signal partial_transcript(text: String)
signal debug_changed

var available := false
var availability_reason := "Not configured yet"
var stt_status := "Not checked"
var last_transcript := ""
var module: Node
var _lesson: Dictionary = {}
var _wait_for_release := false
var _session_id := 0

func configure() -> void:
	# Report missing speech configuration before falling back to authored choices.
	available = false
	stt_status = "Unavailable"
	var elevenlabs_key := SpeechEnvironment.get_value("ELEVENLABS_API_KEY")
	var deepseek_key := SpeechEnvironment.get_value("AI_API_KEY")
	var missing := PackedStringArray()
	if elevenlabs_key.is_empty():
		missing.append("ElevenLabs API key")
	if deepseek_key.is_empty():
		missing.append("DeepSeek API key")
	if not missing.is_empty():
		availability_reason = "Needs: " + ", ".join(missing)
		return

	var scene = load("res://modules/speech/SpeechModule.tscn")
	if scene == null:
		availability_reason = "Speech module scene could not load"
		return

	module = scene.instantiate()
	add_child(module)
	module.state_changed.connect(_state_changed)
	module.failed.connect(_failed)
	module.answer_ready.connect(_answer_ready)
	module.partial_transcript.connect(_partial_transcript)
	module.transcription_status.connect(_transcription_status)
	module.transcript_ready.connect(_transcript_ready)
	available = module.configure(elevenlabs_key, deepseek_key)
	availability_reason = "Configured; service health untested" if available else module.configuration_reason
	if available:
		stt_status = "Not checked"
	if available and not InputMap.has_action("speech_talk"):
		InputMap.add_action("speech_talk")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_E
		InputMap.action_add_event("speech_talk", key)

func open(encounter_id: String, lesson: Resource) -> void:
	close()
	if not available:
		return
	var encounter: Dictionary = lesson.encounters[encounter_id]
	var examples: Array[Dictionary] = []
	for choice in encounter.choices:
		examples.append({"text": choice[1], "quality": choice[2], "feedback": choice[3]})
	_lesson = {
		"encounter_id": encounter_id,
		"prompt": encounter.prompt,
		"rubric": lesson.speech_rubric,
		"target_vocabulary": PackedStringArray(lesson.speech_vocabulary.get(encounter_id, [])),
		"examples": examples,
	}
	# The E press that opened the conversation must be released before push-to-talk can begin.
	_wait_for_release = Input.is_action_pressed("speech_talk")
	state_changed.emit("idle")

func close() -> void:
	if _is_stt_active():
		_set_stt_status("Cancelled")
	_lesson.clear()
	_session_id = 0
	if is_instance_valid(module):
		module.cancel_answer()

func cancel_for_playback() -> void:
	if available and module.state == "recording":
		module.cancel_answer()

func _input(event: InputEvent) -> void:
	if _lesson.is_empty() or not available:
		return
	if event.is_action_released("speech_talk"):
		if _wait_for_release:
			_wait_for_release = false
		else:
			module.finish_answer()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("speech_talk") and not _wait_for_release:
		if module.state in ["idle", "completed", "failed"]:
			last_transcript = ""
			_set_stt_status("Connecting")
			recording_started.emit()
			_session_id = module.begin_answer(_lesson)
		get_viewport().set_input_as_handled()

func _state_changed(state: String) -> void:
	if not _lesson.is_empty():
		if state == "idle" and _is_stt_active():
			_set_stt_status("Cancelled")
		state_changed.emit(state)

func _failed(_code: String, message: String) -> void:
	if not _lesson.is_empty():
		if last_transcript.is_empty():
			_set_stt_status("Failed: " + message)
		failed.emit(message)

func _answer_ready(result: Dictionary) -> void:
	if result.session_id == _session_id and result.encounter_id == _lesson.get("encounter_id", ""):
		answer_ready.emit(result)

func _partial_transcript(text: String) -> void:
	if not _lesson.is_empty():
		partial_transcript.emit(text)

func _transcription_status(status: String) -> void:
	if _lesson.is_empty():
		return
	var labels := {
		"connecting": "Connecting",
		"connected": "Connected",
		"streaming": "Streaming audio",
		"receiving_words": "Receiving words",
	}
	if labels.has(status):
		_set_stt_status(labels[status])

func _transcript_ready(session_id: int, text: String) -> void:
	if session_id != _session_id or _lesson.is_empty():
		return
	last_transcript = text
	_set_stt_status("Transcript received")

func _set_stt_status(value: String) -> void:
	if stt_status == value:
		return
	stt_status = value
	debug_changed.emit()

func _is_stt_active() -> bool:
	return stt_status in ["Connecting", "Connected", "Streaming audio", "Receiving words"]
