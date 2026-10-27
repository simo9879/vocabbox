@abstract
extends Node

signal state_changed(state: String)
signal answer_ready(result: Dictionary)
signal failed(code: String, message: String)
signal partial_transcript(text: String)
signal transcription_status(status: String)
signal transcript_ready(session_id: int, text: String)

var state := "idle"

@abstract func configure(recorder: Node, transcriber: Node, evaluator: Node) -> void
@abstract func begin_answer(lesson: Dictionary) -> int
@abstract func finish_answer() -> void
@abstract func cancel_answer() -> void
@abstract func pump() -> void
@abstract func recording_timed_out() -> void
