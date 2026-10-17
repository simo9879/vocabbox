extends Node3D

# Keep Pip beside the player's right shoulder in player-facing space.
const FLY_OFFSET := Vector3(0.40, 1.43, 0.10)

var target: Node3D
var talking: bool = false
var celebrating: bool = false
var clock: float = 0.0
var placed: bool = false

@onready var visual: Node3D = $Visual
@onready var animation_player: AnimationPlayer = visual.find_child("AnimationPlayer", true, false) as AnimationPlayer

func _ready() -> void:
	for clip_name in [&"Fly", &"Talk"]:
		animation_player.get_animation(clip_name).loop_mode = Animation.LOOP_LINEAR
	animation_player.play(&"Fly")

func _process(delta: float) -> void:
	clock += delta
	if not target:
		return

	# Keep wing motion active while Pip follows or speaks beside the player.
	var player_visual := target.get_node_or_null("Visual") as Node3D
	var next_animation: StringName = &"Talk" if talking and not celebrating else &"Fly"
	# Imported clips can end without resetting current_animation; restart them
	# if playback stops so Pip never holds a frozen wing pose.
	if not animation_player.is_playing():
		animation_player.stop()
		animation_player.play(next_animation)
	elif animation_player.current_animation != next_animation:
		animation_player.play(next_animation, 0.2)
	animation_player.speed_scale = 1.35 if celebrating else 1.0

	# Position and facing follow the player's visual direction, not the collision body.
	var offset := FLY_OFFSET
	offset.y += sin(clock * 3.0) * 0.09
	if celebrating:
		offset += Vector3(sin(clock * 5.0) * 0.4, 0.35, cos(clock * 5.0) * 0.4)
	var facing := player_visual.rotation.y if player_visual else target.rotation.y
	var rotated_offset := Basis(Vector3.UP, facing) * offset
	var destination := target.global_position + rotated_offset
	if not placed:
		global_position = destination
		placed = true
	else:
		global_position = global_position.lerp(destination, 1.0 - exp(-delta * 7.0))
	rotation.y = facing + (sin(clock * 2.0) * 0.1 if talking else 0.0)
