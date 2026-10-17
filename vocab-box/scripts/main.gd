extends Node
const LESSON = preload("res://lessons/banana.tres")
var mission = preload("res://scripts/mission.gd").new()
var evaluator = preload("res://scripts/evaluator.gd").new()
var saved = preload("res://scripts/save.gd").new()
var world: Node3D
var player: CharacterBody3D
var camera: Node3D
var bird: Node3D
var panel: PanelContainer
var help: Button
var hud: Label
var prompt: Label
var subtitle: Label
var fade: ColorRect
var voice: AudioStreamPlayer
var music: AudioStreamPlayer
var effects: AudioStreamPlayer
var mode: String = "title"
var location: String = "city"
var nearest: Node3D
var idle: float = 0
var hinted: Dictionary = {}
var last_line: String = ""
var current_encounter: String = ""
var settings_back: String = "title"
var transition: bool = false
var step_time: float = 0
func _ready() -> void:
	configure_input()
	saved.read_save()
	for bus in ["Voice","Music","Effects"]:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count-1,bus)
		set_volume(saved.volumes[bus],bus)
	voice = AudioStreamPlayer.new()
	voice.bus = "Voice"
	add_child(voice)
	music = AudioStreamPlayer.new()
	music.bus = "Music"
	add_child(music)
	effects = AudioStreamPlayer.new()
	effects.bus = "Effects"
	add_child(effects)
	build_ui()
	mission.changed.connect(func(): idle=0; update_hud())
	load_world("city")
	show_title()
func configure_input() -> void:
	var actions = {"move_left":[KEY_A,KEY_LEFT],"move_right":[KEY_D,KEY_RIGHT],"move_forward":[KEY_W,KEY_UP],"move_back":[KEY_S,KEY_DOWN],"interact":[KEY_E],"pause":[KEY_ESCAPE]}
	for action in actions:
		if not InputMap.has_action(action): InputMap.add_action(action)
		for code in actions[action]:
			var event = InputEventKey.new()
			event.physical_keycode = code
			InputMap.action_add_event(action,event)
func build_ui() -> void:
	var layer = CanvasLayer.new()
	add_child(layer)
	var root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var theme = Theme.new()
	theme.default_font_size = 21
	var style = StyleBoxFlat.new()
	style.bg_color = Color("203f4b")
	style.set_corner_radius_all(18)
	style.content_margin_left=18
	style.content_margin_right=18
	style.content_margin_top=8
	style.content_margin_bottom=8
	theme.set_stylebox("panel","PanelContainer",style)
	for state in ["normal","hover","pressed","focus"]:
		var b = style.duplicate()
		b.bg_color = Color("397568") if state=="normal" else Color("548d79")
		if state=="focus":
			b.set_border_width_all(3)
			b.border_color=Color("ffd475")
		theme.set_stylebox(state,"Button",b)
	root.theme = theme
	hud = Label.new()
	hud.position=Vector2(28,22)
	hud.add_theme_color_override("font_color",Color("fff6dc"))
	hud.add_theme_color_override("font_shadow_color",Color("203f4b"))
	hud.add_theme_constant_override("shadow_offset_x",2)
	hud.add_theme_constant_override("shadow_offset_y",2)
	root.add_child(hud)
	var card=style.duplicate()
	card.bg_color=Color(0.08,0.19,0.23,0.94)
	hud.add_theme_stylebox_override("normal",card)
	hud.add_theme_font_size_override("font_size",18)
	prompt = Label.new()
	root.add_child(prompt)
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.offset_left=-400
	prompt.offset_right=400
	prompt.offset_top=-65
	prompt.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_stylebox_override("normal",card)
	subtitle = Label.new()
	root.add_child(subtitle)
	subtitle.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	subtitle.offset_left=240
	subtitle.offset_right=-240
	subtitle.offset_top=-175
	subtitle.offset_bottom=-85
	subtitle.add_theme_stylebox_override("normal",card)
	subtitle.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_shadow_color",Color("203f4b"))
	subtitle.add_theme_constant_override("shadow_offset_x",2)
	subtitle.add_theme_constant_override("shadow_offset_y",2)
	help = Button.new()
	help.text="Pip’s help  [H]"
	root.add_child(help)
	help.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	help.offset_left=-225
	help.offset_right=-25
	help.offset_top=25
	help.offset_bottom=75
	help.pressed.connect(hint)
	panel=preload("res://scenes/dialogue.tscn").instantiate()
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.anchor_left=0.19
	panel.anchor_right=0.81
	panel.anchor_top=0.08
	panel.anchor_bottom=0.94
	fade=ColorRect.new()
	fade.color=Color(0.08,0.18,0.22,0)
	fade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func load_world(where: String, exiting: bool = false) -> void:
	if world:
		remove_child(world)
		world.queue_free()
	location=where
	world=Node3D.new()
	add_child(world)
	var scene=load("res://scenes/"+where+".tscn").instantiate()
	world.add_child(scene)
	# Only the legacy supermarket still needs batching for its generated fixtures.
	if where == "supermarket":
		preload("res://scripts/art.gd").batch_static(scene)
	player=preload("res://scenes/player.tscn").instantiate()
	world.add_child(player)
	player.position=scene.get_node("Exit" if exiting else "Entry").position
	camera=preload("res://scenes/camera.tscn").instantiate()
	world.add_child(camera)
	camera.target=player
	camera.position=player.position+Vector3(0,1.4,0)
	camera.arm.add_excluded_object(player.get_rid())
	bird=preload("res://scenes/bird.tscn").instantiate()
	world.add_child(bird)
	bird.target=player
	nearest=null
	var path="res://audio/"+where+".wav"
	if ResourceLoader.exists(path):
		music.stream=load(path)
		music.play()
	update_hud()
func overlay(next_mode: String, title: String) -> void:
	hud.hide()
	help.hide()
	prompt.hide()
	subtitle.hide()
	mode=next_mode
	panel.show()
	panel.clear()
	panel.label_text(title,34)
	player.enabled=false
	camera.enabled=false
	bird.talking=next_mode=="dialogue"
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	subtitle.text=""
	voice.stop()
func resume() -> void:
	hud.show()
	help.show()
	prompt.show()
	mode="play"
	panel.hide()
	voice.stop()
	subtitle.text=""
	bird.talking=false
	player.enabled=true
	camera.enabled=true
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	if mission.stage==5: results()
func say(line: String) -> void:
	last_line=line
	voice.stop()
	subtitle.text="Pip: "+line+"  [R · Replay]" if mode=="play" else ""
	subtitle.visible=mode=="play"
	var path: String=LESSON.voice_paths.get(line, "")
	if ResourceLoader.exists(path):
		voice.stream=load(path)
		voice.play()
func replay_button(line: String) -> void:
	panel.button("▶  Listen again",func(): say(line))
func show_title() -> void:
	overlay("title","VOCAB BOX")
	panel.label_text("A little adventure in English",26)
	panel.label_text("SUNNY MARKET\nExplore with Pip. Meet new friends. Let’s buy some bananas!")
	panel.label_text("Best adventure: "+str(saved.best_stars)+" / 3 stars")
	panel.button("Play  →",start)
	panel.button("Settings",func(): settings("title"))
	panel.button("Quit",func(): get_tree().quit())
func start() -> void:
	mission.reset()
	hinted.clear()
	load_world("city")
	resume()
	say(LESSON.lines.arrival)
func update_hud() -> void:
	if not hud: return
	hud.text="VOCAB BOX   /   SUNNY MARKET\n"+LESSON.objectives[mission.stage]+"\n\n"
	for i in range(1,5): hud.text += ("✓  " if mission.stage>i else "○  ")+LESSON.objectives[i]+"\n"
	hud.text+="\nBananas: "+str(mission.bananas)+" bunch\nWASD · Move   Mouse · Look\nE · Talk   Esc · Pause"
func _process(delta: float) -> void:
	if not music.playing and music.stream: music.play()
	if mode!="play" or transition:
		prompt.text=""
		return
	idle+=delta
	if idle>20 and not hinted.has(mission.stage):
		hinted[mission.stage]=true
		hint()
	nearest=null
	var distance=2.8
	for node in get_tree().get_nodes_in_group("interactables"):
		var d=player.global_position.distance_to(node.global_position)
		if d<distance:
			distance=d
			nearest=node
	for node in get_tree().get_nodes_in_group("interactables"): node.highlight(node==nearest)
	prompt.text="[E]  "+nearest.title if nearest else "Follow the signs • Pip is here to help"
	if player.velocity.length()>1 and player.is_on_floor():
		step_time+=delta
		if step_time>0.38:
			step_time=0
			fx("step")
func _unhandled_input(event: InputEvent) -> void:
	if transition: return
	if event.is_action_pressed("pause"):
		if mode=="play": pause_menu()
		elif mode=="dialogue": resume()
		elif mode=="pause" or mode=="confirm": resume()
		elif mode=="settings":
			if settings_back=="title": show_title()
			else: pause_menu()
		elif mode=="intro":
			mission.enter()
			resume()
	elif mode=="play" and event.is_action_pressed("interact") and nearest: interact(nearest.encounter_id)
	elif mode=="play" and event is InputEventKey and event.pressed:
		if event.keycode==KEY_H: hint()
		if event.keycode==KEY_R and not last_line.is_empty(): say(last_line)
func hint() -> void:
	if mode=="play": say(LESSON.hints[mission.stage])
func fx(id: String) -> void:
	var path="res://audio/"+id+".wav"
	if ResourceLoader.exists(path):
		effects.stream=load(path)
		effects.play()
func travel(where: String) -> void:
	transition=true
	player.enabled=false
	camera.enabled=false
	voice.stop()
	var tween=create_tween()
	tween.tween_property(fade,"color:a",1.0,0.25)
	await tween.finished
	load_world(where,where=="city")
	if where=="supermarket":
		overlay("intro","Welcome to Sunny Market")
		panel.label_text(LESSON.lines.intro)
		replay_button(LESSON.lines.intro)
		panel.button("Let’s ask Alex  →",func(): mission.enter(); resume())
		say(LESSON.lines.intro)
	else: resume()
	tween=create_tween()
	tween.tween_property(fade,"color:a",0.0,0.25)
	await tween.finished
	transition=false
func interact(id: String) -> void:
	fx("interact")
	match id:
		"entrance": travel("supermarket")
		"closed": say(LESSON.lines.closed)
		"exit":
			overlay("confirm","Return to the city?")
			panel.label_text("Leaving now resets this shopping attempt. Your best stars stay saved.")
			panel.button("Keep shopping",resume)
			panel.button("Leave and reset",func(): mission.reset(); hinted.clear(); panel.hide(); travel("city"))
		"bananas":
			if mission.collect(): say(LESSON.lines.collected)
			else: say(LESSON.lines.duplicate if mission.bananas else LESSON.lines.locked)
		_:
			var required: int={"worker":1,"customer":3,"cashier":4}.get(id,99)
			if mission.stage<required: say(LESSON.lines.locked)
			else: conversation(id)
func conversation(id: String) -> void:
	current_encounter=id
	var data=LESSON.encounters[id]
	overlay("dialogue",data.name)
	panel.label_text(data.prompt,26)
	replay_button(data.prompt)
	panel.label_text("Choose what you want to say:",18)
	var choices=data.choices.duplicate()
	choices.shuffle()
	for choice in choices:
		var assisted=mission.failures[id]>=2 and choice[2]==2
		panel.choice(("Pip suggests: " if assisted else "")+choice[1],func(): answer(id,choice[0]),func(): say(choice[1]))
	panel.button("Close · Keep exploring",resume)
	say(data.prompt)
func answer(id: String, response: String) -> void:
	var result=evaluator.evaluate(id,response)
	mission.respond(id,result.quality)
	overlay("dialogue","Pip’s phrase tip")
	panel.label_text(result.feedback,25)
	replay_button(result.feedback)
	if result.allowed:
		panel.label_text(LESSON.encounters[id].name+":\n"+LESSON.encounters[id].reply)
		panel.button("▶  Hear the reply",func(): say(LESSON.encounters[id].reply))
		if result.quality==1:
			panel.button("Try a stronger answer",func():
				conversation(id))
		panel.button("Continue  →",resume)
	else:
		panel.button("Try again",func(): conversation(id))
		panel.button("Close · Come back later",resume)
	say(result.feedback)
func results() -> void:
	mission.finalized=true
	var stars=mission.stars()
	saved.write_save(stars)
	overlay("results","You did it!  "+"★".repeat(stars)+"☆".repeat(3-stars))
	bird.celebrating=true
	panel.label_text(LESSON.lines.done,20)
	panel.label_text("You bought bananas using English.\n"+str(stars)+" / 3 stars · Best: "+str(saved.best_stars)+" / 3")
	panel.label_text("1 star: finish your shopping.\n2 stars: two strong conversations.\n3 stars: three strong conversations.",18)
	for id in ["worker","customer","cashier"]:
		var phrase=LESSON.encounters[id].choices[2 if mission.best[id]==2 else 1][1]
		panel.label_text("✓  "+phrase,20)
		panel.button("▶  Practise this phrase",func(): say(phrase))
	panel.button("Return to the city",func(): mission.reset(); hinted.clear(); panel.hide(); travel("city"))
	panel.button("Replay adventure",start)
	say(LESSON.lines.done)
func pause_menu() -> void:
	overlay("pause","Take a little break")
	panel.button("Resume",resume)
	if location=="supermarket": panel.button("Restart mission",func(): mission.reset(); hinted.clear(); panel.hide(); travel("supermarket"))
	panel.button("Settings",func(): settings("pause"))
	panel.button("Quit to title",func(): mission.reset(); load_world("city"); show_title())
func settings(back: String) -> void:
	settings_back=back
	overlay("settings","Make yourself comfortable")
	for bus in ["Voice","Music","Effects"]:
		panel.label_text(bus)
		var slider=HSlider.new()
		slider.min_value=0
		slider.max_value=1
		slider.step=0.05
		slider.value=saved.volumes[bus]
		slider.custom_minimum_size.y=32
		panel.stack.add_child(slider)
		slider.value_changed.connect(func(value): set_volume(value,bus); saved.write_save())
	panel.label_text("Voiced lines have subtitles. Answers are read only when you press Listen.\nThis adventure uses written choices, not speech recognition.",18)
	panel.button("Back",func(): show_title() if back=="title" else pause_menu())
func set_volume(value: float, bus: String) -> void:
	saved.volumes[bus]=value
	var index=AudioServer.get_bus_index(bus)
	if index>=0: AudioServer.set_bus_volume_db(index,linear_to_db(maxf(value,0.0001)))
func _exit_tree() -> void:
	for audio in [voice, music, effects]:
		if is_instance_valid(audio):
			audio.stop()
			audio.stream = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
