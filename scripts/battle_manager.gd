class_name BattleManager extends RefCounted
## FE-style combat formulas.
const TRIANGLE_HIT = 15
const TRIANGLE_DMG = 1
static var rng = RandomNumberGenerator.new()

static func tri(a: Unit, d: Unit) -> int:
	if a.data.weapon == null or d.data.weapon == null: return 0
	return WeaponData.triangle(a.data.weapon.type, d.data.weapon.type)

static func hit_rate(a: Unit, d: Unit) -> int:
	var w = a.data.weapon
	var h = (w.hit if w else 0) + a.stats.skl * 2 + a.stats.lck / 2 + tri(a, d) * TRIANGLE_HIT
	var avoid = d.stats.spd * 2 + d.stats.lck
	return clampi(h - avoid, 0, 100)

static func damage(a: Unit, d: Unit) -> int:
	var defense = d.stats.res if a.data.weapon and a.data.weapon.magic else d.stats.def
	return maxi(0, a.atk() + tri(a, d) * TRIANGLE_DMG - defense)

static func doubles(a: Unit, d: Unit) -> bool:
	return a.stats.spd - d.stats.spd >= 4

static func in_range(a: Unit, d: Unit) -> bool:
	if a.data.weapon == null: return false
	var dist: int = abs(a.cell.x - d.cell.x) + abs(a.cell.y - d.cell.y)
	return dist >= a.data.weapon.min_range and dist <= a.data.weapon.max_range

## 2-RN: hit if average of two rolls < displayed hit.
static func roll_hit(displayed: int) -> bool:
	return (rng.randi_range(0, 99) + rng.randi_range(0, 99)) / 2.0 < displayed

## True hit probability under 2RN for a displayed value (for info).
static func true_hit(displayed: int) -> float:
	var n = 0
	for i in 100:
		for j in 100:
			if (i + j) / 2.0 < displayed: n += 1
	return n / 100.0

## Returns forecast with HP before and expected-after (assuming all hits land).
static func forecast(a: Unit, d: Unit) -> Dictionary:
	var counter = in_range(d, a)
	var a_hits = 2 if doubles(a, d) else 1
	var d_hits = (2 if doubles(d, a) else 1) if counter else 0
	var a_dmg = damage(a, d); var d_dmg = damage(d, a)
	var a_hp = a.hp; var d_hp = d.hp
	# simulate order: A, D, (A double), (D double)
	var seq = [0, 1, 0, 1]; var ac = 0; var dc = 0
	for s in seq:
		if a_hp <= 0 or d_hp <= 0: break
		if s == 0 and ac < a_hits: d_hp = maxi(0, d_hp - a_dmg); ac += 1
		elif s == 1 and dc < d_hits: a_hp = maxi(0, a_hp - d_dmg); dc += 1
	return {"atk_name": a.data.name, "def_name": d.data.name,
		"atk_hp_before": a.hp, "atk_hp_after": a_hp, "def_hp_before": d.hp, "def_hp_after": d_hp,
		"atk_dmg": a_dmg, "atk_hit": hit_rate(a, d), "atk_x2": a_hits == 2,
		"def_dmg": d_dmg if counter else -1, "def_hit": hit_rate(d, a) if counter else -1, "def_x2": d_hits == 2,
		"triangle": tri(a, d)}

## FE-like EXP: (31 + lvdiff)/3 for a hit-exchange, + kill bonus (20 + lvdiff*3). 1 if no damage dealt.
static func exp_for(u: Unit, foe: Unit, dealt: bool, killed: bool) -> int:
	var diff = foe.level - u.level
	if not dealt: return 1
	var e = maxi(1, (31 + diff) / 3)
	if killed: e += maxi(0, 20 + diff * 3)
	return clampi(e, 1, 100)

## Give EXP to player side after a combat; returns log lines (level-ups).
static func award_exp(a: Unit, d: Unit, a_hp0: int, d_hp0: int) -> Array:
	var out = []
	for pair in [[a, d, d_hp0], [d, a, a_hp0]]:
		var u: Unit = pair[0]; var foe: Unit = pair[1]
		if u.team != 0 or u.hp <= 0: continue
		var gained = exp_for(u, foe, foe.hp < pair[2], foe.hp <= 0)
		var ups = u.gain_exp(gained)
		out.append("%s EXP +%d (%d/100)" % [u.data.name, gained, u.exp])
		for g in ups: out.append("%s 레벨 업! Lv%d %s" % [u.data.name, u.level, str(g)])
		var C = Engine.get_main_loop().root.get_node_or_null("Campaign")
		if C: C.record_progress(u)
	return out

## Execute combat. Returns log lines.
static func resolve(a: Unit, d: Unit) -> Array:
	var log = []
	var a_hp0 = a.hp; var d_hp0 = d.hp
	var order = [[a, d]]
	var counter = in_range(d, a)
	if counter: order.append([d, a])
	if doubles(a, d): order.append([a, d])
	elif counter and doubles(d, a): order.append([d, a])
	for pair in order:
		var x: Unit = pair[0]; var y: Unit = pair[1]
		if x.hp <= 0 or y.hp <= 0: break
		if roll_hit(hit_rate(x, y)):
			var dm = damage(x, y); y.hp = maxi(0, y.hp - dm)
			log.append("%s → %s %d 피해" % [x.data.name, y.data.name, dm])
		else: log.append("%s 빗나감" % x.data.name)
	log.append_array(award_exp(a, d, a_hp0, d_hp0))
	return log
