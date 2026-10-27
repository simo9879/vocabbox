extends SceneTree

const Contracts = preload("res://modules/speech/Core/Domain/SpeechContracts.gd")
const Endpoint = preload("res://modules/speech/Adapters/Http/HttpEndpoint.gd")
const Transcriber = preload("res://modules/speech/Adapters/Http/HttpSpeechTranscriber.gd")
const Evaluator = preload("res://modules/speech/Adapters/Http/HttpAnswerEvaluator.gd")

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	check(Endpoint.is_allowed_endpoint("https://example.com/transcribe"), "HTTPS endpoint is allowed")
	check(Endpoint.is_allowed_endpoint("http://127.0.0.1:18971/transcribe"), "Loopback HTTP endpoint is allowed")
	check(not Endpoint.is_allowed_endpoint("http://example.com/transcribe"), "Remote plaintext endpoint is rejected")
	check(not Endpoint.is_allowed_endpoint("https://user@example.com/transcribe"), "Credentials in URL are rejected")
	check(
		not Endpoint.is_allowed_endpoint("https://example.com:bad/transcribe"),
		"Malformed port is rejected during configuration"
	)
	var base := OS.get_environment("VOCAB_SPEECH_TEST_URL")
	if base.is_empty():
		push_error("Start tests/speech_gateway_server.py and set VOCAB_SPEECH_TEST_URL.")
		quit(1)
		return
	var transcriber = Transcriber.new()
	var evaluator = Evaluator.new()
	root.add_child(transcriber)
	root.add_child(evaluator)
	check(transcriber.configure(base + "/transcribe", ""), "Transcriber accepts loopback fixture")
	check(evaluator.configure(base + "/evaluate", ""), "Evaluator accepts loopback fixture")
	var transcription: Array[Dictionary] = []
	var evaluation: Array[Dictionary] = []
	transcriber.completed.connect(func(_id: int, result: Dictionary): transcription.append(result))
	evaluator.completed.connect(func(_id: int, result: Dictionary): evaluation.append(result))
	var pcm := PackedByteArray()
	pcm.resize(3200)
	pcm[0] = 1
	transcriber.start_session(1, 8000)
	transcriber.push_audio(1, pcm)
	transcriber.finish_session(1)
	await _wait_for_result(transcription)
	check(
		transcription.size() == 1 and transcription[0].ok and transcription[0].value == "Where are the bananas?",
		"WAV upload produces a transcript"
	)
	var lesson := {
		"encounter_id": "worker", "prompt": "Where are the bananas?", "rubric": "Reward clear requests.",
		"target_vocabulary": PackedStringArray(["bananas"]),
		"examples": [{"text": "Where are the bananas?", "quality": 1, "feedback": "Correct English."}],
	}
	evaluator.evaluate(1, "Where are the bananas?", lesson)
	await _wait_for_result(evaluation)
	check(evaluation.size() == 1 and evaluation[0].ok, "Evaluation JSON reaches the gateway")
	if evaluation.size() == 1 and evaluation[0].ok:
		check(
			Contracts.validate_assessment(evaluation[0].value, "Where are the bananas?", lesson).ok,
			"Gateway assessment passes domain validation"
		)
	check(transcriber.configure(base + "/slow", ""), "Slow fixture is configured")
	transcriber.start_session(2, 8000)
	transcriber.push_audio(2, pcm)
	transcriber.finish_session(2)
	transcriber.cancel()
	await create_timer(0.65).timeout
	check(transcription.size() == 1, "Cancelled HTTP request cannot publish a late result")
	transcriber.queue_free()
	evaluator.queue_free()
	await process_frame
	print("Speech HTTP: ", failures, " failures")
	quit(0 if failures == 0 else 1)

func _wait_for_result(results: Array[Dictionary]) -> void:
	var deadline := Time.get_ticks_msec() + 3000
	while results.is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
