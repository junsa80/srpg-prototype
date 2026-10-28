extends Node2D
## Battle scene (any chapter, data from Maps.CH). Touch-first FE-style map UX:
## tap unit -> tap blue cell (shows path arrow) -> tap again to slide there -> tap enemy for forecast -> [확인].
## Drag to pan the camera on large maps.
var CHAPTER = "ch1"
var first_guide: FirstPlayGuide
var first_entry = false
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
var fc_panel: Panel; var unit_wicon: TextureRect
var btn_status: Button; var btn_menu: Button
const DROP_W = 1; const DROP_I = 1; const DROP_W_ELITE = 5; const DROP_I_ELITE = 5   # rare (was 3/5 normal, 12/10 elite); junk never rolls
var spawn_seq = 0
var prep: PrepScreen = null; var prep_active = false; var press_ms = 0; var opened: Array = []
var kills = 0; var stole = 0; var chests_got = 0; var escaped: Array = []; var seized = false
var visited: Array = []; var ruined: Array = []; var killed_names: Array = []; var clear_report = {}; var events_seen: Array = []; var boss_talked = false
var drag_from = Vector2.ZERO; var dragging = false; var press_pos = Vector2.ZERO; var pressed = false
const PANEL_H = 396
var sa := Vector2.ZERO   # safe-area insets (top, bottom) in viewport units, see SafeArea

# ---------------------------------------------------------------- setup
## Dev/screenshot hooks: web URL hash (#ch2, #combat, #base) or user args (--demo=ch2 ...).
static func demo_flags() -> String:
	var f = " ".join(OS.get_cmdline_user_args())
	if OS.has_feature("web"): f += " " + str(JavaScriptBridge.eval("location.hash", true))
	return f

func _ready() -> void:
	var demo = demo_flags()
	first_entry = Campaign.get_meta("first_play", false)
	if Campaign.has_meta("first_play"): Campaign.remove_meta("first_play")
	if "lv12" in demo:   # dev: screenshot promotion compare
		Campaign.ensure_roster()
		for n in Campaign.roster: Campaign.roster[n].level = 12
	if "base" in demo and not Campaign.get_meta("from_base", false) and not "--flowtest" in demo:
		get_tree().change_scene_to_file.call_deferred("res://scenes/base.tscn"); return
	if "ch2" in demo and Campaign.chapter == "ch1": Campaign.chapter = "ch2"; Campaign.ensure_roster()
	var gm = RegEx.create_from_string("goto=(ch\\w+)").search(demo)   # dev: #goto=ch5 jumps to a chapter
	if gm and Maps.CH.has(gm.get_string(1)) and Campaign.chapter != gm.get_string(1):
		Campaign.chapter = gm.get_string(1)
		if Roster.CH_INDEX.get(Campaign.chapter, 0) >= Roster.CH_INDEX.get("ch5", 99): Campaign.recruited = ["가렌", "카이"]
		Campaign.ensure_roster()
	var resume: Dictionary = Campaign.resume; Campaign.resume = {}
	if not resume.is_empty() and Maps.CH.has(resume.get("chapter", "")): Campaign.chapter = resume.chapter
	CHAPTER = Campaign.chapter if Maps.CH.has(Campaign.chapter) else "ch1"
	MAP = Maps.CH[CHAPTER].duplicate(true)
	anim_on = Settings.anim
	grid.ground = MAP.get("ground", "grass"); grid.theme = MAP.get("tiles", "")
	grid.load_map(MAP.rows)
	Skills.units = units; Skills.grid = grid
	cam = Camera2D.new(); add_child(cam); cam.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT; cam.make_current(); cam.zoom = Vector2.ONE * Settings.map_zoom
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
	if lineup.size() != MAP.deploy_size or not "아린" in lineup:
		lineup = MAP.get("default_deploy", []).filter(func(n): return n in ROSTER_NAMES)
		for n in ROSTER_NAMES:
			if lineup.size() >= MAP.deploy_size: break
			if not n in lineup: lineup.append(n)
		if not "아린" in lineup: lineup[-1] = "아린"
		lineup.erase("아린"); lineup.push_front("아린")
	deploy_party(lineup)
	for e in MAP.enemies:
		if e[3].has("talk") and Campaign.roster.has(e[3].get("name", "")) and (Campaign.keep_all or e[3].has("route")): continue   # already recruited
		if e[3].has("route") and Campaign.route != e[3].route: continue   # route-specific (e.g. 스칼드 in ch5 only for 남로)
		_spawn_enemy(e)
	for n in MAP.get("npc", []):
		if not Campaign.roster.has(n[0]): _spawn_npc(n)
	_focus(MAP.spots[0])
	info.text = ch.title + " — 목표: " + goal_text()
	Campaign.chapter_start = Campaign.to_dict().duplicate(true)
	if not "--flowtest" in OS.get_cmdline_user_args():
		Sfx.start_bgm()
		var lines = []
		for n in ROSTER_NAMES:
			if Roster.UNITS[n][1] == CHAPTER and Roster.UNITS[n][2] != "" and CHAPTER != "ch1": lines.append([n, Roster.UNITS[n][2]])
		if CHAPTER == "ch1" and Campaign.cycle == 0 and resume.is_empty() and not first_entry: lines.append_array(ChapterData.PROLOGUE)
		lines.append_array(ch.pre.slice(0, 3) if first_entry and CHAPTER == "ch1" else ch.pre)   # 보스 대사는 첫 교전 때 (_boss_talk)
		if not "nodialog" in demo and not "combat" in demo and not "effdemo" in demo: await dialogue.play(lines)
		if not first_entry and not "combat" in demo and not "effdemo" in demo and not "noprep" in demo:   # dev: #noprep skips the deployment screen
			prep = PrepScreen.new(); add_child(prep); await prep.run(self)
	SaveManager.autosave(CHAPTER, 0, payload())  # chapter start (after preparation)
	if "devwin" in demo:   # dev: screenshot the clear/rank/branch screens
		for u in units:
			if u.team == 1: u.hp = 0; u.visible = false
		seized = true; escaped.append("아린")
	tm.start_player_phase()
	if first_entry and CHAPTER == "ch1" and Campaign.get_meta("guided_start", false): _start_guide()
	if Campaign.has_meta("guided_start"): Campaign.remove_meta("guided_start")
	if "mapview" in demo:   # dev: whole-map overview screenshot
		var z = minf(_view_size().x / grid.pixel_size().x, _view_size().y / grid.pixel_size().y)
		cam.zoom = Vector2(z, z); cam.position = Vector2.ZERO
	if "camtop" in demo: cam.position = Vector2(grid.pixel_size().x - _view_size().x, 0)   # dev: screenshot top-right of map
	if "combatfx" in demo: _demo_fx.call_deferred()
	elif "combat" in demo: _demo_combat.call_deferred()
	if "forecast" in demo: _demo_forecast.call_deferred()
	if "effdemo" in demo: _demo_eff.call_deferred("effdemofc" in demo)
	var rd = RegEx.create_from_string("recruit=([^+&]+)").search(demo)   # dev: #recruit=아린|카스 talk dialogue screenshot
	if rd: dialogue.play.call_deferred(ChapterData.TALK.get("아린|" + rd.get_string(1).uri_decode(), ChapterData.CAMP.get(rd.get_string(1).uri_decode(), [])))
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
	u.aoe = opts.get("aoe", false); u.raider = opts.get("raider", false); u.talk_from = opts.get("talk", "")
	if opts.has("item"): u.inventory.append(Weapons.make(opts.item))
	# random drops: equipped weapon / carried item. Elites (guards, "elite") higher; bosses & fixed drops use only the fixed drop.
	u.uid = spawn_seq; spawn_seq += 1
	if not u.boss and u.drop == null and u.talk_from == "":
		var elite = opts.get("elite", false) or u.guard
		u.drop_w = opts.get("drop_w", DROP_W_ELITE if elite else DROP_W) if not junk(u.weapon()) else 0   # no ordinary-weapon drops
		u.drop_i = opts.get("drop_i", DROP_I_ELITE if elite else DROP_I) if u.items().size() > 0 and not junk(u.items()[0]) else 0
	EnemyAI.smart = Campaign.difficulty >= 2
	_level_to(u, int(opts.get("lv", 1)) + Campaign.enemy_lv)
	for st in opts.get("bonus", {}): u.stats[st] = int(u.stats[st]) + int(opts.bonus[st])   # boss-only flat bonus (cap-exempt)
	if opts.has("bonus"): u.hp = u.stats.hp
	_place(u); return u

## Deterministic enemy/NPC levels (fixed growth) — chapter difficulty curve lives in maps.gd "lv".
func _level_to(u: Unit, lv: int) -> void:
	var fg = Unit.fixed_growth; Unit.fixed_growth = true
	if u.team == 1 and Roster.is_promoted_class(u.unit_class.name):   # promoted foes: FE-style hidden base-class levels (~base Lv16) before their own
		for i in 15: u.level_up()
		u.level = 1
	for i in lv - 1: u.level_up()
	Unit.fixed_growth = fg; u.hp = u.stats.hp

## Protect-target NPC (team 2): stands its ground; enemies attack it; lose if it falls.
func _spawn_npc(n: Array) -> Unit:
	var u = Roster.make_unit(n[1], 1, n[2]); u.team = 2; u.data.name = n[0]; u.inventory = [Weapons.make(n[3])]
	_level_to(u, (int(n[4]) if n.size() > 4 else 1) + Campaign.enemy_lv); u.guard = true
	_place(u); return u

func _btn(t: String, parent: Control, fs = 30) -> Button:
	var b = Ornate.button(Button.new()); b.text = t; b.add_theme_font_size_override("font_size", fs)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; parent.add_child(b); return b

func _build_ui() -> void:
	var backdrop = CanvasLayer.new(); backdrop.layer = -10; add_child(backdrop)
	var art = TextureRect.new(); backdrop.add_child(art); art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.texture = load("res://assets/title/ashen-crown-keyart-v1.png"); art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED; art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	art.modulate = Color(0.22, 0.28, 0.34); art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui = CanvasLayer.new(); add_child(ui)
	var panel = Panel.new(); ui.add_child(panel); panel.add_theme_stylebox_override("panel", Ornate.frame(Color8(20, 18, 36, 245)))
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE); sa = SafeArea.insets(get_viewport()); panel.offset_bottom = -sa.y; panel.offset_top = -PANEL_H - sa.y
	var v = VBoxContainer.new(); panel.add_child(v); v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 14; v.offset_right = -14; v.offset_top = 10; v.offset_bottom = -10; v.add_theme_constant_override("separation", 8)
	info = Label.new(); v.add_child(info); info.size_flags_vertical = Control.SIZE_EXPAND_FILL; info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 24); info.add_theme_color_override("font_color", Color8(248, 240, 224)); info.clip_text = true
	var r2 = HBoxContainer.new(); v.add_child(r2); r2.add_theme_constant_override("separation", 8); r2.custom_minimum_size.y = 90  # >=44 CSS px even at 360px width (0.5 scale)
	btn_weapon = _btn("무기", r2, 24); btn_convoy = _btn("아이템", r2, 24); btn_open = _btn("열기", r2, 24)
	btn_status = _btn("상태", r2, 24); btn_danger = _btn("위험", r2, 24); btn_menu = _btn("메뉴", r2, 24)
	btn_status.name = "BtnStatus"; btn_menu.name = "BtnMenu"
	btn_next = _btn("다음", r2, 24); btn_next.name = "BtnNext"; btn_next.pressed.connect(next_unit)
	var r1 = HBoxContainer.new(); v.add_child(r1); r1.add_theme_constant_override("separation", 10); r1.custom_minimum_size.y = 104
	btn_cancel = _btn("취소", r1, 34); btn_confirm = _btn("확인", r1, 34); btn_end = _btn("턴 종료", r1, 34)
	btn_confirm.pressed.connect(_on_confirm); btn_cancel.pressed.connect(_on_cancel); btn_end.pressed.connect(_on_end_turn)
	btn_weapon.pressed.connect(_cycle_weapon); btn_convoy.pressed.connect(_open_convoy); btn_open.pressed.connect(_do_open)
	btn_danger.pressed.connect(_toggle_danger); btn_status.pressed.connect(_status_button); btn_menu.pressed.connect(open_menu)
	for b in [btn_confirm, btn_cancel, btn_weapon, btn_convoy, btn_open]: b.disabled = true
	_refresh_toggle_labels()
	# terrain + unit windows (top)
	terrain_win = Panel.new(); ui.add_child(terrain_win); terrain_win.add_theme_stylebox_override("panel", Ornate.frame()); terrain_win.position = Vector2(10, 10 + sa.x); terrain_win.size = Vector2(190, 110)
	terrain_lbl = Label.new(); terrain_win.add_child(terrain_lbl); terrain_lbl.position = Vector2(16, 8); terrain_lbl.add_theme_font_size_override("font_size", 24)
	unit_win = Panel.new(); ui.add_child(unit_win); unit_win.add_theme_stylebox_override("panel", Ornate.frame()); unit_win.size = Vector2(330, 120)
	unit_win.set_anchors_preset(Control.PRESET_TOP_RIGHT); unit_win.position = Vector2(720 - 340, 10 + sa.x)
	unit_port = TextureRect.new(); unit_win.add_child(unit_port); unit_port.position = Vector2(10, 10); unit_port.size = Vector2(100, 100)
	unit_port.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; unit_port.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	unit_lbl = Label.new(); unit_win.add_child(unit_lbl); unit_lbl.position = Vector2(120, 8); unit_lbl.add_theme_font_size_override("font_size", 24)
	unit_wicon = Icons.rect(null, 32); unit_win.add_child(unit_wicon); unit_wicon.position = Vector2(120, 76); unit_wicon.size = Vector2(32, 32)
	var zb = HBoxContainer.new(); ui.add_child(zb); zb.name = "ZoomButtons"; zb.add_theme_constant_override("separation", 8)
	zb.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT); zb.offset_left = -196; zb.offset_right = -12; zb.offset_top = -PANEL_H - sa.y - 100; zb.offset_bottom = -PANEL_H - sa.y - 12
	for d in [-1, 1]:
		var b = ItemMenus.big("-" if d < 0 else "+", 64, 40); b.name = "ZoomOut" if d < 0 else "ZoomIn"; b.custom_minimum_size = Vector2(88, 88)
		b.modulate = Color(1, 1, 1, 0.85); b.pressed.connect(func(): zoom_step(d)); zb.add_child(b)
	fc_panel = Panel.new(); ui.add_child(fc_panel); fc_panel.add_theme_stylebox_override("panel", Ornate.frame(Color8(20, 18, 36, 248)))
	fc_panel.position = Vector2(10, 140); fc_panel.size = Vector2(700, 480); fc_panel.visible = false; fc_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE; fc_panel.name = "Forecast"
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
		"opened": opened.map(func(c): return [c.x, c.y]), "reinf_done": rd, "deployed": deployed, "chapter_start": Campaign.chapter_start,
		"state": {"events": events_seen, "boss_talked": boss_talked, "kills": kills, "stole": stole, "chests": chests_got, "escaped": escaped, "killed": killed_names,
			"visited": visited.map(func(c): return [c.x, c.y]), "ruined": ruined.map(func(c): return [c.x, c.y])}}

## Save payload for SaveManager (campaign + mid-battle snapshot).
func payload() -> Dictionary: return {"campaign": Campaign.to_dict(), "battle": _snapshot()}

func _restore(r: Dictionary) -> void:
	deployed = r.get("deployed", []); Campaign.chapter_start = r.get("chapter_start", Campaign.to_dict().duplicate(true))
	for d in r.units:
		var c = Vector2i(int(d.cell[0]), int(d.cell[1])); var u: Unit
		if int(d.team) == 0:
			u = Roster.make_unit(d.name, 0, c, {"class": d["class"], "level": d.level, "exp": d.exp, "stats": d.stats, "move_bonus": d.get("move_bonus", 0), "items": d.items, "wexp": d.get("wexp", {})})
		else:
			u = Roster.make_unit(d.get("kind", d["class"]), 1, c); u.data.name = d.name; u.data.tags = PackedStringArray(["dark"])
			u.level = int(d.level)
			for s in d.stats: u.stats[s] = int(d.stats[s])
			u.inventory = d.items.map(func(i): return Weapons.make(i.name, int(i.uses)))
			var di = int(d.get("drop", -1))
			if di >= 0 and di < u.inventory.size(): u.drop = u.inventory[di]
			u.gold_drop = int(d.get("gold", 0)); u.guard = d.get("guard", false); u.boss = d.get("boss", false)
			u.uid = int(d.get("uid", -1)); u.drop_w = int(d.get("dw", 0)); u.drop_i = int(d.get("di", 0)); spawn_seq = maxi(spawn_seq, u.uid + 1)
		u.hp = int(d.hp); u.has_acted = d.get("acted", false); u.awakened = d.get("awakened", false); u.poison = int(d.get("poison", 0))
		u.aoe = d.get("aoe", false); u.raider = d.get("raider", false); u.talk_from = d.get("talk", ""); u.team = int(d.team)
		if u.team == 2: u.data.tags = PackedStringArray([])
		_place(u)
	for oc in r.get("opened", []):
		var c = Vector2i(int(oc[0]), int(oc[1]))
		if grid.terrain.get(c, "") in ["door", "crack"]: grid.open_door(c)
		elif grid.terrain.get(c, "") == "chest": grid.open_chest(c)
		opened.append(c)
	for i in r.get("reinf_done", []):   # guard: a mid-battle save may name a wave index that a later balance pass removed
		if int(i) >= 0 and int(i) < MAP.get("reinforcements", []).size(): MAP.reinforcements[int(i)]["done"] = true
	var st: Dictionary = r.get("state", {})
	kills = int(st.get("kills", 0)); stole = int(st.get("stole", 0)); chests_got = int(st.get("chests", 0)); escaped = st.get("escaped", [])
	killed_names = st.get("killed", []); events_seen = st.get("events", []).map(func(x): return int(x)); boss_talked = st.get("boss_talked", true)
	for v in st.get("visited", []):
		var c = Vector2i(int(v[0]), int(v[1])); visited.append(c); grid.visit_village(c)
	for v in st.get("ruined", []):
		var c = Vector2i(int(v[0]), int(v[1])); ruined.append(c); grid.ruin_village(c)
	tm.turn = int(r.turn); tm.phase = TurnManager.Phase.PLAYER
	_refresh_intents(); _update_warnings(); _update_danger()
	var first = units.filter(func(u): return u.team == 0)
	if first.size(): _focus(first[0].cell)
	info.text = "%s — 턴 %d 재개\n유닛을 탭하세요 (빈 칸 탭=지형 확인 · [메뉴]=메뉴)" % [ChapterData.CHAPTERS[CHAPTER].title, tm.turn]
	btn_end.disabled = false

# ---------------------------------------------------------------- camera / input
func _view_size() -> Vector2: return get_viewport().get_visible_rect().size - Vector2(0, PANEL_H + sa.y)

func _clamp_cam() -> void:
	var vs = _view_size() / cam.zoom.x; var ps = grid.pixel_size()   # visible world size at current zoom
	cam.position.x = clampf(cam.position.x, minf(0, ps.x - vs.x), maxf(0, ps.x - vs.x)) if ps.x > vs.x else (ps.x - vs.x) / 2
	cam.position.y = clampf(cam.position.y, 0, maxf(0, ps.y - vs.y)) if ps.y > vs.y else 0.0

func _focus(c: Vector2i) -> void:
	cam.position = grid.cell_to_pos(c) - _view_size() / cam.zoom.x / 2; _clamp_cam()

# ---- map zoom: pinch (touch / trackpad) + HUD -/+ ; snapped to Settings.ZOOM_STEPS so pixels stay crisp
var touches = {}; var pinch_d0 = 0.0; var pinch_z0 = 1.0
## Zoom keeping the world point under screen pos `at` fixed.
func set_zoom(z: float, at = null, snap = true) -> void:
	if snap:
		var best = Settings.ZOOM_STEPS[0]
		for s in Settings.ZOOM_STEPS: if absf(s - z) < absf(best - z): best = s
		z = best
	z = clampf(z, Settings.ZOOM_STEPS[0], Settings.ZOOM_STEPS[-1])
	var sp: Vector2 = at if at != null else _view_size() / 2
	var world = cam.position + sp / cam.zoom.x
	cam.zoom = Vector2(z, z); cam.position = world - sp / z; _clamp_cam()
	if snap and Settings.map_zoom != z: Settings.map_zoom = z; Settings.save()
func zoom_step(d: int) -> void:
	var i = Settings.ZOOM_STEPS.find(Settings.map_zoom)
	if i < 0: i = 1
	set_zoom(Settings.ZOOM_STEPS[clampi(i + d, 0, Settings.ZOOM_STEPS.size() - 1)])
func _pinch_input(ev: InputEvent) -> bool:
	if ev is InputEventMagnifyGesture: set_zoom(cam.zoom.x * ev.factor, ev.position, false); return true
	if ev is InputEventScreenTouch:
		if ev.pressed: touches[ev.index] = ev.position
		else:
			touches.erase(ev.index)
			if pinch_d0 > 0 and touches.size() < 2: pinch_d0 = 0.0; set_zoom(cam.zoom.x); pressed = false; dragging = true
		if touches.size() == 2:
			var p = touches.values(); pinch_d0 = maxf(1.0, p[0].distance_to(p[1])); pinch_z0 = cam.zoom.x; pressed = false
		return pinch_d0 > 0
	if ev is InputEventScreenDrag and touches.has(ev.index):
		touches[ev.index] = ev.position
		if touches.size() == 2 and pinch_d0 > 0:
			var p = touches.values()
			set_zoom(pinch_z0 * p[0].distance_to(p[1]) / pinch_d0, (p[0] + p[1]) / 2, false); return true
	return pinch_d0 > 0

func _unhandled_input(ev: InputEvent) -> void:
	if _pinch_input(ev): return
	if ev is InputEventMouseButton and ev.pressed and ev.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		zoom_step(1 if ev.button_index == MOUSE_BUTTON_WHEEL_UP else -1); return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			if ev.position.y > get_viewport().get_visible_rect().size.y - PANEL_H - sa.y: return
			pressed = true; dragging = false; press_pos = ev.position; drag_from = cam.position; press_ms = Time.get_ticks_msec()
		elif pressed:
			pressed = false
			if not dragging and not busy and not prep_active and tm.phase == TurnManager.Phase.PLAYER:
				tap(grid.pos_to_cell(get_canvas_transform().affine_inverse() * ev.position))
	elif ev is InputEventMouseMotion and pressed:
		if (ev.position - press_pos).length() > 24: dragging = true
		if dragging: cam.position = drag_from - (ev.position - press_pos) / cam.zoom.x; _clamp_cam()

## Long-press (0.5 s) on any unit opens its status screen.
func _process(_dt: float) -> void:
	for u in units: if u.threat_mark: u.queue_redraw()   # smooth pulse
	if pressed and not dragging and Time.get_ticks_msec() - press_ms > 500:
		pressed = false
		var u = _unit_at(grid.pos_to_cell(get_canvas_transform().affine_inverse() * press_pos))
		if u: open_status(u)

var btn_next: Button
## Close overlays opened from the status/list and centre the camera + cursor on u.
func jump_to(u: Unit) -> void:
	for n in ["UnitList", "Status", "BattleMenu"]:
		for c in ui.find_children(n, "CanvasLayer", true, false): c.queue_free()
	if not is_instance_valid(u) or u.hp <= 0: return
	_focus(u.cell); grid.cursor = u.cell; _show_terrain(u.cell); _show_unit_win(u); grid.queue_redraw()
## [다음]: jump to the next ally that hasn't acted yet (cycles). Selects it when nothing is selected.
func next_unit() -> void:
	if busy or prep_active or tm.phase != TurnManager.Phase.PLAYER: return
	var al = units.filter(func(o): return o.team == 0 and o.hp > 0 and not o.has_acted)
	if al.is_empty(): Menus.toast(ui, "행동할 유닛이 없습니다"); return
	var cur = selected if selected else _unit_at(grid.cursor)
	var u: Unit = al[(al.find(cur) + 1) % al.size()] if cur in al else al[0]
	if selected and selected != u: _on_cancel()   # also reverts an unconfirmed move (no lingering selection)
	jump_to(u)
	if selected == null: _select(u)

func open_status(u: Unit) -> void:
	var same = units.filter(func(o): return o.hp > 0 and o.team == u.team)
	Menus.status(ui, same, same.find(u), jump_to)

func _status_button() -> void:
	var u = selected if selected else _unit_at(grid.cursor)
	if u == null: u = units.filter(func(o): return o.team == 0 and o.hp > 0)[0]
	open_status(u)

# ---------------------------------------------------------------- battle menu ([메뉴] 버튼 전용 — 빈 칸 탭으로는 안 열림)
func open_menu() -> void:
	if busy or prep_active or tm.phase != TurnManager.Phase.PLAYER: return
	var o = Menus.overlay(ui, "메뉴", 30, 150, 150); var cl: CanvasLayer = o[0]; var v: VBoxContainer = o[1]; cl.name = "BattleMenu"
	var items = [["유닛 목록", func(): Menus.unit_list(ui, units.filter(func(u): return u.team == 0) + units.filter(func(u): return u.team == 1), "유닛 목록", null, jump_to)],
		["게임 방법", func(): FirstPlayGuide.manual(self)], ["전투 목표", _objective], ["상성표", func(): Menus.triangle_chart(ui)], ["설정", func(): Menus.settings(ui, func(): anim_on = Settings.anim)],
		["중단 저장", func(): Menus.slots(ui, "save", func(): return [CHAPTER, tm.turn, payload()])],
		["챕터 재시작", func(): Menus.confirm(ui, "이 장을 처음부터 다시 할까요?\n(이번 장에서 얻은 경험치·아이템은 장 시작 상태로 돌아갑니다)", "재시작", restart_chapter)],
		["환생", func(): Menus.rebirth_select(ui, func(): get_tree().change_scene_to_file("res://scenes/battle.tscn"))],
		["타이틀로", func(): Menus.confirm(ui, "타이틀로 돌아갈까요?\n저장하지 않은 진행은 마지막 자동 저장(턴 %d 시작)부터 이어집니다." % tm.turn, "타이틀로", func(): get_tree().change_scene_to_file("res://scenes/title.tscn"))],
		["턴 종료", func(): cl.queue_free(); _on_end_turn()]]
	var list = Menus.scroll(v)
	for it in items:
		var b = ItemMenus.big(it[0], 92, 32); b.name = "M_" + it[0]; list.add_child(b); var cb: Callable = it[1]
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
	var t = "%s\n\n승리 조건: %s\n패배 조건: 아린 사망 / 아군 전멸%s\n\n턴: %d (기준 %d턴 = 랭크 S)\n남은 적: %d%s\n출전: %s" % [ch.title, goal_text(), (" / %s 사망" % MAP.npc[0][0]) if MAP.has("npc") else "", tm.turn, MAP.get("par", 10), foes.size(),
		"  (보스: %s)" % MAP.boss if MAP.get("boss", "") != "" else "", ", ".join(units.filter(func(u): return u.team == 0 and u.hp > 0).map(func(u): return u.data.name))]
	if MAP.get("reinforcements", []).any(func(r): return not r.get("done", false)): t += "\n\n주의: 증원 예정 (느낌표 칸)"
	if MAP.has("side"):
		t += "\n\n부가 목표:"
		for sd in MAP.side: t += "\n · %s (보상: %s)" % [sd.text, sd.reward.get("item", "%sG" % sd.reward.get("gold", 0))]
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
	var st = u.staff()
	return units.filter(func(o): return (o.team == u.team or o.team == 2) and o != u and o.hp > 0 and o.hp < o.stats.hp and _dist(o.cell, u.cell) >= st.min_range and _dist(o.cell, u.cell) <= st.max_range)

func _occ(u: Unit) -> Array:
	var occ = {}; var block = {}
	for o in units:
		if o.hp > 0 and o != u:
			occ[o.cell] = true
			if EnemyAI.foe(u, o): block[o.cell] = true
	return [occ, block]

## FE-style: corner windows jump to the bottom when the cursor is in the top part of the view (and back).
func _screen_y(c: Vector2i) -> float: return (grid.cell_to_pos(c).y - cam.position.y) * cam.zoom.y

func relayout_windows(c: Vector2i) -> void:
	var vs = _view_size(); var sy = _screen_y(c)
	var bottom = sy < vs.y * 0.42
	terrain_win.position.y = vs.y - terrain_win.size.y - 10 if bottom else 10.0 + sa.x
	unit_win.position.y = vs.y - unit_win.size.y - 10 if bottom else 10.0 + sa.x
	terrain_win.set_meta("bottom", bottom)

## Forecast panel goes to whichever half doesn't cover the attacker/target.
func relayout_forecast(cells: Array) -> void:
	var vs = _view_size(); var top_y = 140.0 + sa.x; var bot_y = vs.y - fc_panel.size.y - 10
	var covers_top = cells.any(func(c): var y = _screen_y(c); return y > top_y - 40 and y < top_y + fc_panel.size.y + 40)
	fc_panel.position.y = bot_y if covers_top else top_y

func _show_terrain(c: Vector2i) -> void:
	relayout_windows(c)
	var t = grid.terrain.get(c, "wall" if grid.walls.has(c) else "")
	var names = {"": "평지", "forest": "숲", "fort": "요새", "throne": "옥좌", "light": "빛 기둥(HP 20% 회복)", "door": "문(잠김)", "chest": "보물상자", "chest_open": "빈 상자", "side": "옆문", "wall": "벽"}
	var b = grid.terrain_bonus(c)
	terrain_lbl.text = "%s\n방어 +%d\n회피 +%d%s" % [names.get(t, t), b[0], b[1], ("  회복%d%%" % b[2]) if b[2] > 0 else ""]
	terrain_win.visible = true

func _show_unit_win(u: Unit) -> void:
	if u == null: unit_win.visible = false; return
	unit_port.texture = Sprites.portrait(u.data.name) if Sprites.portrait(u.data.name) else Sprites.unit_tex(u)
	var w = u.weapon()
	unit_lbl.text = "%s  Lv%d\nHP %d/%d\n     %s" % [u.data.name, u.level, u.hp, u.stats.hp, ("%s %d%s" % [w.name, w.uses, (" [%s]" % u.rank_letter(w.type)) if u.team == 0 else ""]) if w else "-"]
	unit_wicon.texture = Icons.of(w if w else u.staff())
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
		else: _clear()   # empty tile: inspect terrain only (clears enemy range); menu opens only via [메뉴]
		return
	if u and u.team == 0 and u != selected and u in _heal_targets(selected) and moved:
		pending_target = null; pending_heal = u
		var st = selected.staff()
		info.text = "%s → %s  %s (%d/%d)\nHP %d → %d\n[확인]으로 회복" % [selected.data.name, u.data.name, st.name, st.uses, st.max_uses,
			u.hp, mini(u.stats.hp, u.hp + BattleManager.heal_amount(selected, st))]
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
	relayout_forecast([u.cell, selected.cell])
	info.text = "%s [%s %d]  HP %d→%d  위력 %d%s 명중 %d%% 치명 %d%%\n%s [%s]  HP %d→%d  위력 %s 명중 %s 치명 %s%s\n[확인]=공격%s" % [
		f.atk_name, f.atk_weapon, f.atk_uses, f.atk_hp_before, f.atk_hp_after, f.atk_dmg, ("×%d" % f.atk_count) if f.atk_count > 1 else "", f.atk_hit, f.atk_crit,
		f.def_name, u.weapon().name if u.weapon() else "-", f.def_hp_before, f.def_hp_after, "-" if f.def_dmg < 0 else str(f.def_dmg) + (("×%d" % f.def_count) if f.def_count > 1 else ""),
		"-" if f.def_hit < 0 else str(f.def_hit) + "%", "-" if f.def_crit < 0 else str(f.def_crit) + "%", " 선공!" if f.vantage else "",
		"  [무기]=변경" if not btn_weapon.disabled else ""]
	for x in [selected, u]:
		if Bosses.passive(x.data.name) != "" and Skills.LIST.has(x.data.name): info.text += "\n◆ %s %s" % [x.data.name, Skills.LIST[x.data.name][0]]
	_fill_forecast(f, selected, u)
	btn_confirm.disabled = false

## GBA-style forecast window: both sides with weapon icons, rank letter + bonuses, effectiveness.
func _fill_forecast(f: Dictionary, a: Unit, d: Unit) -> void:
	for c in fc_panel.get_children(): c.queue_free()
	var h = HBoxContainer.new(); fc_panel.add_child(h); h.position = Vector2(14, 10); h.size = Vector2(672, 340); h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sides = [[a, f.atk_w, f.atk_hp_before, f.atk_hp_after, f.atk_dmg, f.atk_count, f.atk_hit, f.atk_crit, f.atk_eff, f.atk_bonus, Color8(120, 176, 255)],
		[d, f.def_w, f.def_hp_before, f.def_hp_after, f.def_dmg, f.def_count, f.def_hit, f.def_crit, f.def_eff, f.def_bonus, Color8(255, 120, 120)]]
	var tri_of = {a: int(f.get("triangle", 0)), d: -int(f.get("triangle", 0))}
	for sd in sides:
		var u: Unit = sd[0]; var w: WeaponData = sd[1]
		var col = PanelContainer.new(); col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_stylebox_override("panel", Ornate.frame(Color8(30, 34, 70) if u.team == 0 else Color8(70, 26, 34), sd[10], 3)); h.add_child(col)
		var v = VBoxContainer.new(); col.add_child(v); v.add_theme_constant_override("separation", 2)
		var nr = VBoxContainer.new(); nr.add_theme_constant_override("separation", 2); v.add_child(nr)
		var nm = ItemMenus.label(u.data.name, 26, sd[10]); nm.autowrap_mode = TextServer.AUTOWRAP_OFF; nr.add_child(nm)
		if sd[8] and sd[4] >= 0:   # big 특효 banner with the multiplier the formula really uses
			var el = ItemMenus.label("특효! ×%d" % BattleManager.EFF_MULT, 30, Color8(255, 72, 64)); el.name = "Eff"; el.autowrap_mode = TextServer.AUTOWRAP_OFF
			el.add_theme_color_override("font_outline_color", Color8(16, 8, 8)); el.add_theme_constant_override("outline_size", 6); nr.add_child(el)
		var wr = HBoxContainer.new(); v.add_child(wr); wr.add_child(Icons.rect(w, 32))
		var wl = ItemMenus.label(("%s%s" % [w.name, (" [%s]" % sd[9].rank) if sd[9].rank != "" else ""]) if w else "-", 22, Icons.tri_text(w, Color8(248, 240, 224))); wl.autowrap_mode = TextServer.AUTOWRAP_OFF; wr.add_child(wl)
		var tv = tri_of.get(u, 0)
		if tv != 0 and w:   # weapon triangle: big ▲ 유리 (gold) / ▼ 불리 (grey) — colours kept apart from the blue/red/green type code
			var ta = ItemMenus.label(("▲유리" if tv > 0 else "▼불리"), 30, Color8(255, 224, 64) if tv > 0 else Color8(176, 176, 196)); ta.name = "Tri"; ta.autowrap_mode = TextServer.AUTOWRAP_OFF; wr.add_child(ta)
		var dm = "-" if sd[4] < 0 else (str(sd[4]) + (" ×%d" % sd[5] if sd[5] > 1 else ""))
		var t = "명중 시 HP %d → %d\n위력 %s%s\n명중 %s  치명 %s" % [sd[2], sd[3], dm, "",
			"-" if sd[6] < 0 else "%d%%" % sd[6], "-" if sd[7] < 0 else "%d%%" % sd[7]]
		var l = ItemMenus.label(t, 22); l.autowrap_mode = TextServer.AUTOWRAP_OFF; v.add_child(l)
		var b = sd[9]
		var bt = []
		if b.might: bt.append("위력+%d" % b.might)
		if b.hit: bt.append("명중+%d" % b.hit)
		if b.crit: bt.append("치명+%d" % b.crit)
		var bl = ItemMenus.label(("랭크·숙련 " + " ".join(bt)) if bt.size() else (w.desc if w else ""), 18, Color8(255, 216, 128)); v.add_child(bl)
		if u.team == 1:   # what the player may get from this enemy
			var drops = []
			if u.drop: drops.append([u.drop, "확정"])
			if u.drop_w > 0 and u.weapon(): drops.append([u.weapon(), "%d%%" % u.drop_w])
			if u.drop_i > 0 and u.items().size(): drops.append([u.items()[0], "%d%%" % u.drop_i])
			if u.gold_drop > 0: v.add_child(ItemMenus.label("드롭 %dG 확정" % u.gold_drop, 18, Color8(255, 216, 32)))
			for dd in drops:
				var dr = HBoxContainer.new(); dr.name = "Drop"; v.add_child(dr); dr.add_child(Icons.rect(dd[0], 24))
				var dl = ItemMenus.label("드롭 %s %s" % [dd[0].name, dd[1]], 18, Color8(255, 216, 32)); dl.autowrap_mode = TextServer.AUTOWRAP_OFF; dr.add_child(dl)
				for c in dr.get_children(): c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for c in v.get_children() + wr.get_children() + nr.get_children(): if c is Control: c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var note = ItemMenus.label(forecast_note(f), 17, Color8(200, 200, 220)); note.name = "FcNote"; note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note.size = Vector2(672, 110); note.position = Vector2(14, 360); fc_panel.add_child(note)
	# Label wrapping first measures at width 1 before layout; reset after the actual width is known.
	note.set_deferred("size", Vector2(672, 110))
	fc_panel.visible = true

## Uncertainty line under the forecast: HP above assumes every strike hits.
static func forecast_note(f: Dictionary) -> String:
	var p = ["※ HP는 모든 타격 명중 시 예상"]
	if f.atk_hit < 100 or (f.def_hit > 0 and f.def_hit < 100): p.append("빗나가면 달라짐")
	if f.atk_crit > 0 or f.def_crit > 0: p.append("치명 시 3배")
	if f.get("extra_chance", false): p.append("스킬 추격 확률 미포함")
	return " · ".join(p)

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
	var act = _action(selected)
	btn_open.text = act.get("label", "열기")
	if not act.is_empty(): extra.append("[%s]" % act.label)
	info.text = "%s 이동. 적 탭=예측 %s / [확인]=대기" % [selected.data.name, " ".join(extra)]
	btn_confirm.disabled = false; btn_open.disabled = act.is_empty()
	_update_item_btn(selected)
	if not trade_partners(selected).is_empty(): info.text += "\n[아이템]=교환 가능"
	var th = mark_threats(selected)
	if not th.is_empty(): info.text += _threat_text(selected, th).replace("\n%s 약점: %s" % [Menus.tag_text(selected), Weapons.weak_text(selected.tags())], "")
	busy = false

func _slide(u: Unit, path: Array) -> void:
	if not anim_on or path.size() < 2 or not is_inside_tree():
		u.position = grid.cell_to_pos(path[-1] if path.size() else u.cell); return
	var tw = create_tween()
	for i in range(1, path.size()): tw.tween_property(u, "position", grid.cell_to_pos(path[i]), 0.07)
	await tw.finished

func _items_text(u: Unit) -> String:
	return ", ".join(u.inventory.map(func(w): return "%s%s %d/%d%s" % ["▶" if w == u.weapon() else "", w.name, w.uses, w.max_uses, (" (%s)" % Weapons.eff_label(w)) if not w.effective.is_empty() else ""]))

## Enemies whose usable 특효 weapon hits this ally's type and can reach its current cell: [[enemy, weapon], ...]. Display only.
func eff_threats(ally: Unit) -> Array:
	var out = []
	var tg = ally.tags()
	if tg.is_empty(): return out
	for e in units:
		if e.team != 1 or e.hp <= 0: continue
		var ws = e.usable_weapons().filter(func(w): return w.effective.any(func(t): return t in tg))
		if ws.is_empty(): continue
		var o = _occ(e)
		var mv = [e.cell] if e.boss else grid.movement_range(e.cell, e.move_range(), o[1], o[0], "flying" in e.tags())
		for w in ws:
			if ally.cell in grid.attack_range(mv, w.min_range, w.max_range): out.append([e, w]); break
	return out

## Red pulsing "!" on those enemies (ally == null clears all marks). Returns the threat list.
func mark_threats(ally: Unit) -> Array:
	var th = eff_threats(ally) if ally and ally.team == 0 else []
	var hit = th.map(func(p): return p[0])
	for u in units:
		var m = u in hit
		if u.threat_mark != m: u.threat_mark = m; u.queue_redraw()
	return th

func _threat_text(u: Unit, th: Array) -> String:
	var s = ""
	if u.team == 0 and not u.tags().is_empty(): s += "\n%s 약점: %s" % [Menus.tag_text(u), Weapons.weak_text(u.tags())]
	if not th.is_empty(): s += "\n[!] 특효 위협(빨간 !): " + ", ".join(th.map(func(p): return "%s(%s)" % [p[0].data.name, p[1].name]))
	return s

func _skill_text(u: Unit) -> String:
	var sk = Skills.LIST.get(u.data.name)
	return ("스킬: " + sk[0]) if sk else ""

func _show_info(u: Unit) -> void:
	info.text = "%s Lv%d %s HP %d/%d EXP %d%s\n%s\n%s" % [u.data.name, u.level, u.unit_class.name, u.hp, u.stats.hp, u.exp,
		"  [각성]" if u.awakened else "", _items_text(u), _skill_text(u)]
	info.text += _threat_text(u, mark_threats(u))

func _select(u: Unit) -> void:
	selected = u; orig_cell = u.cell; moved = false; pending_target = null; pending_heal = null; pending_dest = Vector2i(-1, -1)
	var o = _occ(u)
	grid.highlight_move = grid.movement_range(u.cell, u.move_range(), o[1], o[0], "flying" in u.tags())
	var r = _ranges(u)
	grid.highlight_attack = grid.attack_range(grid.highlight_move, r[0], r[1]) if r[1] > 0 else []
	grid.queue_redraw(); Sfx.play("select")
	_show_info(u); info.text += "\n파란 칸 탭=경로, 다시 탭=이동 (제자리 탭=행동)"
	btn_cancel.disabled = false
	_update_item_btn(u)

func _show_enemy(u: Unit) -> void:
	mark_threats(null)
	var o = _occ(u)
	grid.highlight_move = [u.cell] if u.boss else grid.movement_range(u.cell, u.move_range(), o[1], o[0], "flying" in u.tags())
	var r = _ranges(u)
	grid.highlight_attack = grid.attack_range(grid.highlight_move, r[0], r[1]) if r[1] > 0 else []
	grid.queue_redraw()
	var intent = ""
	for i in intents: if i.unit == u: intent = intent_text(i, u)
	var ew = u.weapon(); var tri = (" [%s %s]" % [ew.name, Icons.TRI_NAME[int(ew.type)]]) if ew and Icons.TRI_NAME.has(int(ew.type)) else ""
	info.text = "%s Lv%d HP %d/%d%s  %s%s%s%s\n%s%s\n[붉은 칸=공격 가능 범위]" % [u.data.name, u.level, u.hp, u.stats.hp, tri, intent, "  (경계)" if u.guard else "",
		("  [대화: %s]" % u.talk_from) if u.talk_from != "" else "", "  (약탈)" if u.raider else "",
		_items_text(u), ("\n★ 처치 시 획득: " + (u.drop.name if u.drop else "%dG" % u.gold_drop) if (u.drop or u.gold_drop > 0) else "") + drop_text(u)]

## Enemy intent: a prediction from the current board, never a promise.
static func intent_text(i, u: Unit) -> String:
	if i.target: return "예상 목표: %s (현재 배치 기준)" % i.target.data.name
	return "예상: %s (현재 배치 기준)" % ("대기" if i.move_to == u.cell else "이동")

func drop_text(u: Unit) -> String:
	var p = []
	if u.drop_w > 0 and u.weapon(): p.append("%s ?%d%%" % [u.weapon().name, u.drop_w])
	if u.drop_i > 0 and u.items().size(): p.append("%s ?%d%%" % [u.items()[0].name, u.drop_i])
	return ("\n드롭 " + " · ".join(p)) if p.size() else ""

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
		if is_instance_valid(first_guide): first_guide.attacked = true
		await _boss_talk(a, d)
		var log = BattleManager.resolve(a, d)
		await _animate(a, d)
		log.append_array(_handle_kills(a, d))
		info.text = "\n".join(log)
		await show_loot()
	for r in BattleManager.rank_ups: Menus.toast(ui, r); Sfx.play("levelup")
	if pending_heal == null and fc_panel: fc_panel.visible = false
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
		if not dead.has_meta("counted"):
			dead.set_meta("counted", true); kills += 1; killed_names.append(dead.data.name)
		if dead.gold_drop > 0: Campaign.gold += dead.gold_drop; out.append("%dG 획득!" % dead.gold_drop); dead.gold_drop = 0
		if dead.drop and dead.drop in dead.inventory:
			var it: WeaponData = dead.drop; dead.drop = null; dead.inventory.erase(it)
			out.append(grant(killer, it, "확정 드롭"))
		for it in random_drops(dead): out.append(grant(killer, it, "드롭!"))
		Campaign.save_campaign()
	return out

## Give an item to u (or convoy when full) and queue an FE-style pickup popup. Returns the combat-log line.
var loot_queue: Array = []
var traded = false
func grant(u: Unit, it: WeaponData, src: String) -> String:
	var full = not u.give(it)
	if full: Campaign.to_convoy(it)
	Campaign.record_progress(u)
	loot_queue.append({"item": it, "unit": u, "full": full, "src": src})
	return "%s %s을(를) 얻었다! → %s" % [src, it.name, "수송대 (소지품 가득)" if full else u.data.name]

## Show queued pickup popups (tap to dismiss). Animation off / headless: short toast only.
## Full inventory: item already sits in the convoy; choose 수송대로 / 버리기 / 교체 (swap with a carried item).
func show_loot() -> void:
	while loot_queue.size():
		var l = loot_queue.pop_front(); var it: WeaponData = l.item; var u: Unit = l.unit
		Sfx.play("pickup")
		var msg = "%s을(를) 얻었다!\n%s" % [it.name, ("소지품이 가득 차 수송대로 보냈다" if l.full else "%s이(가) 받았다" % u.data.name)]
		if not is_inside_tree() or "--flowtest" in OS.get_cmdline_user_args(): continue
		if not anim_on and not l.full: Menus.toast(ui, it.name + "을(를) 얻었다!"); continue
		var o = Menus.overlay(ui, l.src, 40, 380, 380); var cl: CanvasLayer = o[0]; var v: VBoxContainer = o[1]; cl.name = "Loot"
		var h = HBoxContainer.new(); h.alignment = BoxContainer.ALIGNMENT_CENTER; h.add_theme_constant_override("separation", 16); v.add_child(h)
		h.add_child(Icons.rect(it, 64))
		var lb = ItemMenus.label(msg, 30, Color8(255, 236, 160)); lb.autowrap_mode = TextServer.AUTOWRAP_OFF; h.add_child(lb)
		var done = [false]
		var close = func(): done[0] = true; cl.queue_free()
		if l.full:
			var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 10); v.add_child(row)
			var b1 = ItemMenus.big("수송대로", 84, 26); b1.name = "ToConvoy"; row.add_child(b1); b1.pressed.connect(close)
			var b2 = ItemMenus.big("버리기", 84, 26); b2.name = "Discard"; row.add_child(b2)
			b2.pressed.connect(func():
				var i = Campaign.convoy.rfind(it.to_dict())
				if i >= 0: Campaign.convoy.remove_at(i); Campaign.save_campaign()
				close.call())
			var b3 = ItemMenus.big("교체", 84, 26); b3.name = "Swap"; row.add_child(b3)
			b3.pressed.connect(func():
				for c in v.get_children(): if c != h: c.queue_free()
				v.add_child(ItemMenus.label("수송대로 보낼 소지품을 고르세요", 24))
				for w in u.inventory.duplicate():
					var wb = ItemMenus.weapon_btn(w, u); v.add_child(wb)
					wb.pressed.connect(func():
						var i = Campaign.convoy.rfind(it.to_dict())
						if i >= 0: Campaign.convoy.remove_at(i)
						u.inventory.erase(w); Campaign.to_convoy(w); u.give(it); Campaign.record_progress(u); u.queue_redraw(); close.call()))
		else:
			var ok = ItemMenus.big("확인", 84, 28); ok.name = "LootOK"; v.add_child(ok); ok.pressed.connect(close)
		while not done[0] and is_instance_valid(cl): await get_tree().process_frame

## Deterministic random drop roll: hash(chapter attempt seed, spawn id, slot). Same result after save/load or restart.
func roll(u: Unit, slot: String) -> int: return absi(hash([Campaign.drop_seed(CHAPTER), CHAPTER, u.uid, slot])) % 100

## "Junk" for random drops: basic/steel-tier weapons (rank E/D, no 특효/용사) and plain 상처약. Never rolled randomly.
static func junk(w: WeaponData) -> bool:
	if w == null: return true
	if w.is_item(): return w.name == "상처약"
	return w.rank <= 1 and w.effective.is_empty() and not w.brave

func random_drops(dead: Unit) -> Array:
	var out = []
	if dead.uid < 0: return out
	var w = dead.weapon()
	if dead.drop_w > 0 and w and roll(dead, "w") < dead.drop_w: dead.inventory.erase(w); out.append(w)
	var its = dead.items()
	if dead.drop_i > 0 and its.size() and roll(dead, "i") < dead.drop_i: dead.inventory.erase(its[0]); out.append(its[0])
	dead.drop_w = 0; dead.drop_i = 0
	return out

## Openable door/chest: thieves free (릴리 door reach +1, 잭 chest reach +1); anyone holding a key (1 use each).
func _openable(u: Unit):
	if u == null: return null
	var thief = Roster.is_thief(u)
	var reach_door = (2 if Skills.has(u, "릴리") else 1) if thief else 1
	var reach_chest = (1 if Skills.has(u, "잭") else 0) if thief else 0
	var dk = u.key_for("door"); var ck = u.key_for("chest")
	for c in grid.terrain:
		var t = grid.terrain[c]
		if t == "door":
			if (thief or dk) and _dist(c, u.cell) <= reach_door: return c
			if dk and _dist(c, u.cell) <= dk.fx().get("range", 1): return c
		if t == "chest":
			if (thief or ck) and _dist(c, u.cell) <= reach_chest: return c
			if ck and _dist(c, u.cell) <= ck.fx().get("range", 0): return c
	return null

## Key spent for opening c (null = free thief open).
func _key_used(u: Unit, c: Vector2i) -> WeaponData:
	var t = grid.terrain[c]
	if Roster.is_thief(u):
		var reach = (2 if Skills.has(u, "릴리") else 1) if t == "door" else (1 if Skills.has(u, "잭") else 0)
		if _dist(c, u.cell) <= reach: return null
	return u.key_for(t)

const DIRS = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
## Context action for a moved unit: 대화 > 제압 > 탈출 > 방문 > 훔치기 > 열기 > 부수기.
func _action(u: Unit) -> Dictionary:
	if u == null or u.team != 0: return {}
	for o in units:
		if o.hp > 0 and o.team == 1 and o.talk_from == u.data.name and _dist(o.cell, u.cell) == 1: return {"kind": "talk", "label": "대화", "target": o}
	var here = grid.terrain.get(u.cell, "")
	if MAP.goal == "seize" and u.data.name == "아린" and here == "throne": return {"kind": "seize", "label": "제압"}
	if MAP.goal == "escape" and here == "escape": return {"kind": "escape", "label": "탈출"}
	if here == "village": return {"kind": "village", "label": "방문", "cell": u.cell}
	if Roster.is_thief(u):
		for o in units:
			if o.team == 1 and o.hp > 0 and not o.boss and _dist(o.cell, u.cell) == 1 and o.drop and o.drop in o.inventory and o.drop != o.weapon() and u.eff("spd") >= o.eff("spd"):
				return {"kind": "steal", "label": "훔치기", "target": o}
	var c = _openable(u)
	if c != null: return {"kind": grid.terrain[c], "label": "열기", "cell": c}
	for d in DIRS:
		if grid.terrain.get(u.cell + d, "") == "crack": return {"kind": "crack", "label": "부수기", "cell": u.cell + d}
	return {}

func _do_open() -> void:
	if selected == null or not moved: return
	var act = _action(selected)
	if act.is_empty(): return
	match act.kind:
		"talk": await _talk(selected, act.target); return
		"seize": seized = true; info.text = "아린이 옥좌를 제압했다!"; Sfx.play("levelup"); _finish_unit(selected); return
		"escape": _escape(selected); return
		"village": await _visit(selected, act.cell); return
		"steal":
			var o: Unit = act.target; var it: WeaponData = o.drop
			o.inventory.erase(it); o.drop = null; stole += 1
			info.text = grant(selected, it, "훔치기")
			await show_loot(); _finish_unit(selected); return
		"crack":
			grid.break_wall(act.cell); opened.append(act.cell); info.text = "%s: 금 간 벽을 부쉈다! 숨겨진 길이 열렸다." % selected.data.name
			Sfx.play("crit"); _finish_unit(selected); return
	var c = act.cell
	var t = grid.terrain[c]
	var key = _key_used(selected, c)
	var keymsg = ""
	if key:
		keymsg = " (%s 사용)" % key.name
		if selected.use_item(key): keymsg = " (%s 소모)" % key.name
	opened.append(c)
	if t == "door":
		grid.open_door(c); info.text = "%s: 문을 열었다!%s" % [selected.data.name, keymsg]
	else:
		grid.open_chest(c); chests_got += 1
		var ch = MAP.get("chests", {}).get(c, MAP.get("chest", {"item": "", "gold": 500}))
		var msg = []
		if ch.get("item", "") != "":
			var it = Weapons.make(ch.item)
			msg.append(grant(selected, it, "보물상자"))
		var g = ch.get("gold", 0) + (300 if Skills.has(selected, "잭") else 0)
		if g > 0: Campaign.gold += g; msg.append("%dG 획득!" % g)
		Campaign.record_progress(selected); info.text = "보물상자: " + " ".join(msg) + keymsg
	Sfx.play("levelup")
	var su = selected
	await show_loot()
	selected = su; _finish_unit(su)

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
	_maybe_auto_end()

## Auto end turn when every ally has acted — only if the 설정 "자동 턴 종료" is ON.
func _maybe_auto_end() -> void:
	if not Settings.auto_end: return
	if units.filter(func(o): return o.team == 0 and o.hp > 0 and not o.has_acted).is_empty(): _on_end_turn()

func _clear(reset_text = true) -> void:
	selected = null; pending_target = null; pending_heal = null; moved = false; pending_dest = Vector2i(-1, -1)
	grid.highlight_move = []; grid.highlight_attack = []; grid.highlight_heal = []; grid.arrow = []; grid.queue_redraw()
	if units.size(): mark_threats(null)
	if fc_panel: fc_panel.visible = false
	for b in [btn_confirm, btn_cancel, btn_weapon, btn_convoy, btn_open]: b.disabled = true
	if reset_text: info.text = "유닛을 탭하세요 (드래그=화면 이동)"

func _toggle_danger() -> void:
	danger_on = not danger_on; _update_danger(); _refresh_toggle_labels(); Sfx.play("select")
	if danger_on and is_inside_tree(): Menus.toast(ui, "보라 테두리 = 모든 적의 공격 가능 범위 (적 탭 시 붉은 칸 = 그 적의 범위)")

func _update_danger() -> void:
	var cells = {}
	if danger_on:
		for e in units:
			if e.team != 1 or e.hp <= 0: continue
			var o = _occ(e)
			var mv = [e.cell] if e.boss else grid.movement_range(e.cell, e.move_range(), o[1], o[0], "flying" in e.tags())
			var r = _ranges(e)
			for c in grid.attack_range(mv, r[0], r[1]): cells[c] = true
	grid.danger = cells.keys(); grid.queue_redraw()


func _talk(u: Unit, o: Unit) -> void:
	busy = true
	var lines = ChapterData.TALK.get(u.data.name + "|" + o.data.name, [[u.data.name, "함께 싸우자."], [o.data.name, "…좋다."]])
	if is_inside_tree() and not "--flowtest" in OS.get_cmdline_user_args(): await dialogue.play(lines)
	if MAP.get("noah_choice", "") == o.data.name:   # 14장: 설득 성공 → 약해진 채 합류 / 떠나보냄
		var join = true
		if is_inside_tree() and not "--flowtest" in OS.get_cmdline_user_args(): join = await _noah_choice(o)
		if not join:
			if is_inside_tree() and not "--flowtest" in OS.get_cmdline_user_args(): await dialogue.play(ChapterData.TALK.get(o.data.name + "|떠남", []))
			o.hp = 0; o.visible = false; units.erase(o); Campaign.set_meta("noah_left", true)
			if not "noah_farewell" in Campaign.camp_seen: Campaign.camp_seen.append("noah_farewell")   # 엔딩: 떠나보냄 = 기본 엔딩
			info.text = "%s은(는) 떠났다." % o.data.name; busy = false; _finish_unit(u); return
		Campaign.absent.erase(o.data.name)
		for st in ["str", "skl", "spd", "def"]: o.stats[st] = maxi(1, int(o.stats[st]) - 3)   # 그림자 후유증 (이 유닛 현재치만, 클래스 기본치·성장률 불변)
		o.hp = mini(o.hp, o.stats.hp)
	recruit_unit(o)
	info.text = "%s이(가) 동료가 되었다!" % o.data.name; Sfx.play("levelup")
	busy = false; _finish_unit(u)

## Enemy/NPC -> party member (keeps its current level, stats, items).
func recruit_unit(o: Unit) -> void:
	o.team = 0; o.data.tags = PackedStringArray([]); o.talk_from = ""; o.drop = null; o.guard = false; o.has_acted = true
	o.data.color = Roster.color_for(o.unit_class.name); o.init_ranks(); Campaign.apply_carry(o)
	if not o.data.name in Campaign.recruited: Campaign.recruited.append(o.data.name)
	Campaign.record_progress(o); deployed.append(o.data.name); o.queue_redraw(); _refresh_intents()
	if Roster.UNITS.has(o.data.name) and Roster.UNITS[o.data.name][2] != "": info.text += "\n%s: \"%s\"" % [o.data.name, Roster.UNITS[o.data.name][2]]

func _visit(u: Unit, c: Vector2i) -> void:
	busy = true
	var v: Dictionary = MAP.villages.get(c, {})
	if is_inside_tree() and not "--flowtest" in OS.get_cmdline_user_args() and v.has("lines"): await dialogue.play(v.lines)
	var msg = []
	if v.get("item", "") != "":
		var it = Weapons.make(v.item)
		msg.append(grant(u, it, "마을"))
	if v.get("gold", 0) > 0: Campaign.gold += v.gold; msg.append("%dG 획득!" % v.gold)
	if v.get("recruit", "") != "":
		var n: String = v.recruit
	if v.get("recruit", "") != "" and Campaign.roster.has(v.recruit) and Campaign.keep_all:
		Campaign.gold += 500; msg.append("500G 획득! (마을의 감사)")
	elif v.get("recruit", "") != "":
		var n: String = v.recruit; Campaign.recruit(n)
		for d in DIRS + [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
			var cc = c + d
			if grid.in_bounds(cc) and not grid.walls.has(cc) and not grid.water.has(cc) and _unit_at(cc) == null:
				var nu = Roster.make_unit(n, 0, cc, Campaign.entry(n)); nu.has_acted = true; _place(nu); deployed.append(n); break
		msg.append("%s 합류!" % n)
	visited.append(c); grid.visit_village(c); Campaign.record_progress(u)
	info.text = "마을 방문: " + " ".join(msg); Sfx.play("levelup")
	await show_loot()
	busy = false; _finish_unit(u)

## Ch6 rule: the whole party escapes, 아린 last (allies still on the map).
func _others_left(u: Unit) -> int: return units.filter(func(o): return o != u and o.team == 0 and o.hp > 0).size()

func _escape(u: Unit) -> void:
	escaped.append(u.data.name); Campaign.record_progress(u)
	info.text = "%s 탈출!" % u.data.name; Sfx.play("select")
	units.erase(u); u.queue_free(); selected = null
	_clear(false)
	if _check_end(): return
	_update_danger()
	_maybe_auto_end()

# ---------------------------------------------------------------- convoy (lord only, in battle)
## 아이템: use a consumable (ends the unit's action) / keys info / 아린 opens the convoy.
func _open_convoy() -> void:
	if selected == null or busy: return
	var u = selected
	var o = Menus.overlay(ui, "아이템 — %s" % u.data.name, 30, 180, 180); var cl: CanvasLayer = o[0]; var v: VBoxContainer = o[1]; cl.name = "ItemUse"
	var list = Menus.scroll(v)
	if u.items().is_empty(): list.add_child(ItemMenus.label("사용할 아이템이 없습니다.", 26))
	for it in u.items():
		var fx = it.fx(); var w: WeaponData = it
		var b = ItemMenus.big("%s  %d/%d\n%s" % [it.name, it.uses, it.max_uses, it.desc], 92, 24); b.alignment = HORIZONTAL_ALIGNMENT_LEFT; Icons.on_button(b, it)
		b.name = "Use_" + it.name
		if fx.has("key"): b.disabled = true; b.text += "  (문·상자 옆에서 [열기])"
		elif fx.has("heal") and heal_targets(u).is_empty(): b.disabled = true
		elif fx.has("stat") and int(u.stats[fx.stat]) >= ClassCaps.cap(u.unit_class.name, fx.stat): b.disabled = true; b.text += "  (최대치)"
		b.pressed.connect(func():
			cl.queue_free()
			if fx.has("heal"): pick_heal_target(u, w)
			else: use_item(u, w))
		list.add_child(b)
	for p in trade_partners(u):
		var tb = ItemMenus.big("교환 — %s" % p.data.name, 80, 26); tb.name = "Trade_" + p.data.name; list.add_child(tb)
		var pp = p
		tb.pressed.connect(func(): cl.queue_free(); open_trade(u, pp))
	if u.data.name == "아린":
		var cb = ItemMenus.big("수송대 열기", 80, 26); cb.name = "Convoy"; list.add_child(cb)
		cb.pressed.connect(func(): cl.queue_free(); _open_convoy_panel())
	Menus.close_btn(v, cl)

func _update_item_btn(u: Unit) -> void:
	btn_convoy.disabled = u == null or (u.data.name != "아린" and u.items().is_empty() and trade_partners(u).is_empty())

## Allies next to u (교환 partners).
func trade_partners(u: Unit) -> Array:
	if u == null or u.team != 0: return []
	return units.filter(func(o): return o != u and o.team == 0 and o.hp > 0 and _dist(o.cell, u.cell) == 1)

## 교환 (FE rule): trading doesn't end the action. Before moving you may still move; after moving you can still attack/wait.
## Tap an item to pick it, then tap an item (swap) or an empty slot (move) on the other side. Tap a picked weapon again = equip.
func open_trade(a: Unit, b: Unit) -> CanvasLayer:
	var o = Menus.overlay(ui, "교환", 30, 60, 60); var cl: CanvasLayer = o[0]; var v: VBoxContainer = o[1]; cl.name = "TradeUI"
	var hint = ItemMenus.label("아이템 탭=선택 → 반대편 아이템(교체)/빈 칸(이동)\n선택한 무기 다시 탭=장비", 22, Color8(200, 190, 230)); v.add_child(hint)
	var cols = HBoxContainer.new(); cols.add_theme_constant_override("separation", 10); cols.size_flags_vertical = Control.SIZE_EXPAND_FILL; v.add_child(cols)
	var state = {"pick": null, "side": -1}
	var refill = [null]
	refill[0] = func():
		for c in cols.get_children(): c.queue_free()
		for side in 2:
			var u: Unit = [a, b][side]
			var col = VBoxContainer.new(); col.size_flags_horizontal = Control.SIZE_EXPAND_FILL; col.add_theme_constant_override("separation", 6); cols.add_child(col)
			col.add_child(ItemMenus.label("%s (%d/%d)" % [u.data.name, u.inventory.size(), Unit.MAX_ITEMS], 26, Color8(160, 200, 255)))
			for i in Unit.MAX_ITEMS:
				var w = u.inventory[i] if i < u.inventory.size() else null
				var bt: Button
				if w:
					bt = ItemMenus.big("%s%s\n%d/%d" % ["▶" if w == u.weapon() else "", w.name, w.uses, w.max_uses], 88, 20); Icons.on_button(bt, w)
					if u.block_reason(w) != "": bt.add_theme_color_override("font_color", Color8(150, 140, 130))
				else: bt = ItemMenus.big("(빈 칸)", 88, 20)
				bt.alignment = HORIZONTAL_ALIGNMENT_LEFT; bt.name = "T%d_%d" % [side, i]
				if state.pick == w and w != null: bt.modulate = Color(1.3, 1.2, 0.6)
				col.add_child(bt)
				var sd = side; var ww = w
				bt.pressed.connect(func():
					Sfx.play("select")
					if state.pick == null:
						if ww: state.pick = ww; state.side = sd
					elif ww == state.pick:   # same item again: equip it
						var ow: Unit = [a, b][sd]
						if not ww.is_item() and not ww.is_staff(): ow.equip(ww)
						state.pick = null
					elif sd == state.side:
						state.pick = ww
					else:
						var src: Unit = [a, b][state.side]; var dst: Unit = [a, b][sd]
						var pi = src.inventory.find(state.pick)
						if ww:
							var di = dst.inventory.find(ww)
							src.inventory[pi] = ww; dst.inventory[di] = state.pick
						elif dst.inventory.size() < Unit.MAX_ITEMS:
							src.inventory.remove_at(pi); dst.inventory.append(state.pick)
						state.pick = null; traded = true
					for x in [a, b]: x.queue_redraw()
					refill[0].call())
	refill[0].call()
	Menus.close_btn(v, cl, func():
		for x in [a, b]: Campaign.record_progress(x)
		if selected == a: _show_info(a); info.text += "\n교환 완료 — 계속 행동 가능" + ("" if moved else " (이동 가능)")
		_show_unit_win(a))
	return cl

## Healing items: self or an adjacent injured ally.
func heal_targets(u: Unit) -> Array:
	return units.filter(func(o): return o.team == 0 and o.hp > 0 and o.hp < o.stats.hp and (o == u or abs(o.cell.x - u.cell.x) + abs(o.cell.y - u.cell.y) == 1))

func pick_heal_target(u: Unit, it: WeaponData) -> CanvasLayer:
	var tg = heal_targets(u)
	grid.highlight_heal = tg.map(func(o): return o.cell); grid.queue_redraw()
	var o = Menus.overlay(ui, "%s — 누구에게?" % it.name, 30, 300, 300); var cl: CanvasLayer = o[0]; var v: VBoxContainer = o[1]; cl.name = "HealTarget"
	for t in tg:
		var h = mini(int(it.fx().heal), t.stats.hp - t.hp)
		var b = ItemMenus.big("%s%s  HP %d → %d" % [t.data.name, " (자신)" if t == u else "", t.hp, t.hp + h], 80, 26); b.name = "Target_" + t.data.name; v.add_child(b)
		var tt = t
		b.pressed.connect(func(): grid.highlight_heal = []; cl.queue_free(); use_item(u, it, tt))
	Menus.close_btn(v, cl, func(): grid.highlight_heal = []; grid.queue_redraw())
	return cl

func use_item(u: Unit, it: WeaponData, target: Unit = null) -> void:
	var fx = it.fx()
	if fx.has("heal"):
		var t: Unit = target if target else u
		var h = mini(int(fx.heal), t.stats.hp - t.hp); t.hp += h
		info.text = "%s: %s 사용 — %sHP +%d" % [u.data.name, it.name, ("" if t == u else t.data.name + " "), h]
		if t != u: Campaign.record_progress(t); t.queue_redraw()
	elif fx.has("stat"):
		var room = ClassCaps.cap(u.unit_class.name, fx.stat) - int(u.stats[fx.stat])
		if room <= 0:   # at cap: warn, don't consume, turn not spent
			info.text = "%s의 %s은(는) 이미 최대치입니다. (%s 미사용)" % [u.data.name, Menus.STAT_NAMES.get(fx.stat, fx.stat), it.name]; Sfx.play("cancel"); return
		var n = mini(int(fx.n), room)
		u.stats[fx.stat] += n
		if fx.stat == "hp": u.hp += n
		info.text = "%s: %s 사용 — %s +%d!%s" % [u.data.name, it.name, Menus.STAT_NAMES.get(fx.stat, fx.stat), n, "  (최대치)" if n == room else ""]
	u.use_item(it); Campaign.record_progress(u); Sfx.play("levelup")
	selected = u; moved = true; _finish_unit(u)

func _open_convoy_panel() -> void:
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
	if is_instance_valid(first_guide) and first_guide.attacked: first_guide.finish()
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
		info.text = "\n".join(lines) + ("\n" if lines.size() else "") + "턴 %d — 플레이어 페이즈\n유닛 탭=선택 · 길게=상태 · 빈 칸=지형 · [메뉴]=메뉴" % turn
		if _check_end(): return
		await _banner("플레이어 페이즈", Color8(120, 176, 255))
		if turn == 1 and CHAPTER == "ch2" and is_inside_tree() and not has_meta("flowtest"):   # weapon triangle tip (colour code)
			Menus.toast(ui, "무기 상성: 파랑(검) > 빨강(도끼) > 초록(창) > 파랑\n유리 ▲ / 불리 ▼ — 자세히는 [메뉴] > 상성표")
		await _turn_event(turn)
	else:
		busy = true
		await _banner("적 페이즈", Color8(255, 96, 96))
		await _run_enemy_phase()
		busy = false

## Mid-battle story beat (ChapterData.EVENTS), once per chapter attempt.
func _turn_event(turn: int) -> void:
	var ev = ChapterData.EVENTS.get(CHAPTER, {}).get(turn, [])
	if ev.is_empty() or turn in events_seen: return
	events_seen.append(turn)
	ev = ev.filter(func(l): return l[0] == "" or _unit_named(l[0]) != null or not Roster.UNITS.has(l[0]))   # skip lines of undeployed allies
	if ev.is_empty() or not is_inside_tree() or "--flowtest" in OS.get_cmdline_user_args() or "nodialog" in demo_flags(): return
	busy = true; await dialogue.play(ev); busy = false

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
		if e.raider: plan = _raid_plan(e, plan)
		if plan.move_to != e.cell:
			var o = _occ(e)
			var path = grid.move_path(e.cell, plan.move_to, grid.movement_range(e.cell, e.move_range(), o[1], o[0], "flying" in e.tags()))
			e.cell = plan.move_to
			if anim_on and is_inside_tree(): _focus(e.cell); await _slide(e, path)
			else: e.position = grid.cell_to_pos(e.cell)
		if plan.get("ruin", false) and grid.terrain.get(e.cell, "") == "village":
			grid.ruin_village(e.cell); ruined.append(e.cell); lines.append("%s이(가) 마을을 파괴했다!" % e.data.name)
		if plan.target:
			await _boss_talk(e, plan.target)
			lines.append_array(BattleManager.resolve(e, plan.target))
			await _animate(e, plan.target)
			lines.append_array(_handle_kills(plan.target, e))
			await show_loot()
		elif is_inside_tree() and anim_on: await get_tree().create_timer(0.05).timeout
		for u in units: u.visible = u.hp > 0
	for u in units: u.visible = u.hp > 0; u.queue_redraw()
	if _check_end(): return
	tm.end_enemy_phase()
	if lines.size(): info.text = "\n".join(lines.slice(-4)) + "\n" + info.text

## Raiders: reach an unvisited village this turn -> destroy it; otherwise attack if possible, else head for the nearest village.
func _raid_plan(e: Unit, plan: Dictionary) -> Dictionary:
	var vill = grid.terrain.keys().filter(func(c): return grid.terrain[c] == "village")
	if vill.is_empty(): return plan
	var o = _occ(e)
	var reach = grid.movement_range(e.cell, e.move_range(), o[1], o[0], "flying" in e.tags())
	for c in reach:
		if c in vill: return {"unit": e, "move_to": c, "target": null, "ruin": true}
	if plan.target: return plan
	var best = e.cell; var bd = 999
	for c in reach:
		for v in vill:
			if _dist(c, v) < bd: bd = _dist(c, v); best = c
	return {"unit": e, "move_to": best, "target": null}

## Phase start for team: poison, 카이젠, terrain healing (fort/throne).
func _start_of_phase(team: int) -> Array:
	var out = []
	for u in units:
		if u.hp <= 0 or u.team != team: continue
		if team == 0 and Skills.has(u, "카이젠"): u.flags["kaizen"] = true
		var h = grid.terrain_bonus(u.cell)[2]
		if MAP.get("light_only_heal", false) and grid.terrain.get(u.cell, "") != "light": h = 0   # 종장 심연: 빛 기둥에서만 회복
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
	match MAP.goal:
		"boss": return units.filter(func(u): return u.team == 1 and u.boss and u.hp > 0).is_empty()
		"seize": return seized
		"escape": return "아린" in escaped
		"defend": return (tm.turn > int(MAP.turns) and tm.phase == TurnManager.Phase.PLAYER) or (MAP.get("rout_early", false) and units.filter(func(u): return u.team == 1 and u.hp > 0).is_empty() and MAP.get("reinforcements", []).all(func(r): return r.get("done", false)))
	return units.filter(func(u): return u.team == 1 and u.hp > 0).is_empty()

func _lost() -> bool:
	var p = units.filter(func(u): return u.team == 0 and u.hp > 0).size()
	if "아린" in escaped: return false
	if p == 0 or _unit_named("아린") == null: return true
	return units.any(func(u): return u.team == 2 and u.hp <= 0)

func goal_text() -> String:
	match MAP.goal:
		"boss": return "%s 격파" % MAP.get("boss", "보스")
		"seize": return "아린이 옥좌에서 [제압]"
		"escape": return "아린이 탈출 지점에서 [탈출]"
		"defend": return "%d턴 동안 버티기 (현재 %d턴)%s" % [MAP.turns, tm.turn, " · 적 전멸 시 조기 승리" if MAP.get("rout_early", false) else ""]
	return "적 전멸" + (" · %s 보호" % MAP.npc[0][0] if MAP.has("npc") else "")

## Side objectives + turn rank. Grants rewards once; returns report for the clear screen.
func evaluate_clear() -> Dictionary:
	var rep = {"turns": tm.turn, "par": MAP.get("par", 10), "sides": [], "rank": "C", "bonus": 0}
	var par = int(rep.par)
	rep.rank = "S" if tm.turn <= par else ("A" if tm.turn <= par + 3 else ("B" if tm.turn <= par + 6 else "C"))
	rep.bonus = {"S": 500, "A": 200}.get(rep.rank, 0); Campaign.gold += rep.bonus
	var order = ["S", "A", "B", "C"]
	if not Campaign.ranks.has(CHAPTER) or order.find(rep.rank) < order.find(Campaign.ranks[CHAPTER]): Campaign.ranks[CHAPTER] = rep.rank
	var done: Array = Campaign.sides.get(CHAPTER, [])
	for sd in MAP.get("side", []):
		var ok = false
		match sd.type:
			"turns": ok = tm.turn <= int(sd.n)
			"villages": ok = visited.size() == MAP.get("villages", {}).size()
			"kills": ok = kills >= int(sd.n)
			"recruit": ok = sd.name in Campaign.recruited
			"steal": ok = stole > 0
			"chests": ok = chests_got > 0
			"kill": ok = sd.name in killed_names
			"npc_hp": ok = units.any(func(u): return u.team == 2 and u.hp * 100 >= u.stats.hp * int(sd.pct))
		var reward = ""
		if ok and not sd.id in done:
			done.append(sd.id)
			if sd.reward.has("gold"): Campaign.gold += int(sd.reward.gold); reward = "%dG" % sd.reward.gold
			if sd.reward.has("item"): Campaign.convoy.append(Weapons.make(sd.reward.item).to_dict()); reward = sd.reward.item + " → 수송대"
		elif ok: reward = "(이미 획득)"
		rep.sides.append({"text": sd.text, "ok": ok, "reward": reward})
	Campaign.sides[CHAPTER] = done
	for u in units:   # rescued NPC joins (사르한 리안)
		if u.team == 2 and u.hp > 0 and Roster.UNITS.has(u.data.name): recruit_unit(u)
	return rep

var ended = false
func _check_end() -> bool:
	if ended: return true
	if _lost():
		ended = true
		info.text = "패배..."; btn_end.disabled = true
		var tl = Campaign.record_defeat(CHAPTER, deployed)  # EXP/levels kept + 훈련 bonus
		game_over.open(ROSTER_NAMES, deployed, Campaign.attempts.get(CHAPTER, []), tl)
		return true
	if _won():
		ended = true
		btn_end.disabled = true
		clear_report = evaluate_clear()
		for u in units: if u.team == 0: Campaign.record_progress(u, false)
		var g = MAP.get("clear_gold", Campaign.CLEAR_GOLD.get(CHAPTER, 500))
		if MAP.get("noah_choice", "") != "": _record_noah_outcome(MAP.noah_choice)
		Campaign.record_clear(CHAPTER)  # 각성 removed on clear; advances Campaign.chapter
		clear_report["gold"] = g
		info.text = "승리! 클리어 보상 %dG · 랭크 %s" % [g, clear_report.rank]
		for n in MAP.get("absent_add", []):
			if not n in Campaign.absent: Campaign.absent.append(n); Campaign.save_campaign()
		_after_clear()
		return true
	return false

## 14장 클리어 시 노아 결과를 저장에 남긴다 (엔딩 판정·구버전 이전용).
func _record_noah_outcome(n: String) -> void:
	for f in Campaign.NOAH_OUTCOMES: Campaign.camp_seen.erase(f)
	var f = "noah_out_lost"
	if units.any(func(x): return x.team == 0 and x.data.name == n and x.hp > 0) or (n in Campaign.recruited and not n in Campaign.absent): f = "noah_out_joined"
	elif n in killed_names: f = "noah_out_killed"
	elif units.any(func(x): return x.team == 1 and x.data.name == n and x.hp > 0): f = "noah_out_lost"   # 끝내 설득 못 함
	elif "noah_farewell" in Campaign.camp_seen: f = "noah_out_farewell"
	if f != "noah_out_farewell": Campaign.camp_seen.erase("noah_farewell")   # 이전 시도의 떠나보냄 기록은 무효
	Campaign.camp_seen.append(f)

func _after_clear() -> void:
	if "--flowtest" in OS.get_cmdline_user_args(): return
	await _clear_screen()
	var post_lines = ChapterData.CHAPTERS[CHAPTER].post
	if CHAPTER == "final":
		var eid = Campaign.ending_for(Campaign.absent, Campaign.roster.has("노아"), Campaign.camp_seen, Campaign.supports_seen)
		post_lines = post_lines + ChapterData.ENDINGS[eid]
		if not ("ending_" + eid) in Campaign.camp_seen: Campaign.camp_seen.append("ending_" + eid)
	await dialogue.play(post_lines)
	if MAP.has("branch"): await _branch_choice()
	get_tree().change_scene_to_file("res://scenes/base.tscn")

signal _closed
func _clear_screen() -> void:
	var r = clear_report
	var o = Menus.overlay(ui, "%s 클리어!" % ChapterData.CHAPTERS[CHAPTER].title, 45, 160, 160); var cl: CanvasLayer = o[0]; var v: VBoxContainer = o[1]; cl.name = "ClearScreen"
	var rk = ItemMenus.label("랭크 %s" % r.rank, 64, {"S": Color8(255, 216, 64), "A": Color8(150, 225, 255)}.get(r.rank, Menus.TXT)); v.add_child(rk)
	v.add_child(ItemMenus.label("턴 %d (기준 %d)   클리어 보상 %dG%s" % [r.turns, r.par, r.gold, ("  랭크 보너스 %dG" % r.bonus) if r.bonus else ""], 26))
	v.add_child(ItemMenus.label("— 부가 목표 —", 28, Menus.GOLD))
	for sd in r.sides:
		v.add_child(ItemMenus.label(("● " if sd.ok else "○ ") + sd.text + (("  → " + sd.reward) if sd.ok and sd.reward != "" else ""), 26, Menus.TXT if sd.ok else Menus.DIM))
	var sp = Control.new(); sp.size_flags_vertical = Control.SIZE_EXPAND_FILL; v.add_child(sp)
	var b = ItemMenus.big("계속", 100, 34); v.add_child(b); b.name = "Continue"
	b.pressed.connect(func(): cl.queue_free(); _closed.emit())
	await _closed

## Pre-boss '왜 싸우는가' lines: once, the first time anyone fights the boss (either side).
func _boss_talk(a: Unit, d: Unit) -> void:
	if boss_talked or not (a.boss or d.boss): return
	boss_talked = true
	var lines = ChapterData.CHAPTERS.get(CHAPTER, {}).get("boss", [])
	if lines.size() and is_inside_tree() and not "--flowtest" in OS.get_cmdline_user_args(): await dialogue.play(lines)

func _noah_choice(o: Unit) -> bool:
	var ov = Menus.overlay(ui, "노아의 선택", 45, 200, 200); var cl: CanvasLayer = ov[0]; var v: VBoxContainer = ov[1]; cl.name = "NoahChoice"
	v.add_child(ItemMenus.label("그림자에서 돌아온 노아. 어떻게 할까?", 26, Menus.DIM))
	var res = [true]
	for opt in [[true, "함께 간다\n그림자 후유증: 힘·기술·속도·수비 -3"], [false, "떠나보낸다\n노아는 홀로 속죄의 길을 떠난다 (재합류 없음)"]]:
		var bt = ItemMenus.big(opt[1], 200, 26); bt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(bt); var val = opt[0]
		bt.name = "N_" + ("join" if val else "leave")
		bt.pressed.connect(func(): res[0] = val; cl.queue_free(); _closed.emit())
	await _closed
	return res[0]

func _branch_choice() -> void:
	var o = Menus.overlay(ui, "진로 선택", 45, 200, 200); var cl: CanvasLayer = o[0]; var v: VBoxContainer = o[1]; cl.name = "Branch"
	v.add_child(ItemMenus.label("어느 왕국으로 향할까? (다른 지도·다른 동료)", 26, Menus.DIM))
	for br in MAP.branch:
		var b = ItemMenus.big("%s\n%s" % [br[1], br[2]], 200, 26); b.name = "B_" + br[0]; v.add_child(b); var dest = br[0]
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(func(): Campaign.route = dest; Campaign.chapter = dest; Campaign.save_campaign(); cl.queue_free(); _closed.emit())
	await _closed

func _retry_same() -> void:
	Campaign.deploy = deployed.duplicate(); Campaign.save_campaign(); get_tree().reload_current_scene()

func _retry_swap(lineup: Array) -> void:
	Campaign.deploy = lineup; Campaign.save_campaign(); get_tree().reload_current_scene()

## Dev (#ch2 forecast): 아린 with 아머킬러 (rank C) next to the armored enemy, forecast open.
func _demo_forecast() -> void:
	await get_tree().create_timer(0.8).timeout
	var a = _unit_named("아린")
	var e = units.filter(func(u): return u.team == 1 and "armor" in u.tags() and not u.boss)
	if e.is_empty(): return
	a.wexp[0] = 70; a.inventory.push_front(Weapons.make("아머킬러")); a.cell = e[0].cell + Vector2i(0, 1); a.position = grid.cell_to_pos(a.cell); _focus(a.cell)
	_select(a); moved = true; grid.highlight_move = []; tap(e[0].cell)

func _demo_combat() -> void:
	await get_tree().create_timer(6.5 if "late" in demo_flags() else 1.6).timeout   # +late: after the chapter-start toasts (clean screenshots)
	var a = units.filter(func(u): return u.team == 0)[0]
	var e = units.filter(func(u): return u.team == 1 and (u.boss if "boss" in demo_flags() else not u.boss))[0]   # #combat+boss = boss aura shot
	a.exp = 95; a.cell = e.cell + Vector2i(0, 1); a.position = grid.cell_to_pos(a.cell); _focus(a.cell)
	selected = a; moved = true; pending_target = e
	await _on_confirm()

## Dev (#combatfx[+magic]): visual-only replay of a ranged (bow, or tome with +magic) crit + miss for screenshots. Never touches HP/RNG/saves.
func _demo_fx() -> void:
	await get_tree().create_timer(6.5 if "late" in demo_flags() else 1.6).timeout
	var allies = units.filter(func(u): return u.team == 0)
	var a = allies[0]
	var want = WeaponData.Type.TOME if "magic" in demo_flags() else WeaponData.Type.BOW   # #combatfx+magic = tome shot
	var found = false
	for u in allies: if u.weapon() and u.weapon().type == want: a = u; found = true
	if not found and want == WeaponData.Type.TOME: a.inventory.push_front(Weapons.make("파이어"))   # dev screenshot only (page is never saved)
	var e = units.filter(func(u): return u.team == 1 and not u.boss)[0]
	a.cell = e.cell + Vector2i(0, 2)
	BattleManager.pre_fc = BattleManager.forecast(a, e)
	var dm = maxi(1, e.hp - 2)
	var evs = [{"type": "strike", "x": a, "y": e, "hit": false, "crit": false, "dmg": 0, "w": a.weapon(), "x_hp": a.hp, "y_hp": e.hp},
		{"type": "strike", "x": a, "y": e, "hit": true, "crit": true, "dmg": dm, "w": a.weapon(), "x_hp": a.hp, "y_hp": e.hp - dm}]
	combat.play(a, e, evs, [], {a: a.hp, e: e.hp})

## Dev (#effdemo / #effdemofc): 특효 marks screenshot — an enemy with a weapon effective vs a tagged ally moves into reach,
## the ally is tapped (red "!" + weakness line); fc = also open the forecast so the enemy's counter shows '특효! ×N'. Never saved.
func _demo_eff(fc: bool) -> void:
	await get_tree().create_timer(1.2).timeout
	var allies = units.filter(func(u): return u.team == 0 and u.hp > 0)
	var a: Unit = null
	for u in allies: if not u.tags().is_empty() and a == null: a = u
	if a == null and not allies.is_empty():   # no tagged ally deployed: drop in 카엘 (아머나이트) next to the first ally (dev only)
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			var c = allies[0].cell + dv
			if a == null and grid.in_bounds(c) and _unit_at(c) == null and not grid.walls.has(c): a = Roster.make_unit("카엘", 0, c); _place(a)
	if a == null: return
	var wn = {"armor": "아머킬러", "flying": "철활", "cavalry": "호스슬레이어"}[a.tags()[0]]
	var foes = units.filter(func(u): return u.team == 1 and u.hp > 0 and not u.boss)
	foes.sort_custom(func(x, y): return _dist(x.cell, a.cell) < _dist(y.cell, a.cell))
	if foes.is_empty(): return
	var e: Unit = foes[0]; e.inventory.push_front(Weapons.make(wn))
	var near = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(2, 0), Vector2i(0, 2), Vector2i(1, 1), Vector2i(-1, 1)]
	for dv in (near if fc else near.slice(4)):
		var c = a.cell + dv
		if grid.in_bounds(c) and _unit_at(c) == null and not grid.walls.has(c): e.cell = c; e.position = grid.cell_to_pos(c); break
	_focus(a.cell)
	if fc:
		_select(a); moved = true; grid.highlight_move = []; tap(e.cell)
	else:
		tap(a.cell)

## Optional, presentation-only guidance; never changes battle rules or saved units.
func _start_guide() -> void:
	if is_instance_valid(first_guide): first_guide.queue_free()
	first_guide = FirstPlayGuide.new(); first_guide.battle = self; add_child(first_guide)
