extends Node

signal completed(request_id: int, result: Dictionary)

func configure(_api_key: String) -> bool:
	return false

func synthesize(_request_id: int, _text: String) -> void:
	pass

func cancel() -> void:
	pass
