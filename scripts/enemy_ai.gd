class_name EnemyAI extends RefCounted
## Enemy AI. Attackers in reach pick the target with best expected damage (kills weigh most, counter-damage
## and terrain considered). Units with no target advance; guard units hold position; bosses never move.
## plan() returns an intent dict {unit, move_to, target} shown to the player before the enemy phase.

static var smart = false   # 매우 어려움: focus kills, healers and soft targets; less afraid of counters
static func expected(e: Unit, f: Unit) -> Dictionary:
	var fc = BattleManager.forecast(e, f)
	var hits = maxi(1, fc.atk_count)
	var exp_dmg = mini(f.hp, fc.atk_dmg * hits) * fc.atk_hit / 100.0
	var p_kill = 0.0
	if fc.def_hp_after == 0: p_kill = pow(fc.atk_hit / 100.0, hits if fc.atk_dmg * 1 < f.hp else 1)
	var taken = 0.0
	if fc.def_dmg > 0: taken = fc.def_dmg * maxi(1, fc.def_count) * fc.def_hit / 100.0
	if smart:
		var soft = 15.0 if (f.weapon() == null or f.inventory.any(func(w): return w.is_staff())) else 0.0
		return {"score": exp_dmg * 1.2 + p_kill * 80.0 + soft - taken * 0.2, "fc": fc}
	return {"score": exp_dmg + p_kill * 40.0 - taken * 0.5, "fc": fc}

static func plan(e: Unit, units: Array, grid: Grid) -> Dictionary:
	var stay = {"unit": e, "move_to": e.cell, "target": null}
	var foes = units.filter(func(u): return foe(e, u) and u.hp > 0)
	var w = e.weapon()
	if foes.is_empty() or w == null: return stay
	var occ = {}; var block = {}
	for u in units:
		if u != e and u.hp > 0:
			occ[u.cell] = true
			if foe(e, u): block[u.cell] = true
	var reach = [e.cell] if e.boss or e.talk_from != "" else grid.movement_range(e.cell, e.move_range(), block, occ, "flying" in e.tags())
	var best = {}; var best_score = -INF
	var old: Vector2i = e.cell
	for c in reach:
		for f in foes:
			var dist: int = abs(c.x - f.cell.x) + abs(c.y - f.cell.y)
			if dist < w.min_range or dist > w.max_range: continue
			e.cell = c
			var r = expected(e, f)
			var t = grid.terrain_bonus(c)
			var score = r.score + t[1] * 0.05 + t[0] * 0.5
			e.cell = old
			if score > best_score: best_score = score; best = {"unit": e, "move_to": c, "target": f}
	e.cell = old
	if not best.is_empty(): return best
	if e.guard or e.boss: return stay
	# advance toward nearest foe by path distance (approximate with manhattan over reachable cells)
	var nearest: Unit = foes[0]
	for f in foes:
		if _d(e.cell, f.cell) < _d(e.cell, nearest.cell): nearest = f
	var dest: Vector2i = e.cell; var best_len = INF
	for c in reach:
		var p = grid.path(c, nearest.cell)
		var l = p.size() if p.size() > 0 else 999 + _d(c, nearest.cell)
		if l < best_len: best_len = l; dest = c
	return {"unit": e, "move_to": dest, "target": null}

static func _d(a: Vector2i, b: Vector2i) -> int: return abs(a.x - b.x) + abs(a.y - b.y)

## Team 1 (shadows) vs everyone else; team 2 = allied NPC.
static func foe(a: Unit, b: Unit) -> bool: return (a.team == 1) != (b.team == 1)
