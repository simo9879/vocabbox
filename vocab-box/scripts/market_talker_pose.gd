@tool
extends Node3D

@export var left_arm_name := ""
@export var right_arm_name := ""
@export var idle_left_angle := 0.0
@export var idle_right_angle := 0.0
@export var arm_axis := Vector3.FORWARD
@onready var skeleton: Skeleton3D = $Model.find_child("Skeleton3D", true, false)
var left_arm := -1
var right_arm := -1
var talking := false
var gesture_time := 0.0


func _ready() -> void:
	left_arm = skeleton.find_bone(left_arm_name)
	right_arm = skeleton.find_bone(right_arm_name)
	if left_arm == -1 or right_arm == -1:
		push_error("Market character rig is missing an upper arm bone")
		set_process(false)
		return
	_apply_arm_pose(0.0)
	set_process(false)


func set_talking(active: bool) -> void:
	talking = active
	gesture_time = 0.0
	if not talking:
		_apply_arm_pose(0.0)
	set_process(talking)


func _process(delta: float) -> void:
	gesture_time += delta
	# Small alternating arm movements accompany dialogue while each character stays in place.
	_apply_arm_pose(sin(gesture_time * 4.0) * 12.0)


func _apply_arm_pose(gesture: float) -> void:
	# Idle angles keep the supplied standing rigs relaxed between conversations.
	skeleton.set_bone_pose_rotation(left_arm, Quaternion(arm_axis, deg_to_rad(idle_left_angle + gesture)))
	skeleton.set_bone_pose_rotation(right_arm, Quaternion(arm_axis, deg_to_rad(idle_right_angle + gesture)))
