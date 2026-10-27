extends SceneTree

const PipVoice = preload("res://scripts/pip_voice.gd")
const SynthesisPort = preload("res://modules/speech/Core/Ports/Driven/SpeechSynthesisPort.gd")

class FakeSynthesizer extends SynthesisPort:
	var requests: Array[Dictionary] = []
	var cancellations := 0
	func configure(_api_key: String) -> bool:
		return true
	func synthesize(request_id: int, spoken_text: String) -> void:
		requests.append({"id": request_id, "text": spoken_text})
	func cancel() -> void:
		cancellations += 1
	func complete(request_id: int, stream: AudioStream) -> void:
		completed.emit(request_id, {"ok": true, "value": stream})

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var player := AudioStreamPlayer.new()
	root.add_child(player)
	var pip_voice = PipVoice.new()
	root.add_child(pip_voice)
	var fake := FakeSynthesizer.new()
	check(pip_voice.configure(player, fake), "Pip voice accepts a replaceable synthesizer")
	var audio := AudioStreamWAV.new()
	audio.mix_rate = 8000
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.data = PackedByteArray()
	audio.data.resize(1600)
	pip_voice.speak("Great answer!")
	var first_id: int = fake.requests.back().id
	pip_voice.cancel()
	fake.complete(first_id, audio)
	check(player.stream == null, "Cancelled speech ignores late audio")
	pip_voice.speak("Great answer!")
	var second_id: int = fake.requests.back().id
	fake.complete(second_id, audio)
	check(player.stream == audio and pip_voice.has_cached_line("Great answer!"), "Successful speech is played and cached")
	pip_voice.speak("Great answer!")
	check(fake.requests.size() == 2, "Replay uses cached audio without a second API call")
	pip_voice.speak("Try another phrase!")
	check(fake.requests.size() == 3 and fake.requests.back().text == "Try another phrase!", "New text requests new audio")
	check(fake.cancellations >= 3, "New speech cancels pending synthesis")
	player.stop()
	player.stream = null
	pip_voice.queue_free()
	player.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.2).timeout
	print("Pip voice: ", failures, " failures")
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
