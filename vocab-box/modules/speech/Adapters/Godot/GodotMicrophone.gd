extends "res://modules/speech/Core/Ports/Driven/RecordingPort.gd"

const Contracts = preload("res://modules/speech/Core/Domain/SpeechContracts.gd")

var _effect := AudioEffectCapture.new()
var _player := AudioStreamPlayer.new()
var _bus_name := ""
var _pcm := PackedByteArray()
var _sample_rate := 0
var _discarded_at_start := 0
var _recording := false
var _has_signal := false
var _sent_bytes := 0

func _ready() -> void:
	_bus_name = "SpeechCapture_%s" % get_instance_id()
	_effect.buffer_length = 1.0
	AudioServer.add_bus()
	var bus := AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus, _bus_name)
	AudioServer.add_bus_effect(bus, _effect)
	# Capture the microphone without routing its sound back to the speakers.
	AudioServer.set_bus_mute(bus, true)
	_player.bus = _bus_name
	_player.stream = AudioStreamMicrophone.new()
	add_child(_player)

func start_capture() -> Dictionary:
	if not ProjectSettings.get_setting("audio/driver/enable_input", false):
		return Contracts.failure("microphone_disabled", "Microphone input is not enabled.")
	_effect.clear_buffer()
	_pcm.clear()
	_sent_bytes = 0
	_has_signal = false
	_sample_rate = int(AudioServer.get_mix_rate())
	_discarded_at_start = _effect.get_discarded_frames()
	_player.play()
	_recording = true
	return Contracts.success(_sample_rate)

func pump() -> Dictionary:
	if not _recording:
		return Contracts.success(PackedByteArray())
	if _effect.get_discarded_frames() != _discarded_at_start:
		return Contracts.failure("audio_overflow", "Some microphone audio was lost. Please try again.")
	var count := _effect.get_frames_available()
	if count == 0:
		return Contracts.success(PackedByteArray())
	var next_size := _pcm.size() + count * 2
	if next_size > _sample_rate * 2 * 30:
		return Contracts.failure("recording_too_long", "Please try a shorter answer.")
	var frames := _effect.get_buffer(count)
	if frames.size() != count or _pcm.resize(next_size) != OK:
		return Contracts.failure("audio_overflow", "Some microphone audio was lost. Please try again.")
	# Convert the microphone's stereo frames to mono PCM16 for the transcription adapter.
	var byte_index := next_size - count * 2
	for frame in frames:
		var sample := int(clampf((frame.x + frame.y) * 0.5, -1.0, 1.0) * 32767.0)
		_has_signal = _has_signal or sample != 0
		_pcm[byte_index] = sample & 0xff
		_pcm[byte_index + 1] = (sample >> 8) & 0xff
		byte_index += 2
	if _pcm.size() - _sent_bytes < _sample_rate * 2 / 10:
		return Contracts.success(PackedByteArray())
	var chunk := _pcm.slice(_sent_bytes)
	_sent_bytes = _pcm.size()
	return Contracts.success(chunk)

func stop_capture() -> Dictionary:
	if not _recording:
		return Contracts.failure("not_recording", "There is no recording to submit.")
	var drained := pump()
	if not drained.ok:
		cancel_capture()
		return drained
	if not _has_signal:
		cancel_capture()
		return Contracts.failure("empty_audio", "No microphone audio was captured. Check your microphone and try again.")
	var tail: PackedByteArray = drained.value
	if tail.is_empty():
		tail = _pcm.slice(_sent_bytes)
	var audio := {
		"pcm": tail,
		"sample_rate": _sample_rate,
		"channels": 1,
		"captured_bytes": _pcm.size(),
	}
	cancel_capture()
	return Contracts.success(audio)

func cancel_capture() -> void:
	_player.stop()
	_recording = false
	_effect.clear_buffer()
	_pcm.clear()
	_sent_bytes = 0

func _exit_tree() -> void:
	cancel_capture()
	var bus := AudioServer.get_bus_index(_bus_name)
	if bus >= 0:
		AudioServer.remove_bus(bus)
