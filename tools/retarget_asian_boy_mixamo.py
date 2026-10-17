"""Bake Mixamo idle/walk bone motion onto the complete Asian Boy player model.

Run with Blender: blender --background --factory-startup --python tools/retarget_asian_boy_mixamo.py
The Mixamo FBXs are authoring inputs; only the resulting GLB belongs in Godot.
"""

from pathlib import Path

import bpy
import bmesh
from mathutils import Quaternion
from mathutils.bvhtree import BVHTree


ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / ".local/archive/generated-player/AsianBoy_player.glb"
OUTPUT = ROOT / "vocab-box/models/AsianBoy_animated.glb"
CLIPS = {
    "Idle": ROOT / ".local/archive/player-authoring/mixamo/Idle.fbx",
    "Walking": ROOT / ".local/archive/player-authoring/mixamo/Walking.fbx",
}

# Mixamo auto-rigged a body-only copy of this exact character. Each target bone
# receives the matching source bone's world-space rotation change from rest.
# Keep parent bones before their children so local rotations can be calculated.
BONE_MAP = {
    "root.x": "Hips",
    "spine_01.x": "Spine",
    "spine_02.x": "Spine1",
    "spine_03.x": "Spine2",
    "neck.x": "Neck",
    "head.x": "Head",
}
for side, mixamo_side in (("l", "Left"), ("r", "Right")):
    BONE_MAP.update({
        f"thigh_stretch.{side}": f"{mixamo_side}UpLeg",
        f"leg_stretch.{side}": f"{mixamo_side}Leg",
        f"foot.{side}": f"{mixamo_side}Foot",
        f"toes_01.{side}": f"{mixamo_side}ToeBase",
        f"shoulder.{side}": f"{mixamo_side}Shoulder",
        f"arm_stretch.{side}": f"{mixamo_side}Arm",
        f"forearm_stretch.{side}": f"{mixamo_side}ForeArm",
        f"hand.{side}": f"{mixamo_side}Hand",
    })
    for target_finger, mixamo_finger in (
        ("thumb", "Thumb"),
        ("index", "Index"),
        ("middle", "Middle"),
        ("ring", "Ring"),
        ("pinky", "Pinky"),
    ):
        for joint in (1, 2, 3):
            BONE_MAP[f"c_{target_finger}{joint}.{side}"] = (
                f"{mixamo_side}Hand{mixamo_finger}{joint}"
            )


bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
target = bpy.data.objects["root"]
player_objects = set(bpy.context.scene.objects)
bpy.context.scene.render.fps = 30

# The body asset includes skin beneath its shirt. Deformation makes some of
# those hidden triangles poke through, so remove the concealed torso surface
# and nearby skin faces that the shirt covers in the rest pose.
body_mesh = bpy.data.objects["asian boy.002"].data
shirt_index = next(i for i, material in enumerate(body_mesh.materials) if material.name == "Shirt")
shirt_surface = BVHTree.FromPolygons(
    [vertex.co for vertex in body_mesh.vertices],
    [tuple(face.vertices) for face in body_mesh.polygons if face.material_index == shirt_index],
)
hidden_skin_faces = []
for face in body_mesh.polygons:
    if face.material_index != 0 or not 0.9 < face.center.z < 1.52:
        continue
    under_torso = 0.94 < face.center.z < 1.52 and abs(face.center.x) < 0.34
    hit, _normal, _index, _distance = shirt_surface.ray_cast(
        face.center + face.normal * 0.001, face.normal, 0.08
    )
    if under_torso or hit is not None:
        hidden_skin_faces.append(face.index)
editable_mesh = bmesh.new()
editable_mesh.from_mesh(body_mesh)
editable_mesh.faces.ensure_lookup_table()
bmesh.ops.delete(
    editable_mesh,
    geom=[editable_mesh.faces[index] for index in hidden_skin_faces],
    context="FACES_ONLY",
)
editable_mesh.to_mesh(body_mesh)
editable_mesh.free()
print(f"Removed {len(hidden_skin_faces)} concealed skin faces beneath the shirt")


def bone_depth(name):
    depth = 0
    bone = target.data.bones[name]
    while bone.parent:
        depth += 1
        bone = bone.parent
    return depth


ordered_targets = sorted(BONE_MAP, key=bone_depth)
for target_name in ordered_targets:
    if target_name not in target.pose.bones:
        raise ValueError(f"Missing player bone: {target_name}")
    target.pose.bones[target_name].rotation_mode = "QUATERNION"


for clip_name, path in CLIPS.items():
    existing_objects = set(bpy.context.scene.objects)
    existing_actions = set(bpy.data.actions)
    bpy.ops.import_scene.fbx(filepath=str(path), use_anim=True)
    source = next(
        obj for obj in bpy.context.scene.objects
        if obj not in existing_objects and obj.type == "ARMATURE"
    )
    source_action = source.animation_data.action
    if not source_action:
        raise ValueError(f"{path.name} contains no armature action")

    for source_name in BONE_MAP.values():
        if f"mixamorig:{source_name}" not in source.pose.bones:
            raise ValueError(f"{path.name} is missing {source_name}")

    source_rest = {
        name: (source.matrix_world @ source.data.bones[f"mixamorig:{name}"].matrix_local).to_quaternion()
        for name in BONE_MAP.values()
    }
    target_rest = {
        name: (target.matrix_world @ target.data.bones[name].matrix_local).to_quaternion()
        for name in BONE_MAP
    }

    # Bake rotations on the original skeleton. Ignore Mixamo hip translation:
    # the Godot CharacterBody3D already owns movement and the walk cycle must
    # stay in place even if an FBX contains root drift.
    action = bpy.data.actions.new(clip_name)
    target.animation_data_create()
    target.animation_data.action = action
    for pose_bone in target.pose.bones:
        pose_bone.rotation_mode = "QUATERNION"
        pose_bone.rotation_quaternion = Quaternion()
        pose_bone.location = (0, 0, 0)

    first = int(source_action.frame_range.x)
    last = int(source_action.frame_range.y)
    previous_rotations = {}
    for frame in range(first, last + 1):
        bpy.context.scene.frame_set(frame)
        desired_world = {}
        for target_name in ordered_targets:
            source_name = BONE_MAP[target_name]
            source_pose = (
                source.matrix_world @ source.pose.bones[f"mixamorig:{source_name}"].matrix
            ).to_quaternion()
            rotation_delta = source_pose @ source_rest[source_name].inverted()
            desired = rotation_delta @ target_rest[target_name]
            desired_world[target_name] = desired

            bone = target.data.bones[target_name]
            if bone.parent:
                parent_name = bone.parent.name
                parent_pose = desired_world.get(parent_name, target_rest[parent_name])
                local = (
                    target_rest[target_name].inverted()
                    @ target_rest[parent_name]
                    @ parent_pose.inverted()
                    @ desired
                )
            else:
                local = target_rest[target_name].inverted() @ desired
            pose_bone = target.pose.bones[target_name]
            local.normalize()
            if target_name in previous_rotations and local.dot(previous_rotations[target_name]) < 0:
                local.negate()
            previous_rotations[target_name] = local.copy()
            pose_bone.rotation_quaternion = local
            pose_bone.keyframe_insert("rotation_quaternion", frame=frame, group=target_name)

    # The donor rig and its mesh must not enter the Godot model or animation set.
    for obj in set(bpy.context.scene.objects) - existing_objects:
        bpy.data.objects.remove(obj, do_unlink=True)
    for old_action in set(bpy.data.actions) - existing_actions - {action}:
        bpy.data.actions.remove(old_action)
    print(f"Baked {clip_name}: frames {first}-{last}, {len(ordered_targets)} bones")


# Export only the complete original model with its two newly baked actions.
bpy.ops.object.select_all(action="DESELECT")
for obj in player_objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = target
bpy.ops.export_scene.gltf(
    filepath=str(OUTPUT),
    export_format="GLB",
    use_selection=True,
    export_animations=True,
    export_animation_mode="ACTIONS",
    export_skins=True,
    export_morph_animation=False,
)
print(f"Animated player ready: {OUTPUT}")
