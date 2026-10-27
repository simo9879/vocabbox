extends SceneTree

const Transcriber = preload("res://modules/speech/Adapters/ElevenLabs/RealtimeTranscriber.gd")

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var ws_url := OS.get_environment("VOCAB_SPEECH_TEST_WS_URL")
	if ws_url.is_empty():
		push_error("Set VOCAB_SPEECH_TEST_WS_URL for the loopback fixture.")
		quit(1)
		return
	var transcriber = Transcriber.new()
	root.add_child(transcriber)
	check(not transcriber.configure("", ws_url), "Missing API key is rejected")
	check(transcriber.configure("fixture-key", ws_url), "Loopback fixture is accepted")
	check(not transcriber.configure("fixture-key", "ws://example.com"), "Remote plaintext WebSocket is rejected")
	check(transcriber.configure("fixture-key", ws_url), "Fixture can be configured again")
	var results: Array[Dictionary] = []
	var partials: Array[String] = []
	var activity: Array[String] = []
	transcriber.completed.connect(func(_id: int, result: Dictionary): results.append(result))
	transcriber.partial_transcript.connect(func(_id: int, value: String): partials.append(value))
	transcriber.activity.connect(func(_id: int, value: String): activity.append(value))
	var pcm := PackedByteArray()
	pcm.resize(1600)
	transcriber.start_session(1, 16000)
	for index in 3:
		transcriber.push_audio(1, pcm)
	transcriber.finish_session(1)
	await _wait_for_result(results)
	check(results.size() == 1 and results[0].ok and results[0].value == "Where are the bananas?", "PCM chunks are committed over WebSocket")
	check(partials.has("Where are"), "Partial transcript arrives before the committed answer")
	check(activity.has("connected") and activity.has("streaming") and activity.has("receiving_words"), "Connection and live transcription states are reported")
	transcriber.start_session(2, 16000)
	transcriber.push_audio(2, pcm)
	transcriber.cancel()
	await create_timer(0.2).timeout
	check(results.size() == 1, "Cancelled stream cannot publish a transcript")
	transcriber.queue_free()
	await process_frame
	print("Speech realtime: ", failures, " failures")
	quit(0 if failures == 0 else 1)

func _wait_for_result(results: Array[Dictionary]) -> void:
	var deadline := Time.get_ticks_msec() + 5000
	while results.is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
