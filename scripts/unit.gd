class_name Unit extends Node2D
## A unit on the grid. Placeholder drawn as a colored square.
const FONT = preload("res://assets/fonts/NanumGothic-Bold.ttf")
const AWAKEN_BONUS = 2
const AWAKEN_HP = 5
const STATS = ["hp", "str", "mag", "skl", "spd", "lck", "def", "res"]
static var fixed_growth = false   # global option: fixed (averaged) growth instead of RNG

@export var data: UnitData
@export var team = 0  # 0 = player, 1 = enemy
var stats = {}
var growth_accum = {}  # for fixed growth mode
var level = 1
var exp = 0
var hp = 0
var cell = Vector2i.ZERO
var has_acted = false
var unit_class: ClassData
var move_bonus = 0
var awakened = false
var inventory: Array = []   # Array[WeaponData]; first non-staff usable = equipped
var flags = {}              # per-chapter flags: moved, kaizen
var poison = 0              # turns remaining
var pending_gift = []       # items that did not fit (go to convoy)
var drop: WeaponData = null # enemy droppable item
var gold_drop = 0
var guard = false           # AI: hold position unless target reachable
var boss = false            # AI: never moves
var weapon_used: WeaponData = null
var aoe = false            # boss: hits also splash units adjacent to the target
static var show_badge = true   # set from Settings.weapon_badge
var uid = -1               # spawn index (random drop roll key)
var drop_w = 0             # random drop chance % for equipped weapon
var drop_i = 0             # random drop chance % for carried item
var raider = false         # AI: goes for villages
var talk_from = ""         # name of player unit that can recruit this enemy via 대화
var wexp = {}               # weapon type (int) -> weapon EXP points (players)

func setup(d: UnitData, t: int, c: Vector2i) -> void:
	data = d; team = t; cell = c; level = d.level; unit_class = d.unit_class
	for s in STATS:
		stats[s] = unit_class.base_stats.get(s, 0); growth_accum[s] = 50
	hp = stats.hp
	if d.weapon: inventory = [d.weapon]
	init_ranks()

func init_ranks() -> void:
	wexp = {}
	for t in ClassProfs.START_RANK.get(unit_class.name, {}): wexp[int(t)] = ClassProfs.WEXP[ClassProfs.START_RANK[unit_class.name][t]]

func rank(t: int) -> int:
	if team != 0: return 5 if wexp.is_empty() else ClassProfs.rank_of(wexp.get(t, 0))
	return ClassProfs.rank_of(int(wexp.get(t, -1))) if wexp.has(t) else -1

func rank_letter(t: int) -> String: return Weapons.RANKS[rank(t)] if rank(t) >= 0 else "-"

func tags() -> Array: return ClassProfs.tags(unit_class.name)

## "" if usable, else the reason (shown greyed out in menus).
func block_reason(w: WeaponData) -> String:
	if w.uses <= 0: return "파손"
	if w.is_item(): return ""
	if unit_class.weapon_types.is_empty(): return ""   # enemies: any
	if not w.type in unit_class.weapon_types: return "병종 불가"
	if team == 0 and rank(w.type) < w.rank: return "랭크 부족 (%s 필요, 현재 %s)" % [Weapons.RANKS[w.rank], rank_letter(w.type)]
	if w.type in ClassProfs.LIGHT_ONLY.get(unit_class.name, []) and not (w.light or w.weight <= ClassProfs.LIGHT_WT): return "경량 무기만 사용 가능"
	if w.type in ClassProfs.DAGGER_ONLY.get(unit_class.name, []) and not w.dagger: return "단검만 사용 가능"
	return ""

## Adds weapon EXP; returns new rank letter on rank-up or "".
func gain_wexp(t: int, pts: int) -> String:
	if team != 0 or not wexp.has(t): return ""
	var r0 = rank(t); wexp[t] = mini(ClassProfs.WEXP[-1], wexp[t] + pts)
	return Weapons.RANKS[rank(t)] if rank(t) > r0 else ""

const MAX_ITEMS = 5

func can_use(w: WeaponData) -> bool:
	return block_reason(w) == ""

func usable_weapons() -> Array: return inventory.filter(func(w): return not w.is_staff() and not w.is_item() and can_use(w))
func items() -> Array: return inventory.filter(func(w): return w.is_item())
## First key-type item that can open terrain kind ("door"/"chest").
func key_for(kind: String) -> WeaponData:
	for w in inventory:
		if w.is_item() and w.fx().get("key", "") in [kind, "both"] and w.uses > 0: return w
	return null

func equip(w: WeaponData) -> void:
	if w in inventory: inventory.erase(w); inventory.push_front(w)

func give(w: WeaponData) -> bool:
	if inventory.size() >= MAX_ITEMS: return false
	inventory.append(w); return true

func weapon() -> WeaponData:
	for w in inventory:
		if not w.is_staff() and not w.is_item() and can_use(w): return w
	return null

func staff() -> WeaponData:
	for w in inventory:
		if w.is_staff() and can_use(w): return w
	return null

## Spend one use; drop when broken. Returns true if it broke.
func use_item(w: WeaponData) -> bool:
	w.uses -= 1
	if w.uses <= 0: inventory.erase(w); return true
	return false

## Effective stat including skills.
func eff(s: String) -> int: return stats[s] + Skills.stat_mod(self, s)

func growth(s: String) -> int:
	return data.personal_growths.get(s, 0) + unit_class.growth_rates.get(s, 0)

## Returns dict of stat increases.
func level_up(rng: RandomNumberGenerator = null) -> Dictionary:
	if rng == null: rng = RandomNumberGenerator.new(); rng.randomize()
	var gains = {}
	if level >= ClassCaps.MAX_LEVEL and not boss and team == 0: return gains
	var cp = {} if boss else ClassCaps.caps(unit_class.name)
	for s in STATS:
		var g = growth(s); var inc = 0
		if fixed_growth:
			growth_accum[s] += g
			while growth_accum[s] >= 100: growth_accum[s] -= 100; inc += 1
		else:
			inc = g / 100 + (1 if rng.randi_range(0, 99) < g % 100 else 0)
		if cp.has(s): inc = clampi(inc, 0, maxi(0, int(cp[s]) - int(stats[s])))   # capped stat doesn't grow
		if inc > 0: stats[s] += inc; gains[s] = inc
	level += 1
	hp += gains.get("hp", 0)
	return gains

func gain_exp(amount: int) -> Array:
	if level >= ClassCaps.MAX_LEVEL and team == 0: exp = 0; return []
	exp += amount; var results = []
	while exp >= 100 and not (level >= ClassCaps.MAX_LEVEL and team == 0):
		exp -= 100; results.append(level_up())
	return results

## 각성: all stats +2, HP +5 for this chapter only.
func apply_awakening() -> void:
	awakened = true
	for s in STATS: stats[s] += AWAKEN_HP if s == "hp" else AWAKEN_BONUS
	hp = stats.hp

## Restore saved progress (level/exp/stats) from Campaign roster.
func apply_progress(p: Dictionary) -> void:
	level = int(p.level); exp = int(p.exp)
	for s in p.stats: stats[s] = int(p.stats[s])
	hp = stats.hp
	move_bonus = int(p.get("move_bonus", 0))
	if p.has("class") and p["class"] != unit_class.name: unit_class = Roster.cls(p["class"])
	if p.has("wexp") and typeof(p.wexp) == TYPE_DICTIONARY and not p.wexp.is_empty():
		wexp = {}
		for k in p.wexp: wexp[int(k)] = int(p.wexp[k])
	else: init_ranks()   # migrate old saves: class starting ranks
	for t in ClassProfs.START_RANK.get(unit_class.name, {}):   # migrate: weapon types added to a class later (e.g. 성기사 창)
		if not wexp.has(int(t)): wexp[int(t)] = ClassProfs.WEXP[ClassProfs.START_RANK[unit_class.name][t]]
	if p.has("items"): inventory = p.items.map(func(i): return Weapons.make(i.name, int(i.uses)))
	if team == 0:   # migrate: old saves clamp to class caps / level 20
		ClassCaps.clamp_unit(self); level = mini(level, ClassCaps.MAX_LEVEL)
		if level >= ClassCaps.MAX_LEVEL: exp = 0

func can_promote() -> bool:
	return level >= ClassCaps.PROMOTE_MIN_LV and unit_class.promotes_to != null

func promote(alt := "") -> void:
	if not can_promote(): return
	var target: ClassData = Roster.cls(alt) if alt != "" else unit_class.promotes_to
	# new weapon types -> free iron weapon of each new type
	for t in target.weapon_types:
		if not t in unit_class.weapon_types and Roster.IRON.has(t):
			var iw = Weapons.make("라이트" if target.name == "비숍" and t == WeaponData.Type.TOME else Roster.IRON[t])
			if inventory.size() < MAX_ITEMS: inventory.append(iw)
			else: pending_gift.append(iw)
	var b = target.get_promotion_bonus()
	for s in b:
		if s == "move": move_bonus += b[s]
		else: stats[s] += b[s]
	if b.has("hp"): hp += b["hp"]
	var mn = ClassCaps.mins(target.name)   # raise to promoted-class minimums, then clamp to promoted caps
	for s in mn:
		if stats.get(s, 0) < mn[s]:
			if s == "hp": hp += mn[s] - stats[s]
			stats[s] = mn[s]
	unit_class = target; level = 1; exp = 0
	ClassCaps.clamp_unit(self)
	for t in ClassProfs.START_RANK.get(target.name, {}):   # promotion broadens ranks
		wexp[int(t)] = maxi(int(wexp.get(int(t), 0)), ClassProfs.WEXP[ClassProfs.START_RANK[target.name][t]])

func atk() -> int:
	var w = weapon()
	return (eff("mag") if w and w.magic else eff("str")) + (w.might if w else 0) + (BattleManager.bonus(self).might if w else 0)
func has_tag(t: String) -> bool: return t in data.tags
func move_range() -> int: return unit_class.move + move_bonus + Skills.move_mod(self)

func to_dict() -> Dictionary:
	return {"name": data.name, "team": team, "cell": [cell.x, cell.y], "level": level, "exp": exp, "hp": hp, "move_bonus": move_bonus, "class": unit_class.name, "stats": stats, "acted": has_acted, "awakened": awakened, "items": inventory.map(func(w): return w.to_dict()), "poison": poison, "wexp": wexp, "kind": unit_class.name, "drop": inventory.find(drop) if drop else -1, "gold": gold_drop, "guard": guard, "boss": boss, "aoe": aoe, "raider": raider, "talk": talk_from, "uid": uid, "dw": drop_w, "di": drop_i}

func from_dict(d: Dictionary) -> void:
	cell = Vector2i(d.cell[0], d.cell[1]); level = d.level; exp = d.exp; hp = d.hp; stats = d.stats; has_acted = d.acted; move_bonus = d.get("move_bonus", 0)

var threat_mark = false   # red pulsing "!" : this enemy's 특효 weapon can reach the selected ally (set by battle)

## Tags this unit's usable weapons are effective against (map badge), e.g. ["flying"] for any bow user.
func eff_weapon_tags() -> Array:
	var out = []
	for w in usable_weapons():
		for t in w.effective: if not t in out: out.append(t)
	return out

## Small target-type glyph for the 특효 badge: wing (flying) / shield (armor) / horseshoe (cavalry).
func _eff_glyph(c: Vector2, tag: String, col: Color) -> void:
	match tag:
		"flying": draw_colored_polygon(PackedVector2Array([c + Vector2(-7, -4), c + Vector2(0, 2), c + Vector2(7, -4), c + Vector2(5, 3), c + Vector2(0, 6), c + Vector2(-5, 3)]), col)
		"armor": draw_colored_polygon(PackedVector2Array([c + Vector2(-6, -6), c + Vector2(6, -6), c + Vector2(6, 0), c + Vector2(0, 7), c + Vector2(-6, 0)]), col)
		"cavalry": draw_arc(c + Vector2(0, 1), 5, PI * 0.75, PI * 2.25, 12, col, 3.0)
		_: draw_circle(c, 4, col)

static var anim_frame = 0   # global idle frame (0,1,2) advanced by battle scene

func _draw() -> void:
	var sz = Grid.CELL - 8
	var grey = has_acted and team == 0
	var bob = [0, -4, 0, 4][anim_frame % 4] if not grey else 0
	var px = 64.0 if not boss else 76.0
	# team base (blue/red ellipse) like GBA map palettes
	var base = Color8(48, 96, 232, 200) if team == 0 else Color8(216, 40, 40, 200)
	if grey: base = Color8(96, 96, 96, 200)
	draw_set_transform(Vector2(0, 26), 0, Vector2(1, 0.35)); draw_circle(Vector2.ZERO, 30, base); draw_set_transform(Vector2.ZERO)
	var mod = Color.WHITE
	if team == 1 and has_tag("dark"): mod = Color(0.85, 0.7, 1.0)
	if grey: mod = Color(0.45, 0.45, 0.5)
	var user = Sprites.user_sheet(self) != null
	if user: mod = Color(1, 1, 1) if not grey else Color(0.5, 0.5, 0.55)
	draw_texture_rect(Sprites.unit_frame(self, (anim_frame / 2) % 2) if user else Sprites.unit_tex(self), Rect2(-px / 2, -px / 2 - 6 + (-3 if anim_frame % 4 == 1 else 0), px, px), false, mod)
	if team == 1: draw_rect(Rect2(-px / 2, -px / 2 - 6, 10, 10), Color8(216, 40, 40))
	# HP bar
	var w = float(hp) / stats.hp
	draw_rect(Rect2(-30, 30, 60, 6), Color8(16, 16, 24))
	draw_rect(Rect2(-29, 31, 58 * w, 4), Color8(88, 232, 96) if w > 0.5 else (Color8(248, 200, 48) if w > 0.25 else Color8(240, 64, 48)))
	if drop or gold_drop > 0:
		draw_rect(Rect2(sz / 2.0 - 16, -sz / 2.0, 14, 14), Color8(255, 216, 32)); draw_rect(Rect2(sz / 2.0 - 16, -sz / 2.0, 14, 14), Color8(16, 16, 24), false, 2)
	if show_badge:   # equipped weapon badge (bottom-left), FE-style
		var bw = weapon() if weapon() else staff()
		if bw:
			draw_rect(Rect2(-sz / 2.0 - 2, sz / 2.0 - 24, 24, 24), Color8(16, 16, 24, 220)); draw_rect(Rect2(-sz / 2.0 - 2, sz / 2.0 - 24, 24, 24), Color8(248, 216, 112), false, 1.5)
			draw_texture_rect(Icons.of(bw), Rect2(-sz / 2.0 + 2, sz / 2.0 - 20, 16, 16), false)   # 1:1 pixels (integer scale)
	var et = eff_weapon_tags()   # 특효 badge(s) right of the weapon badge: dark red chip + target-type glyph
	for i in et.size():
		var r = Rect2(-sz / 2.0 + 23 + i * 19, sz / 2.0 - 22, 18, 18)
		draw_rect(r, Color8(120, 16, 24, 230)); draw_rect(r, Color8(255, 96, 80), false, 1.5)
		_eff_glyph(r.get_center(), et[i], Color8(255, 236, 200))
	if threat_mark:   # pulsing red "!" above the head
		var p = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 130.0)
		var hc = Vector2(0, -px / 2 - 16)
		draw_circle(hc, 13 + 3 * p, Color(1, 0.1, 0.1, 0.35 + 0.35 * p)); draw_circle(hc, 11, Color8(220, 24, 24)); draw_arc(hc, 11, 0, TAU, 20, Color.WHITE, 2.0)
		draw_string(FONT, hc + Vector2(-11, 7), "!", HORIZONTAL_ALIGNMENT_CENTER, 22, 20, Color.WHITE)
	if boss: draw_string(FONT, Vector2(-sz / 2.0, -sz / 2.0 + 12), "BOSS", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color8(255, 80, 80))
	if poison > 0: draw_circle(Vector2(-sz / 2.0 + 8, -sz / 2.0 + 8), 7, Color(0.6, 0.1, 0.8))
	if awakened:
		draw_rect(Rect2(sz / 2.0 - 30, sz / 2.0 - 30, 30, 18), Color8(255, 200, 32))
		draw_string(FONT, Vector2(sz / 2.0 - 30, sz / 2.0 - 16), "각성", HORIZONTAL_ALIGNMENT_CENTER, 30, 13, Color.BLACK)

func _ready() -> void: add_to_group("units")
