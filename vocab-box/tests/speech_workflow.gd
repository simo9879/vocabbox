extends SceneTree

const Contracts = preload("res://modules/speech/Core/Domain/SpeechContracts.gd")
const Workflow = preload("res://modules/speech/Core/Application/PracticeSpeech.gd")
const WaveEncoder = preload("res://modules/speech/Adapters/Http/WaveEncoder.gd")

class FakeRecorder extends Node:
	var starts := 0
	var stops := 0
	var cancels := 0
	var audio := {"pcm": PackedByteArray(), "sample_rate": 8000, "channels": 1}
	var next_chunk := PackedByteArray()
	func start_capture() -> Dictionary:
		starts += 1
		return {"ok": true, "value": 8000}
	func pump() -> Dictionary:
		var chunk := next_chunk
		next_chunk = PackedByteArray()
		return {"ok": true, "value": chunk}
	func stop_capture() -> Dictionary:
		stops += 1
		return {"ok": true, "value": audio}
	func cancel_capture() -> void:
		cancels += 1

class FakeTranscriber extends Node:
	signal completed(session_id: int, result: Dictionary)
	signal partial_transcript(session_id: int, text: String)
	signal activity(session_id: int, status: String)
	var requested: Array[int] = []
	var started: Array[int] = []
	var chunks: Array[PackedByteArray] = []
	var cancels := 0
	func start_session(session_id: int, _sample_rate: int) -> void:
		started.append(session_id)
	func push_audio(_session_id: int, pcm: PackedByteArray) -> void:
		chunks.append(pcm)
	func finish_session(session_id: int) -> void:
		requested.append(session_id)
	func cancel() -> void:
		cancels += 1

class FakeEvaluator extends Node:
	signal completed(session_id: int, result: Dictionary)
	var requested: Array[int] = []
	var last_transcript := ""
	var cancels := 0
	func evaluate(session_id: int, transcript: String, _lesson: Dictionary) -> void:
		requested.append(session_id)
		last_transcript = transcript
	func cancel() -> void:
		cancels += 1

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var recorder := FakeRecorder.new()
	var transcriber := FakeTranscriber.new()
	var evaluator := FakeEvaluator.new()
	var workflow := Workflow.new()
	for part in [recorder, transcriber, evaluator, workflow]:
		root.add_child(part)
	workflow.configure(recorder, transcriber, evaluator)
	var audio := PackedByteArray()
	audio.resize(3200)
	recorder.audio.pcm = audio
	var lesson := {
		"encounter_id": "worker", "prompt": "Where are the bananas?", "rubric": "Reward clear requests.",
		"target_vocabulary": PackedStringArray(["bananas"]),
		"examples": [{"text": "Where are the bananas?", "quality": 1, "feedback": "Correct English."}],
	}
	var answers: Array[Dictionary] = []
	var errors: Array[String] = []
	workflow.answer_ready.connect(func(answer: Dictionary): answers.append(answer))
	workflow.failed.connect(func(code: String, _message: String): errors.append(code))

	var first: int = workflow.begin_answer(lesson)
	check(first > 0 and workflow.state == "recording", "Recording starts for a valid lesson")
	recorder.next_chunk = PackedByteArray([1, 2, 3, 4])
	workflow.pump()
	check(transcriber.started == [first] and transcriber.chunks == [PackedByteArray([1, 2, 3, 4])], "Audio streams while E is held")
	var partials: Array[String] = []
	var stt_statuses: Array[String] = []
	var transcripts: Array[String] = []
	workflow.partial_transcript.connect(func(value: String): partials.append(value))
	workflow.transcription_status.connect(func(value: String): stt_statuses.append(value))
	workflow.transcript_ready.connect(func(_id: int, value: String): transcripts.append(value))
	transcriber.activity.emit(first, "connected")
	check(stt_statuses == ["connected"], "Live connection status reaches the game")
	transcriber.partial_transcript.emit(first, "Where are")
	check(partials == ["Where are"], "Live transcript reaches the game")
	check(workflow.begin_answer(lesson) == 0 and errors.back() == "busy", "A second answer cannot start while recording")
	workflow.finish_answer()
	check(workflow.state == "transcribing" and transcriber.requested == [first], "Audio moves to transcription")
	transcriber.completed.emit(first, Contracts.success("Where are the bananas?"))
	check(workflow.state == "evaluating" and evaluator.requested == [first], "Transcript moves to evaluation")
	check(transcripts == ["Where are the bananas?"], "Committed transcript is reported before evaluation")
	check(evaluator.last_transcript == "Where are the bananas?", "Evaluator receives the transcript")
	evaluator.completed.emit(first, Contracts.success({
		"quality": 1, "feedback": "Correct English.", "pip_response": "Great! You asked for bananas clearly.", "suggested_wording": "Could you show me the bananas?",
		"vocabulary_used": [{"word": "bananas", "evidence": "bananas"}],
	}))
	check(
		answers.size() == 1 and answers[0].allowed and answers[0].quality == 1,
		"Valid assessment produces one permitted answer"
	)
	check(answers[0].pip_response == "Great! You asked for bananas clearly.", "Pip's spoken line survives the assessment workflow")

	var cancelled: int = workflow.begin_answer(lesson)
	workflow.finish_answer()
	workflow.cancel_answer()
	transcriber.completed.emit(cancelled, Contracts.success("Late answer"))
	transcriber.activity.emit(cancelled, "connected")
	check(
		workflow.state == "idle" and answers.size() == 1 and evaluator.requested.size() == 1 and stt_statuses.size() == 1,
		"Cancellation ignores late transcription"
	)
	var current: int = workflow.begin_answer(lesson)
	workflow.finish_answer()
	transcriber.completed.emit(cancelled, Contracts.success("Older answer"))
	check(workflow.state == "transcribing", "Old session cannot advance a new session")
	transcriber.completed.emit(current, Contracts.success("Where are the bananas?"))
	evaluator.completed.emit(current, Contracts.success({
		"quality": 2, "feedback": "Well done.", "pip_response": "Wonderful question!", "suggested_wording": "Excuse me, where are the bananas?",
		"vocabulary_used": [{"word": "bananas", "evidence": "not in transcript"}],
	}))
	check(errors.back() == "invalid_assessment" and answers.size() == 1, "Unverified vocabulary cannot affect mission score")
	check(workflow.state == "failed", "Invalid assessment leaves a retryable state")

	var timed_out: int = workflow.begin_answer(lesson)
	workflow.recording_timed_out()
	check(
		timed_out > current and workflow.state == "failed" and errors.back() == "recording_too_long",
		"Recording timeout fails safely"
	)
	check(recorder.cancels > 0 and transcriber.cancels > 0 and evaluator.cancels > 0, "Cancellation reaches every adapter")
	var token_failure: int = workflow.begin_answer(lesson)
	transcriber.completed.emit(token_failure, Contracts.failure("service_unavailable", "Token request failed."))
	check(workflow.state == "failed" and errors.back() == "service_unavailable", "Token failure during recording stops capture")

	var requests_before_short := transcriber.requested.size()
	recorder.audio.pcm = PackedByteArray([1, 2])
	workflow.begin_answer(lesson)
	workflow.finish_answer()
	check(
		errors.back() == "empty_audio" and transcriber.requested.size() == requests_before_short,
		"Short capture never reaches transcription"
	)
	recorder.audio.pcm = audio
	var empty_transcript: int = workflow.begin_answer(lesson)
	workflow.finish_answer()
	transcriber.completed.emit(empty_transcript, Contracts.success("  "))
	check(errors.back() == "no_speech" and answers.size() == 1, "Empty transcript is a retryable error, not a score")
	var late_evaluation: int = workflow.begin_answer(lesson)
	workflow.finish_answer()
	transcriber.completed.emit(late_evaluation, Contracts.success("Where are the bananas?"))
	workflow.cancel_answer()
	evaluator.completed.emit(late_evaluation, Contracts.success({
		"quality": 2, "feedback": "Well done.", "pip_response": "Wonderful question!", "suggested_wording": "Where are the bananas?",
		"vocabulary_used": [{"word": "bananas", "evidence": "bananas"}],
	}))
	check(answers.size() == 1 and workflow.state == "idle", "Late evaluation cannot publish after cancel")
	check(not Contracts.validate_assessment({
		"quality": 1.5, "feedback": "Good.", "pip_response": "Good try!", "suggested_wording": "Where are the bananas?",
		"vocabulary_used": [],
	}, "Where are the bananas?", lesson).ok, "Fractional JSON quality is rejected")
	check(not Contracts.validate_assessment({
		"quality": 1, "feedback": "Good.", "suggested_wording": "Where are the bananas?",
		"vocabulary_used": [],
	}, "Where are the bananas?", lesson).ok, "An assessment without Pip's line is rejected")

	var wav := WaveEncoder.encode({"pcm": PackedByteArray([1, 2, 3, 4]), "sample_rate": 8000, "channels": 1})
	check(wav.size() == 48 and wav.slice(0, 4).get_string_from_ascii() == "RIFF", "WAV has the expected container header")
	check(wav.decode_u32(24) == 8000 and wav.decode_u32(40) == 4, "WAV preserves sample rate and payload size")
	check(wav.slice(44, 48) == PackedByteArray([1, 2, 3, 4]), "WAV contains the original PCM bytes")

	for part in [workflow, evaluator, transcriber, recorder]:
		part.queue_free()
	await process_frame
	print("Speech workflow: ", failures, " failures")
	quit(0 if failures == 0 else 1)
