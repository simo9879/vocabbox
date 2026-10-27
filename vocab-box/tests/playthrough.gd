extends SceneTree
var failed: bool = false
var game: Node
var samples: Array[float] = []
func fail(message: String) -> void:
	failed = true
	push_error(message)
	quit(1)
func _initialize() -> void:
	call_deferred("run")
func press_button(prefix: String) -> void:
	for node in game.find_children("*", "Button", true, false):
		if node is Button and node.is_visible_in_tree() and node.text.begins_with(prefix):
			node.pressed.emit()
			return
	fail("Missing button: "+prefix)
func walk_to(point: Vector3) -> void:
	var begin=Time.get_ticks_msec()
	while Vector2(game.player.position.x-point.x,game.player.position.z-point.z).length()>0.28:
		if Time.get_ticks_msec()-begin>15000:
			fail("Route blocked at "+str(game.player.position)+" toward "+str(point))
			return
		var diff=point-game.player.position
		for action in ["move_left","move_right","move_forward","move_back"]: Input.action_release(action)
		if abs(diff.x)>0.18: Input.action_press("move_right" if diff.x>0 else "move_left",minf(abs(diff.x),1))
		if abs(diff.z)>0.18: Input.action_press("move_back" if diff.z>0 else "move_forward",minf(abs(diff.z),1))
		await physics_frame
		if not DisplayServer.get_name()=="headless": samples.append(1.0/maxf(game.get_process_delta_time(),0.0001))
	for action in ["move_left","move_right","move_forward","move_back"]: Input.action_release(action)
	await create_timer(0.2).timeout
func interact(id: String) -> void:
	if not game.nearest or game.nearest.encounter_id!=id:
		fail("Wrong proximity target for "+id)
		return
	var event=InputEventAction.new()
	event.action="interact"
	event.pressed=true
	game._unhandled_input(event)
func snap(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	print("Screenshot image: ",root.get_texture().get_image().get_size())
	root.get_texture().get_image().save_png("/tmp/vocab-"+name+".png")
func run() -> void:
	if "--1080" in OS.get_cmdline_user_args():
		root.min_size=Vector2i(1920,1080)
		root.size=Vector2i(1920,1080)
		await process_frame
	print("Render size: ",root.size)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	# This route verifies authored choices even when this checkout has provider keys in .env.
	game.speech.available = false
	game.speech.availability_reason = "Authored-choice route test"
	game.speech.stt_status = "Unavailable"
	game.update_speech_debug()
	await snap("title-final")
	press_button("Play")
	await walk_to(Vector3(0,0,-1.3))
	await snap("city-final")
	interact("entrance")
	await create_timer(0.8).timeout
	press_button("Let’s ask")
	# Enter the right-side aisle, then follow the open south cross-aisle to produce.
	await walk_to(Vector3(6.1,0,1.8))
	interact("worker")
	await snap("dialogue-final")
	# Bad answer twice; helper appears and survives closing/reopening.
	press_button("Where bananas")
	press_button("Try again")
	press_button("Where bananas")
	press_button("Close")
	interact("worker")
	press_button("Pip suggests")
	press_button("Continue")
	await walk_to(Vector3(6.1,0,3.5))
	await walk_to(Vector3(-3.2,0,3.5))
	interact("bananas")
	interact("bananas")
	if game.mission.bananas!=1: fail("Duplicate bananas")
	await walk_to(Vector3(-1.2,0,3.5))
	await walk_to(Vector3(-1.2,0,4.6))
	interact("customer")
	press_button("I like bananas.")
	# Choice prefix can select either relevant answer; force an authored clear path.
	if game.mission.best.customer==2:
		press_button("Continue")
	else:
		press_button("Try a stronger")
		press_button("I like bananas. Do")
		press_button("Continue")
	await walk_to(Vector3(6.1,0,4.6))
	await walk_to(Vector3(6.1,0,-4.2))
	await snap("shop-final")
	interact("cashier")
	press_button("I want these")
	press_button("Try a stronger")
	press_button("I would like")
	press_button("Continue")
	if game.mode!="results" or game.mission.stars()!=3: fail("Results wrong")
	await snap("results-final")
	# Scroll UI and settings are exercised through their live controls.
	press_button("Return to the city")
	await create_timer(0.8).timeout
	if game.location!="city" or game.mission.stage!=0: fail("City return")
	game.camera.yaw=PI
	await create_timer(0.4).timeout
	if game.camera.arm.get_hit_length()>=5.4: fail("Camera did not avoid market wall")
	var mouse=InputEventMouseMotion.new()
	mouse.relative=Vector2(0,10000)
	game.camera._unhandled_input(mouse)
	if not is_equal_approx(game.camera.pitch,-0.9): fail("Camera lower pitch clamp")
	mouse.relative=Vector2(0,-10000)
	game.camera._unhandled_input(mouse)
	if not is_equal_approx(game.camera.pitch,-0.1): fail("Camera upper pitch clamp")
	game.camera.yaw=0
	game.camera.pitch=-0.4
	game.pause_menu()
	press_button("Settings")
	for node in game.settings_screen.find_children("*", "HSlider", true, false):
		if node is HSlider: node.value=0.5
	press_button("Back")
	press_button("Resume")
	interact("entrance")
	await create_timer(0.8).timeout
	press_button("Let’s ask")
	game.pause_menu()
	press_button("Restart mission")
	await create_timer(0.8).timeout
	press_button("Let’s ask")
	await create_timer(0.2).timeout
	interact("exit")
	press_button("Keep shopping")
	interact("exit")
	press_button("Leave and reset")
	await create_timer(0.8).timeout
	if game.mission.stage!=0 or game.mission.bananas!=0: fail("Exit reset")
	if not samples.is_empty():
		samples.sort()
		print("FPS samples=",samples.size()," median=",samples[samples.size()/2]," p10=",samples[int(samples.size()*0.1)])
	print("PASS: full physics-driven city → shopping → results → city; retry, restart, exit, settings")
	for audio in [game.voice, game.music, game.effects]:
		audio.stop()
		audio.stream=null
	await create_timer(0.15).timeout
	game.queue_free()
	await process_frame
	quit(1 if failed else 0)
