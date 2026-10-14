class_name DialogueBox extends CanvasLayer
## Portrait-less text box. Tap anywhere to advance, [건너뛰기] to skip. await play(lines).
signal finished
var lines: Array = []
var idx = 0
var panel: Panel; var speaker: Label; var body: Label; var skip: Button

func _ready() -> void:
	layer = 10; visible = false
	panel = Panel.new(); add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.self_modulate = Color(0, 0, 0, 0.6)
	panel.gui_input.connect(_on_input)
	var box = ColorRect.new(); box.color = Color(0.08, 0.08, 0.15, 0.95); panel.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE); box.offset_top = -420; box.offset_bottom = 0; box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speaker = Label.new(); box.add_child(speaker); speaker.position = Vector2(30, 20)
	speaker.add_theme_font_size_override("font_size", 34); speaker.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	body = Label.new(); box.add_child(body); body.position = Vector2(30, 80); body.size = Vector2(660, 260)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; body.add_theme_font_size_override("font_size", 32)
	var hint = Label.new(); box.add_child(hint); hint.text = "탭하여 계속 ▶"; hint.position = Vector2(30, 360)
	hint.add_theme_font_size_override("font_size", 24); hint.modulate = Color(1, 1, 1, 0.6)
	skip = Button.new(); panel.add_child(skip); skip.text = "건너뛰기"; skip.add_theme_font_size_override("font_size", 30)
	skip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT); skip.offset_left = -230; skip.offset_top = 30; skip.offset_right = -20; skip.offset_bottom = 120
	skip.pressed.connect(_end)

func play(l: Array) -> void:
	lines = l; idx = 0; visible = true; _show(); await finished

func _show() -> void:
	var e = lines[idx]; speaker.text = e[0]; body.text = e[1]

func _on_input(ev: InputEvent) -> void:
	if (ev is InputEventScreenTouch and ev.pressed) or (ev is InputEventMouseButton and ev.pressed):
		idx += 1
		if idx >= lines.size(): _end()
		else: _show()

func _end() -> void:
	if not visible: return
	visible = false; finished.emit()
