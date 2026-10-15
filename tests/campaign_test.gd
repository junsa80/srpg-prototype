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
	# 7. keys / items / random drops
	b = await _battle("ch2")
	var noah2 = _named(b, "노아"); noah2.inventory = [Weapons.make("철검"), Weapons.make("문 열쇠"), Weapons.make("상자 열쇠")]
	_put(b, noah2, Vector2i(2, 3))
	check(b._action(noah2).get("kind", "") == "door", "non-thief with 문 열쇠 can open door")
	b.selected = noah2; b.moved = true; await b._do_open()
	check(not b.grid.walls.has(Vector2i(2, 2)) and noah2.key_for("door") == null, "door opened, 문 열쇠 consumed")
	noah2.has_acted = false; _put(b, noah2, Vector2i(1, 1))
	check(b._action(noah2).get("kind", "") == "chest", "상자 열쇠 holder standing on chest -> 열기")
	b.selected = noah2; b.moved = true; await b._do_open()
	check(b.chests_got == 1 and noah2.key_for("chest") == null, "chest opened with 상자 열쇠")
	var lina2 = _named(b, "리나"); lina2.inventory.append(Weapons.make("상처약")); lina2.inventory.append(Weapons.make("힘의 반지"))
	lina2.hp = 3; var str0 = lina2.stats.str
	b.use_item(lina2, lina2.items()[0])
	check(lina2.hp == mini(13, lina2.stats.hp) and lina2.items()[0].uses == 2 and lina2.has_acted, "상처약 heals 10, 3 uses -> 2, ends action")
	b.use_item(lina2, lina2.items()[1])
	check(lina2.stats.str == str0 + 2 and lina2.items().size() == 1, "힘의 반지 str +2 and consumed")
	check(lina2.weapon() != null and not lina2.weapon().is_item(), "items never equipped as weapons")
	var foes = b.units.filter(func(u): return u.team == 1 and not u.boss and u.drop == null)
	var e1 = foes[0]
	check(e1.drop_w == 8 and b.drop_text(e1).contains("?8%"), "random drop shown: %s" % b.drop_text(e1).strip_edges())
	var r1 = b.roll(e1, "w"); var r2 = b.roll(e1, "w")
	check(r1 == r2 and r1 >= 0 and r1 < 100, "drop roll deterministic per seed (%d)" % r1)
	var seed0 = Campaign.drop_seed("ch2")
	var snap2 = b.payload()
	e1.drop_w = 100; var got = b.random_drops(e1)
	check(got.size() == 1 and not got[0].is_item(), "100%% weapon drop -> %s" % [got.map(func(w): return w.name)])
	var guard = b.units.filter(func(u): return u.team == 1 and u.guard and u.drop == null)
	check(guard.is_empty() or guard[0].drop_w == 15, "elite/guard drop 15%")
	var boss2 = b.units.filter(func(u): return u.boss)[0]
	check(boss2.drop_w == 0 and boss2.drop != null, "boss: fixed drop only")
	# forecast triangle arrow (sword vs axe)
	var ar = _named(b, "아린"); var axe = b.units.filter(func(u): return u.team == 1 and u.weapon() and u.weapon().type == WeaponData.Type.AXE)[0]
	ar.equip(ar.usable_weapons()[0])
	b._fill_forecast(BattleManager.forecast(ar, axe), ar, axe)
	await get_tree().process_frame
	var tris = b.fc_panel.find_children("Tri", "Label", true, false)
	check(tris.size() == 2 and tris.any(func(l): return l.text == "▲") and tris.any(func(l): return l.text == "▼"), "forecast shows ▲/▼ triangle arrows")
	var tc = Menus.triangle_chart(b.ui); await get_tree().process_frame
	check(tc.name == "TriChart", "상성표 screen opens"); tc.queue_free()
	b.queue_free(); await get_tree().process_frame
	# save/load: same seed restored -> same rolls
	Campaign.from_dict(snap2.campaign)
	check(Campaign.drop_seed("ch2") == seed0, "drop seed persisted in save")
	# 8. 환생 / 완전 초기화 / supports / events
	Campaign.reset(); Campaign.ensure_roster(); Campaign.cleared = ["ch1", "ch2", "ch3"]; Campaign.chapter = "ch3"
	Campaign.recruit("가렌"); Campaign.gold = 1234
	var lv0 = Campaign.roster["아린"].level
	check(Campaign.supports_open().size() >= 4, "supports unlocked: %d" % Campaign.supports_open().size())
	Campaign.chapter = "end"; Campaign.clears = 1
	Campaign.rebirth()
	check(Campaign.cycle == 1 and Campaign.chapter == "ch1" and Campaign.cleared.is_empty() and Campaign.gold == 1234 and Campaign.roster["아린"].level == lv0 and Campaign.roster.has("가렌"), "환생: back to ch1 keeping units/gold, cycle 1")
	Campaign.chapter = "ch3"
	var b3 = load("res://scenes/battle.tscn").instantiate(); add_child(b3); await get_tree().process_frame
	var e3 = b3.units.filter(func(u): return u.data.name == "바르가스")[0]
	check(e3.level == 2 + Campaign.CYCLE_LV and b3.units.filter(func(u): return u.data.name == "가렌" and u.team == 1).is_empty() and "가렌" in b3.ROSTER_NAMES, "cycle 2: enemies Lv+%d, 가렌 not re-spawned as enemy but in party pool" % Campaign.CYCLE_LV)
	b3.queue_free(); await get_tree().process_frame
	Campaign.wipe_all()
	check(Campaign.cycle == 0 and Campaign.clears == 0 and Campaign.roster.is_empty() and SaveManager.latest_slot() < 0, "완전 초기화 wipes everything")
	check(ChapterData.EVENTS.ch1.has(1) and ChapterData.CAMP.has("ch2") and ChapterData.PROLOGUE.size() > 5, "story: prologue/events/camp present")
	Campaign.reset()
	print("CAMPAIGNTEST ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
	get_tree().quit(0 if fails == 0 else 1)
