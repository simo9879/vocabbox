extends SceneTree

const SpeechEnvironment = preload("res://scripts/speech_environment.gd")
const SynthesisPort = preload("res://modules/speech/Core/Ports/Driven/SpeechSynthesisPort.gd")

# Exercise the game dialogue wiring with a module double and no microphone or provider.
class ModuleDouble extends Node:
	var state := "idle"
	var starts := 0
	func begin_answer(_lesson: Dictionary) -> int:
		starts += 1
		state = "recording"
		return starts
	func finish_answer() -> void:
		state = "transcribing"
	func cancel_answer() -> void:
		state = "idle"

class VoiceDouble extends SynthesisPort:
	var requested := ""
	var request_id := 0
	func configure(_api_key: String) -> bool:
		return true
	func synthesize(id: int, line: String) -> void:
		request_id = id
		requested = line
	func cancel() -> void:
		pass

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	if DisplayServer.get_name() == "headless":
		root.size = Vector2i(1280, 720)
		await process_frame
	check(game.speech_debug_status.text.contains("Speech available: " + str(game.speech.available)), "Debug badge reflects actual speech availability")
	check(not game.speech.availability_reason.is_empty(), "Debug badge has a configuration reason")
	if SpeechEnvironment.get_value("ELEVENLABS_API_KEY").is_empty():
		check(game.speech.availability_reason.contains("API key"), "Badge names the missing API key")
	if SpeechEnvironment.get_value("AI_API_KEY").is_empty():
		check(game.speech.availability_reason.contains("DeepSeek API key"), "Badge names the missing DeepSeek key")
	elif not SpeechEnvironment.get_value("ELEVENLABS_API_KEY").is_empty():
		check(game.speech.available, "Both provider keys enable the speech route")
	check(not game.speech.availability_reason.contains("Godot .NET"), "Standard Godot no longer needs .NET for speech")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/vocab-speech-debug-disabled.png")

	var module_double := ModuleDouble.new()
	game.speech.add_child(module_double)
	game.speech.module = module_double
	game.speech.available = true
	game.speech.availability_reason = "Module double for UI test"
	game.update_speech_debug()
	check(game.speech_debug_status.text.contains("Speech available: true"), "Debug badge shows enabled speech")
	game.mission.enter()
	if not InputMap.has_action("speech_talk"):
		InputMap.add_action("speech_talk")
	game.conversation("worker")
	await process_frame
	check(game.speech_prompt.visible, "Configured dialogue shows the speaking prompt")
	game.speech._failed("service_unavailable", "Could not connect.")
	check(game.speech_debug_status.text.contains("STT: Failed: Could not connect."), "Badge reports transcription failure")
	game.speech._transcription_status("connected")
	check(game.speech_debug_status.text.contains("STT: Connected"), "Badge shows a live transcription connection")
	game.speech._state_changed("idle")
	check(game.speech_debug_status.text.contains("STT: Cancelled"), "Badge reports a cancelled connection")
	game.speech._transcription_status("connected")
	check(game.speech_debug_status.get_global_rect().end.x < game.speech_prompt.get_global_rect().position.x, "Debug badge stays clear of speaking prompt")
	game.speech._session_id = 3
	game.speech._transcript_ready(2, "Stale words")
	check(not game.speech_debug_status.text.contains("Stale words"), "Badge ignores an old transcript")
	game.speech._transcript_ready(3, "Where are the bananas?")
	game.speech._state_changed("evaluating")
	check(game.speech_debug_status.text.contains("STT: Transcript received"), "Badge confirms committed transcription")
	check(game.speech_debug_status.text.contains("Heard: “Where are the bananas?”"), "Badge shows the recognized phrase")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/vocab-stt-debug-transcribed.png")
	game.speech._failed("service_unavailable", "Evaluator unavailable.")
	check(game.speech_debug_status.text.contains("STT: Transcript received"), "Evaluation failure does not erase STT success")
	check(game.speech_prompt.position.y > 540 and game.speech_prompt.get_global_rect().end.y <= 720, "Speaking prompt sits at the bottom at 720p")
	check(game.panel.get_global_rect().end.y < game.speech_prompt.get_global_rect().position.y, "Conversation card does not overlap the speaking prompt")
	check(is_equal_approx(game.panel.anchor_bottom, 0.50), "Dialogue fits the speaking controls")
	check(game.panel.find_children("*", "Button", true, false).size() == 2, "Configured dialogue omits answer choices")
	game.speech._state_changed("recording")
	check(game.speech_prompt.bars.visible, "Recording shows the listening animation")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/vocab-speech-listening-" + str(root.size.x) + ".png")
	game.mission.failures.worker = 2
	game.conversation("worker")
	await process_frame
	check(is_equal_approx(game.panel.anchor_bottom, 0.66), "Model phrase has room in the dialogue card")
	check(game.panel.find_children("*", "Button", true, false).size() == 3, "Speech retry offers an audible model phrase")
	# The presentation check routes generated text through a fake voice service.
	var voice_double := VoiceDouble.new()
	check(game.pip_voice.configure(game.voice, voice_double), "Dialogue accepts a replaceable Pip voice service")
	game.spoken_answer({"encounter_id": "worker", "quality": 1, "allowed": true, "transcript": "Where are the bananas?", "feedback": "Correct!", "pip_response": "Great! You asked about the bananas clearly.", "suggested_wording": "Please show me the bananas."})
	check(game.mission.stage == 2 and not game.speech_prompt.visible, "Spoken answer follows the mission and closes the prompt")
	check(voice_double.requested == "Great! You asked about the bananas clearly.", "Pip's generated line reaches the voice service")
	voice_double.completed.emit(voice_double.request_id, {"ok": false, "code": "service_unavailable", "message": "ElevenLabs HTTP 422 · model_not_supported"})
	check(game.speech_debug_status.text.contains("Pip TTS: Failed: ElevenLabs HTTP 422"), "TTS failure stays visible in the debug badge")
	check(game.speech_debug_status.get_theme_color("font_color") == Color("ff9a90"), "TTS failure gives the debug badge an error color")
	check(game.panel.find_children("*", "Label", true, false).any(func(label: Label): return label.text.contains("Pip audio: ElevenLabs HTTP 422")), "Provider error appears in the review panel")
	check(game.panel.find_children("*", "Label", true, false).any(func(label: Label): return label.text.contains("AI review (debug): Correct!")), "AI review remains visible for debugging")
	check(game.panel.find_children("*", "Label", true, false).any(func(label: Label): return label.text.contains("Pip: “Great!")), "Pip's generated response is shown")
	game.resume()
	check(not game.speech_prompt.visible and module_double.state == "idle", "Leaving dialogue hides and cancels speech")

	game.speech.available = false
	game.conversation("worker")
	await process_frame
	check(not game.speech_prompt.visible, "Unconfigured dialogue does not show the speaking prompt")
	check(game.panel.find_children("*", "Button", true, false).size() == 8, "Unconfigured dialogue keeps authored choices")

	for audio in [game.voice, game.music, game.effects]:
		audio.stop()
		audio.stream = null
	await create_timer(0.15).timeout
	game.queue_free()
	await process_frame
	await process_frame
	print("Speech conversation: ", failures, " failures")
	quit(0 if failures == 0 else 1)
