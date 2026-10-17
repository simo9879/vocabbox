"""Export the existing two-shoe Blender character as a clean player GLB.

Run with Blender: blender --background .local/archive/player-authoring/boy.blend --python tools/build_asian_boy_player.py
This only reattaches an existing mirrored shoe; it creates no model geometry.
"""

from pathlib import Path

import bpy


ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / ".local/archive/generated-player/AsianBoy_player.glb"
character = bpy.data.objects["root"]
second_shoe = bpy.data.objects["Shoe.001"]
extra_rig = bpy.data.objects["root.001"]


# The Blender source has the mirrored shoe bound to a duplicate skeleton.
# Rebind it to the character so one animation rig moves both shoes.
OUTPUT.parent.mkdir(parents=True, exist_ok=True)
world_transform = second_shoe.matrix_world.copy()
second_shoe.parent = character
second_shoe.matrix_world = world_transform
for modifier in second_shoe.modifiers:
    if modifier.type == "ARMATURE":
        modifier.object = character


# Mirroring moved the shoe to the opposite foot but kept its original bone weights.
for group in second_shoe.vertex_groups:
    if group.name.endswith(".l") or group.name.endswith(".r"):
        group.name = group.name[:-2] + (".__swap_l" if group.name.endswith(".l") else ".__swap_r")
for group in second_shoe.vertex_groups:
    if group.name.endswith(".__swap_l"):
        group.name = group.name[:-9] + ".r"
    elif group.name.endswith(".__swap_r"):
        group.name = group.name[:-9] + ".l"


# Apply the mirrored object transform so the exported skin has normal winding.
bpy.ops.object.select_all(action="DESELECT")
second_shoe.select_set(True)
bpy.context.view_layer.objects.active = second_shoe
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
bpy.data.objects.remove(extra_rig, do_unlink=True)


# Export only the character and its existing mesh parts, excluding studio equipment.
bpy.ops.object.select_all(action="DESELECT")
for obj in bpy.context.scene.objects:
    if obj.type in {"ARMATURE", "MESH", "EMPTY"}:
        obj.select_set(True)
bpy.context.view_layer.objects.active = character
bpy.ops.export_scene.gltf(
    filepath=str(OUTPUT),
    export_format="GLB",
    use_selection=True,
    export_animations=False,
    export_skins=True,
)

print(f"Player model ready: {OUTPUT}")
