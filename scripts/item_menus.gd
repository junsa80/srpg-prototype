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
	var sc = TouchScroll.new(); sc.size_flags_vertical = Control.SIZE_EXPAND_FILL; v.add_child(sc)
	var list = VBoxContainer.new(); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; list.add_theme_constant_override("separation", 8); sc.add_child(list)
	var close = big("닫기"); close.pressed.connect(on_close); v.add_child(close)
	return [root, list, t]

## ◀ 이전 / 다음 ▶ row (touch-sized) for switching units without backing out.
static func nav_row(cycle: Callable, prefix := "N") -> HBoxContainer:
	var h = HBoxContainer.new(); h.add_theme_constant_override("separation", 10); h.name = prefix + "Nav"
	var pv = big("◀ 이전 유닛", 76, 26); pv.name = prefix + "Prev"; pv.pressed.connect(func(): cycle.call(-1)); h.add_child(pv)
	var nx = big("다음 유닛 ▶", 76, 26); nx.name = prefix + "Next"; nx.pressed.connect(func(): cycle.call(1)); h.add_child(nx)
	return h

static func big(t: String, h = 88, fs = 28) -> Button:
	var b = Ornate.button(Button.new()); b.text = t; b.custom_minimum_size = Vector2(0, h)
	b.add_theme_font_size_override("font_size", fs); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; return b

static func label(t: String, fs = 26, col = Color8(248, 240, 224)) -> Label:
	var l = Label.new(); l.text = t; l.add_theme_font_size_override("font_size", fs); l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; return l

## Item button: icon + name/uses + role text; greyed with reason if unit can't use it.
static func weapon_btn(w: WeaponData, u = null, prefix = "", suffix = "", h = 92) -> Button:
	var reason = u.block_reason(w) if u != null else ""
	var b = big("%s%s  %d/%d%s\n%s" % [prefix, w.name, w.uses, w.max_uses, suffix, ("× " + reason) if reason != "" else Weapons.effect_text(w) + ("  " + w.desc if w.desc != "" and w.desc.length() < 14 else "")], h, 22)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT; Icons.on_button(b, w)
	if reason != "": b.add_theme_color_override("font_color", Color8(140, 130, 120))
	elif Icons.tri_color(w).a > 0: b.add_theme_color_override("font_color", Icons.tri_text(w))   # 검 파랑 / 도끼 빨강 / 창 초록
	b.set_meta("reason", reason)
	return b

static func item_str(w: WeaponData) -> String: return "%s  %d/%d" % [w.name, w.uses, w.max_uses]
static func dict_str(d: Dictionary) -> String:
	var w = Weapons.make(d.name, int(d.uses)); return item_str(w)

## Convoy for a live Unit (battle) — deposit unit items / withdraw convoy items.
## cycle (optional): func(d: int) — ◀ ▶ buttons switch straight to the previous/next unit (출전 준비).
static func convoy_panel(parent: Node, u: Unit, on_close: Callable, cycle := Callable()) -> Control:
	var p = _panel(parent, "수송대 — %s" % u.data.name, on_close)
	if cycle.is_valid():
		var t: Label = p[2]; var v = t.get_parent()
		v.add_child(nav_row(cycle, "CV")); v.move_child(v.get_child(v.get_child_count() - 1), t.get_index() + 1)
	_fill_convoy(p[1], u, func(): Campaign.record_progress(u))
	return p[0]

static func _fill_convoy(list: VBoxContainer, u: Unit, changed: Callable) -> void:
	for c in list.get_children(): c.queue_free()
	if list.get_parent() is ScrollContainer:   # overlay (battle): portrait + filter toggle here; base builds its own header
		var hh = HBoxContainer.new(); hh.add_theme_constant_override("separation", 12); list.add_child(hh)
		var pt = TextureRect.new(); pt.texture = Sprites.portrait(u.data.name) if Sprites.portrait(u.data.name) else Sprites.unit_tex(u)
		pt.custom_minimum_size = Vector2(120, 120); pt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; pt.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; pt.name = "UPortrait"; hh.add_child(pt)
		var fb = big("사용 가능한 것만 보기: " + ("ON" if Settings.usable_only else "OFF"), 64, 22); fb.name = "UsableOnly"; hh.add_child(fb)
		fb.pressed.connect(func(): Settings.usable_only = not Settings.usable_only; Settings.save(); _fill_convoy(list, u, changed))
	list.add_child(label("소지품 (%d/%d) — 탭=맡기기" % [u.inventory.size(), Unit.MAX_ITEMS], 26, Color8(160, 200, 255)))
	for w in u.inventory.duplicate():
		var b = weapon_btn(w, u, "▶ " if w == u.weapon() else "")
		b.pressed.connect(func():
			u.inventory.erase(w); Campaign.to_convoy(w); changed.call(); Sfx.play("select"); _fill_convoy(list, u, changed))
		list.add_child(b)
	list.add_child(label("수송대 (%d) — 탭=꺼내기" % Campaign.convoy.size(), 26, Color8(255, 216, 128)))
	var hidden = 0
	for i in Campaign.convoy.size():
		var idx = i
		var cw = Weapons.make(Campaign.convoy[i].name, int(Campaign.convoy[i].uses))
		if Settings.usable_only and u.block_reason(cw) != "": hidden += 1; continue
		var b = weapon_btn(cw, u)
		b.disabled = u.inventory.size() >= Unit.MAX_ITEMS
		b.pressed.connect(func():
			var w = Campaign.from_convoy(idx); u.give(w); changed.call(); Sfx.play("select"); _fill_convoy(list, u, changed))
		list.add_child(b)
	if hidden > 0: list.add_child(label("(사용 불가 %d개 숨김)" % hidden, 22, Color8(170, 170, 190)))
