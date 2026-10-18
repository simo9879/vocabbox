extends Control

signal action_requested(action: String)

# Screens report intent; mission, navigation and save behavior stay with the app.
func _on_action_pressed(action: String) -> void:
	action_requested.emit(action)

func open() -> void:
	show()
	%PrimaryAction.grab_focus()
