extends Node3D

@export var encounter_id := ""
@export var title := ""
@onready var marker: Label3D = $Label3D


func _ready() -> void:
	add_to_group("interactables")


func highlight(active: bool) -> void:
	marker.modulate = Color("ffe08a") if active else Color.WHITE
	marker.font_size = 38 if active else 32


func set_talking(active: bool) -> void:
	var actor := get_parent()
	if actor.has_method("set_talking"):
		actor.set_talking(active)
