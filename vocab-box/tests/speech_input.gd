extends SceneTree

# A module double tests the host input policy without a microphone or network.
class ModuleDouble extends Node:
	var state := "idle"
	var starts := 0
	var finishes := 0
	func begin_answer(_lesson: Dictionary) -> int:
		starts += 1
		state = "recording"
		return starts
	func finish_answer() -> void:
		if state == "recording":
			finishes += 1
			state = "transcribing"
	func cancel_answer() -> void:
		state = "idle"

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func key(pressed: bool, echo: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = pressed
	event.echo = echo
	return event

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	InputMap.add_action("speech_talk")
	InputMap.action_add_event("speech_talk", key(true))
	var driver = load("res://scripts/speech_dialogue.gd").new()
	root.add_child(driver)
	var double := ModuleDouble.new()
	driver.add_child(double)
	driver.module = double
	driver.available = true
	var prompt = load("res://scenes/ui/speech_prompt.tscn").instantiate()
	root.add_child(prompt)
	driver.state_changed.connect(prompt.set_state)
	driver.failed.connect(prompt.show_error)
	var lesson = load("res://lessons/banana.tres")
	Input.action_press("speech_talk")
	driver.open("worker", lesson)
	prompt.show_ready()
	check(prompt.status_label.text.contains("release to submit"), "Conversation shows the speaking instruction")
	driver._input(key(true, true))
	driver._input(key(false))
	Input.action_release("speech_talk")
	check(double.starts == 0 and double.finishes == 0, "Opening E press/release must not submit audio")
	driver._input(key(true))
	driver._input(key(true, true))
	check(double.starts == 1, "Key repeat must not start another recording")
	driver._state_changed("recording")
	check(prompt.bars.visible, "Listening animation appears during recording")
	prompt._process(0.1)
	check(prompt.bars.get_child(0).scale.y != 1.0, "Listening bars animate while E is held")
	driver._input(key(false))
	driver._input(key(false))
	check(double.finishes == 1, "Release submits exactly once")
	driver._state_changed("transcribing")
	check(not prompt.bars.visible and prompt.status_label.text.contains("Transcribing"), "Animation stops when recording ends")
	driver._failed("service_unavailable", "Speech checking is unavailable.")
	check(prompt.status_label.text.contains("Hold E to try again"), "Speech errors remain retryable")
	driver.close()
	prompt.hide_prompt()
	check(double.state == "idle", "Closing dialogue cancels pending work")
	check(not prompt.visible, "Closing dialogue hides the speaking prompt")
	var answers: Array = []
	driver.answer_ready.connect(func(result: Dictionary): answers.append(result))
	driver._answer_ready({"session_id": 1, "encounter_id": "worker"})
	check(answers.is_empty(), "Late assessment is ignored after close")
	driver.open("worker", lesson)
	driver._input(key(true))
	driver.cancel_for_playback()
	check(double.state == "idle", "Narration cancels recording before playback")
	driver.queue_free()
	prompt.queue_free()
	await process_frame
	print("Speech input: ", failures, " failures")
	quit(0 if failures == 0 else 1)
