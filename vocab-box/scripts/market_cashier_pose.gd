@tool
extends Node3D

@onready var skeleton: Skeleton3D = get_node("Visual/Model/Sketchfab_model/root/GLTF_SceneRootNode/russian-girl_mid_75/GLTF_created_0/Skeleton3D")


func _ready() -> void:
	# Bend the supplied rig into a seated pose; the visual offset in the scene keeps her shoes on the floor.
	for bone_name in ["mixamorig_LeftUpLeg_58", "mixamorig_RightUpLeg_63", "mixamorig_LeftLeg_57", "mixamorig_RightLeg_62"]:
		_rotate_bone(bone_name, Vector3.RIGHT, 90.0)
	for bone_name in ["mixamorig_LeftArm_25", "mixamorig_RightArm_49"]:
		_rotate_bone(bone_name, Vector3.RIGHT, 60.0)


func _rotate_bone(bone_name: String, axis: Vector3, degrees: float) -> void:
	var bone := skeleton.find_bone(bone_name)
	if bone == -1:
		push_error("Cashier rig is missing bone: " + bone_name)
		return
	skeleton.set_bone_pose_rotation(bone, Quaternion(axis, deg_to_rad(degrees)))
