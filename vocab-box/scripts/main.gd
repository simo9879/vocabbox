extends Node
const LESSON = preload("res://lessons/banana.tres")
var mission = preload("res://scripts/mission.gd").new()
var evaluator = preload("res://scripts/evaluator.gd").new()
var speech = preload("res://scripts/speech_dialogue.gd").new()
var pip_voice = preload("res://scripts/pip_voice.gd").new()
var saved = preload("res://scripts/save.gd").new()
var world: Node3D
var player: CharacterBody3D
var camera: Node3D
var bird: Node3D
@onready var title_menu = $Menus/TitleMenu
@onready var settings_screen = $Menus/SettingsMenu
@onready var pause_screen = $Menus/PauseMenu
@onready var notebook_hud = $NotebookUI/NotebookHUD
@onready var speech_prompt = $SpeechUI/SpeechPrompt
# Debug-only badge references; uncomment together with the SpeechDebug node in main.tscn.
# @onready var speech_debug_panel: PanelContainer = $SpeechUI/SpeechDebug
# @onready var speech_debug_status: Label = $SpeechUI/SpeechDebug/Status
@onready var pip_paper_line = $PaperUI/PipPaperLine
var panel: PanelContainer
var help: Button
var prompt: Label
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
var last_line_speaker: String = "Pip"
var last_line_generated := false
var current_encounter: String = ""
var settings_back: String = "title"
var transition: bool = false
var step_time: float = 0
var pip_voice_status := "Not checked"
func _ready() -> void:
	configure_input()
	# The speech controller owns push-to-talk; mission progression still consumes assessment results here.
	add_child(speech)
	speech.configure()
	# Debug badge refresh is disabled for release; see update_speech_debug() below.
	# update_speech_debug()
	# speech.debug_changed.connect(update_speech_debug)
	speech.answer_ready.connect(spoken_answer)
	speech.recording_started.connect(func(): voice.stop())
	speech.state_changed.connect(speech_prompt.set_state)
	speech.partial_transcript.connect(speech_prompt.show_partial)
	speech.failed.connect(speech_prompt.show_error)
	saved.read_save()
	for bus in ["Voice","Music","Effects"]:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count-1,bus)
		set_volume(saved.volumes[bus],bus)
	voice = AudioStreamPlayer.new()
	voice.bus = "Voice"
	add_child(voice)
	add_child(pip_voice)
	pip_voice.status_changed.connect(_pip_voice_status_changed)
	pip_voice.configure(voice)
	pip_voice.failed.connect(_pip_voice_failed)
	music = AudioStreamPlayer.new()
	music.bus = "Music"
	add_child(music)
	effects = AudioStreamPlayer.new()
	effects.bus = "Effects"
	add_child(effects)
	build_ui()
	title_menu.action_requested.connect(menu_action)
	pause_screen.action_requested.connect(menu_action)
	settings_screen.action_requested.connect(menu_action)
	settings_screen.volume_changed.connect(settings_volume_changed)
	mission.changed.connect(func(): idle=0; update_hud())
	load_world("city")
	show_title()
func update_speech_debug() -> void:
	pass
	# Disabled for release. This populated the lower-left debug badge and kept no gameplay
	# state; restore it together with the SpeechDebug node and the @onready vars above.
	# Keep configuration and live transcription health separate; never show credentials or URLs.
	# var tts_status := pip_voice_status
	# if tts_status.length() > 115:
	# 	tts_status = tts_status.left(114) + "…"
	# var lines := PackedStringArray([
	# 	"Speech available: " + str(speech.available),
	# 	speech.availability_reason,
	# 	"STT: " + speech.stt_status,
	# 	"Pip TTS: " + tts_status,
	# ])
	# if not speech.last_transcript.is_empty():
	# 	var excerpt: String = speech.last_transcript.replace("\n", " ").replace("\r", " ").strip_edges()
	# 	if excerpt.length() > 58:
	# 		excerpt = excerpt.left(57) + "…"
	# 	lines.append("Heard: “" + excerpt + "”")
	# speech_debug_status.text = "\n".join(lines)
	# var color := Color("ffc88a")
	# if pip_voice_status.begins_with("Failed"):
	# 	color = Color("ff9a90")
	# elif speech.stt_status == "Transcript received":
	# 	color = Color("8ee8a5")
	# elif speech.stt_status.begins_with("Failed"):
	# 	color = Color("ff9a90")
	# elif speech.stt_status in ["Connected", "Streaming audio", "Receiving words"] or pip_voice_status.begins_with("Requesting"):
	# 	color = Color("9fd8ff")
	# speech_debug_status.add_theme_color_override("font_color", color)
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
	var card=style.duplicate()
	card.bg_color=Color(0.08,0.19,0.23,0.94)
	prompt = Label.new()
	root.add_child(prompt)
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.offset_left=-400
	prompt.offset_right=400
	prompt.offset_top=-65
	prompt.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_stylebox_override("normal",card)
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
	speech.close()
	pip_voice.cancel()
	if world:
		remove_child(world)
		world.queue_free()
	location=where
	world=Node3D.new()
	add_child(world)
	var scene_path := "res://scenes/new_market.tscn" if where == "supermarket" else "res://scenes/" + where + ".tscn"
	var scene=load(scene_path).instantiate()
	world.add_child(scene)
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
# Shared input/audio policy for authored menus and the remaining legacy overlays.
func prepare_overlay(next_mode: String) -> void:
	set_npc_talking(current_encounter, false)
	speech.close()
	pip_voice.cancel()
	settings_screen.hide()
	title_menu.hide()
	pause_screen.hide()
	panel.hide()
	speech_prompt.hide_prompt()
	notebook_hud.hide()
	help.hide()
	prompt.hide()
	mode=next_mode
	set_bottom_line("")
	player.enabled=false
	camera.enabled=false
	bird.talking=next_mode=="dialogue"
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	voice.stop()
func overlay(next_mode: String, title: String) -> void:
	prepare_overlay(next_mode)
	panel.show()
	panel.clear()
	panel.anchor_bottom = 0.94
	panel.label_text(title,34)

func resume() -> void:
	set_npc_talking(current_encounter, false)
	speech.close()
	pip_voice.cancel()
	speech_prompt.hide_prompt()
	settings_screen.hide()
	title_menu.hide()
	pause_screen.hide()
	notebook_hud.show()
	help.show()
	prompt.show()
	mode="play"
	panel.hide()
	voice.stop()
	set_bottom_line("")
	bird.talking=false
	player.enabled=true
	camera.enabled=true
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	if mission.stage==5: results()
func say(line: String, speaker: String = "Pip") -> void:
	speech.cancel_for_playback()
	pip_voice.cancel()
	last_line=line
	last_line_speaker=speaker
	last_line_generated=false
	voice.stop()
	# The authored paper strip owns bottom-screen subtitles; centered dialogue keeps its own panel.
	set_bottom_line(line if mode == "play" else "", speaker)
	var path: String=LESSON.voice_paths.get(line, "")
	# Choice text has the original preview voice and a separate Pip reading for suggestions.
	var pip_path := "res://audio/pip/" + line.sha256_text() + ".wav"
	if speaker == "Pip" and ResourceLoader.exists(pip_path):
		path = pip_path
	if ResourceLoader.exists(path):
		voice.stream=load(path)
		voice.play()
func say_pip_response(line: String) -> void:
	last_line = line
	last_line_speaker = "Pip"
	last_line_generated = true
	set_bottom_line(line if mode == "play" else "")
	pip_voice.speak(line)

func set_bottom_line(line: String, speaker: String = "Pip") -> void:
	# Keep the paper clear of the nearby-interaction prompt; the debug badge toggle is
	# disabled along with the badge itself.
	pip_paper_line.set_line(line, speaker)
	# speech_debug_panel.visible = line.is_empty()
	prompt.visible = mode == "play" and line.is_empty()
func _pip_voice_failed(message: String) -> void:
	if mode == "dialogue" and panel.visible:
		panel.label_text("Pip audio: " + message, 18)
func _pip_voice_status_changed(status: String) -> void:
	pip_voice_status = status
	update_speech_debug()
func replay_button(line: String, speaker: String = "Pip") -> void:
	panel.button("▶  Listen again",func(): say(line, speaker))
func show_title() -> void:
	prepare_overlay("title")
	title_menu.get_node("%BestStars").text = "Best adventure: " + str(saved.best_stars) + " / 3 stars"
	title_menu.open()

# Menu scenes emit intent without depending on world, mission or save objects.
func menu_action(action: String) -> void:
	match action:
		"play": start()
		"resume": resume()
		"settings": settings(mode)
		"back":
			if settings_back == "title": show_title()
			else: pause_menu()
		"quit": get_tree().quit()
		"restart":
			mission.reset()
			hinted.clear()
			pause_screen.hide()
			travel("supermarket")
		"title":
			mission.reset()
			load_world("city")
			show_title()

func start() -> void:
	mission.reset()
	hinted.clear()
	load_world("city")
	resume()
	say(LESSON.lines.arrival)
func update_hud() -> void:
	notebook_hud.set_progress(mission.stage, LESSON.objectives)
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
		if event.keycode==KEY_R and not last_line.is_empty():
			if last_line_generated: say_pip_response(last_line)
			else: say(last_line, last_line_speaker)
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
		# auto start mission
		mission.enter()
		resume()
		say(LESSON.lines.intro)
	else:
		# load_world builds a fresh player and camera with input disabled, so city arrivals
		# must re-enter play mode or the player is left frozen behind the closing overlay.
		resume()

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
	var speaker: String = data.name.get_slice(" · ", 0)
	overlay("dialogue",data.name)
	set_npc_talking(id, true)
	panel.label_text(data.prompt,26)
	replay_button(data.prompt, speaker)
	if speech.available:
		# Leave space below the conversation card for the dedicated speaking prompt.
		panel.anchor_bottom = 0.66 if mission.failures[id] >= 2 else 0.50
		speech_prompt.show_ready()
		speech.open(id, LESSON)
		if mission.failures[id] >= 2:
			for choice in data.choices:
				if choice[2] == 2:
					panel.label_text("Pip suggests: “" + choice[1] + "”",20)
					panel.button("▶  Hear Pip’s phrase",func(): say(choice[1]))
					break
	else:
		panel.label_text("Choose what you want to say:",18)
		var choices=data.choices.duplicate()
		choices.shuffle()
		for choice in choices:
			var assisted=mission.failures[id]>=2 and choice[2]==2
			panel.choice(("Pip suggests: " if assisted else "")+choice[1],func(): answer(id,choice[0]),func(): say(choice[1], "Answer"))
	panel.button("Close · Keep exploring",resume)
	say(data.prompt, speaker)

func set_npc_talking(id: String, active: bool) -> void:
	if id.is_empty():
		return
	for node in get_tree().get_nodes_in_group("interactables"):
		if node.encounter_id == id and node.has_method("set_talking"):
			node.set_talking(active)
func answer(id: String, response: String) -> void:
	var result=evaluator.evaluate(id,response)
	present_assessment(id, result)

func spoken_answer(result: Dictionary) -> void:
	if mode == "dialogue" and result.encounter_id == current_encounter:
		present_assessment(current_encounter, result)

# Authored choices and speech share the same mission/scoring policy and feedback presentation.
func present_assessment(id: String, result: Dictionary) -> void:
	mission.respond(id,result.quality)
	overlay("dialogue","Pip’s phrase tip")
	if result.has("transcript"):
		panel.label_text("You said: “" + result.transcript + "”",20)
	# Keep the AI's review visible while Pip speaks the child-facing response.
	if result.has("pip_response"):
		panel.label_text("Pip: “" + result.pip_response + "”",25)
		# Debug-only review detail; comment back in to show the raw AI assessment.
		# panel.label_text("AI review (debug): " + result.feedback,18)
		panel.button("▶  Hear Pip again",func(): say_pip_response(result.pip_response))
	else:
		panel.label_text(result.feedback,25)
		if LESSON.voice_paths.has(result.feedback):
			replay_button(result.feedback)
	if result.has("transcript"):
		panel.label_text("Try this phrase: “" + result.suggested_wording + "”",20)
	if result.allowed:
		panel.label_text(LESSON.encounters[id].name+":\n"+LESSON.encounters[id].reply)
		panel.button("▶  Hear the reply",func(): say(LESSON.encounters[id].reply, LESSON.encounters[id].name.get_slice(" · ", 0)))
		if result.quality==1:
			panel.button("Try a stronger answer",func():
				conversation(id))
		panel.button("Continue  →",resume)
	else:
		panel.button("Try again",func(): conversation(id))
		panel.button("Close · Come back later",resume)
	if result.has("pip_response"):
		say_pip_response(result.pip_response)
	else:
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
	prepare_overlay("pause")
	pause_screen.get_node("%Restart").visible = location == "supermarket"
	pause_screen.open()
func settings(back: String) -> void:
	settings_back=back
	prepare_overlay("settings")
	settings_screen.set_volumes(saved.volumes)
	settings_screen.open()

func settings_volume_changed(value: float, bus: String) -> void:
	set_volume(value, bus)
	saved.write_save()

func set_volume(value: float, bus: String) -> void:
	saved.volumes[bus]=value
	var index=AudioServer.get_bus_index(bus)
	if index>=0: AudioServer.set_bus_volume_db(index,linear_to_db(maxf(value,0.0001)))
func _exit_tree() -> void:
	pip_voice.cancel()
	for audio in [voice, music, effects]:
		if is_instance_valid(audio):
			audio.stop()
			audio.stream = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
