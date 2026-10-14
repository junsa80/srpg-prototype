class_name EnemyAI extends RefCounted
## Simple AI: pick best reachable target (max damage, prefer kills), else move toward nearest.
## plan() returns an intent dict which the UI can display before execution.

static func plan(e: Unit, units: Array, grid: Grid) -> Dictionary:
	var foes = units.filter(func(u): return u.team != e.team and u.hp > 0)
	if foes.is_empty(): return {"unit": e, "move_to": e.cell, "target": null}
	var occ = {}; var block = {}
	for u in units:
		if u != e and u.hp > 0:
			occ[u.cell] = true
			if u.team != e.team: block[u.cell] = true
	var reach = grid.movement_range(e.cell, e.move_range(), block, occ)
	var best = {}; var best_score = -INF
	var w = e.data.weapon
	for c in reach:
		for f in foes:
			var dist: int = abs(c.x - f.cell.x) + abs(c.y - f.cell.y)
			if dist < w.min_range or dist > w.max_range: continue
			var old: Vector2i = e.cell; e.cell = c
			var fc = BattleManager.forecast(e, f); e.cell = old
			var score: float = (f.hp - fc.def_hp_after) * fc.atk_hit / 100.0 + (50 if fc.def_hp_after == 0 else 0) - (e.hp - fc.atk_hp_after) * 0.5
			if score > best_score: best_score = score; best = {"unit": e, "move_to": c, "target": f}
	if not best.is_empty(): return best
	# approach nearest foe
	var nearest: Unit = foes[0]
	for f in foes:
		if _d(e.cell, f.cell) < _d(e.cell, nearest.cell): nearest = f
	var dest: Vector2i = e.cell
	for c in reach:
		if _d(c, nearest.cell) < _d(dest, nearest.cell): dest = c
	return {"unit": e, "move_to": dest, "target": null}

static func _d(a: Vector2i, b: Vector2i) -> int: return abs(a.x - b.x) + abs(a.y - b.y)
