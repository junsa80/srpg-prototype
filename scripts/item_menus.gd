class_name ItemMenus extends RefCounted
## Shared touch item UIs: convoy (deposit/withdraw), equip/trade, shop. Built in code, big buttons.

static func _panel(parent: Node, title: String, on_close: Callable) -> Array:
	var root = ColorRect.new(); parent.add_child(root); root.color = Color(0, 0, 0, 0.7)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card = Panel.new(); root.add_child(card); card.add_theme_stylebox_override("panel", Ornate.frame())
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); card.offset_left = 20; card.offset_right = -20; card.offset_top = 60; card.offset_bottom = -40
	var v = VBoxContainer.new(); card.add_child(v); v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 18; v.offset_right = -18; v.offset_top = 16; v.offset_bottom = -16; v.add_theme_constant_override("separation", 10)
	var t = Label.new(); t.text = title; t.add_theme_font_size_override("font_size", 36); t.add_theme_color_override("font_color", Color8(248, 216, 112)); v.add_child(t)
	var sc = ScrollContainer.new(); sc.size_flags_vertical = Control.SIZE_EXPAND_FILL; v.add_child(sc)
	var list = VBoxContainer.new(); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; list.add_theme_constant_override("separation", 8); sc.add_child(list)
	var close = big("닫기"); close.pressed.connect(on_close); v.add_child(close)
	return [root, list, t]

static func big(t: String, h = 88, fs = 28) -> Button:
	var b = Ornate.button(Button.new()); b.text = t; b.custom_minimum_size = Vector2(0, h)
	b.add_theme_font_size_override("font_size", fs); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; return b

static func label(t: String, fs = 26, col = Color8(248, 240, 224)) -> Label:
	var l = Label.new(); l.text = t; l.add_theme_font_size_override("font_size", fs); l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; return l

static func item_str(w: WeaponData) -> String: return "%s  %d/%d" % [w.name, w.uses, w.max_uses]
static func dict_str(d: Dictionary) -> String:
	var w = Weapons.make(d.name, int(d.uses)); return item_str(w)

## Convoy for a live Unit (battle) — deposit unit items / withdraw convoy items.
static func convoy_panel(parent: Node, u: Unit, on_close: Callable) -> Control:
	var p = _panel(parent, "수송대 — %s" % u.data.name, on_close)
	_fill_convoy(p[1], u, func(): Campaign.record_progress(u))
	return p[0]

static func _fill_convoy(list: VBoxContainer, u: Unit, changed: Callable) -> void:
	for c in list.get_children(): c.queue_free()
	list.add_child(label("소지품 (%d/%d) — 탭=맡기기" % [u.inventory.size(), Unit.MAX_ITEMS], 26, Color8(160, 200, 255)))
	for w in u.inventory.duplicate():
		var b = big(("▶ " if w == u.weapon() else "") + item_str(w))
		b.pressed.connect(func():
			u.inventory.erase(w); Campaign.to_convoy(w); changed.call(); Sfx.play("select"); _fill_convoy(list, u, changed))
		list.add_child(b)
	list.add_child(label("수송대 (%d) — 탭=꺼내기" % Campaign.convoy.size(), 26, Color8(255, 216, 128)))
	for i in Campaign.convoy.size():
		var idx = i
		var b = big(dict_str(Campaign.convoy[i]))
		b.disabled = u.inventory.size() >= Unit.MAX_ITEMS
		b.pressed.connect(func():
			var w = Campaign.from_convoy(idx); u.give(w); changed.call(); Sfx.play("select"); _fill_convoy(list, u, changed))
		list.add_child(b)
