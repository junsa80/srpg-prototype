class_name PrepScreen extends CanvasLayer
## 출전 준비 (before every chapter): pick deployed units (max = chapter slots, 아린 fixed), items/equipment,
## status, then 시작. Deployment spots are highlighted on the live map above the panel and units appear on them.
signal started
const H = 620
var b                     # battle scene
var panel: Panel; var head: Label; var grid_box: GridContainer; var lineup: Array = []

func run(battle) -> void:
	b = battle; layer = 6; b.prep_active = true
	lineup = b.deployed.duplicate()
	panel = Panel.new(); add_child(panel); panel.add_theme_stylebox_override("panel", Ornate.frame(Color8(20, 18, 36, 250)))
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE); panel.offset_top = -H; panel.name = "PrepPanel"
	var v = VBoxContainer.new(); panel.add_child(v); v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 16; v.offset_right = -16; v.offset_top = 12; v.offset_bottom = -12; v.add_theme_constant_override("separation", 10)
	head = ItemMenus.label("", 30, Menus.GOLD); head.autowrap_mode = TextServer.AUTOWRAP_OFF; v.add_child(head)
	v.add_child(ItemMenus.label("탭=출전/제외 (아린 고정) · 위 지도 파란 칸=배치 위치 · 지도 길게 누르기=상태", 20, Menus.DIM))
	var sc = TouchScroll.new(); sc.size_flags_vertical = Control.SIZE_EXPAND_FILL; sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; v.add_child(sc)
	grid_box = GridContainer.new(); grid_box.columns = 2; grid_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_box.add_theme_constant_override("h_separation", 8); grid_box.add_theme_constant_override("v_separation", 8); sc.add_child(grid_box)
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 8); v.add_child(row)
	for t in [["아이템", _items], ["상태", _status], ["시작 ▶", _start]]:
		var bt = ItemMenus.big(t[0], 100, 32); bt.name = "P_" + t[0].replace(" ▶", ""); bt.pressed.connect(t[1]); row.add_child(bt)
	_refresh()
	await started

func _view_h() -> float: return b.get_viewport().get_visible_rect().size.y - H

func _focus_spots() -> void:
	var ps = b.grid.pixel_size(); var vs = b.get_viewport().get_visible_rect().size
	var cy = 0.0
	for c in b.MAP.spots: cy += b.grid.cell_to_pos(c).y
	cy /= b.MAP.spots.size()
	b.cam.position.x = (ps.x - vs.x) / 2 if ps.x <= vs.x else clampf(b.grid.cell_to_pos(b.MAP.spots[0]).x - vs.x / 2, 0, ps.x - vs.x)
	b.cam.position.y = clampf(cy - _view_h() / 2, 0, maxf(0, ps.y - _view_h()))

func _refresh() -> void:
	var size: int = b.MAP.deploy_size
	head.text = "출전 준비 — %s   출전 %d/%d" % [ChapterData.CHAPTERS[b.CHAPTER].title, lineup.size(), size]
	for c in grid_box.get_children(): c.queue_free()
	for n in b.ROSTER_NAMES:
		var on = n in lineup; var e = Campaign.entry(n)
		var star = " ★" if Campaign.is_awakened(b.CHAPTER, n) else ""
		var tag = "[고정] " if n == "아린" else ("[출전] " if on else "")
		var bt = Ornate.button(Button.new(), Color8(120, 200, 255) if on else Color8(120, 104, 80)); bt.custom_minimum_size = Vector2(0, 96)
		bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL; bt.add_theme_font_size_override("font_size", 24)
		bt.text = tag + "%s  Lv%d%s\n%s" % [n, int(e.get("level", 1)), star, e.get("class", Roster.UNITS[n][0])]
		bt.name = "D_" + n
		if e.has("items") and e.items.size(): Icons.on_button(bt, Weapons.make(e.items[0].name, int(e.items[0].uses)))
		if on: bt.add_theme_color_override("font_color", Color8(150, 225, 255))
		else: bt.add_theme_color_override("font_color", Color8(170, 160, 150))
		bt.disabled = not on and lineup.size() >= size
		bt.pressed.connect(func(): _toggle(n))
		grid_box.add_child(bt)
	b.deploy_party(lineup)
	b.grid.highlight_move = b.MAP.spots.slice(0, size); b.grid.queue_redraw()
	_focus_spots()

func _toggle(n: String) -> void:
	if n == "아린": return
	if n in lineup: lineup.erase(n)
	elif lineup.size() < b.MAP.deploy_size: lineup.append(n)
	Sfx.play("select"); _refresh()

func _live(): return b.units.filter(func(u): return u.team == 0)

func _status() -> void:
	Menus.unit_list(self, _live(), "출전 유닛 상태")

## 아이템: pick a deployed unit -> tap item = 장착, [수송대] = deposit/withdraw.
func _items() -> void:
	var o = Menus.overlay(self, "아이템 — 유닛 선택"); var cl: CanvasLayer = o[0]; var v: VBoxContainer = o[1]; cl.name = "PrepItems"
	var list = Menus.scroll(v)
	for u in _live():
		var bt = ItemMenus.big("%s   %s" % [u.data.name, ", ".join(u.inventory.map(func(w): return "%s %d" % [w.name, w.uses]))], 96, 24)
		Icons.on_button(bt, u.weapon() if u.weapon() else u.staff()); bt.alignment = HORIZONTAL_ALIGNMENT_LEFT
		bt.name = "I_" + u.data.name; bt.pressed.connect(func(): _unit_items(u)); list.add_child(bt)
	Menus.close_btn(v, cl)

## Neighbour of u among deployed units (wraps). Used by ◀ ▶ in 소지품/수송대.
func _cycle_target(u: Unit, d: int) -> Unit:
	var lv = _live(); var i = lv.find(u)
	return lv[(maxi(i, 0) + d + lv.size()) % lv.size()] if lv.size() else u

func _unit_items(u: Unit, open_convoy := false) -> void:
	var o = Menus.overlay(self, "%s의 소지품" % u.data.name, 32); var cl: CanvasLayer = o[0]; var v: VBoxContainer = o[1]; cl.name = "PrepUnitItems"
	var jump = func(d: int, to_convoy: bool):
		Campaign.record_progress(u); Sfx.play("cursor"); cl.queue_free(); _unit_items(_cycle_target(u, d), to_convoy)
	if _live().size() > 1: v.add_child(ItemMenus.nav_row(func(d): jump.call(d, false), "PI"))
	var list = Menus.scroll(v)
	var fill = func(self_ref):
		for c in list.get_children(): c.queue_free()
		list.add_child(ItemMenus.label("탭=장착 (맨 위가 장비 무기)", 22, Menus.DIM))
		for w in u.inventory:
			var eq = w == u.weapon()
			var bt = ItemMenus.weapon_btn(w, u, "▶ " if eq else "")
			bt.disabled = not u.can_use(w) or w.is_staff()
			bt.pressed.connect(func(): u.equip(w); Campaign.record_progress(u); Sfx.play("select"); self_ref.call(self_ref))
			list.add_child(bt)
	fill.call(fill)
	var cv = ItemMenus.big("수송대 (맡기기/꺼내기)", 92, 28); v.add_child(cv)
	var holder = {}
	var open_cv = func(): holder["p"] = ItemMenus.convoy_panel(cl, u, func(): holder.p.queue_free(); Campaign.record_progress(u); fill.call(fill),
		(func(d): jump.call(d, true)) if _live().size() > 1 else Callable())
	cv.pressed.connect(open_cv)
	var st = ItemMenus.big("상태 보기", 92, 28); v.add_child(st); st.pressed.connect(func(): Menus.status(self, _live(), _live().find(u)))
	Menus.close_btn(v, cl, func(): Campaign.record_progress(u))
	if open_convoy: open_cv.call()

func _start() -> void:
	Sfx.play("levelup")
	Campaign.deploy = lineup.duplicate(); Campaign.save_campaign()
	b.grid.highlight_move = []; b.grid.queue_redraw(); b.prep_active = false
	b._focus(b.MAP.spots[0])
	queue_free(); started.emit()
