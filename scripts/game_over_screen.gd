class_name GameOverScreen extends CanvasLayer
## Defeat screen: retry same party, or swap units (picker). Shows who would gain 각성.
signal retry_same
signal retry_swap(lineup: Array)
var SIZE = 5
const LOCKED = ["아린"]  # lord must deploy
var root: Control; var picker: VBoxContainer; var choice = []; var roster = []; var prior = []
var start_btn: Button

func _ready() -> void:
	layer = 20; visible = false
	root = ColorRect.new(); root.color = Color(0, 0, 0, 0.85); add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _big(t: String, h = 130) -> Button:
	var b = Ornate.button(Button.new()); b.text = t; b.custom_minimum_size = Vector2(0, h); b.add_theme_font_size_override("font_size", 36); return b

func _clear() -> void:
	for c in root.get_children(): c.queue_free()

func _box() -> VBoxContainer:
	var v = VBoxContainer.new(); root.add_child(v)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); v.offset_left = 40; v.offset_right = -40; v.offset_top = 120; v.offset_bottom = -60
	v.add_theme_constant_override("separation", 20); return v

func open(all: Array, deployed: Array, attempts: Array) -> void:
	SIZE = deployed.size(); roster = all; choice = deployed.duplicate(); prior = attempts; visible = true; _clear()
	var v = _box()
	var t = Label.new(); t.text = "패배…\n(얻은 EXP·레벨은 유지됩니다)"; t.add_theme_font_size_override("font_size", 44)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(t)
	var b1 = _big("같은 파티로 재도전"); b1.pressed.connect(func(): retry_same.emit()); v.add_child(b1)
	var b2 = _big("유닛 교체 후 재도전"); b2.pressed.connect(_open_picker); v.add_child(b2)

func _never_deployed(n: String) -> bool:
	for a in prior:
		if n in a: return false
	return true

func _open_picker() -> void:
	_clear(); var v = _box()
	var t = Label.new(); t.text = "출격 유닛 %d명 선택\n★ = 첫 출격 시 「각성」(전 스탯+2, HP+5)" % SIZE
	t.add_theme_font_size_override("font_size", 30); t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(t)
	var g = GridContainer.new(); g.columns = 2; g.add_theme_constant_override("h_separation", 16); g.add_theme_constant_override("v_separation", 16)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL; v.add_child(g)
	for n in roster:
		var b = _big(n + (" ★" if _never_deployed(n) else ""), 110); b.toggle_mode = true; b.button_pressed = n in choice
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; b.disabled = n in LOCKED
		b.toggled.connect(func(on): _toggle(n, on, b)); g.add_child(b)
	start_btn = _big("출격"); start_btn.pressed.connect(func(): retry_swap.emit(choice.duplicate())); v.add_child(start_btn)
	_refresh()

func _toggle(n: String, on: bool, b: Button) -> void:
	if on and not n in choice:
		if choice.size() >= SIZE: b.set_pressed_no_signal(false); return
		choice.append(n)
	elif not on: choice.erase(n)
	_refresh()

func _refresh() -> void:
	if start_btn: start_btn.disabled = choice.size() != SIZE; start_btn.text = "출격 (%d/%d)" % [choice.size(), SIZE]
