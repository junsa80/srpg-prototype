extends Node
## Campaign mechanics test. Run: godot --headless res://tests/campaign_test.tscn -- --flowtest
var fails = 0
func check(c: bool, m: String) -> void:
	print(("  ok   " if c else "  FAIL ") + m)
	if not c: fails += 1

func _battle(ch: String, recruited = []) -> Node:
	Campaign.reset(); Campaign.chapter = ch; Campaign.recruited = recruited; Campaign.ensure_roster(); Campaign.deploy = []
	var b = load("res://scenes/battle.tscn").instantiate(); add_child(b)
	await get_tree().process_frame
	b.anim_on = false
	return b

func _named(b, n: String):
	for u in b.units:
		if u.data.name == n and u.hp > 0: return u
	return null

func _put(b, u, c: Vector2i) -> void:
	var o = b._unit_at(c)
	if o and o != u: o.cell = Vector2i(-50, -50)
	u.cell = c; u.position = b.grid.cell_to_pos(c)

func _ready() -> void:
	# 1. every map: spawns on walkable tiles, villages/chests on matching terrain
	for ch in ["ch1", "ch2", "ch3", "ch4a", "ch4b", "ch5", "ch6"]:
		var b = await _battle(ch)
		var bad = []
		for u in b.units:
			var t = "wall" if b.grid.walls.has(u.cell) else ("water" if b.grid.water.has(u.cell) else b.grid.terrain.get(u.cell, "plain"))
			if not b.grid.in_bounds(u.cell): t = "out"
			if t in ["wall", "water", "crack", "out"] and not "flying" in u.tags(): bad.append("%s@%s=%s" % [u.data.name, u.cell, t])
		for c in b.MAP.get("villages", {}):
			if b.grid.terrain.get(c, "") != "village": bad.append("village %s" % c)
		check(bad.is_empty(), "%s spawns/villages valid %s (%d units, goal %s)" % [ch, bad, b.units.size(), b.MAP.goal])
		b.queue_free(); await get_tree().process_frame
	# 2. ch3: talk-recruit 가렌, crack, 바르가스 splash
	var b = await _battle("ch3")
	var arin = _named(b, "아린"); var garen = _named(b, "가렌")
	_put(b, arin, garen.cell + Vector2i(1, 0))
	if b.grid.walls.has(arin.cell): _put(b, arin, garen.cell + Vector2i(0, 1))
	check(b._action(arin).get("kind", "") == "talk", "ch3 아린 next to 가렌 -> 대화")
	b.selected = arin; b.moved = true; await b._do_open()
	check(garen.team == 0 and "가렌" in Campaign.recruited, "가렌 recruited by talk")
	var crack = Vector2i(-1, -1)
	for c in b.grid.terrain: if b.grid.terrain[c] == "crack": crack = c
	var noah = _named(b, "노아")
	for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		if b.grid.in_bounds(crack + d) and not b.grid.walls.has(crack + d) and b.grid.terrain.get(crack + d, "") != "crack":
			_put(b, noah, crack + d); break
	check(b._action(noah).get("kind", "") == "crack", "crack wall -> 부수기")
	b.selected = noah; b.moved = true; await b._do_open()
	check(b.grid.terrain.get(crack, "") != "crack", "crack broken (%s)" % b.grid.terrain.get(crack, ""))
	var varg = _named(b, "바르가스"); var lina = _named(b, "리나"); var sera = _named(b, "세라")
	_put(b, lina, varg.cell + Vector2i(0, 1)); _put(b, sera, varg.cell + Vector2i(1, 1))
	var hp0 = sera.hp; lina.hp = 99; lina.stats.hp = 99
	BattleManager.rng.seed = 3
	BattleManager.resolve(varg, lina)
	check(sera.hp < hp0 and sera.hp > 0, "바르가스 area attack splashes adjacent ally (%d->%d), non-lethal" % [hp0, sera.hp])
	b.queue_free(); await get_tree().process_frame
	# 3. ch4a: village visit + defend win
	b = await _battle("ch4a")
	var v = b.MAP.villages.keys()[0]; arin = _named(b, "아린")
	_put(b, arin, v)
	check(b._action(arin).get("kind", "") == "village", "ch4a village -> 방문")
	b.selected = arin; b.moved = true; await b._do_open()
	check(b.grid.terrain.get(v, "") == "village_done" and v in b.visited, "village visited")
	var snap = b._snapshot()
	check(snap.get("state", {}).get("visited", []).size() == 1, "visited saved in snapshot")
	b.tm.turn = int(b.MAP.turns) + 1; b.tm.phase = TurnManager.Phase.PLAYER
	check(b._won(), "defend: surviving %d turns wins" % b.MAP.turns)
	b.queue_free(); await get_tree().process_frame
	# 4. ch4b: NPC death loses
	b = await _battle("ch4b")
	var npc = b.units.filter(func(u): return u.team == 2)[0]
	check(not b._lost(), "ch4b NPC %s alive -> not lost" % npc.data.name)
	npc.hp = 0
	check(b._lost(), "ch4b NPC death -> defeat")
	b.queue_free(); await get_tree().process_frame
	# 5. ch5 seize, ch6 escape
	b = await _battle("ch5", ["가렌", "카이"])
	arin = _named(b, "아린")
	for c in b.grid.terrain: if b.grid.terrain[c] == "throne": _put(b, arin, c)
	b.selected = arin; b.moved = true; await b._do_open()
	check(b.seized and b.ended, "ch5 seize on throne clears chapter")
	check(Campaign.chapter == "ch6", "ch5 -> ch6 (got %s)" % Campaign.chapter)
	b.queue_free(); await get_tree().process_frame
	b = await _battle("ch6", ["가렌", "카이"])
	arin = _named(b, "아린")
	check(Campaign.roster.has("아서"), "아서 joins the roster in ch6")
	for c in b.grid.terrain: if b.grid.terrain[c] == "escape": _put(b, arin, c)
	b.selected = arin; b.moved = true; await b._do_open()
	check("아린" in b.escaped and b.ended and Campaign.chapter == "end", "ch6 escape clears the campaign")
	b.queue_free(); await get_tree().process_frame
	# 6. branch + 훈련
	Campaign.reset(); Campaign.route = "ch4b"; Campaign.record_clear("ch3")
	check(Campaign.chapter == "ch4b", "branch: route ch4b after ch3")
	Campaign.reset(); Campaign.ensure_roster()
	var e0 = Campaign.roster["아린"].get("exp", 0)
	print("   roster ", Campaign.roster.keys(), " exp ", e0)
	var tl = Campaign.record_defeat("ch2", ["아린"])
	print("   after ", Campaign.roster.get("아린", {}).get("exp"))
	check(tl.size() > 0 and Campaign.roster["아린"].get("exp", 0) != e0, "defeat -> 훈련 bonus %s" % [tl])
	Campaign.reset()
	print("CAMPAIGNTEST ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
	get_tree().quit(0 if fails == 0 else 1)
