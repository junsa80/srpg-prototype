extends Node
## Difficulty sim: scripted AI plays each chapter (player side uses the same tactical AI as the enemy,
## lord heads for seize/escape tiles, healers heal). Run: godot --headless res://tests/sim_test.tscn -- --flowtest
const PLAN = {   # chapter: [party level, extra weapons, recruits, promote]
	"ch1": [1, [], [], false], "ch2": [3, [], [], false], "ch3": [5, ["강철"], [], false],
	"ch4a": [7, ["강철"], ["가렌"], false], "ch4b": [7, ["강철"], ["가렌"], false],
	"ch5": [9, ["강철"], ["가렌", "카이"], false], "ch6": [3, ["강철", "은"], ["가렌", "카이", "실라"], true],
	"ch7": [5, ["강철", "은"], ["가렌", "카이", "실라"], true],
	"ch8": [7, ["강철", "은"], ["가렌", "카이", "실라", "다린"], true],
	"ch9": [8, ["강철", "은"], ["가렌", "카이", "실라", "다린", "소라"], true],
	"ch10": [9, ["강철", "은"], ["가렌", "카이", "실라", "다린", "소라", "엘렌"], true],
	"ch11": [10, ["강철", "은"], ["가렌", "카이", "실라", "다린", "소라", "엘렌", "카린"], true],
	"ch12": [11, ["강철", "은"], ["가렌", "카이", "실라", "다린", "소라", "엘렌", "카린"], true],
	"ch13": [12, ["강철", "은"], ["가렌", "카이", "실라", "다린", "소라", "엘렌", "카린", "카이린"], true],
	"ch14": [13, ["강철", "은"], ["가렌", "카이", "실라", "다린", "소라", "엘렌", "카린", "카이린"], true],
	"ch15": [15, ["강철", "은"], ["가렌", "카이", "실라", "다린", "소라", "엘렌", "카린", "카이린", "리엘"], true],
	"ch16": [16, ["강철", "은"], ["가렌", "카이", "실라", "다린", "소라", "엘렌", "카린", "카이린", "리엘"], true],
	"ch17": [17, ["강철", "은"], ["가렌", "카이", "실라", "다린", "소라", "엘렌", "카린", "카이린", "리엘", "제드"], true],
	"ch18": [17, ["강철", "은"], ["가렌", "카이", "실라", "다린", "소라", "엘렌", "카린", "카이린", "리엘", "제드"], true],
	"ch19": [18, ["강철", "은"], ["가렌", "카이", "실라", "다린", "소라", "엘렌", "카린", "카이린", "리엘", "제드"], true],
	"ch20": [19, ["강철", "은"], ["가렌", "카이", "실라", "다린", "소라", "엘렌", "카린", "카이린", "리엘", "제드"], true]}
const TRIALS = 16
var results = {}
var threat = {}

## cell -> number of enemies that could attack it next enemy phase
func _threat(b) -> Dictionary:
	var t = {}
	for e in b.units:
		if e.team != 1 or e.hp <= 0 or e.weapon() == null: continue
		var occ = {}; var block = {}
		for o in b.units:
			if o != e and o.hp > 0:
				occ[o.cell] = true
				if EnemyAI.foe(e, o): block[o.cell] = true
		var reach = [e.cell] if (e.boss or e.guard) else b.grid.movement_range(e.cell, e.move_range(), block, occ, "flying" in e.tags())
		var hit = {}
		for c in reach:
			for w in e.usable_weapons():
				for dx in range(-w.max_range, w.max_range + 1):
					for dy in range(-w.max_range, w.max_range + 1):
						var d = abs(dx) + abs(dy)
						if d >= w.min_range and d <= w.max_range: hit[c + Vector2i(dx, dy)] = true
		for c in hit:
			if not t.has(c): t[c] = []
			t[c].append(e)
	return t

func _safe(u: Unit, c: Vector2i) -> bool:
	var dmg = 0.0
	var old = u.cell; u.cell = c
	for e in threat.get(c, []):
		var fc = BattleManager.forecast(e, u)
		dmg += fc.atk_dmg * maxi(1, fc.atk_count) * fc.atk_hit / 100.0
	u.cell = old
	if u.data.name == "아린": return dmg < u.hp * 0.5
	return dmg < u.hp

func _ready() -> void:
	var only = OS.get_environment("SIM_ONLY")
	for ch in PLAN:
		if only != "" and only != ch: continue
		var wins = 0; var turns = []; var deaths = 0
		for t in TRIALS:
			var r = await run(ch, t)
			if r.win: wins += 1; turns.append(r.turns)
			deaths += r.deaths
		var avg = (turns.reduce(func(a, b): return a + b, 0) / float(turns.size())) if turns.size() else 0.0
		results[ch] = {"win": wins, "avg_turns": avg, "deaths": deaths / float(TRIALS)}
		print("SIM %-5s win %d/%d  avg turns %.1f  avg player deaths %.1f" % [ch, wins, TRIALS, avg, deaths / float(TRIALS)])
	var ok = true
	for ch in results:
		var r = results[ch]
		var good = r.win >= TRIALS * 0.15 and (r.deaths >= 0.2 or r.avg_turns >= 4 or ch == "ch1")
		if not good: print("  ! %s outside target band (want win >= 15%% — crude sim AI; human-tested ch2 scores ~20%%, and not trivial)" % ch)
		ok = ok and good
	print("SIMTEST ", "PASS" if ok else "FAIL")
	Campaign.reset(); get_tree().quit(0 if ok else 1)

func _prep_party(ch: String) -> void:
	Campaign.absent = []
	Campaign.reset(); Campaign.chapter = ch; Campaign.recruited = PLAN[ch][2].duplicate()
	Campaign.ensure_roster()
	var fg = Unit.fixed_growth; Unit.fixed_growth = true
	for n in Campaign.roster.keys():
		var u = Roster.make_unit(n, 0, Vector2i.ZERO, Campaign.entry(n))
		if PLAN[ch][3]:
			while u.level < 10: u.level_up()
			u.promote()
		while u.level < PLAN[ch][0]: u.level_up()
		u.hp = u.stats.hp
		for t in u.wexp: u.wexp[t] = maxi(u.wexp[t], 70 if PLAN[ch][0] >= 5 or PLAN[ch][3] else u.wexp[t])
		for tier in PLAN[ch][1]:
			for t in u.unit_class.weapon_types:
				var nm = {"강철": {0: "강철검", 1: "강철창", 3: "강철활", 4: "썬더", 2: "철도끼"}, "은": {0: "은검", 1: "은창", 3: "은활", 4: "엘파이어"}}[tier].get(int(t), "")
				if tier == "은": u.wexp[t] = maxi(u.wexp.get(t, 0), 120)
				if nm != "" and u.inventory.size() < Unit.MAX_ITEMS: u.inventory.append(Weapons.make(nm))
		Campaign.record_progress(u, false); u.free()
	Unit.fixed_growth = fg
	Campaign.deploy = []
	if OS.get_environment("SIM_NOHEAL") != "":   # healer-free run: 세라 out, 보리스 in
		var dd: Array = Maps.CH[ch].get("default_deploy", []).duplicate(); dd.erase("세라")
		if not "보리스" in dd: dd.append("보리스")
		Campaign.deploy = dd

func run(ch: String, seed_: int) -> Dictionary:
	_prep_party(ch)
	BattleManager.rng.seed = 1000 + seed_ * 7919 + ch.hash()
	var b = load("res://scenes/battle.tscn").instantiate(); add_child(b)
	await get_tree().process_frame
	b.anim_on = false
	if OS.get_environment("SIM_V") != "": print("   start ", b.units.map(func(x): return "%s t%d %s hp%d/%d lv%d" % [x.data.name, x.team, x.cell, x.hp, x.stats.hp, x.level]))
	var target_cell = Vector2i(-1, -1)
	for c in b.grid.terrain:
		if (b.MAP.goal == "seize" and b.grid.terrain[c] == "throne") or (b.MAP.goal == "escape" and b.grid.terrain[c] == "escape"): target_cell = c
	var turn_cap = 30
	while not b.ended and b.tm.turn <= turn_cap:
		threat = _threat(b)
		var turn0 = b.tm.turn
		for u in b.units.duplicate():
			if b.ended: break
			if b.tm.turn != turn0: break
			if u.team != 0 or u.hp <= 0 or u.has_acted or not is_instance_valid(u): continue
			if OS.get_environment("SIM_V") != "": print("   act ", u.data.name, " phase", b.tm.phase, " busy", b.busy)
			_act(b, u, target_cell)
		if b.ended: break
		if b.tm.turn == turn0: b._on_end_turn()
		await get_tree().process_frame
	if OS.get_environment("SIM_V") != "": print("  doors=", b.grid.terrain.values().count("door"), " luke=", b.units.filter(func(x): return x.data.name == "루크").map(func(x): return [x.cell, x.unit_class.name]), " arin=", b.units.filter(func(x): return x.data.name == "아린").map(func(x): return x.cell))
	var win = b.ended and not b.clear_report.is_empty()
	var deaths = b.units.filter(func(u): return u.team == 0 and u.hp <= 0).size()
	if OS.get_environment("SIM_V") != "": print("  ", ch, " t", b.tm.turn, " ended=", b.ended, " lost=", b._lost(), " rep=", b.clear_report.keys(), " dead=", b.units.filter(func(u): return u.team == 0 and u.hp <= 0).map(func(u): return u.data.name), " foes=", b.units.filter(func(u): return u.team == 1 and u.hp > 0).size())
	var r = {"win": win, "turns": b.tm.turn, "deaths": deaths}
	b.queue_free(); await get_tree().process_frame
	return r

func _act(b, u: Unit, target_cell: Vector2i) -> void:
	var o = b._occ(u)
	var reach = b.grid.movement_range(u.cell, u.move_range(), o[1], o[0], "flying" in u.tags())
	# lord objective (seize/escape): walk toward the tile once early fighting has thinned the enemy
	if b.MAP.goal == "escape" and target_cell.x >= 0:   # everyone runs for the nearest exit; 아린 waits until last
		var exits = b.grid.terrain.keys().filter(func(c): return b.grid.terrain[c] == "escape")
		if u.data.name == "아린":
			var be = u.cell; var bl2 = 9999
			for c in reach:
				if b._unit_at(c) and b._unit_at(c) != u: continue
				for ex in exits:
					var l = 0 if c == ex else (b.grid.path(c, ex).size() if b.grid.path(c, ex).size() else 999)
					if l < bl2: bl2 = l; be = c
			if b.tm.turn >= 2 or bl2 == 0:
				_move(b, u, be)
				if b.grid.terrain.get(u.cell, "") == "escape":
					b.selected = u; b.moved = true; b._do_open(); return
	elif u.data.name == "아린" and target_cell.x >= 0:
		var best = u.cell; var bl = 9999
		for c in reach:
			var p = b.grid.path(c, target_cell); var l = p.size() if p.size() else 999
			if c == target_cell: l = 0
			if l < bl: bl = l; best = c
		if b.tm.turn >= 3 or bl == 0:
			_move(b, u, best)
			if u.cell == target_cell:
				b.selected = u; b.moved = true; b._do_open(); return
	# door openers (thieves / key holders) head for the nearest locked door on escape maps
	if b.MAP.goal == "escape" and (Roster.is_thief(u) or u.inventory.any(func(w): return w.is_item() and w.fx().get("key", "") in ["door", "both"])):
		var doors = b.grid.terrain.keys().filter(func(c): return b.grid.terrain[c] == "door")
		if doors.size():
			var bc = u.cell; var bl3 = 9999
			for c in reach:
				if b._unit_at(c) and b._unit_at(c) != u: continue
				for dr in doors:
					for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						var nb = dr + dd
						if not b.grid.in_bounds(nb) or b.grid.walls.has(nb): continue
						var l = 0 if c == nb else b.grid.path(c, nb).size()
						if c != nb and l == 0: continue
						if l < bl3: bl3 = l; bc = c
			_move(b, u, bc)
			var act0 = b._action(u)
			if not act0.is_empty() and act0.kind == "door": b.selected = u; b.moved = true; b._do_open(); return
			_done(b, u); return
	# healer
	var st = u.staff()
	if st:
		for c in reach:
			var old = u.cell; u.cell = c
			var hurt = b._heal_targets(u).filter(func(x): return x.hp * 2 < x.stats.hp)
			u.cell = old
			if hurt.size():
				_move(b, u, c); BattleManager.heal(u, hurt[0]); _done(b, u); return
	var plan = EnemyAI.plan(u, b.units, b.grid)
	if not _safe(u, plan.move_to) or (plan.target == null and u.data.name == "아린" and target_cell.x < 0):
		# fall back: best safe attack, else safest cell that still closes distance
		var best = {}; var bs = -INF
		for c in reach:
			if not _safe(u, c) or (b._unit_at(c) and b._unit_at(c) != u): continue
			var old = u.cell; u.cell = c
			for f in b.units:
				if f.team != 1 or f.hp <= 0: continue
				var dist = b._dist(c, f.cell)
				if u.usable_weapons().filter(func(w): return dist >= w.min_range and dist <= w.max_range).is_empty(): continue
				var sc = EnemyAI.expected(u, f).score
				if sc > bs: bs = sc; best = {"move_to": c, "target": f}
			u.cell = old
		if best.is_empty():
			var dest = u.cell; var bd = 9999
			for c in reach:
				if not _safe(u, c) or (b._unit_at(c) and b._unit_at(c) != u): continue
				var nd = 9999
				for f in b.units:
					if f.team == 1 and f.hp > 0: nd = mini(nd, b._dist(c, f.cell))
				if u.data.name == "아린": nd = threat.get(c, []).size()  # lord just stays out of reach
				if nd < bd: bd = nd; dest = c
			best = {"move_to": dest, "target": null}
		plan = best
	if b.MAP.goal == "escape" and not Roster.is_thief(u) and plan.target == null:   # keep door-side tiles free for the thieves
		for dr in b.grid.terrain.keys().filter(func(c): return b.grid.terrain[c] == "door"):
			if b._dist(dr, plan.move_to) == 1: plan.move_to = u.cell; break
	_move(b, u, plan.move_to)
	if plan.target and plan.target.hp > 0:
		var d = plan.target
		var dist = b._dist(u.cell, d.cell)
		var ok = u.usable_weapons().filter(func(w): return dist >= w.min_range and dist <= w.max_range)
		if ok.size(): u.equip(ok[0])
		var rr = BattleManager.resolve(u, d)
		if OS.get_environment("SIM_V") != "": print("   P ", u.data.name, u.cell, " hp", u.hp, " -> ", d.data.name, " hp", d.hp)
		b._handle_kills(u, d)
	else:
		var act = b._action(u)
		if not act.is_empty() and act.kind in ["village", "talk", "crack", "door", "chest", "steal"]:
			b.selected = u; b.moved = true; b._do_open(); return
	_done(b, u)

func _move(b, u: Unit, c: Vector2i) -> void:
	if b._unit_at(c) == null or b._unit_at(c) == u: u.cell = c; u.position = b.grid.cell_to_pos(c)

func _done(b, u: Unit) -> void:
	if not is_instance_valid(u): return
	b.selected = u; b.moved = true; b._finish_unit(u)
