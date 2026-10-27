extends Control

@onready var line_label: Label = %Line
@onready var speaker_label: Label = $Paper/Speaker


func _ready() -> void:
	# Preserve readable lines when the viewport becomes narrow.
	resized.connect(_update_type_size)
	_update_type_size()


func set_line(line: String, speaker: String = "Pip") -> void:
	# Show the speaker on replay as well as during Pip's regular narration.
	line_label.text = line
	speaker_label.text = "Pip says" if speaker == "Pip" else speaker
	visible = not line.is_empty()


func _update_type_size() -> void:
	line_label.add_theme_font_size_override("font_size", 22 if size.x < 900 else 30)
