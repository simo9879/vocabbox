extends RefCounted

const MAX_TRANSCRIPT := 8000
const MAX_FEEDBACK := 2000
const MAX_PIP_RESPONSE := 400
const MAX_VOCABULARY_USES := 100

static func success(value: Variant = null) -> Dictionary:
	return {"ok": true, "value": value}

static func failure(code: String, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message}

static func validate_lesson(lesson: Dictionary) -> Dictionary:
	if not _has_text(lesson, "encounter_id") or not _has_text(lesson, "prompt") or not _has_text(lesson, "rubric"):
		return failure("invalid_lesson", "The speech lesson is not configured correctly.")
	if not lesson.get("target_vocabulary") is PackedStringArray or not lesson.get("examples") is Array:
		return failure("invalid_lesson", "The speech lesson is not configured correctly.")
	for word in lesson.target_vocabulary:
		if word.strip_edges().is_empty():
			return failure("invalid_lesson", "The speech lesson is not configured correctly.")
	for example in lesson.examples:
		if not example is Dictionary or not _has_text(example, "text") or not _has_quality(example, "quality"):
			return failure("invalid_lesson", "The speech lesson is not configured correctly.")
	return success(lesson.duplicate(true))

static func validate_audio(audio: Dictionary) -> Dictionary:
	var pcm: Variant = audio.get("pcm")
	var rate: Variant = audio.get("sample_rate")
	var channels: Variant = audio.get("channels")
	if not pcm is PackedByteArray or not rate is int or not channels is int:
		return failure("invalid_audio", "The recording format is not supported.")
	if rate < 8000 or rate > 192000 or channels < 1 or channels > 2 or pcm.size() % (channels * 2) != 0:
		return failure("invalid_audio", "The recording format is not supported.")
	var captured_bytes: Variant = audio.get("captured_bytes", pcm.size())
	if not captured_bytes is int or captured_bytes < pcm.size() or captured_bytes % (channels * 2) != 0:
		return failure("invalid_audio", "The recording format is not supported.")
	var duration := float(captured_bytes) / float(rate * channels * 2)
	if duration < 0.15:
		return failure("empty_audio", "Hold E while speaking, then release it.")
	if duration > 30.0:
		return failure("recording_too_long", "Please try a shorter answer.")
	return success(audio)

static func validate_transcript(value: Variant) -> Dictionary:
	if not value is String or value.strip_edges().is_empty():
		return failure("no_speech", "I could not hear an answer. Please try again.")
	if value.length() > MAX_TRANSCRIPT:
		return failure("invalid_transcript", "The transcription could not be used. Please try again.")
	return success(value.strip_edges())

static func validate_assessment(value: Variant, transcript: String, lesson: Dictionary) -> Dictionary:
	if not value is Dictionary or not _has_quality(value, "quality"):
		return _invalid_assessment()
	if not _has_assessment_text(value):
		return _invalid_assessment()
	var uses: Variant = value.get("vocabulary_used")
	if not uses is Array or uses.size() > MAX_VOCABULARY_USES:
		return _invalid_assessment()
	for use in uses:
		if not use is Dictionary or not _has_bounded_text(use, "word", 100) or not _has_bounded_text(use, "evidence", 1000):
			return _invalid_assessment()
		if not _is_target_word(use.word, lesson.target_vocabulary) or not transcript.to_lower().contains(use.evidence.to_lower()):
			return _invalid_assessment()
	var assessment: Dictionary = value.duplicate(true)
	assessment.quality = int(value.quality)
	return success(assessment)

static func _has_text(data: Dictionary, key: String) -> bool:
	return data.get(key) is String and not data[key].strip_edges().is_empty()

static func _has_bounded_text(data: Dictionary, key: String, limit: int) -> bool:
	return _has_text(data, key) and data[key].length() <= limit

static func _has_assessment_text(data: Dictionary) -> bool:
	return _has_bounded_text(data, "feedback", MAX_FEEDBACK) \
		and _has_bounded_text(data, "suggested_wording", MAX_FEEDBACK) \
		and _has_bounded_text(data, "pip_response", MAX_PIP_RESPONSE)

static func _has_quality(data: Dictionary, key: String) -> bool:
	var quality: Variant = data.get(key)
	if quality is int:
		return quality >= 0 and quality <= 2
	# Godot's JSON parser represents integer-looking numbers as floats.
	return quality is float and quality >= 0.0 and quality <= 2.0 and quality == floorf(quality)

static func _is_target_word(word: String, targets: PackedStringArray) -> bool:
	for target in targets:
		if target.to_lower() == word.to_lower():
			return true
	return false

static func _invalid_assessment() -> Dictionary:
	return failure("invalid_assessment", "The evaluator returned an unusable assessment.")
