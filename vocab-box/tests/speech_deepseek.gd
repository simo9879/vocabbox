extends SceneTree

const Contracts = preload("res://modules/speech/Core/Domain/SpeechContracts.gd")
const Evaluator = preload("res://modules/speech/Adapters/DeepSeek/DeepSeekAnswerEvaluator.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var base := OS.get_environment("VOCAB_SPEECH_TEST_URL")
	if base.is_empty():
		push_error("Start tests/speech_deepseek_server.py and set VOCAB_SPEECH_TEST_URL.")
		quit(1)
		return
	var evaluator = Evaluator.new()
	root.add_child(evaluator)
	check(not evaluator.configure("", base + "/evaluate"), "Missing DeepSeek key is rejected")
	check(not evaluator.configure("fixture-deepseek-key", "http://example.com/evaluate"), "Remote plaintext is rejected")
	check(evaluator.configure("fixture-deepseek-key", base + "/evaluate"), "Loopback evaluator is configured")
	var lesson := {
		"encounter_id": "worker", "prompt": "Hello! What are you looking for?", "rubric": "Reward clear polite requests.",
		"target_vocabulary": PackedStringArray(["bananas" , "please" , "where"]),
		"examples": [{"text": "Where are the bananas please?", "quality": 1, "feedback": "Correct English."}],
	}
	var results: Array[Dictionary] = []
	evaluator.completed.connect(func(_id: int, result: Dictionary): results.append(result))
	evaluator.(1, "Where are the bananas?", lesson)
	await _wait_for_result(results)
	check(results.size() == 1 and results[0].ok, "DeepSeek response is decoded")
	if results.size() == 1 and results[0].ok:
		check(Contracts.validate_assessment(results[0].value, "Where are the bananas?", lesson).ok, "Assessment passes the lesson contract")

	results.clear()
	check(evaluator.configure("fixture-deepseek-key", base + "/blocked"), "Blocked fixture is configured")
	evaluator.evaluate(2, "Where are the bananas?", lesson)
	await _wait_for_result(results)
	check(results.size() == 1 and not results[0].ok, "Blocked output does not score an answer")

	results.clear()
	check(evaluator.configure("fixture-deepseek-key", base + "/malformed"), "Malformed fixture is configured")
	evaluator.evaluate(3, "Where are the bananas?", lesson)
	await _wait_for_result(results)
	check(results.size() == 1 and not results[0].ok, "Malformed JSON does not score an answer")

	results.clear()
	check(evaluator.configure("fixture-deepseek-key", base + "/truncated"), "Truncated fixture is configured")
	evaluator.evaluate(4, "Where are the bananas?", lesson)
	await _wait_for_result(results)
	check(results.size() == 1 and not results[0].ok, "Truncated output does not score an answer")

	results.clear()
	check(evaluator.configure("fixture-deepseek-key", base + "/slow"), "Slow fixture is configured")
	evaluator.evaluate(5, "Where are the bananas?", lesson)
	evaluator.cancel()
	await create_timer(0.7).timeout
	check(results.is_empty(), "Cancelled evaluation cannot publish a late answer")
	evaluator.queue_free()
	await process_frame
	print("Speech DeepSeek: ", failures, " failures")
	quit(0 if failures == 0 else 1)

func _wait_for_result(results: Array[Dictionary]) -> void:
	var deadline := Time.get_ticks_msec() + 3000
	while results.is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
