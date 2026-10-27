@abstract
extends Node

signal completed(session_id: int, result: Dictionary)

@abstract func evaluate(session_id: int, transcript: String, lesson: Dictionary) -> void
@abstract func cancel() -> void
