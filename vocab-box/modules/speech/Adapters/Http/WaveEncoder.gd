extends RefCounted

# The speech gateway accepts PCM16 in a standard little-endian WAV container.
static func encode(audio: Dictionary) -> PackedByteArray:
	var pcm: PackedByteArray = audio.pcm
	var channels: int = audio.channels
	var rate: int = audio.sample_rate
	var wave := PackedByteArray()
	wave.resize(44 + pcm.size())
	_write_text(wave, 0, "RIFF")
	_write_u32(wave, 4, 36 + pcm.size())
	_write_text(wave, 8, "WAVEfmt ")
	_write_u32(wave, 16, 16)
	_write_u16(wave, 20, 1)
	_write_u16(wave, 22, channels)
	_write_u32(wave, 24, rate)
	_write_u32(wave, 28, rate * channels * 2)
	_write_u16(wave, 32, channels * 2)
	_write_u16(wave, 34, 16)
	_write_text(wave, 36, "data")
	_write_u32(wave, 40, pcm.size())
	for index in pcm.size():
		wave[44 + index] = pcm[index]
	return wave

static func _write_text(bytes: PackedByteArray, offset: int, value: String) -> void:
	var encoded := value.to_ascii_buffer()
	for index in encoded.size():
		bytes[offset + index] = encoded[index]

static func _write_u16(bytes: PackedByteArray, offset: int, value: int) -> void:
	bytes[offset] = value & 0xff
	bytes[offset + 1] = (value >> 8) & 0xff

static func _write_u32(bytes: PackedByteArray, offset: int, value: int) -> void:
	for index in 4:
		bytes[offset + index] = (value >> (index * 8)) & 0xff
