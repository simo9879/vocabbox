extends PanelContainer

@onready var status_label: Label = %Status
@onready var bars: Control = %Bars

var _listening := false
var _elapsed := 0.0

func show_ready() -> void:
	show()
	set_state("idle")

func hide_prompt() -> void:
	_listening = false
	hide()

func set_state(state: String) -> void:
	_listening = state == "recording"
	bars.visible = _listening
	match state:
		"recording": status_label.text = "Listening… Release E when you finish."
		"transcribing": status_label.text = "Transcribing your answer…"
		"evaluating": status_label.text = "Checking your words…"
		_: status_label.text = "Hold E to speak, then release to submit."

func show_error(message: String) -> void:
	_listening = false
	bars.hide()
	status_label.text = message + " Hold E to try again."

func show_partial(text: String) -> void:
	if _listening and not text.strip_edges().is_empty():
		var excerpt := text.strip_edges()
		if excerpt.length() > 48:
			excerpt = "…" + excerpt.right(47)
		status_label.text = "Listening… “%s”" % excerpt

func _process(delta: float) -> void:
	if not _listening:
		return

	# Animate the authored 2D bars only while the microphone is recording.
	_elapsed += delta
	for index in bars.get_child_count():
		var bar: ColorRect = bars.get_child(index)
		bar.scale.y = 0.35 + 0.65 * absf(sin(_elapsed * 7.0 + index * 0.85))
