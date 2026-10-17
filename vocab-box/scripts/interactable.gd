extends Node3D
@export var encounter_id: String = ""
@export var title: String = ""
var marker: Label3D
func _ready() -> void:
	add_to_group("interactables")
	marker = preload("res://scripts/art.gd").sign_text(self, "◆ " + title, Vector3(0,2.25,0),32)
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
func highlight(active: bool) -> void:
	marker.modulate = Color("ffe08a") if active else Color("ffffff")
	marker.font_size = 38 if active else 30
