extends SceneTree

const CLIPS := {"Idle": "Chick_idle", "Fly": "Chick_flying"}
const DURATIONS := {"Idle": 120.0 / 24.0, "Fly": 98.0 / 24.0}
const LOOP_FPS := 24.0
const FLY_START_FRAME := 41
const FLY_END_FRAME := 65
const TALK_START := 2.75
const SEAM_FRAMES := 4

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("Expected the absolute output GLB path")
		quit(1)
		return
	var root: Node3D = load("res://Chick_idle.fbx").instantiate()
	var player: AnimationPlayer = root.get_node("AnimationPlayer")
	var library := AnimationLibrary.new()
	for clip_name in CLIPS:
		var source: Node3D = load("res://" + CLIPS[clip_name] + ".fbx").instantiate()
		var source_player: AnimationPlayer = source.get_node("AnimationPlayer")
		var animation: Animation = source_player.get_animation(source_player.get_animation_list()[0]).duplicate(true)
		# The source has a large Maya control rig. Its baked skin joints contain
		# the motion needed by the game, so omit animation of authoring controls.
		for i in range(animation.get_track_count() - 1, -1, -1):
			var path := str(animation.track_get_path(i))
			if not path.begins_with("ChikRig/jnt_org/"):
				animation.remove_track(i)
			# The Fly source rises more than half a meter. Pip's follower owns
			# world height, so retain the wing pose without that root travel.
			elif clip_name == "Fly" and path.ends_with(":spine_C0_0_jnt") and animation.track_get_type(i) == Animation.TYPE_POSITION_3D:
				animation.remove_track(i)
		animation.length = DURATIONS[clip_name]
		animation.loop_mode = Animation.LOOP_LINEAR
		_trim_keys(animation)
		if clip_name == "Fly":
			animation = _extract_fly_cycle(animation)
		library.add_animation(clip_name, animation)
		source.free()
	# A full feeding pose bends toward the floor. Use its authored beak rotation
	# over Fly so Pip keeps flapping while it speaks.
	var feeding: Node3D = load("res://Chick_feeding.fbx").instantiate()
	var feeding_player: AnimationPlayer = feeding.get_node("AnimationPlayer")
	var feeding_clip: Animation = feeding_player.get_animation(feeding_player.get_animation_list()[0])
	var talk_clip: Animation = library.get_animation("Fly").duplicate(true)
	for i in feeding_clip.get_track_count():
		var path := str(feeding_clip.track_get_path(i))
		if not path.contains(":beack_") or feeding_clip.track_get_type(i) != Animation.TYPE_ROTATION_3D:
			continue
		for j in range(talk_clip.get_track_count() - 1, -1, -1):
			if talk_clip.track_get_path(j) == feeding_clip.track_get_path(i) and talk_clip.track_get_type(j) == Animation.TYPE_ROTATION_3D:
				talk_clip.remove_track(j)
		var new_track := talk_clip.add_track(Animation.TYPE_ROTATION_3D)
		talk_clip.track_set_path(new_track, feeding_clip.track_get_path(i))
		# This one-second section opens and closes the beak without the feeding
		# pose's downward head movement or a rushed full-clip time stretch.
		var first: Quaternion = feeding_clip.rotation_track_interpolate(i, TALK_START)
		for frame in range(FLY_END_FRAME - FLY_START_FRAME + 1):
			var value: Quaternion = feeding_clip.rotation_track_interpolate(i, TALK_START + float(frame) / LOOP_FPS)
			if frame >= FLY_END_FRAME - FLY_START_FRAME - SEAM_FRAMES:
				value = value.slerp(first, _seam_weight(frame))
			talk_clip.track_insert_key(new_track, float(frame) / LOOP_FPS, value)
	_trim_keys(talk_clip)
	library.add_animation("Talk", talk_clip)
	feeding.free()
	for name in player.get_animation_library_list():
		player.remove_animation_library(name)
	player.add_animation_library("", library)

	# The FBX does not link its texture; restore the artist's supplied color atlas.
	var material := StandardMaterial3D.new()
	material.albedo_texture = load("res://lambert7_Base_color.png")
	material.roughness = 0.85
	var rig: Node = root.get_node("ChikRig")
	for child in root.get_children():
		if child == player or child == rig:
			continue
		root.remove_child(child)
		child.free()
	for child in rig.get_children():
		if child.name == "jnt_org":
			continue
		rig.remove_child(child)
		child.free()
	_apply_material(root, material)

	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var err := document.append_from_scene(root, state)
	if err == OK:
		err = document.write_to_filesystem(state, args[0])
	root.free()
	if err != OK:
		push_error("Could not export Yellow Chick: " + str(err))
	quit(0 if err == OK else 1)

func _trim_keys(animation: Animation) -> void:
	# Maya's FBX has stray keys through 9.33 seconds even in the shorter clips.
	# glTF export includes those keys despite Animation.length, extending the
	# imported playback and leaving the wings motionless before the next cycle.
	for track in range(animation.get_track_count() - 1, -1, -1):
		for key in range(animation.track_get_key_count(track) - 1, -1, -1):
			var time := animation.track_get_key_time(track, key)
			if time < 0.0 or time > animation.length:
				animation.track_remove_key(track, key)
		if animation.track_get_key_count(track) == 0:
			animation.remove_track(track)

func _extract_fly_cycle(source: Animation) -> Animation:
	# Frames 41–65 contain a repeating wing stroke. The original clip starts
	# and ends in an idle pose, which made every full-clip loop look like landing.
	var cycle := Animation.new()
	cycle.length = float(FLY_END_FRAME - FLY_START_FRAME) / LOOP_FPS
	cycle.loop_mode = Animation.LOOP_LINEAR
	var start := float(FLY_START_FRAME) / LOOP_FPS
	for track in source.get_track_count():
		var kind := source.track_get_type(track)
		var output_track := cycle.add_track(kind)
		cycle.track_set_path(output_track, source.track_get_path(track))
		for frame in range(FLY_END_FRAME - FLY_START_FRAME + 1):
			var sample_time := start + float(frame) / LOOP_FPS
			var output_time := float(frame) / LOOP_FPS
			var seam := _seam_weight(frame) if frame >= FLY_END_FRAME - FLY_START_FRAME - SEAM_FRAMES else 0.0
			match kind:
				Animation.TYPE_POSITION_3D:
					var value: Vector3 = source.position_track_interpolate(track, sample_time)
					cycle.track_insert_key(output_track, output_time, value.lerp(source.position_track_interpolate(track, start), seam))
				Animation.TYPE_ROTATION_3D:
					var value: Quaternion = source.rotation_track_interpolate(track, sample_time)
					cycle.track_insert_key(output_track, output_time, value.slerp(source.rotation_track_interpolate(track, start), seam))
				Animation.TYPE_SCALE_3D:
					var value: Vector3 = source.scale_track_interpolate(track, sample_time)
					cycle.track_insert_key(output_track, output_time, value.lerp(source.scale_track_interpolate(track, start), seam))
	return cycle

func _seam_weight(frame: int) -> float:
	var seam_start := FLY_END_FRAME - FLY_START_FRAME - SEAM_FRAMES
	var progress := float(frame - seam_start) / float(SEAM_FRAMES)
	return smoothstep(0.0, 1.0, progress)

func _apply_material(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			node.set_surface_override_material(i, material)
	for child in node.get_children():
		_apply_material(child, material)
