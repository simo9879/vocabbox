extends Node3D
var target: Node3D
var enabled: bool = false
var yaw: float = 0
var pitch: float = -0.4
var arm: SpringArm3D
func _ready() -> void:
	arm = SpringArm3D.new()
	arm.spring_length = 5.5
	arm.margin = 0.25
	var shape = SphereShape3D.new()
	shape.radius = 0.2
	arm.shape = shape
	add_child(arm)
	var cam = Camera3D.new()
	cam.fov = 65
	cam.current = true
	arm.add_child(cam)
func _unhandled_input(event: InputEvent) -> void:
	if enabled and event is InputEventMouseMotion:
		yaw -= event.relative.x * 0.003
		pitch = clampf(pitch - event.relative.y * 0.003, -0.9, -0.1)
func _process(delta: float) -> void:
	if target:
		global_position = global_position.lerp(target.global_position + Vector3(0,1.4,0), 1-exp(-delta*10))
	rotation = Vector3(pitch,yaw,0)
