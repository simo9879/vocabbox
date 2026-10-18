extends "res://scripts/ui/blackboard_menu.gd"

signal volume_changed(value: float, bus: String)

func set_volumes(volumes: Dictionary) -> void:
	# Opening settings must not trigger save writes or change the stored preferences.
	%Voice.set_value_no_signal(volumes["Voice"])
	%Music.set_value_no_signal(volumes["Music"])
	%Effects.set_value_no_signal(volumes["Effects"])

func _on_volume_changed(value: float, bus: String) -> void:
	volume_changed.emit(value, bus)
