extends PanelContainer
var stack: VBoxContainer
func _ready() -> void:
	var margin = MarginContainer.new()
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,24)
	add_child(margin)
	var scroll = ScrollContainer.new()
	margin.add_child(scroll)
	stack = VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation",12)
	scroll.add_child(stack)
func clear() -> void:
	for child in stack.get_children():
		stack.remove_child(child)
		child.queue_free()
func label_text(text: String, size: int = 22) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(label)
	return label
func button(text: String, action: Callable) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size.y = 48
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.pressed.connect(action)
	stack.add_child(b)
	return b

func choice(text: String, select: Callable, listen: Callable) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	stack.add_child(row)
	var answer = Button.new()
	answer.text = text
	answer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	answer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	answer.custom_minimum_size.y = 64
	answer.pressed.connect(select)
	row.add_child(answer)
	var replay = Button.new()
	replay.text = "▶"
	replay.tooltip_text = "Hear this answer"
	replay.custom_minimum_size.x = 64
	replay.pressed.connect(listen)
	row.add_child(replay)
