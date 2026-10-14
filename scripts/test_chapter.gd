extends Node2D
## Minimal test chapter, touch-first: tap unit -> tap blue cell to move -> tap red enemy to see forecast -> Confirm.
const CHAPTER = "ch1"
@onready var grid: Grid = $Grid
@onready var tm: TurnManager = $TurnManager
@onready var info: Label = $UI/Panel/Info
@onready var btn_confirm: Button = $UI/Panel/Buttons/Confirm
@onready var btn_cancel: Button = $UI/Panel/Buttons/Cancel
@onready var btn_end: Button = $UI/Panel/Buttons/EndTurn
@onready var dialogue: DialogueBox = $Dialogue
var units: Array = []
var selected: Unit = null
var orig_cell = Vector2i.ZERO
var moved = false
var pending_target: Unit = null
var intents: Array = []
const DEFAULT_DEPLOY = ["아린", "노아", "리나", "세라", "엘리아"]
var ROSTER_NAMES = []
var deployed = []
var game_over: GameOverScreen

func _mk_weapon(n: String, t: int, mt: int) -> WeaponData:
	var w = WeaponData.new(); w.name = n; w.type = t; w.might = mt; return w

func _mk_unit(n: String, cls: ClassData, w: WeaponData, col: Color, team: int, c: Vector2i) -> void:
	var d = UnitData.new(); d.name = n; d.unit_class = cls; d.weapon = w; d.color = col
	var u = Unit.new(); add_child(u); u.setup(d, team, c); u.position = grid.cell_to_pos(c); units.append(u)

## Placeholder color per class (until pixel art from ASSETS.md is generated)
const CLASS_COLORS = {"용병": Color(0.2, 0.45, 0.95), "궁수": Color(0.2, 0.7, 0.3), "성기사": Color(0.95, 0.85, 0.3),
	"마법사": Color(0.6, 0.3, 0.9), "기사": Color(0.6, 0.65, 0.75), "도적": Color(0.2, 0.75, 0.75), "그림자 병사": Color(0.35, 0.1, 0.4), "그림자 창병": Color(0.45, 0.1, 0.25)}

func _cls(n: String, mv: int, st: Dictionary, promo: ClassData = null) -> ClassData:
	var c = ClassData.new(); c.name = n; c.move = mv; c.base_stats = st; c.promotes_to = promo; return c

func _wp(n: String, t: int, mt: int, rmin = 1, rmax = 1, magic = false) -> WeaponData:
	var w = WeaponData.new(); w.name = n; w.type = t; w.might = mt; w.min_range = rmin; w.max_range = rmax; w.magic = magic; return w

func _add(n: String, cls: ClassData, w: WeaponData, team: int, c: Vector2i, tags = []) -> void:
	var d = UnitData.new(); d.name = n; d.unit_class = cls; d.weapon = w; d.tags = PackedStringArray(tags)
	d.color = CLASS_COLORS.get(cls.name, Color.GRAY)
	var u = Unit.new(); add_child(u); u.setup(d, team, c); u.position = grid.cell_to_pos(c); units.append(u)

func _ready() -> void:
	game_over = GameOverScreen.new(); add_child(game_over)
	var T = WeaponData.Type
	var merc = _cls("용병", 5, {"hp": 20, "str": 6, "mag": 0, "skl": 8, "spd": 8, "lck": 5, "def": 4, "res": 1}, _cls("영웅", 6, {}))
	var archer = _cls("궁수", 5, {"hp": 17, "str": 5, "mag": 0, "skl": 7, "spd": 6, "lck": 4, "def": 3, "res": 1}, _cls("스나이퍼", 6, {}))
	var pal = _cls("성기사", 5, {"hp": 19, "str": 5, "mag": 3, "skl": 5, "spd": 5, "lck": 6, "def": 6, "res": 5}, _cls("발키리", 6, {}))
	var mage = _cls("마법사", 5, {"hp": 15, "str": 0, "mag": 7, "skl": 6, "spd": 6, "lck": 3, "def": 1, "res": 6}, _cls("세이지", 6, {}))
	var shadow = _cls("그림자 병사", 5, {"hp": 18, "str": 7, "mag": 0, "skl": 3, "spd": 4, "lck": 0, "def": 3, "res": 0})
	var shadow_l = _cls("그림자 창병", 4, {"hp": 19, "str": 6, "mag": 0, "skl": 4, "spd": 3, "lck": 0, "def": 5, "res": 0})
	var knight = _cls("기사", 4, {"hp": 22, "str": 7, "mag": 0, "skl": 5, "spd": 3, "lck": 3, "def": 8, "res": 1}, _cls("그레이트나이트", 5, {}))
	var thief = _cls("도적", 6, {"hp": 16, "str": 4, "mag": 0, "skl": 8, "spd": 10, "lck": 7, "def": 2, "res": 1}, _cls("어쌔신", 7, {}))
	# Ch1 roster: 5 default deployers + bench (카엘, 루크, 미라)
	var roster = {
		"아린": [merc, _wp("철검", T.SWORD, 5)], "노아": [merc, _wp("철검", T.SWORD, 5)],
		"리나": [archer, _wp("철궁", T.BOW, 6, 2, 2)], "세라": [pal, _wp("철창", T.LANCE, 6)],
		"엘리아": [mage, _wp("파이어", T.TOME, 5, 1, 2, true)],
		"카엘": [knight, _wp("철창", T.LANCE, 7)], "루크": [thief, _wp("철검", T.SWORD, 4)],
		"미라": [mage, _wp("썬더", T.TOME, 7, 1, 2, true)]}
	ROSTER_NAMES = roster.keys()
	var lineup: Array = Campaign.deploy if Campaign.deploy.size() > 0 else DEFAULT_DEPLOY
	var spots = [Vector2i(3, 10), Vector2i(5, 10), Vector2i(4, 11), Vector2i(2, 11), Vector2i(6, 11)]
	for i in lineup.size():
		var n: String = lineup[i]
		_add(n, roster[n][0], roster[n][1], 0, spots[i])
		var u: Unit = units[-1]
		if Campaign.roster.has(n): u.apply_progress(Campaign.roster[n])
		if Campaign.is_awakened(CHAPTER, n): u.apply_awakening()
	deployed = lineup.duplicate()
	_add("그림자 병사", shadow, _wp("철도끼", T.AXE, 8), 1, Vector2i(2, 1), ["dark"])
	_add("그림자 병사", shadow, _wp("철도끼", T.AXE, 8), 1, Vector2i(6, 1), ["dark"])
	_add("그림자 창병", shadow_l, _wp("철창", T.LANCE, 6), 1, Vector2i(4, 2), ["dark"])
	_add("그림자 병사", shadow, _wp("철검", T.SWORD, 5), 1, Vector2i(1, 3), ["dark"])
	game_over.retry_same.connect(_retry_same); game_over.retry_swap.connect(_retry_swap)
	btn_confirm.pressed.connect(_on_confirm); btn_cancel.pressed.connect(_on_cancel); btn_end.pressed.connect(_on_end_turn)
	tm.phase_changed.connect(_on_phase)
	SaveManager.autosave(CHAPTER, 0, _snapshot())  # chapter start
	var ch = ChapterData.CHAPTERS.ch1
	info.text = ch.title + " — 목표: " + ch.goal
	if not "--flowtest" in OS.get_cmdline_user_args(): await dialogue.play(ch.pre)
	tm.start_player_phase()
	if "--gameover-demo" in OS.get_cmdline_user_args():  # dev: jump to defeat → swap picker
		for u in units: if u.team == 0: u.hp = 0
		_check_end(); game_over._open_picker()

func _snapshot() -> Dictionary:
	return {"campaign": Campaign.to_dict(), "turn": tm.turn, "units": units.map(func(u): return u.to_dict())}

func _unit_at(c: Vector2i) -> Unit:
	for u in units:
		if u.hp > 0 and u.cell == c: return u
	return null

func _unhandled_input(ev: InputEvent) -> void:
	if tm.phase != TurnManager.Phase.PLAYER: return
	var p = null
	if ev is InputEventScreenTouch and ev.pressed: p = ev.position
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and not ev.device == -1: p = ev.position
	if p == null: return
	tap(grid.pos_to_cell(get_canvas_transform().affine_inverse() * p))

func tap(c: Vector2i) -> void:
	if not grid.in_bounds(c): return
	var u = _unit_at(c)
	if selected == null:
		if u and u.team == 0 and not u.has_acted: _select(u)
		elif u and u.team == 1: _show_enemy(u)
		return
	if u and u.team == 1 and c in grid.highlight_attack and BattleManager.in_range(selected, u):
		pending_target = u
		var f = BattleManager.forecast(selected, u)
		info.text = "%s  HP %d→%d\n  DMG %d%s  HIT %d%%\n%s  HP %d→%d\n  DMG %s  HIT %s\n[확인]으로 공격" % [
			f.atk_name, f.atk_hp_before, f.atk_hp_after, f.atk_dmg, " x2" if f.atk_x2 else "", f.atk_hit,
			f.def_name, f.def_hp_before, f.def_hp_after, "-" if f.def_dmg < 0 else str(f.def_dmg) + (" x2" if f.def_x2 else ""),
			"-" if f.def_hit < 0 else str(f.def_hit) + "%"]
		btn_confirm.disabled = false
		return
	if not moved and c in grid.highlight_move and (u == null or u == selected):
		selected.cell = c; selected.position = grid.cell_to_pos(c); moved = true
		grid.highlight_move = []
		grid.highlight_attack = grid.attack_range([c], selected.data.weapon.min_range, selected.data.weapon.max_range)
		grid.queue_redraw()
		info.text = "%s 이동 완료. 적을 탭해 예측 보기 / [확인]=대기" % selected.data.name
		btn_confirm.disabled = false

func _select(u: Unit) -> void:
	selected = u; orig_cell = u.cell; moved = false; pending_target = null
	var occ = {}; var block = {}
	for o in units:
		if o.hp > 0 and o != u:
			occ[o.cell] = true
			if o.team != u.team: block[o.cell] = true
	grid.highlight_move = grid.movement_range(u.cell, u.move_range(), block, occ)
	grid.highlight_attack = grid.attack_range(grid.highlight_move, u.data.weapon.min_range, u.data.weapon.max_range)
	grid.queue_redraw()
	info.text = "%s Lv%d %s  HP %d/%d\n파란 칸을 탭해 이동" % [u.data.name, u.level, u.unit_class.name, u.hp, u.stats.hp]
	btn_cancel.disabled = false

func _show_enemy(u: Unit) -> void:
	var occ = {}
	for o in units: if o.hp > 0 and o != u: occ[o.cell] = true
	grid.highlight_move = grid.movement_range(u.cell, u.move_range(), {}, occ)
	grid.highlight_attack = grid.attack_range(grid.highlight_move, u.data.weapon.min_range, u.data.weapon.max_range)
	grid.queue_redraw()
	var intent = ""
	for i in intents: if i.unit == u: intent = "→ " + (i.target.data.name + " 공격 예정" if i.target else "이동 예정")
	info.text = "%s HP %d/%d  %s" % [u.data.name, u.hp, u.stats.hp, intent]

func _on_confirm() -> void:
	if selected == null: return
	if pending_target:
		var log = BattleManager.resolve(selected, pending_target)
		info.text = "\n".join(log)
	_finish_unit()

func _on_cancel() -> void:
	if selected and moved:
		selected.cell = orig_cell; selected.position = grid.cell_to_pos(orig_cell)
	_clear()

func _finish_unit() -> void:
	selected.has_acted = true; selected.queue_redraw()
	for u in units: u.visible = u.hp > 0; u.queue_redraw()
	_clear(false)
	if _check_end(): return
	if units.filter(func(u): return u.team == 0 and u.hp > 0 and not u.has_acted).is_empty(): _on_end_turn()

func _clear(reset_text = true) -> void:
	selected = null; pending_target = null; moved = false
	grid.highlight_move = []; grid.highlight_attack = []; grid.queue_redraw()
	btn_confirm.disabled = true; btn_cancel.disabled = true
	if reset_text: info.text = "유닛을 탭하세요"

func _on_end_turn() -> void:
	if tm.phase != TurnManager.Phase.PLAYER: return
	_clear(); tm.end_player_phase()

func _on_phase(phase: int, turn: int) -> void:
	btn_end.disabled = phase != TurnManager.Phase.PLAYER
	if phase == TurnManager.Phase.PLAYER:
		for u in units: u.has_acted = false; u.queue_redraw()
		_refresh_intents()
		SaveManager.autosave(CHAPTER, turn, _snapshot())  # autosave each turn
		info.text = "턴 %d — 플레이어 페이즈\n유닛을 탭하세요" % turn
	else:
		await _run_enemy_phase()

func _refresh_intents() -> void:
	intents = []
	for e in units.filter(func(u): return u.team == 1 and u.hp > 0): intents.append(EnemyAI.plan(e, units, grid))

func _run_enemy_phase() -> void:
	var lines = []
	for e in units.filter(func(u): return u.team == 1 and u.hp > 0):
		var plan = EnemyAI.plan(e, units, grid)
		e.cell = plan.move_to; e.position = grid.cell_to_pos(e.cell)
		if plan.target: lines.append_array(BattleManager.resolve(e, plan.target))
		if is_inside_tree(): await get_tree().create_timer(0.3).timeout
	for u in units: u.visible = u.hp > 0; u.queue_redraw()
	if _check_end(): return
	tm.end_enemy_phase()
	if lines.size(): info.text = "\n".join(lines) + "\n" + info.text

func _check_end() -> bool:
	var p = units.filter(func(u): return u.team == 0 and u.hp > 0).size()
	var e = units.filter(func(u): return u.team == 1 and u.hp > 0).size()
	if e == 0:
		info.text = "승리!"; btn_end.disabled = true
		Campaign.record_clear(CHAPTER)  # 각성 is removed on clear (never stored in roster)
		dialogue.play(ChapterData.CHAPTERS.ch1.post); return true
	if p == 0 or _unit_named("아린") == null:
		info.text = "패배..."; btn_end.disabled = true
		Campaign.record_defeat(CHAPTER, deployed)  # EXP/levels already persisted per combat
		game_over.open(ROSTER_NAMES, deployed, Campaign.attempts.get(CHAPTER, []))
		return true
	return false

func _unit_named(n: String) -> Unit:
	for u in units:
		if u.team == 0 and u.hp > 0 and u.data.name == n: return u
	return null

func _retry_same() -> void:
	Campaign.deploy = deployed.duplicate(); Campaign.save_campaign(); get_tree().reload_current_scene()

func _retry_swap(lineup: Array) -> void:
	Campaign.deploy = lineup; Campaign.save_campaign(); get_tree().reload_current_scene()
