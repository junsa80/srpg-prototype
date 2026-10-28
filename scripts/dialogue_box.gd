class_name DialogueBox extends CanvasLayer
## Dialogue box with ornate portrait card. Party speaks from the left, others from the right.
## Portraits load from assets/portraits/<name>.png (96x96 or 128x128). Tap to advance; [건너뛰기] skips.
signal finished
var lines: Array = []
var idx = 0
var panel: Control; var box: Panel; var speaker: Label; var body: Label; var skip: Button
var tw: Tween
var port_card: Panel; var port: TextureRect; var name_plate: Panel

func _ready() -> void:
	layer = 10; visible = false
	panel = Control.new(); add_child(panel); panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim = ColorRect.new(); panel.add_child(dim); dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); dim.color = Color(0, 0, 0, 0.45)
	dim.gui_input.connect(_on_input)
	box = Panel.new(); panel.add_child(box); box.add_theme_stylebox_override("panel", Ornate.frame())
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE); box.offset_top = -330; box.offset_bottom = -20; box.offset_left = 16; box.offset_right = -16
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body = Label.new(); box.add_child(body); body.position = Vector2(28, 70); body.size = Vector2(640, 200)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; body.add_theme_font_size_override("font_size", 32)
	body.add_theme_color_override("font_color", Color8(248, 240, 224))
	var hint = Label.new(); box.add_child(hint); hint.text = "▼"; hint.position = Vector2(640, 260); hint.add_theme_color_override("font_color", Color8(248, 216, 112))
	port_card = Ornate.card(panel, Rect2(Vector2(24, 0), Vector2(220, 220)), Color8(40, 32, 64))
	port = TextureRect.new(); port_card.add_child(port); port.position = Vector2(14, 14); port.size = Vector2(192, 192)
	port.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; port.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR; port.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_plate = Panel.new(); panel.add_child(name_plate); name_plate.add_theme_stylebox_override("panel", Ornate.frame(Color8(96, 56, 24), Color8(248, 216, 112), 3))
	name_plate.size = Vector2(240, 60); name_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speaker = Label.new(); name_plate.add_child(speaker); speaker.position = Vector2(16, 8); speaker.size = Vector2(208, 44)
	speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; speaker.add_theme_font_size_override("font_size", 30)
	speaker.add_theme_color_override("font_color", Color8(255, 240, 200))
	skip = Ornate.button(Button.new()); panel.add_child(skip); skip.text = "대화 스킵"; skip.add_theme_font_size_override("font_size", 28)
	skip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT); skip.offset_left = -220; skip.offset_top = 24; skip.offset_right = -20; skip.offset_bottom = 112
	skip.pressed.connect(_end)

func play(l: Array) -> void:
	if l.is_empty(): return
	lines = l; idx = 0; visible = true; _show(); await finished

func _layout(left: bool) -> void:
	var h = get_viewport().get_visible_rect().size.y
	var w = get_viewport().get_visible_rect().size.x
	var safe = SafeArea.insets(get_viewport())
	var narration = str(lines[idx][0]) == ""
	box.offset_bottom = -safe.y - 20; box.offset_top = -safe.y - (260 if narration else 330)
	box.add_theme_stylebox_override("panel", Ornate.frame(Color8(19, 28, 44, 248) if not narration else Color8(20, 30, 38, 240), Color8(202, 166, 97) if not narration else Color8(107, 132, 145), 2))
	body.position = Vector2(28, 46 if narration else 70); body.size = Vector2(w - 88, 170 if narration else 200)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if narration else HORIZONTAL_ALIGNMENT_LEFT
	body.add_theme_color_override("font_color", Color8(200, 215, 225) if narration else Color8(248, 240, 224))
	skip.offset_top = safe.x + 20; skip.offset_bottom = safe.x + 108
	var top = h - safe.y - 330 - 210
	port_card.position = Vector2(24 if left else w - 244, top)
	name_plate.position = Vector2(250 if left else w - 494, top + 150)

func _show() -> void:
	var e = lines[idx]
	var n: String = e[0]
	speaker.text = n if n != "" else "—"; body.text = e[1]
	if tw and tw.is_valid(): tw.kill()
	var cps = Settings.cps() if is_instance_valid(Settings) else 0.0
	if cps > 0 and is_inside_tree():
		body.visible_ratio = 0.0; tw = create_tween(); tw.tween_property(body, "visible_ratio", 1.0, body.text.length() / cps)
	else: body.visible_ratio = 1.0
	var tex = Sprites.portrait(n) if n != "" else null
	port_card.visible = tex != null; port.texture = tex
	name_plate.visible = n != ""
	_layout(Roster.UNITS.has(n) or n == "")
	if not Engine.is_editor_hint(): Sfx.play("cursor")

func _on_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if tw and tw.is_running(): tw.kill(); body.visible_ratio = 1.0; return   # tap = finish line first
		idx += 1
		if idx >= lines.size(): _end()
		else: _show()

func _end() -> void:
	if not visible: return
	if tw and tw.is_valid(): tw.kill()
	visible = false; finished.emit()
