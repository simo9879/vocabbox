extends SceneTree

const Synthesizer = preload("res://modules/speech/Adapters/ElevenLabs/ElevenLabsTextToSpeech.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var base := OS.get_environment("VOCAB_SPEECH_TEST_URL")
	if base.is_empty():
		push_error("Start tests/pip_tts_server.py and set VOCAB_SPEECH_TEST_URL.")
		quit(1)
		return
	var synthesizer = Synthesizer.new()
	root.add_child(synthesizer)
	var url := base + "/v1/text-to-speech/" + Synthesizer.VOICE_ID + "?output_format=mp3_44100_128"
	check(not synthesizer.configure("", url), "Missing ElevenLabs key is rejected")
	check(synthesizer.configure("fixture-elevenlabs-key", url), "Loopback TTS is configured")
	var results: Array[Dictionary] = []
	synthesizer.completed.connect(func(_id: int, result: Dictionary): results.append(result))
	synthesizer.synthesize(1, "Great answer!")
	await _wait_for_result(results)
	check(results.size() == 1 and results[0].ok, "ElevenLabs request returns decodable MP3 audio")
	if results.size() == 1 and results[0].ok:
		check(results[0].value is AudioStreamMP3 and results[0].value.get_length() > 0, "MP3 is ready for the Voice bus")
	results.clear()
	synthesizer.synthesize(2, "")
	check(results.size() == 1 and not results[0].ok, "Empty Pip lines are rejected before sending")
	results.clear()
	check(synthesizer.configure("fixture-elevenlabs-key", url + "&bad=1"), "Malformed fixture is configured")
	synthesizer.synthesize(3, "Great answer!")
	await _wait_for_result(results)
	check(results.size() == 1 and not results[0].ok and results[0].message.contains("non-MP3"), "Non-MP3 response reports its format")
	results.clear()
	check(synthesizer.configure("fixture-elevenlabs-key", url + "&error=1"), "Provider error fixture is configured")
	synthesizer.synthesize(4, "Great answer!")
	await _wait_for_result(results)
	check(results.size() == 1 and not results[0].ok and results[0].message.contains("HTTP 422"), "Provider HTTP status reaches the screen")
	check(results[0].message.contains("model_not_supported") and results[0].message.contains("cannot use eleven_v4"), "Provider code and message are preserved")
	check(not results[0].message.contains("fixture-elevenlabs-key"), "Debug text does not reveal the API key")
	check(Synthesizer._transport_error(HTTPRequest.RESULT_TIMEOUT, 0).contains("timed out after 30 seconds"), "Timeout names the transport failure")
	results.clear()
	check(synthesizer.configure("fixture-elevenlabs-key", url + "&slow=1"), "Slow fixture is configured")
	synthesizer.synthesize(5, "Great answer!")
	synthesizer.cancel()
	await create_timer(0.7).timeout
	check(results.is_empty(), "Cancelled TTS cannot publish late audio")
	synthesizer.queue_free()
	await process_frame
	print("Pip TTS: ", failures, " failures")
	quit(0 if failures == 0 else 1)

func _wait_for_result(results: Array[Dictionary]) -> void:
	var deadline := Time.get_ticks_msec() + 3000
	while results.is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
