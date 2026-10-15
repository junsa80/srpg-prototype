extends Node2D
## Battle scene (any chapter, data from Maps.CH). Touch-first FE-style map UX:
## tap unit -> tap blue cell (shows path arrow) -> tap again to slide there -> tap enemy for forecast -> [확인].
## Drag to pan the camera on large maps.
var CHAPTER = "ch1"
var MAP = {}
@onready var grid: Grid = $Grid
@onready var tm: TurnManager = $TurnManager
@onready var dialogue: DialogueBox = $Dialogue
var cam: Camera2D
var ui: CanvasLayer; var info: Label
var btn_confirm: Button; var btn_cancel: Button; var btn_end: Button
var btn_weapon: Button; var btn_convoy: Button; var btn_open: Button; var btn_danger: Button; var btn_anim: Button; var btn_mute: Button
var terrain_win: Panel; var terrain_lbl: Label; var unit_win: Panel; var unit_lbl: Label; var unit_port: TextureRect
var banner: Label; var combat: CombatScene; var game_over: GameOverScreen; var convoy_ui: Control
var units: Array = []
var selected: Unit = null
var orig_cell = Vector2i.ZERO
var moved = false
var pending_dest = Vector2i(-1, -1)
var pending_target: Unit = null
var pending_heal: Unit = null
var intents: Array = []
var ROSTER_NAMES = []
var deployed = []
var busy = false
var danger_on = false
var anim_on = true
var btn_status: Button; var btn_menu: Button
var prep: PrepScreen = null; var prep_active = false; var press_ms = 0; var opened: Array = []
var drag_from = Vector2.ZERO; var dragging = false; var press_pos = Vector2.ZERO; var pressed = false
const PANEL_H = 380

# ---------------------------------------------------------------- setup
## Dev/screenshot hooks: web URL hash (#ch2, #combat, #base) or user args (--demo=ch2 ...).
static func demo_flags() -> String:
	var f = " ".join(OS.get_cmdline_user_args())
	if OS.has_feature("web"): f += " " + str(JavaScriptBridge.eval("location.hash", true))
	return f

func _ready() -> void:
	var demo = demo_flags()
	if "base" in demo and not Campaign.get_meta("from_base", false) and not "--flowtest" in demo:
		get_tree().change_scene_to_file.call_deferred("res://scenes/base.tscn"); return
	if "ch2" in demo and Campaign.chapter == "ch1": Campaign.chapter = "ch2"; Campaign.ensure_roster()
	var resume: Dictionary = Campaign.resume; Campaign.resume = {}
	if not resume.is_empty() and Maps.CH.has(resume.get("chapter", "")): Campaign.chapter = resume.chapter
	CHAPTER = Campaign.chapter if Maps.CH.has(Campaign.chapter) else "ch1"
	MAP = Maps.CH[CHAPTER].duplicate(true)
	anim_on = Settings.anim
	grid.load_map(MAP.rows)
	Skills.units = units; Skills.grid = grid
	cam = Camera2D.new(); add_child(cam); cam.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT; cam.make_current()
	_build_ui()
	Campaign.ensure_roster()
	ROSTER_NAMES = Roster.joined_by(CHAPTER)
	var tw = Timer.new(); add_child(tw); tw.wait_time = 0.28; tw.autostart = true
	tw.timeout.connect(func(): Unit.anim_frame += 1; for u in units: u.queue_redraw())
	tm.phase_changed.connect(_on_phase)
	var ch = ChapterData.CHAPTERS[CHAPTER]
	if not resume.is_empty():
		_restore(resume); Sfx.start_bgm(); return
	var lineup: Array = Campaign.deploy.filter(func(n): return n in ROSTER_NAMES)
	if lineup.size() != MAP.deploy_size: lineup = MAP.default_deploy.filter(func(n): return n in ROSTER_NAMES)
	deploy_party(lineup)
	for e in MAP.enemies: _spawn_enemy(e)
	_focus(MAP.spots[0])
	info.text = ch.title + " — 목표: " + ch.goal
	Campaign.chapter_start = Campaign.to_dict().duplicate(true)
	if not "--flowtest" in OS.get_cmdline_user_args():
		Sfx.start_bgm()
		var lines = []
		for n in ROSTER_NAMES:
			if Roster.UNITS[n][1] == CHAPTER and Roster.UNITS[n][2] != "" and CHAPTER != "ch1": lines.append([n, Roster.UNITS[n][2]])
		lines.append_array(ch.pre); lines.append_array(ch.get("boss", []))
		if not "nodialog" in demo and not "combat" in demo: await dialogue.play(lines)
		if not "combat" in demo:
			prep = PrepScreen.new(); add_child(prep); await prep.run(self)
	SaveManager.autosave(CHAPTER, 0, payload())  # chapter start (after preparation)
	tm.start_player_phase()
	if "camtop" in demo: cam.position = Vector2(grid.pixel_size().x - _view_size().x, 0)   # dev: screenshot top-right of map
	if "combat" in demo: _demo_combat.call_deferred()
	if "--gameover-demo" in OS.get_cmdline_user_args():
		for u in units: if u.team == 0: u.hp = 0
		_check_end(); game_over._open_picker()

## (Re)place the player party at the chapter's deployment spots.
func deploy_party(lineup: Array) -> void:
	for u in units.duplicate():
		if u.team == 0: units.erase(u); u.queue_free()
	for i in mini(lineup.size(), MAP.spots.size()):
		var n: String = lineup[i]
		var u = Roster.make_unit(n, 0, MAP.spots[i], Campaign.entry(n))
		_place(u)
		if Campaign.is_awakened(CHAPTER, n): u.apply_awakening()
	deployed = lineup.duplicate()

func _place(u: Unit) -> void:
	add_child(u); u.position = grid.cell_to_pos(u.cell); units.append(u)

func _spawn_enemy(e: Array) -> Unit:
	var opts: Dictionary = e[3]
	var u = Roster.make_unit(e[0], 1, e[2])
	if opts.has("name"): u.data.name = opts.name
	u.inventory = [Weapons.make(e[1])]
	u.data.tags = PackedStringArray(["dark"])
	if opts.has("drop"): u.drop = Weapons.make(opts.drop); u.inventory.append(u.drop)
	u.gold_drop = opts.get("gold", 0); u.guard = opts.get("guard", false); u.boss = opts.get("boss", false)
	_place(u); return u

func _btn(t: String, parent: Control, fs = 30) -> Button:
	var b = Ornate.button(Button.new()); b.text = t; b.add_theme_font_size_override("font_size", fs)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; parent.add_child(b); return b

func _build_ui() -> void:
	ui = CanvasLayer.new(); add_child(ui)
	var panel = Panel.new(); ui.add_child(panel); panel.add_theme_stylebox_override("panel", Ornate.frame(Color8(20, 18, 36, 245)))
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE); panel.offset_top = -PANEL_H
	var v = VBoxContainer.new(); panel.add_child(v); v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 14; v.offset_right = -14; v.offset_top = 10; v.offset_bottom = -10; v.add_theme_constant_override("separation", 8)
	info = Label.new(); v.add_child(info); info.size_flags_vertical = Control.SIZE_EXPAND_FILL; info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 24); info.add_theme_color_override("font_color", Color8(248, 240, 224)); info.clip_text = true
	var r2 = HBoxContainer.new(); v.add_child(r2); r2.add_theme_constant_override("separation", 8); r2.custom_minimum_size.y = 74
	btn_weapon = _btn("무기", r2, 24); btn_convoy = _btn("수송", r2, 24); btn_open = _btn("열기", r2, 24)
	btn_status = _btn("상태", r2, 24); btn_danger = _btn("위험", r2, 24); btn_menu = _btn("메뉴", r2, 24)
	btn_status.name = "BtnStatus"; btn_menu.name = "BtnMenu"
	var r1 = HBoxContainer.new(); v.add_child(r1); r1.add_theme_constant_override("separation", 10); r1.custom_minimum_size.y = 104
	btn_cancel = _btn("취소", r1, 34); btn_confirm = _btn("확인", r1, 34); btn_end = _btn("턴 종료", r1, 34)
	btn_confirm.pressed.connect(_on_confirm); btn_cancel.pressed.connect(_on_cancel); btn_end.pressed.connect(_on_end_turn)
	btn_weapon.pressed.connect(_cycle_weapon); btn_convoy.pressed.connect(_open_convoy); btn_open.pressed.connect(_do_open)
	btn_danger.pressed.connect(_toggle_danger); btn_status.pressed.connect(_status_button); btn_menu.pressed.connect(open_menu)
	for b in [btn_confirm, btn_cancel, btn_weapon, btn_convoy, btn_open]: b.disabled = true
	_refresh_toggle_labels()
	# terrain + unit windows (top)
	terrain_win = Panel.new(); ui.add_child(terrain_win); terrain_win.add_theme_stylebox_override("panel", Ornate.frame()); terrain_win.position = Vector2(10, 10); terrain_win.size = Vector2(190, 110)
	terrain_lbl = Label.new(); terrain_win.add_child(terrain_lbl); terrain_lbl.position = Vector2(16, 8); terrain_lbl.add_theme_font_size_override("font_size", 22)
	unit_win = Panel.new(); ui.add_child(unit_win); unit_win.add_theme_stylebox_override("panel", Ornate.frame()); unit_win.size = Vector2(330, 120)
	unit_win.set_anchors_preset(Control.PRESET_TOP_RIGHT); unit_win.position = Vector2(720 - 340, 10)
	unit_port = TextureRect.new(); unit_win.add_child(unit_port); unit_port.position = Vector2(10, 10); unit_port.size = Vector2(100, 100)
	unit_port.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; unit_port.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	unit_lbl = Label.new(); unit_win.add_child(unit_lbl); unit_lbl.position = Vector2(120, 8); unit_lbl.add_theme_font_size_override("font_size", 22)
	terrain_win.visible = false; unit_win.visible = false
	for w in [terrain_win, unit_win]: w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner = Label.new(); ui.add_child(banner); banner.add_theme_font_size_override("font_size", 64); banner.visible = false
	banner.add_theme_color_override("font_outline_color", Color8(16, 16, 24)); banner.add_theme_constant_override("outline_size", 14)
	combat = CombatScene.new(); add_child(combat)
	game_over = GameOverScreen.new(); add_child(game_over)
	game_over.retry_same.connect(_retry_same); game_over.retry_swap.connect(_retry_swap)

func _refresh_toggle_labels() -> void:
	btn_danger.text = "위험 " + ("ON" if danger_on else "OFF")

func _snapshot() -> Dictionary:
	var rd = []
	for i in MAP.get("reinforcements", []).size(): if MAP.reinforcements[i].get("done", false): rd.append(i)
	return {"chapter": CHAPTER, "turn": tm.turn, "units": units.filter(func(u): return u.hp > 0).map(func(u): return u.to_dict()),
		"opened": opened.map(func(c): return [c.x, c.y]), "reinf_done": rd, "deployed": deployed, "chapter_start": Campaign.chapter_start}

## Save payload for SaveManager (campaign + mid-battle snapshot).
func payload() -> Dictionary: return {"campaign": Campaign.to_dict(), "battle": _snapshot()}

func _restore(r: Dictionary) -> void:
	deployed = r.get("deployed", []); Campaign.chapter_start = r.get("chapter_start", Campaign.to_dict().duplicate(true))
	for d in r.units:
		var c = Vector2i(int(d.cell[0]), int(d.cell[1])); var u: Unit
		if int(d.team) == 0:
			u = Roster.make_unit(d.name, 0, c, {"class": d["class"], "level": d.level, "exp": d.exp, "stats": d.stats, "move_bonus": d.get("move_bonus", 0), "items": d.items})
		else:
			u = Roster.make_unit(d.get("kind", d["class"]), 1, c); u.data.name = d.name; u.data.tags = PackedStringArray(["dark"])
			u.level = int(d.level)
			for s in d.stats: u.stats[s] = int(d.stats[s])
			u.inventory = d.items.map(func(i): return Weapons.make(i.name, int(i.uses)))
			var di = int(d.get("drop", -1))
			if di >= 0 and di < u.inventory.size(): u.drop = u.inventory[di]
			u.gold_drop = int(d.get("gold", 0)); u.guard = d.get("guard", false); u.boss = d.get("boss", false)
		u.hp = int(d.hp); u.has_acted = d.get("acted", false); u.awakened = d.get("awakened", false); u.poison = int(d.get("poison", 0))
		_place(u)
	for oc in r.get("opened", []):
		var c = Vector2i(int(oc[0]), int(oc[1]))
		if grid.terrain.get(c, "") == "door": grid.open_door(c)
		elif grid.terrain.get(c, "") == "chest": grid.open_chest(c)
		opened.append(c)
	for i in r.get("reinf_done", []): MAP.reinforcements[int(i)]["done"] = true
	tm.turn = int(r.turn); tm.phase = TurnManager.Phase.PLAYER
	_refresh_intents(); _update_warnings(); _update_danger()
	var first = units.filter(func(u): return u.team == 0)
	if first.size(): _focus(first[0].cell)
	info.text = "%s — 턴 %d 재개\n유닛을 탭하세요 (빈 칸 탭=메뉴)" % [ChapterData.CHAPTERS[CHAPTER].title, tm.turn]
	btn_end.disabled = false

# ---------------------------------------------------------------- camera / input
func _view_size() -> Vector2: return get_viewport().get_visible_rect().size - Vector2(0, PANEL_H)

func _clamp_cam() -> void:
	var vs = _view_size(); var ps = grid.pixel_size()
	cam.position.x = clampf(cam.position.x, minf(0, ps.x - vs.x), maxf(0, ps.x - vs.x)) if ps.x > vs.x else (ps.x - vs.x) / 2
	cam.position.y = clampf(cam.position.y, 0, maxf(0, ps.y - vs.y)) if ps.y > vs.y else 0.0

func _focus(c: Vector2i) -> void:
	cam.position = grid.cell_to_pos(c) - _view_size() / 2; _clamp_cam()

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			if ev.position.y > get_viewport().get_visible_rect().size.y - PANEL_H: return
			pressed = true; dragging = false; press_pos = ev.position; drag_from = cam.position; press_ms = Time.get_ticks_msec()
		elif pressed:
			pressed = false
			if not dragging and not busy and not prep_active and tm.phase == TurnManager.Phase.PLAYER:
				tap(grid.pos_to_cell(get_canvas_transform().affine_inverse() * ev.position))
	elif ev is InputEventMouseMotion and pressed:
		if (ev.position - press_pos).length() > 24: dragging = true
		if dragging: cam.position = drag_from - (ev.position - press_pos); _clamp_cam()

## Long-press (0.5 s) on any unit opens its status screen.
func _process(_dt: float) -> void:
	if pressed and not dragging and Time.get_ticks_msec() - press_ms > 500:
		pressed = false
		var u = _unit_at(grid.pos_to_cell(get_canvas_transform().affine_inverse() * press_pos))
		if u: open_status(u)

func open_status(u: Unit) -> void:
	var same = units.filter(func(o): return o.hp > 0 and o.team == u.team)
	Menus.status(ui, same, same.find(u))

func _status_button() -> void:
	var u = selected if selected else _unit_at(grid.cursor)
	if u == null: u = units.filter(func(o): return o.team == 0 and o.hp > 0)[0]
	open_status(u)

# ---------------------------------------------------------------- battle menu (빈 칸 탭 / [메뉴])
func open_menu() -> void:
	if busy or prep_active or tm.phase != TurnManager.Phase.PLAYER: return
	var o = Menus.overlay(ui, "메뉴", 30, 150, 150); var cl: CanvasLayer = o[0]; var v: VBoxContainer = o[1]; cl.name = "BattleMenu"
	var items = [["유닛 목록", func(): Menus.unit_list(ui, units.filter(func(u): return u.team == 0) + units.filter(func(u): return u.team == 1))],
		["전투 목표", _objective], ["설정", func(): Menus.settings(ui, func(): anim_on = Settings.anim)],
		["중단 저장", func(): Menus.slots(ui, "save", func(): return [CHAPTER, tm.turn, payload()])],
		["챕터 재시작", func(): Menus.confirm(ui, "이 장을 처음부터 다시 할까요?\n(이번 장에서 얻은 경험치·아이템은 장 시작 상태로 돌아갑니다)", "재시작", restart_chapter)],
		["타이틀로", func(): Menus.confirm(ui, "타이틀로 돌아갈까요?\n저장하지 않은 진행은 마지막 자동 저장(턴 %d 시작)부터 이어집니다." % tm.turn, "타이틀로", func(): get_tree().change_scene_to_file("res://scenes/title.tscn"))],
		["턴 종료", func(): cl.queue_free(); _on_end_turn()]]
	for it in items:
		var b = ItemMenus.big(it[0], 92, 32); b.name = "M_" + it[0]; v.add_child(b); var cb: Callable = it[1]
		b.pressed.connect(func(): Sfx.play("select"); cb.call())
	Menus.close_btn(v, cl)
	Sfx.play("select")

func restart_chapter() -> void:
	if not Campaign.chapter_start.is_empty(): Campaign.from_dict(Campaign.chapter_start)
	Campaign.resume = {}; Campaign.save_campaign(); get_tree().reload_current_scene()

func _objective() -> void:
	var ch = ChapterData.CHAPTERS[CHAPTER]
	var o = Menus.overlay(ui, "전투 목표", 35, 200, 200); var cl: CanvasLayer = o[0]; var v: VBoxContainer = o[1]
	var foes = units.filter(func(u): return u.team == 1 and u.hp > 0)
	var t = "%s\n\n승리 조건: %s\n패배 조건: 아린 사망 / 아군 전멸\n\n턴: %d\n남은 적: %d%s\n출전: %s" % [ch.title, ch.goal, tm.turn, foes.size(),
		"  (보스: %s)" % MAP.boss if MAP.get("boss", "") != "" else "", ", ".join(units.filter(func(u): return u.team == 0 and u.hp > 0).map(func(u): return u.data.name))]
	if MAP.get("reinforcements", []).any(func(r): return not r.get("done", false)): t += "\n\n주의: 증원 예정 (느낌표 칸)"
	var l = ItemMenus.label(t, 28); l.size_flags_vertical = Control.SIZE_EXPAND_FILL; v.add_child(l)
	Menus.close_btn(v, cl)

# ---------------------------------------------------------------- helpers
func _unit_at(c: Vector2i) -> Unit:
	for u in units:
		if u.hp > 0 and u.cell == c: return u
	return null

func _unit_named(n: String) -> Unit:
	for u in units:
		if u.team == 0 and u.hp > 0 and u.data.name == n: return u
	return null

func _ranges(u: Unit) -> Array:  # union min/max over usable weapons
	var ws = u.usable_weapons()
	if ws.is_empty(): return [0, 0]
	return [ws.map(func(w): return w.min_range).min(), ws.map(func(w): return w.max_range).max()]

func _dist(a: Vector2i, b: Vector2i) -> int: return abs(a.x - b.x) + abs(a.y - b.y)

func _heal_targets(u: Unit) -> Array:
	if u.staff() == null: return []
	return units.filter(func(o): return o.team == u.team and o != u and o.hp > 0 and o.hp < o.stats.hp and _dist(o.cell, u.cell) == 1)

func _occ(u: Unit) -> Array:
	var occ = {}; var block = {}
	for o in units:
		if o.hp > 0 and o != u:
			occ[o.cell] = true
			if o.team != u.team: block[o.cell] = true
	return [occ, block]

func _show_terrain(c: Vector2i) -> void:
	var t = grid.terrain.get(c, "wall" if grid.walls.has(c) else "")
	var names = {"": "평지", "forest": "숲", "fort": "요새", "throne": "옥좌", "door": "문(잠김)", "chest": "보물상자", "chest_open": "빈 상자", "side": "옆문", "wall": "벽"}
	var b = grid.terrain_bonus(c)
	terrain_lbl.text = "%s\n방어 +%d\n회피 +%d%s" % [names.get(t, t), b[0], b[1], ("  회복%d%%" % b[2]) if b[2] > 0 else ""]
	terrain_win.visible = true

func _show_unit_win(u: Unit) -> void:
	if u == null: unit_win.visible = false; return
	unit_port.texture = Sprites.portrait(u.data.name) if Sprites.portrait(u.data.name) else Sprites.unit_tex(u)
	var w = u.weapon()
	unit_lbl.text = "%s  Lv%d\nHP %d/%d\n%s" % [u.data.name, u.level, u.hp, u.stats.hp, (w.name + " %d" % w.uses) if w else "-"]
	unit_win.visible = true

# ---------------------------------------------------------------- tap state machine
func tap(c: Vector2i) -> void:
	if not grid.in_bounds(c): return
	grid.cursor = c; Sfx.play("cursor"); _show_terrain(c)
	var u = _unit_at(c)
	_show_unit_win(u if u else selected)
	if selected == null:
		if u and u.team == 0 and not u.has_acted: _select(u)
		elif u and u.team == 1: _show_enemy(u)
		elif u: _show_info(u)
		else: open_menu()
		return
	if u and u.team == 0 and u != selected and u in _heal_targets(selected) and moved:
		pending_target = null; pending_heal = u
		var st = selected.staff()
		info.text = "%s → %s  %s (%d/%d)\nHP %d → %d\n[확인]으로 회복" % [selected.data.name, u.data.name, st.name, st.uses, st.max_uses,
			u.hp, mini(u.stats.hp, u.hp + st.heal + selected.eff("mag"))]
		btn_confirm.disabled = false
		return
	if u and u.team == 1 and moved:
		var d = _dist(selected.cell, u.cell)
		var ok = selected.usable_weapons().filter(func(w): return d >= w.min_range and d <= w.max_range)
		if ok.is_empty(): return
		if not BattleManager.in_range(selected, u): selected.equip(ok[0])
		pending_target = u; pending_heal = null
		btn_weapon.disabled = ok.size() < 2
		_show_forecast()
		return
	if not moved and c in grid.highlight_move and (u == null or u == selected):
		if pending_dest == c:
			await _move_selected(c)
		else:
			pending_dest = c
			grid.arrow = grid.move_path(selected.cell, c, grid.highlight_move); grid.queue_redraw()
			info.text = "한 번 더 탭하면 이동 (경로 표시)"

func _show_forecast() -> void:
	var u = pending_target
	var old = selected.flags.get("moved", false); selected.flags["moved"] = true
	var f = BattleManager.forecast(selected, u)
	selected.flags["moved"] = old
	info.text = "%s [%s %d]  HP %d→%d  위력 %d%s 명중 %d%% 치명 %d%%\n%s [%s]  HP %d→%d  위력 %s 명중 %s 치명 %s%s\n[확인]=공격%s" % [
		f.atk_name, f.atk_weapon, f.atk_uses, f.atk_hp_before, f.atk_hp_after, f.atk_dmg, "×2" if f.atk_x2 else "", f.atk_hit, f.atk_crit,
		f.def_name, u.weapon().name if u.weapon() else "-", f.def_hp_before, f.def_hp_after, "-" if f.def_dmg < 0 else str(f.def_dmg) + ("×2" if f.def_x2 else ""),
		"-" if f.def_hit < 0 else str(f.def_hit) + "%", "-" if f.def_crit < 0 else str(f.def_crit) + "%", " 선공!" if f.vantage else "",
		"  [무기]=변경" if not btn_weapon.disabled else ""]
	btn_confirm.disabled = false

func _cycle_weapon() -> void:
	if selected == null or pending_target == null: return
	var d = _dist(selected.cell, pending_target.cell)
	var ok = selected.usable_weapons().filter(func(w): return d >= w.min_range and d <= w.max_range)
	if ok.size() < 2: return
	var i = ok.find(selected.weapon())
	selected.equip(ok[(i + 1) % ok.size()]); Sfx.play("select"); _show_forecast(); selected.queue_redraw()

func _move_selected(c: Vector2i) -> void:
	busy = true
	var path = grid.move_path(selected.cell, c, grid.highlight_move)
	grid.highlight_move = []; grid.highlight_attack = []; grid.arrow = []; grid.queue_redraw()
	await _slide(selected, path)
	selected.cell = c; moved = true; pending_dest = Vector2i(-1, -1)
	var r = _ranges(selected)
	grid.highlight_attack = grid.attack_range([c], r[0], r[1]) if r[1] > 0 else []
	grid.highlight_heal = _heal_targets(selected).map(func(o): return o.cell)
	grid.queue_redraw()
	var extra = []
	if not grid.highlight_heal.is_empty(): extra.append("초록=지팡이")
	if _openable(selected) != null: extra.append("[열기]")
	info.text = "%s 이동. 적 탭=예측 %s / [확인]=대기" % [selected.data.name, " ".join(extra)]
	btn_confirm.disabled = false; btn_open.disabled = _openable(selected) == null
	busy = false

func _slide(u: Unit, path: Array) -> void:
	if not anim_on or path.size() < 2 or not is_inside_tree():
		u.position = grid.cell_to_pos(path[-1] if path.size() else u.cell); return
	var tw = create_tween()
	for i in range(1, path.size()): tw.tween_property(u, "position", grid.cell_to_pos(path[i]), 0.07)
	await tw.finished

func _items_text(u: Unit) -> String:
	return ", ".join(u.inventory.map(func(w): return "%s%s %d/%d" % ["▶" if w == u.weapon() else "", w.name, w.uses, w.max_uses]))

func _skill_text(u: Unit) -> String:
	var sk = Skills.LIST.get(u.data.name)
	return ("스킬: " + sk[0]) if sk else ""

func _show_info(u: Unit) -> void:
	info.text = "%s Lv%d %s HP %d/%d EXP %d%s\n%s\n%s" % [u.data.name, u.level, u.unit_class.name, u.hp, u.stats.hp, u.exp,
		"  [각성]" if u.awakened else "", _items_text(u), _skill_text(u)]

func _select(u: Unit) -> void:
	selected = u; orig_cell = u.cell; moved = false; pending_target = null; pending_heal = null; pending_dest = Vector2i(-1, -1)
	var o = _occ(u)
	grid.highlight_move = grid.movement_range(u.cell, u.move_range(), o[1], o[0])
	var r = _ranges(u)
	grid.highlight_attack = grid.attack_range(grid.highlight_move, r[0], r[1]) if r[1] > 0 else []
	grid.queue_redraw(); Sfx.play("select")
	_show_info(u); info.text += "\n파란 칸 탭=경로, 다시 탭=이동 (제자리 탭=행동)"
	btn_cancel.disabled = false
	btn_convoy.disabled = u.data.name != "아린"

func _show_enemy(u: Unit) -> void:
	var o = _occ(u)
	grid.highlight_move = [u.cell] if u.boss else grid.movement_range(u.cell, u.move_range(), o[1], o[0])
	var r = _ranges(u)
	grid.highlight_attack = grid.attack_range(grid.highlight_move, r[0], r[1]) if r[1] > 0 else []
	grid.queue_redraw()
	var intent = ""
	for i in intents: if i.unit == u: intent = "→ " + (i.target.data.name + " 공격 예정" if i.target else ("대기" if i.move_to == u.cell else "이동 예정"))
	info.text = "%s HP %d/%d  %s%s\n%s%s" % [u.data.name, u.hp, u.stats.hp, intent, "  (경계)" if u.guard else "",
		_items_text(u), "\n★ 처치 시 획득: " + (u.drop.name if u.drop else "%dG" % u.gold_drop) if (u.drop or u.gold_drop > 0) else ""]

# ---------------------------------------------------------------- actions
func _on_confirm() -> void:
	if selected == null or busy: return
	if not moved:  # act in place
		moved = true; await _move_selected(selected.cell); return
	busy = true
	selected.flags["moved"] = selected.cell != orig_cell
	var a = selected
	if pending_heal:
		var log = BattleManager.heal(a, pending_heal)
		await _animate(a, pending_heal)
		info.text = "\n".join(log)
	elif pending_target:
		var d = pending_target
		var log = BattleManager.resolve(a, d)
		await _animate(a, d)
		log.append_array(_handle_kills(a, d))
		info.text = "\n".join(log)
	a.flags["moved"] = false
	busy = false
	_finish_unit(a)

func _animate(a: Unit, d: Unit) -> void:
	if anim_on and is_inside_tree() and not "--flowtest" in OS.get_cmdline_user_args():
		combat.play(a, d, BattleManager.events, BattleManager.exp_events, BattleManager.start_hp)
		await combat.done
	else:
		for e in BattleManager.events: Sfx.play("miss" if e.type == "strike" and not e.hit else ("crit" if e.get("crit", false) else "hit"))
		for ee in BattleManager.exp_events: if ee.ups.size(): Sfx.play("levelup")

## Drops/gold for killed enemies; killer gets item or it goes to convoy.
func _handle_kills(a: Unit, d: Unit) -> Array:
	var out = []
	for pair in [[a, d], [d, a]]:
		var killer: Unit = pair[0]; var dead: Unit = pair[1]
		if dead.hp > 0 or dead.team != 1 or killer.team != 0: continue
		if dead.gold_drop > 0: Campaign.gold += dead.gold_drop; out.append("%dG 획득!" % dead.gold_drop); dead.gold_drop = 0
		if dead.drop and dead.drop in dead.inventory:
			var it: WeaponData = dead.drop; dead.drop = null
			if killer.give(it): out.append("%s 획득 → %s" % [it.name, killer.data.name])
			else: Campaign.to_convoy(it); out.append("%s → 수송대 (소지품 가득)" % it.name)
			Campaign.record_progress(killer)
		Campaign.save_campaign()
	return out

func _openable(u: Unit):
	if u == null or not Roster.is_thief(u): return null
	var reach_door = 2 if Skills.has(u, "릴리") else 1
	var reach_chest = 1 if Skills.has(u, "잭") else 0
	for c in grid.terrain:
		var t = grid.terrain[c]
		if t == "door" and _dist(c, u.cell) <= reach_door: return c
		if t == "chest" and _dist(c, u.cell) <= reach_chest: return c
	return null

func _do_open() -> void:
	if selected == null or not moved: return
	var c = _openable(selected)
	if c == null: return
	var t = grid.terrain[c]
	opened.append(c)
	if t == "door":
		grid.open_door(c); info.text = "%s: 문을 열었다!" % selected.data.name
	else:
		grid.open_chest(c)
		var ch = MAP.get("chest", {"item": "", "gold": 500})
		var msg = []
		if ch.get("item", "") != "":
			var it = Weapons.make(ch.item)
			if selected.give(it): msg.append("%s 획득!" % it.name)
			else: Campaign.to_convoy(it); msg.append("%s → 수송대" % it.name)
		var g = ch.get("gold", 0) + (300 if Skills.has(selected, "잭") else 0)
		if g > 0: Campaign.gold += g; msg.append("%dG 획득!" % g)
		Campaign.record_progress(selected); info.text = "보물상자: " + " ".join(msg)
	Sfx.play("levelup")
	_finish_unit(selected)

func _on_cancel() -> void:
	if busy: return
	Sfx.play("cancel")
	if selected and moved:
		selected.cell = orig_cell; selected.position = grid.cell_to_pos(orig_cell)
	_clear()

func _finish_unit(u: Unit) -> void:
	u.has_acted = true; u.queue_redraw()
	for o in units: o.visible = o.hp > 0; o.queue_redraw()
	_clear(false)
	if _check_end(): return
	_update_danger()
	if units.filter(func(o): return o.team == 0 and o.hp > 0 and not o.has_acted).is_empty(): _on_end_turn()

func _clear(reset_text = true) -> void:
	selected = null; pending_target = null; pending_heal = null; moved = false; pending_dest = Vector2i(-1, -1)
	grid.highlight_move = []; grid.highlight_attack = []; grid.highlight_heal = []; grid.arrow = []; grid.queue_redraw()
	for b in [btn_confirm, btn_cancel, btn_weapon, btn_convoy, btn_open]: b.disabled = true
	if reset_text: info.text = "유닛을 탭하세요 (드래그=화면 이동)"

func _toggle_danger() -> void:
	danger_on = not danger_on; _update_danger(); _refresh_toggle_labels(); Sfx.play("select")

func _update_danger() -> void:
	var cells = {}
	if danger_on:
		for e in units:
			if e.team != 1 or e.hp <= 0: continue
			var o = _occ(e)
			var mv = [e.cell] if e.boss else grid.movement_range(e.cell, e.move_range(), o[1], o[0])
			var r = _ranges(e)
			for c in grid.attack_range(mv, r[0], r[1]): cells[c] = true
	grid.danger = cells.keys(); grid.queue_redraw()


# ---------------------------------------------------------------- convoy (lord only, in battle)
func _open_convoy() -> void:
	if selected == null or selected.data.name != "아린": return
	if convoy_ui: convoy_ui.queue_free()
	convoy_ui = ItemMenus.convoy_panel(ui, selected, func(): convoy_ui.queue_free(); convoy_ui = null; _show_info(selected))

# ---------------------------------------------------------------- phases
func _banner(text: String, col: Color) -> void:
	Sfx.play("phase")
	banner.text = text; banner.add_theme_color_override("font_color", col); banner.visible = true
	if not is_inside_tree() or "--flowtest" in OS.get_cmdline_user_args(): banner.visible = false; return
	var vs = get_viewport().get_visible_rect().size
	banner.position = Vector2(-600, vs.y * 0.3)
	var tw = create_tween()
	tw.tween_property(banner, "position:x", vs.x / 2 - 260, 0.25).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(0.6); tw.tween_property(banner, "position:x", vs.x + 50, 0.25)
	await tw.finished
	banner.visible = false

func _on_end_turn() -> void:
	if tm.phase != TurnManager.Phase.PLAYER or busy: return
	_clear()
	var lines = _end_of_player_turn()
	tm.end_player_phase()
	if lines.size(): info.text = "\n".join(lines)

func _on_phase(phase: int, turn: int) -> void:
	btn_end.disabled = phase != TurnManager.Phase.PLAYER
	if phase == TurnManager.Phase.PLAYER:
		var lines = _start_of_phase(0)
		for u in units: u.has_acted = false; u.visible = u.hp > 0; u.queue_redraw()
		_refresh_intents(); _update_warnings(); _update_danger()
		SaveManager.autosave(CHAPTER, turn, payload())  # autosave each turn
		info.text = "\n".join(lines) + ("\n" if lines.size() else "") + "턴 %d — 플레이어 페이즈\n유닛 탭=선택 · 길게=상태 · 빈 칸=메뉴" % turn
		if _check_end(): return
		await _banner("플레이어 페이즈", Color8(120, 176, 255))
	else:
		busy = true
		await _banner("적 페이즈", Color8(255, 96, 96))
		await _run_enemy_phase()
		busy = false

func _update_warnings() -> void:
	var w = []
	for r in MAP.get("reinforcements", []):
		if tm.turn >= r.turn - 1 and tm.turn < r.turn + 1 and not r.get("done", false):
			for e in r.units: w.append(e[2])
	grid.warnings = w; grid.queue_redraw()

func _refresh_intents() -> void:
	intents = []
	for e in units.filter(func(u): return u.team == 1 and u.hp > 0): intents.append(EnemyAI.plan(e, units, grid))

func _run_enemy_phase() -> void:
	var lines = _start_of_phase(1)
	for r in MAP.get("reinforcements", []):
		if tm.turn == r.turn and not r.get("done", false):
			r["done"] = true
			for e in r.units:
				if _unit_at(e[2]) == null: _spawn_enemy(e); lines.append("증원 출현!")
	for e in units.filter(func(u): return u.team == 1 and u.hp > 0):
		var plan = EnemyAI.plan(e, units, grid)
		if plan.move_to != e.cell:
			var o = _occ(e)
			var path = grid.move_path(e.cell, plan.move_to, grid.movement_range(e.cell, e.move_range(), o[1], o[0]))
			e.cell = plan.move_to
			if anim_on and is_inside_tree(): _focus(e.cell); await _slide(e, path)
			else: e.position = grid.cell_to_pos(e.cell)
		if plan.target:
			lines.append_array(BattleManager.resolve(e, plan.target))
			await _animate(e, plan.target)
			lines.append_array(_handle_kills(plan.target, e))
		elif is_inside_tree() and anim_on: await get_tree().create_timer(0.05).timeout
		for u in units: u.visible = u.hp > 0
	for u in units: u.visible = u.hp > 0; u.queue_redraw()
	if _check_end(): return
	tm.end_enemy_phase()
	if lines.size(): info.text = "\n".join(lines.slice(-4)) + "\n" + info.text

## Phase start for team: poison, 카이젠, terrain healing (fort/throne).
func _start_of_phase(team: int) -> Array:
	var out = []
	for u in units:
		if u.hp <= 0 or u.team != team: continue
		if team == 0 and Skills.has(u, "카이젠"): u.flags["kaizen"] = true
		var h = grid.terrain_bonus(u.cell)[2]
		if h > 0 and u.hp < u.stats.hp:
			var amt = mini(u.stats.hp - u.hp, maxi(1, u.stats.hp * h / 100)); u.hp += amt; out.append("%s 지형 회복 +%d" % [u.data.name, amt])
		if u.poison > 0:
			u.hp = maxi(1, u.hp - 3); u.poison -= 1; out.append("%s 독 피해 3" % u.data.name)
	return out

func _start_of_player_turn() -> Array: return _start_of_phase(0)

func _end_of_player_turn() -> Array:
	var out = []
	for u in units:
		var h = Skills.end_turn_heal(u)
		if h <= 0 or u.hp <= 0: continue
		for o in units:
			if o != u and o.team == u.team and o.hp > 0 and o.hp < o.stats.hp and _dist(o.cell, u.cell) == 1:
				var amt = mini(h, o.stats.hp - o.hp); o.hp += amt; o.queue_redraw(); out.append("%s 스킬: %s HP +%d" % [u.data.name, o.data.name, amt])
	return out

# ---------------------------------------------------------------- end conditions
func _won() -> bool:
	if MAP.goal == "boss":
		return units.filter(func(u): return u.team == 1 and u.boss and u.hp > 0).is_empty()
	return units.filter(func(u): return u.team == 1 and u.hp > 0).is_empty()

func _check_end() -> bool:
	var p = units.filter(func(u): return u.team == 0 and u.hp > 0).size()
	if _won():
		info.text = "승리!"; btn_end.disabled = true
		for u in units: if u.team == 0: Campaign.record_progress(u, false)
		var g = Campaign.CLEAR_GOLD.get(CHAPTER, 500)
		Campaign.record_clear(CHAPTER)  # 각성 removed on clear; advances Campaign.chapter
		info.text = "승리! 클리어 보상 %dG" % g
		_after_clear()
		return true
	if p == 0 or _unit_named("아린") == null:
		info.text = "패배..."; btn_end.disabled = true
		Campaign.record_defeat(CHAPTER, deployed)  # EXP/levels/items already persisted
		game_over.open(ROSTER_NAMES, deployed, Campaign.attempts.get(CHAPTER, []))
		return true
	return false

func _after_clear() -> void:
	if "--flowtest" in OS.get_cmdline_user_args(): return
	await dialogue.play(ChapterData.CHAPTERS[CHAPTER].post)
	get_tree().change_scene_to_file("res://scenes/base.tscn")

func _retry_same() -> void:
	Campaign.deploy = deployed.duplicate(); Campaign.save_campaign(); get_tree().reload_current_scene()

func _retry_swap(lineup: Array) -> void:
	Campaign.deploy = lineup; Campaign.save_campaign(); get_tree().reload_current_scene()

func _demo_combat() -> void:
	await get_tree().create_timer(1.6).timeout
	var a = units.filter(func(u): return u.team == 0)[0]
	var e = units.filter(func(u): return u.team == 1 and not u.boss)[0]
	a.exp = 95; a.cell = e.cell + Vector2i(0, 1); a.position = grid.cell_to_pos(a.cell); _focus(a.cell)
	selected = a; moved = true; pending_target = e
	await _on_confirm()
