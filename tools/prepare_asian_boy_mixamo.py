"""Export the existing boy mesh as an unrigged Mixamo animation donor.

Run with Blender: blender --background --factory-startup --python tools/prepare_asian_boy_mixamo.py
The OBJ is an authoring file, not a game asset. Mixamo will auto-rig it.
"""

from pathlib import Path

import bpy


ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / ".local/archive/generated-player/AsianBoy_player.glb"
OUTPUT = ROOT / ".local/archive/generated-player/AsianBoy_unrigged_for_Mixamo.obj"


# Import the reviewed player model, then export only its complete body mesh.
# Its facial rig and separate eye parts are unnecessary for Mixamo's motion donor.
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
body = bpy.data.objects["asian boy.002"]

# OBJ stores the rest-pose mesh without a skeleton, so Mixamo opens its
# automatic rigger instead of trying to map the original 259-bone rig.
bpy.ops.object.select_all(action="DESELECT")
body.select_set(True)
bpy.context.view_layer.objects.active = body

OUTPUT.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.export_scene.obj(
    filepath=str(OUTPUT),
    use_selection=True,
    use_materials=False,
    use_mesh_modifiers=False,
    axis_forward="-Z",
    axis_up="Y",
)

print(f"Unrigged Mixamo motion donor ready: {OUTPUT}")
