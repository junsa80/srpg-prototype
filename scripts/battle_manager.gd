class_name BattleManager extends RefCounted
## FE-style combat formulas + personal skill hooks (see skills.gd).
const TRIANGLE_HIT = 15
const TRIANGLE_DMG = 1
static var rng = RandomNumberGenerator.new()
## Structured record of the last resolve()/heal() for the animated combat scene.
static var events: Array = []    # {type:"strike", x, y, hit, crit, dmg, x_hp, y_hp, broke} | {type:"heal", ...}
static var start_hp = {}
static var rank_ups: Array = []  # ["아린 검 랭크 C!"] from the last resolve()/heal()
static var exp_events: Array = [] # {unit, gained, before, after, level_before, ups:[gains]}

static func tri(a: Unit, d: Unit) -> int:
	if a.weapon() == null or d.weapon() == null: return 0
	return WeaponData.triangle(a.weapon().type, d.weapon().type)

## AS = spd - max(0, weight - str)   (magic: weight - mag, 미라 -2)
static func attack_speed(u: Unit) -> int:
	var w = u.weapon()
	if w == null: return u.eff("spd")
	if w.light: return u.eff("spd")
	var burden = w.weight - (u.eff("mag") if w.magic else u.eff("str")) - (Skills.weight_relief(u) if w.magic else 0)
	return u.eff("spd") - maxi(0, burden)

## Weapon-rank bonus [might, hit, crit] (players only) + class proficiency.
static func bonus(a: Unit) -> Dictionary:
	var w = a.weapon()
	if w == null: return {"might": 0, "hit": 0, "crit": 0, "rank": ""}
	var rb = ClassProfs.RANK_BONUS[a.rank(w.type)] if a.team == 0 and a.rank(w.type) >= 0 else [0, 0, 0]
	var p = ClassProfs.prof(a.unit_class.name, w.type)
	if w.dagger and ClassProfs.DAGGER_PROF.has(a.unit_class.name): p = ClassProfs.DAGGER_PROF[a.unit_class.name]
	return {"might": rb[0] + p.get("might", 0), "hit": rb[1] + p.get("hit", 0), "crit": rb[2] + p.get("crit", 0),
		"rank": a.rank_letter(w.type) if a.team == 0 else ""}

static func is_effective(a: Unit, d: Unit) -> bool:
	var w = a.weapon()
	if w == null or w.effective.is_empty(): return false
	for t in d.tags(): if t in w.effective: return true
	return false

static func avoid(d: Unit) -> int:
	var terrain = Skills.grid.terrain_bonus(d.cell)[1] if Skills.grid else 0
	return attack_speed(d) * 2 + d.eff("lck") + terrain + Skills.avo_mod(d)

static func hit_rate(a: Unit, d: Unit) -> int:
	var w = a.weapon()
	if w == null: return 0
	var h = w.hit + a.eff("skl") * 2 + a.eff("lck") / 2 + tri(a, d) * TRIANGLE_HIT + Skills.hit_mod(a, d) + bonus(a).hit
	return clampi(h - avoid(d), 0, 100)

static func crit_rate(a: Unit, d: Unit) -> int:
	var w = a.weapon()
	if w == null: return 0
	return clampi(w.crit + a.eff("skl") / 2 + Skills.crit_mod(a) + bonus(a).crit - d.eff("lck"), 0, 100)

static func damage(a: Unit, d: Unit, initiator = true, strike_no = 1) -> int:
	var w = a.weapon()
	if w == null: return 0
	var power = (a.eff("mag") if w.magic else a.eff("str")) + w.might * (3 if is_effective(a, d) else 1) + bonus(a).might
	var base = power + tri(a, d) * TRIANGLE_DMG - Skills.defense_vs(a, d, w.magic)
	return maxi(0, maxi(0, base) + Skills.dmg_mod(a, d, w.magic, initiator, strike_no))

static func doubles(a: Unit, d: Unit) -> bool:
	return attack_speed(a) - attack_speed(d) >= 4

static func in_range(a: Unit, d: Unit) -> bool:
	var w = a.weapon()
	if w == null: return false
	var dist: int = abs(a.cell.x - d.cell.x) + abs(a.cell.y - d.cell.y)
	return dist >= w.min_range and dist <= w.max_range

## 2-RN: hit if average of two rolls < displayed hit.
static func roll_hit(displayed: int) -> bool:
	return (rng.randi_range(0, 99) + rng.randi_range(0, 99)) / 2.0 < displayed

static func true_hit(displayed: int) -> float:
	var n = 0
	for i in 100:
		for j in 100:
			if (i + j) / 2.0 < displayed: n += 1
	return n / 100.0

## Strike order as [attacker, defender, is_initiator_side] entries. extra_roll forces skill doubles.
static func strike_order(a: Unit, d: Unit, extra_a = false, extra_d = false) -> Array:
	var counter = in_range(d, a)
	var o = []
	if counter and Skills.vantage(d, a): o = [[d, a, false], [a, d, true]]
	else:
		o = [[a, d, true]]
		if counter: o.append([d, a, false])
	if doubles(a, d) or extra_a: o.append([a, d, true])
	elif counter and (doubles(d, a) or extra_d): o.append([d, a, false])
	# brave weapons: each of that unit's strikes happens twice in a row
	var out = []
	for s in o:
		out.append(s)
		var w = s[0].weapon()
		if w and w.brave: out.append(s)
	return out

static func strikes(x: Unit, a: Unit, d: Unit) -> int:
	return strike_order(a, d).filter(func(s): return s[0] == x).size()

static func _extra(u: Unit, foe: Unit) -> bool:
	var c = Skills.extra_double_chance(u)
	return c > 0 and attack_speed(u) > attack_speed(foe) and not doubles(u, foe) and rng.randf() < c

## Forecast: before/after HP assuming all strikes hit (no skill-proc doubles).
static func forecast(a: Unit, d: Unit) -> Dictionary:
	var counter = in_range(d, a)
	var hp = {a: a.hp, d: d.hp}; var n = {a: 0, d: 0}; var dmg_first = {}
	for s in strike_order(a, d):
		var x: Unit = s[0]; var y: Unit = s[1]
		if hp[x] <= 0 or hp[y] <= 0: break
		n[x] += 1
		var dm = damage(x, y, s[2], n[x]); if not dmg_first.has(x): dmg_first[x] = dm
		hp[y] = maxi(0, hp[y] - dm)
	return {"atk_name": a.data.name, "def_name": d.data.name,
		"atk_hp_before": a.hp, "atk_hp_after": hp[a], "def_hp_before": d.hp, "def_hp_after": hp[d],
		"atk_dmg": damage(a, d, true, 1), "atk_hit": hit_rate(a, d), "atk_crit": crit_rate(a, d), "atk_x2": doubles(a, d),
		"def_dmg": damage(d, a, false, 1) if counter else -1, "def_hit": hit_rate(d, a) if counter else -1,
		"def_crit": crit_rate(d, a) if counter else -1, "def_x2": counter and doubles(d, a),
		"atk_weapon": a.weapon().name if a.weapon() else "-", "atk_uses": a.weapon().uses if a.weapon() else 0,
		"vantage": counter and Skills.vantage(d, a), "triangle": tri(a, d),
		"atk_count": strikes(a, a, d), "def_count": strikes(d, a, d) if counter else 0,
		"atk_eff": is_effective(a, d), "def_eff": counter and is_effective(d, a),
		"atk_bonus": bonus(a), "def_bonus": bonus(d), "atk_w": a.weapon(), "def_w": d.weapon()}

## FE-like EXP.
static func exp_for(u: Unit, foe: Unit, dealt: bool, killed: bool) -> int:
	var diff = foe.level - u.level
	if not dealt: return 1
	var e = maxi(1, (31 + diff) / 3)
	if killed: e += maxi(0, 20 + diff * 3)
	return clampi(e, 1, 100)

static func _campaign():
	var ml = Engine.get_main_loop()
	return ml.root.get_node_or_null("Campaign") if ml is SceneTree else null

static func award_exp(a: Unit, d: Unit, a_hp0: int, d_hp0: int) -> Array:
	var out = []
	for pair in [[a, d, d_hp0], [d, a, a_hp0]]:
		var u: Unit = pair[0]; var foe: Unit = pair[1]
		if u.team != 0 or u.hp <= 0: continue
		out.append_array(give_exp(u, exp_for(u, foe, foe.hp < pair[2], foe.hp <= 0)))
	return out

static func give_exp(u: Unit, gained: int) -> Array:
	var out = []
	var before = u.exp; var lv0 = u.level
	var ups = u.gain_exp(gained)
	exp_events.append({"unit": u, "gained": gained, "before": before, "after": u.exp, "level_before": lv0, "ups": ups})
	out.append("%s EXP +%d (%d/100)" % [u.data.name, gained, u.exp])
	for g in ups: out.append("%s 레벨 업! Lv%d %s" % [u.data.name, u.level, str(g)])
	var C = _campaign()
	if C: C.record_progress(u)
	return out

## Execute combat. Returns log lines.
static func resolve(a: Unit, d: Unit) -> Array:
	var log = []
	events = []; exp_events = []; start_hp = {a: a.hp, d: d.hp}
	var a_hp0 = a.hp; var d_hp0 = d.hp
	var n = {a: 0, d: 0}
	for s in strike_order(a, d, _extra(a, d), _extra(d, a)):
		var x: Unit = s[0]; var y: Unit = s[1]
		if x.hp <= 0 or y.hp <= 0: break
		var w = x.weapon()
		if w == null: continue
		n[x] += 1; x.weapon_used = w
		var ev = {"type": "strike", "x": x, "y": y, "hit": false, "crit": false, "dmg": 0}
		if roll_hit(hit_rate(x, y)):
			var dm = damage(x, y, s[2], n[x]); var crit = rng.randi_range(0, 99) < crit_rate(x, y)
			if crit: dm = dm * 3 + Skills.crit_dmg_bonus(x)
			y.hp = maxi(0, y.hp - dm)
			ev.hit = true; ev.crit = crit; ev.dmg = dm
			log.append("%s → %s %d 피해%s" % [x.data.name, y.data.name, dm, " (치명!)" if crit else ""])
			var ls = Skills.lifesteal_magic(x)
			if ls > 0 and w.magic: var h = int(dm * ls); x.hp = mini(x.stats.hp, x.hp + h); log.append("%s HP +%d 흡수" % [x.data.name, h])
			if y.hp > 0 and rng.randf() < Skills.poison_chance(x): y.poison = 3; log.append("%s 중독!" % y.data.name)
			if x.aoe:   # 바르가스: splash half damage to the target's allies next to it (never lethal)
				for o in Skills.units:
					if o != y and o != x and o.team == y.team and o.hp > 0 and abs(o.cell.x - y.cell.x) + abs(o.cell.y - y.cell.y) == 1:
						var sp = maxi(1, dm / 2); o.hp = maxi(1, o.hp - sp); log.append("%s의 광역 공격! %s %d 피해" % [x.data.name, o.data.name, sp])
		else: log.append("%s 빗나감" % x.data.name)
		ev["x_hp"] = x.hp; ev["y_hp"] = y.hp; events.append(ev)
		if x.use_item(w): log.append("%s의 %s 파손!" % [x.data.name, w.name])
	rank_ups = []
	for u in n:
		if n[u] > 0 and u.hp > 0 and u.weapon_used != null: _wexp(u, u.weapon_used.type, ClassProfs.WEXP_PER_COMBAT, log)
	for u in [a, d]: u.weapon_used = null
	log.append_array(award_exp(a, d, a_hp0, d_hp0))
	return log

static func _wexp(u: Unit, t: int, pts: int, log: Array) -> void:
	var r = u.gain_wexp(t, pts)
	if r != "":
		var line = "%s %s 랭크 %s 달성!" % [u.data.name, Weapons.TYPE_NAMES.get(t, "?"), r]
		log.append(line); rank_ups.append(line)

## Staff heal: amount = staff heal + mag. Returns log.
static func heal(healer: Unit, target: Unit) -> Array:
	var st = healer.staff()
	if st == null: return []
	events = []; exp_events = []
	var amt = mini(target.stats.hp - target.hp, heal_amount(healer, st))
	target.hp += amt
	events.append({"type": "heal", "x": healer, "y": target, "amt": amt, "y_hp": target.hp})
	var log = ["%s → %s HP +%d (%s)" % [healer.data.name, target.data.name, amt, st.name]]
	rank_ups = []
	var t = st.type
	if healer.use_item(st): log.append("%s 파손!" % st.name)
	_wexp(healer, t, ClassProfs.WEXP_PER_HEAL, log)
	log.append_array(give_exp(healer, 11))
	return log

static func heal_amount(healer: Unit, st: WeaponData) -> int:
	return st.heal + healer.eff("mag") + ClassProfs.prof(healer.unit_class.name, st.type).get("heal", 0)
