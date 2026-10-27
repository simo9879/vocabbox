@abstract
extends Node

signal completed(session_id: int, result: Dictionary)
signal partial_transcript(session_id: int, text: String)
signal activity(session_id: int, status: String)

@abstract func start_session(session_id: int, sample_rate: int) -> void
@abstract func push_audio(session_id: int, pcm: PackedByteArray) -> void
@abstract func finish_session(session_id: int) -> void
@abstract func cancel() -> void
