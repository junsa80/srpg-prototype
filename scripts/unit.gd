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

func setup(d: UnitData, t: int, c: Vector2i) -> void:
	data = d; team = t; cell = c; level = d.level; unit_class = d.unit_class
	for s in STATS:
		stats[s] = unit_class.base_stats.get(s, 0); growth_accum[s] = 50
	hp = stats.hp
	if d.weapon: inventory = [d.weapon]

func weapon() -> WeaponData:
	for w in inventory:
		if not w.is_staff() and w.uses > 0: return w
	return null

func staff() -> WeaponData:
	for w in inventory:
		if w.is_staff() and w.uses > 0: return w
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
	for s in STATS:
		var g = growth(s); var inc = 0
		if fixed_growth:
			growth_accum[s] += g
			while growth_accum[s] >= 100: growth_accum[s] -= 100; inc += 1
		else:
			inc = g / 100 + (1 if rng.randi_range(0, 99) < g % 100 else 0)
		if inc > 0: stats[s] += inc; gains[s] = inc
	level += 1
	hp += gains.get("hp", 0)
	return gains

func gain_exp(amount: int) -> Array:
	exp += amount; var results = []
	while exp >= 100:
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
	if p.has("items"): inventory = p.items.map(func(i): return Weapons.make(i.name, int(i.uses)))

func can_promote() -> bool:
	return level >= unit_class.promotion_level and unit_class.promotes_to != null

func promote() -> void:
	if not can_promote(): return
	var target: ClassData = unit_class.promotes_to
	var b = target.get_promotion_bonus()
	for s in b:
		if s == "move": move_bonus += b[s]
		else: stats[s] += b[s]
	if b.has("hp"): hp += b["hp"]
	unit_class = target; level = 1

func atk() -> int:
	var w = weapon()
	return (eff("mag") if w and w.magic else eff("str")) + (w.might if w else 0)
func has_tag(t: String) -> bool: return t in data.tags
func move_range() -> int: return unit_class.move + move_bonus + Skills.move_mod(self)

func to_dict() -> Dictionary:
	return {"name": data.name, "team": team, "cell": [cell.x, cell.y], "level": level, "exp": exp, "hp": hp, "move_bonus": move_bonus, "class": unit_class.name, "stats": stats, "acted": has_acted, "awakened": awakened, "items": inventory.map(func(w): return w.to_dict()), "poison": poison}

func from_dict(d: Dictionary) -> void:
	cell = Vector2i(d.cell[0], d.cell[1]); level = d.level; exp = d.exp; hp = d.hp; stats = d.stats; has_acted = d.acted; move_bonus = d.get("move_bonus", 0)

func _draw() -> void:
	var sz = Grid.CELL - 8
	var col = data.color
	if has_acted: col = col.darkened(0.5)
	draw_rect(Rect2(-sz / 2.0, -sz / 2.0, sz, sz), col)
	draw_rect(Rect2(-sz / 2.0, -sz / 2.0, sz, sz), Color.WHITE if team == 0 else Color.BLACK, false, 3)
	var w = float(hp) / stats.hp
	draw_rect(Rect2(-sz / 2.0, sz / 2.0 - 8, sz * w, 8), Color.GREEN)
	var f = FONT
	draw_string(f, Vector2(-sz / 2.0 + 2, -4), data.name, HORIZONTAL_ALIGNMENT_CENTER, sz - 4, 15, Color.WHITE)
	if poison > 0: draw_circle(Vector2(-sz / 2.0 + 8, -sz / 2.0 + 8), 7, Color(0.6, 0.1, 0.8))
	if awakened:
		draw_rect(Rect2(sz / 2.0 - 26, -sz / 2.0 - 4, 30, 22), Color(1, 0.8, 0.1))
		draw_string(f, Vector2(sz / 2.0 - 26, -sz / 2.0 + 13), "각성", HORIZONTAL_ALIGNMENT_CENTER, 30, 13, Color.BLACK)
	if unit_class.name != data.name: draw_string(f, Vector2(-sz / 2.0 + 2, 20), unit_class.name, HORIZONTAL_ALIGNMENT_CENTER, sz - 4, 15, Color(1, 1, 1, 0.85))
