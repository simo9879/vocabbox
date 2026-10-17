# Asian Boy animation handoff

Generate `.local/archive/generated-player/AsianBoy_unrigged_for_Mixamo.obj` with `tools/prepare_asian_boy_mixamo.py`, then upload it to [Mixamo](https://www.mixamo.com/). This is only the character's body mesh, without its complex facial skeleton and separate eye pieces. Mixamo should show the **automatic rigging markers** (wrists, elbows, knees, groin). A gray preview and missing hair/shoes/eyes are expected: the game keeps the complete textured GLB. Center the markers on the body and finish auto-rigging.

Choose an **Idle** animation and a **Walking** animation. Set **In Place** for Walking so the Godot `CharacterBody3D` continues to control movement. Download each as **FBX Binary**, **With Skin**, at **30 FPS**. Save them under `.local/archive/player-authoring/mixamo/` as `Idle.fbx` and `Walking.fbx`.

The previous `AsianBoy_for_Mixamo.fbx` used the model's original 259-bone rig. Mixamo reported “unable to map your existing skeleton” and failed to generate motion, so do not upload that file again. OBJ has no skeleton to map. If Mixamo does not show marker placement after uploading the new OBJ, record the exact message and a screenshot of its preview.

These FBX files are local animation source assets. Run `tools/retarget_asian_boy_mixamo.py` in Blender after replacing them. It bakes their motion to the original character and exports `vocab-box/models/AsianBoy_animated.glb`, which the active Godot player scene uses. The script intentionally removes Mixamo hip translation because the Godot controller already owns world movement.
