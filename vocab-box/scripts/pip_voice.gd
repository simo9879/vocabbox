extends Node

const ElevenLabsTextToSpeech = preload("res://modules/speech/Adapters/ElevenLabs/ElevenLabsTextToSpeech.gd")
const SpeechEnvironment = preload("res://scripts/speech_environment.gd")

signal failed(message: String)
signal status_changed(status: String)

var _player: AudioStreamPlayer
var _synthesizer: Node
var _request_id := 0
var _active_text := ""
var _cached_text := ""
var _cached_stream: AudioStream
var is_configured := false

func configure(player: AudioStreamPlayer, synthesizer: Node = null) -> bool:
	cancel()
	if is_instance_valid(_synthesizer):
		remove_child(_synthesizer)
		_synthesizer.queue_free()
	if is_instance_valid(_player):
		_player.stop()
	_player = player
	_cached_text = ""
	_cached_stream = null
	is_configured = false
	_synthesizer = synthesizer if synthesizer != null else ElevenLabsTextToSpeech.new()
	add_child(_synthesizer)
	_synthesizer.completed.connect(_on_completed)
	is_configured = _synthesizer.configure(SpeechEnvironment.get_value("ELEVENLABS_API_KEY"))
	status_changed.emit("Ready" if is_configured else "Not configured")
	return is_configured

func speak(text: String) -> void:
	if not is_configured:
		_report_failure("Pip's voice is not configured.")
		return
	cancel()
	_player.stop()
	# Replay the last generated line without spending another TTS request.
	if text == _cached_text and is_instance_valid(_cached_stream):
		_play(_cached_stream)
		status_changed.emit("Playing cached audio")
		return
	_request_id += 1
	_active_text = text
	status_changed.emit("Requesting ElevenLabs TTS")
	_synthesizer.synthesize(_request_id, text)

func cancel() -> void:
	var was_requesting := not _active_text.is_empty()
	_request_id += 1
	_active_text = ""
	if is_instance_valid(_synthesizer):
		_synthesizer.cancel()
	if was_requesting:
		status_changed.emit("Cancelled")

func has_cached_line(text: String) -> bool:
	return text == _cached_text and is_instance_valid(_cached_stream)

func _on_completed(request_id: int, result: Dictionary) -> void:
	# Closing a dialogue or starting another line invalidates late audio.
	if request_id != _request_id or _active_text.is_empty():
		return
	if not result.ok:
		_active_text = ""
		_report_failure(result.message)
		return
	_cached_text = _active_text
	_cached_stream = result.value
	_active_text = ""
	_play(_cached_stream)
	status_changed.emit("Playing generated audio")

func _report_failure(message: String) -> void:
	status_changed.emit("Failed: " + message)
	failed.emit(message)

func _play(stream: AudioStream) -> void:
	_player.stream = stream
	_player.play()
