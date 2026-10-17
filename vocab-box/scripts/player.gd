extends CharacterBody3D
var enabled: bool = false
@onready var visual: Node3D = $Visual
@onready var animation_player: AnimationPlayer = visual.find_child("AnimationPlayer", true, false) as AnimationPlayer

func _ready() -> void:
	# Imported glTF clips are non-looping by default; both locomotion clips repeat.
	for clip_name in [&"Idle", &"Walking"]:
		animation_player.get_animation(clip_name).loop_mode = Animation.LOOP_LINEAR
	animation_player.play(&"Idle")

func _physics_process(delta: float) -> void:
	var input = Input.get_vector("move_left", "move_right", "move_forward", "move_back") if enabled else Vector2.ZERO
	# Project camera-relative input onto the ground so camera pitch cannot move the player vertically.
	var camera = get_viewport().get_camera_3d()
	var direction = Vector3(input.x,0,input.y)
	if camera:
		direction = camera.global_basis * direction
	direction.y = 0
	direction = direction.normalized() * input.length()
	velocity.x = move_toward(velocity.x, direction.x * 4.2, delta * 20)
	velocity.z = move_toward(velocity.z, direction.z * 4.2, delta * 20)
	velocity.y = -0.1 if is_on_floor() else velocity.y - 20 * delta
	move_and_slide()
	# Face the visual without rotating the collision body; Pip also reads this orientation.
	if direction.length() > 0.1:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(direction.x,direction.z), delta * 12)
	# Keep the imported in-place clips aligned with the body's actual ground speed.
	if animation_player:
		var next_animation: StringName = &"Walking" if Vector2(velocity.x, velocity.z).length() > 0.2 else &"Idle"
		if animation_player.current_animation != next_animation:
			animation_player.play(next_animation, 0.18)
