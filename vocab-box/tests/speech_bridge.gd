extends SceneTree

var failures := 0
var failure_code := ""
var states: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var module = load("res://modules/speech/SpeechModule.tscn").instantiate()
	root.add_child(module)
	module.failed.connect(func(code: String, _message: String): failure_code = code)
	module.state_changed.connect(func(state: String): states.append(state))
	var lesson = load("res://lessons/banana.tres")
	var data := {
		"encounter_id": "worker", "prompt": lesson.encounters.worker.prompt,
		"rubric": lesson.speech_rubric,
		"target_vocabulary": PackedStringArray(["bananas"]),
		"examples": [{"text": "Where are the bananas?", "quality": 1, "feedback": "Correct English."}],
	}
	check(module.begin_answer(data) == 0 and failure_code == "not_configured", "Unconfigured bridge reports a typed error")
	check(not module.configure("", "fixture-deepseek-key"), "Bad configuration is rejected")
	check(module.configuration_reason.contains("API key"), "Bad configuration reports the missing key")
	# Providers are never contacted: this headless test exercises capture failure and cancellation.
	check(module.configure("fixture-key", "fixture-deepseek-key"), "Configured bridge loads")
	var id: int = module.begin_answer(data)
	check(id > 0 and module.state == "recording", "GDScript module starts recording with a lesson dictionary")
	module.cancel_answer()
	check(module.state == "idle", "The bridge cancels recording")
	check(states.has("recording") and states.has("idle"), "Module state signals reach the game")
	module.begin_answer(data)
	module.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(module.state == "idle", "Losing focus cancels microphone capture")
	# A dummy audio driver cannot record speech; it must never produce an assessment.
	var answers: Array = []
	module.answer_ready.connect(func(result: Dictionary): answers.append(result))
	module.begin_answer(data)
	module.finish_answer()
	for frame in range(10):
		await process_frame
	check(failure_code == "empty_audio", "Missing microphone samples produce an audio error")
	check(answers.is_empty(), "Capture failure never produces a language score")
	var buses := AudioServer.bus_count
	module.queue_free()
	await process_frame
	await process_frame
	check(AudioServer.bus_count == buses - 1, "Module removes its private recording bus")
	print("Speech bridge: ", failures, " failures")
	quit(0 if failures == 0 else 1)
