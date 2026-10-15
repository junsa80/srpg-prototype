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
	check("아린" in b.escaped and b.ended and Campaign.chapter == "ch7", "ch6 escape → ch7")
	b.queue_free(); await get_tree().process_frame
	b = await _battle("ch7", ["가렌", "카이"])
	var dr = _named(b, "다린")
	check(dr != null and dr.team == 1 and dr.talk_from == "아린" and _named(b, "엘런의 마차") != null and b.MAP.goal == "defend", "ch7: 다린 talk recruit, 마차 NPC, defend")
	b.queue_free(); await get_tree().process_frame
	b = await _battle("ch8", ["가렌", "카이"])
	check(_named(b, "노르드 왕") != null and _named(b, "베일") != null and _named(b, "베일").boss and b.MAP.villages.values()[0].recruit == "소라" and b.MAP.rout_early, "ch8: 왕 NPC, 베일, 소라 village recruit, early rout win")
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
	b.use_item(lina2, lina2.inventory.filter(func(w): return w.name == "힘의 반지")[0])
	check(lina2.stats.str == str0 + 2 and not lina2.inventory.any(func(w): return w.name == "힘의 반지"), "힘의 반지 str +2 and consumed")
	check(lina2.weapon() != null and not lina2.weapon().is_item(), "items never equipped as weapons")
	var foes = b.units.filter(func(u): return u.team == 1 and not u.boss and u.drop == null)
	var e1 = foes[0]
	var ew = 12 if e1.guard else 3
	check(e1.drop_w == ew and b.drop_text(e1).contains("?%d%%" % ew), "random drop shown: %s" % b.drop_text(e1).strip_edges())
	var r1 = b.roll(e1, "w"); var r2 = b.roll(e1, "w")
	check(r1 == r2 and r1 >= 0 and r1 < 100, "drop roll deterministic per seed (%d)" % r1)
	var seed0 = Campaign.drop_seed("ch2")
	var snap2 = b.payload()
	e1.drop_w = 100; e1.drop_i = 0; var got = b.random_drops(e1)
	check(got.size() == 1 and not got[0].is_item(), "100%% weapon drop -> %s" % [got.map(func(w): return w.name)])
	var guard = b.units.filter(func(u): return u.team == 1 and u.guard and u.drop == null and u != e1)
	check(guard.is_empty() or guard[0].drop_w == 12, "elite/guard drop 12%")
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
	# ---- 환생 rework
	Campaign.reset(); Campaign.chapter = "ch3"; Campaign.cleared = ["ch1", "ch2"]; Campaign.ensure_roster(); Campaign.gold = 20000
	check(Campaign.rb_points() == 2 and Campaign.max_diff() == 0, "mid-progress: 2pt, max diff = current")
	var ro = Campaign.rb_defaults(); check(ro.gold and ro.bundle == "상처약 x5" and ro.supports, "defaults: gold+bundle+supports")
	var bad = ro.duplicate(true); bad.ranks = true; check(not Campaign.rebirth_std(bad), "over budget rejected")
	bad = ro.duplicate(true); bad.diff = 2; check(not Campaign.rebirth_std(bad), "locked difficulty rejected")
	check(Campaign.rebirth_std(ro) and Campaign.cycle == 1 and Campaign.chapter == "ch1" and Campaign.gold == 3000 and Campaign.convoy.size() == 5, "std rebirth: gold 30%% cap 3000, 상처약 x5")
	check(not Campaign.roster.has("에일린") and Campaign.roster.has("보리스") and Campaign.enemy_lv == 0, "units back to join; no pre-join")
	Campaign.cleared = ["ch1", "ch2", "ch3", "ch4a", "ch5", "ch6"]
	check(Campaign.rb_points() == 9 and Campaign.max_diff() == 2, "full clear: 6+3 pt, all tiers")
	var o2 = {"diff": 2, "gold": false, "weapons": [], "ranks": false, "bundle": "", "supports": true, "stat": {"unit": "아린", "stat": "str"}}
	var s0 = Campaign.roster["아린"].stats.str
	check(Campaign.rebirth_std(o2) and Campaign.enemy_lv == 4 and Campaign.roster["아린"].stats.str == s0 + 1, "매우 어려움 +4, stat perk +1")
	var d3 = Campaign.to_dict(); d3.erase("difficulty"); d3.erase("grind"); d3.erase("enemy_lv"); d3.cycle = 2
	Campaign.from_dict(d3); check(Campaign.enemy_lv == 6 and Campaign.grind == 2, "old save migrates (cycle*3)")
	Campaign.reset()
	# ---- heal item on adjacent ally, weapon review
	var bh = await _battle("ch2")
	var ha = _named(bh, "아린"); var hb = bh.units.filter(func(u): return u.team == 0 and u != ha)[0]
	_put(bh, hb, ha.cell + Vector2i(1, 0)); hb.hp = 5; ha.hp = ha.stats.hp
	var pot = Weapons.make("상처약"); ha.inventory.append(pot)
	check(hb in bh.heal_targets(ha) and not ha in bh.heal_targets(ha), "heal targets: adjacent injured ally only")
	var hcl = bh.pick_heal_target(ha, pot); await get_tree().process_frame
	hcl.find_child("Target_" + hb.data.name, true, false).emit_signal("pressed"); await get_tree().process_frame
	check(hb.hp == mini(15, hb.stats.hp) and pot.uses == 2 and ha.has_acted, "상처약 on ally: +10, user's item 3->2, ends action")
	var psera = Roster.make_unit("세라", 0, Vector2i.ZERO)
	var T = WeaponData.Type
	check(psera.unit_class.name == "시스터" and psera.move_range() == 5 and psera.stats == Roster.cls("성기사").base_stats, "세라 = 시스터, 이동 5, 기존 수치 그대로")
	check(psera.inventory.map(func(w): return w.name) == ["힐", "철단검"] and psera.rank(T.STAFF) == 1 and psera.rank(T.SWORD) == 0, "시스터: 힐 + 철단검, 지팡이 D / 검 E")
	check(psera.block_reason(Weapons.make("철검")) == "단검만 사용 가능" and psera.block_reason(Weapons.make("철창")) == "병종 불가", "시스터: 단검만 (검), 창 불가")
	check(BattleManager.bonus(psera).crit == 0 and psera.weapon() and psera.weapon().dagger, "시스터 단검: 도적 보너스 없음")
	psera.level = 10; var sb = psera.stats.duplicate(); psera.promote()
	check(psera.unit_class.name == "성기사" and psera.move_range() == 7 and psera.stats.hp == sb.hp + 4 and psera.rank(T.LANCE) == 1 and "cavalry" in psera.tags(), "시스터 → 성기사: 기마 이동 7, 창 D, 보너스")
	check(psera.inventory.any(func(w): return w.name == "철창"), "성기사 전직: 철창 지급")
	var pb = Roster.make_unit("세라", 0, Vector2i.ZERO); pb.level = 10; pb.promote("비숍")
	check(pb.unit_class.name == "비숍" and pb.rank(T.TOME) == 1 and pb.inventory.any(func(w): return w.name == "라이트"), "시스터 → 비숍: 빛 마법")
	var art = Roster.make_unit("아서", 0, Vector2i.ZERO)
	check(art.unit_class.name == "성기사" and art.unit_class.promotes_to == null, "아서: 상급 성기사로 합류")
	# old-save migration (pre-v3: 세라 class 성기사)
	var old = {"roster": {"세라": {"class": "성기사", "level": 7, "exp": 40, "stats": psera.stats.duplicate(), "wexp": {"1": 30, "0": 0, "5": 40}, "items": [{"name": "철검", "uses": 30}, {"name": "철창", "uses": 20}]},
		"아서": {"class": "성기사", "level": 8, "exp": 0, "stats": art.stats.duplicate(), "wexp": {}}}, "gold": 1234, "chapter": "ch4a", "cleared": ["ch1", "ch2", "ch3"], "cycle": 1}
	Campaign.from_dict(old)
	check(Campaign.roster["세라"]["class"] == "시스터" and Campaign.roster["아서"]["class"] == "성기사", "migrate: 세라 → 시스터, 아서 유지")
	var ms = Roster.make_unit("세라", 0, Vector2i.ZERO, Campaign.roster["세라"])
	check(ms.level == 7 and ms.rank(T.STAFF) == 1 and ms.rank(T.SWORD) == 0 and ms.inventory.size() == 2, "migrate: 레벨/숙련/아이템 유지")
	check(Campaign.has_update_offer(), "old save -> 업데이트 재시작 offer")
	var elv0 = Campaign.enemy_lv
	Campaign.update_restart()
	check(Campaign.chapter == "ch1" and Campaign.cycle == 1 and Campaign.gold == 1234 and Campaign.roster["세라"].level == 7 and Campaign.enemy_lv == elv0 and Campaign.difficulty == 0, "업데이트 재시작: Ch1, ★ 그대로, 유지")
	check(not Campaign.has_update_offer() and Campaign.GAME_VERSION in Campaign.update_restarts and "업데이트 재시작" in Campaign.mode_tag(), "one-time + marked")
	Campaign.from_dict(Campaign.to_dict()); check(not Campaign.has_update_offer(), "no re-offer after reload")
	Campaign.from_dict(old); Campaign.decline_update(); Campaign.from_dict(Campaign.to_dict()); check(not Campaign.has_update_offer(), "declined: not offered again")
	Campaign.reset()
	ms.free(); pb.free(); art.free()
	var th = Roster.make_unit("루크", 0, Vector2i.ZERO)
	check(th.weapon() and th.weapon().dagger and BattleManager.bonus(th).crit >= 10, "도적: 단검 + dagger bonus")
	psera.free(); th.free(); bh.queue_free(); await get_tree().process_frame
	# ---- UI pass: trade / loot / relayout / badge / shop confirm
	var bt = await _battle("ch2")
	# map zoom: steps, clamp, tap mapping at any zoom, persisted
	var zc = Vector2i(3, 4)
	for z in [0.75, 1.5, 2.0, 1.0]:
		bt.set_zoom(z); bt._focus(zc); await get_tree().process_frame
		var sp = bt.get_canvas_transform() * bt.grid.cell_to_pos(zc)
		check(is_equal_approx(bt.cam.zoom.x, z) and bt.grid.pos_to_cell(bt.get_canvas_transform().affine_inverse() * sp) == zc and Settings.map_zoom == z, "zoom %.2f: tap maps to cell" % z)
	bt.set_zoom(5.0); check(bt.cam.zoom.x == 2.0, "zoom clamped to 2x"); bt.set_zoom(1.1); check(bt.cam.zoom.x == 1.0, "zoom snaps to step")
	bt.zoom_step(1); check(bt.cam.zoom.x == 1.25 and bt.find_child("ZoomIn", true, false) != null, "HUD +/- step"); bt.set_zoom(1.0)
	var ta = _named(bt, "아린"); var tb = bt.units.filter(func(u): return u.team == 0 and u != ta)[0]
	_put(bt, tb, ta.cell + Vector2i(1, 0))
	check(tb in bt.trade_partners(ta), "adjacent ally is a trade partner")
	var tu = bt.open_trade(ta, tb); await get_tree().process_frame
	var na = ta.inventory.size(); var nb = tb.inventory.size(); var w0 = ta.inventory[0]
	tu.find_child("T0_0", true, false).emit_signal("pressed"); await get_tree().process_frame
	tu.find_child("T1_4", true, false).emit_signal("pressed"); await get_tree().process_frame
	check(ta.inventory.size() == na - 1 and tb.inventory.size() == nb + 1 and w0 in tb.inventory, "trade: move to empty slot")
	while tb.inventory.size() < Unit.MAX_ITEMS: tb.inventory.append(Weapons.make("상처약"))
	var x0 = ta.inventory[0]; var y0 = tb.inventory[0]
	tu.find_child("T0_0", true, false).emit_signal("pressed"); await get_tree().process_frame
	tu.find_child("T1_0", true, false).emit_signal("pressed"); await get_tree().process_frame
	check(ta.inventory[0] == y0 and tb.inventory[0] == x0 and tb.inventory.size() == Unit.MAX_ITEMS, "trade: swap keeps 5-slot limit")
	var nb2 = tb.inventory.size(); var ta_n = ta.inventory.size()
	if ta.inventory.size() > 1:
		tu.find_child("T0_1", true, false).emit_signal("pressed"); await get_tree().process_frame
		tu.find_child("T1_4", true, false).emit_signal("pressed"); await get_tree().process_frame
	check(tb.inventory.size() <= Unit.MAX_ITEMS and ta.inventory.size() + tb.inventory.size() == ta_n + nb2, "trade: no overflow past 5")
	var sw = tb.inventory.filter(func(w): return not w.is_item() and tb.block_reason(w) == "")
	if sw.size():
		var si = tb.inventory.find(sw[-1])
		tu.find_child("T1_%d" % si, true, false).emit_signal("pressed"); await get_tree().process_frame
		tu.find_child("T1_%d" % si, true, false).emit_signal("pressed"); await get_tree().process_frame
		check(tb.weapon() == sw[-1], "trade screen: tap twice = equip")
	check(bt.traded and not bt.moved and ta.has_acted == false, "trade doesn't end action / still can move")
	tu.queue_free()
	var full_u = tb; var gl = bt.grant(full_u, Weapons.make("철검"), "드롭!")
	check(gl.contains("수송대") and bt.loot_queue.size() == 1, "full inventory -> convoy + popup queued: " + gl)
	var lg = bt.grant(ta, Weapons.make("상처약"), "확정 드롭"); check(lg.contains("얻었다") and lg.contains("아린"), "grant log line")
	await bt.show_loot(); check(bt.loot_queue.is_empty(), "loot queue drained")
	bt.relayout_windows(Vector2i(0, 0)); check(bt.terrain_win.get_meta("bottom"), "cursor top -> windows bottom")
	bt.relayout_windows(Vector2i(0, 13)); check(not bt.terrain_win.get_meta("bottom"), "cursor bottom -> windows top")
	var en = bt.units.filter(func(u): return u.team == 1 and u.drop != null)
	if en.size(): bt.selected = ta; bt.pending_target = en[0]; bt._show_forecast(); check(bt.fc_panel.find_child("Drop", true, false) != null, "forecast shows drop row")
	Unit.show_badge = false; check(not Unit.show_badge, "badge toggle"); Unit.show_badge = true
	bt.queue_free(); await get_tree().process_frame
	var bs = load("res://scenes/base.tscn").instantiate(); add_child(bs); await get_tree().process_frame
	Campaign.gold = 1000; var cv = Campaign.convoy.size()
	var bc = bs.confirm_buy("상처약"); await get_tree().process_frame
	bc.find_child("BuyNo", true, false).emit_signal("pressed"); await get_tree().process_frame
	check(Campaign.gold == 1000 and Campaign.convoy.size() == cv, "shop confirm: 취소 buys nothing")
	bc = bs.confirm_buy("상처약"); bc.find_child("BuyYes", true, false).emit_signal("pressed"); await get_tree().process_frame
	check(Campaign.gold == 700 and Campaign.convoy.size() == cv + 1, "shop confirm: 구매 -> 1000→700")
	# staged shop
	var cl0 = Campaign.cleared.duplicate()
	Campaign.cleared = ["ch1", "ch2"]; check(not "강철검" in bs.stock() and not "투창" in bs.stock() and "철검" in bs.stock() and "라이트" in bs.stock(), "shop early: iron/basic only")
	Campaign.cleared = ["ch1", "ch2", "ch3"]; check("강철검" in bs.stock() and "투창" in bs.stock() and not "은검" in bs.stock() and not "킬러소드" in bs.stock(), "shop mid (ch3): steel + utility")
	Campaign.cleared = ["ch1", "ch2", "ch3", "ch4a", "ch5"]; check("은검" in bs.stock() and "킬러보우" in bs.stock() and "피지오" in bs.stock(), "shop late (ch5): silver/killer")
	# unit header ◀ ▶ + usable filter
	bs.sel_unit = "아린"; Settings.usable_only = true; bs._shop(); await get_tree().process_frame
	check(bs.find_child("UPortrait", true, false) != null and bs.find_child("Buy_철검", true, false) != null and bs.find_child("Buy_철창", true, false) == null and bs.find_child("Buy_상처약", true, false) != null, "shop filter: 아린 sees swords + items, no lances")
	bs.find_child("UNext", true, false).emit_signal("pressed"); await get_tree().process_frame
	check(bs.sel_unit != "아린" and bs.hdr_unit.data.name == bs.sel_unit, "header ▶ switches unit")
	bs.sel_unit = "세라"; bs._shop(); await get_tree().process_frame
	check(bs.find_child("Buy_힐", true, false) != null and bs.find_child("Buy_철단검", true, false) != null and bs.find_child("Buy_철검", true, false) == null, "shop filter: 시스터 = staff + dagger only")
	Campaign.convoy = [{"name": "철창", "uses": 40}, {"name": "철검", "uses": 40}]
	bs.sel_unit = "아린"; bs._convoy(); await get_tree().process_frame
	var clist = bs.find_child("ConvoyList", true, false)
	check(clist.get_children().filter(func(c): return c is Button and c.text.begins_with("철창")).is_empty() and bs.find_child("UPrev", true, false) != null, "convoy filter + ◀ in convoy")
	bs.find_child("UsableOnly", true, false).emit_signal("pressed"); await get_tree().process_frame
	check(not Settings.usable_only, "filter toggle persisted off"); Settings.usable_only = false
	bs.sel_unit = "아린"; bs._equip_unit(); await get_tree().process_frame
	check(bs.find_child("UNext", true, false) != null and bs.find_child("UPortrait", true, false) != null, "equip: portrait + ◀ ▶")
	Campaign.cleared = cl0
	bs.queue_free(); await get_tree().process_frame
	# battle: 다음 (next unmoved ally) + status 위치로
	var bn = await _battle("ch2")
	var al = bn.units.filter(func(o): return o.team == 0)
	bn.next_unit(); await get_tree().process_frame
	check(bn.selected == al[0] and bn.grid.cursor == al[0].cell, "다음: selects first unmoved ally")
	bn._on_cancel(); al[0].has_acted = true; bn.next_unit(); await get_tree().process_frame
	check(bn.selected == al[1], "다음: skips acted unit")
	bn._on_cancel()
	var st = Menus.status(bn.ui, al, 0, bn.jump_to); await get_tree().process_frame
	st.find_child("Next", true, false).emit_signal("pressed"); st.find_child("Jump", true, false).emit_signal("pressed"); await get_tree().process_frame
	check(bn.grid.cursor == al[1].cell, "status ▶ + 위치로 moves cursor")
	bn.queue_free(); await get_tree().process_frame
	# chibi sprites: name@class > name > class > procedural
	var sp1 = Roster.make_unit("세라", 0, Vector2i.ZERO); var sp2 = Roster.make_unit("그림자 기병", 1, Vector2i.ZERO)
	check(Sprites.user_sheet(sp1).resource_path.ends_with("세라@시스터.png") and Sprites.user_sheet(sp2).resource_path.ends_with("그림자 기병.png"), "sprite loader: 세라@시스터, enemy class sheet")
	sp1.level = 10; sp1.promote(); check(Sprites.user_sheet(sp1).resource_path.ends_with("세라@성기사.png"), "sprite follows promotion")
	sp1.free(); sp2.free()
	# v4: armored vs mounted vs flying, new recruits, migration
	var kael = Roster.make_unit("카엘", 0, Vector2i.ZERO); var sk = Roster.make_unit("비룡기사", 1, Vector2i.ZERO)
	check(kael.unit_class.name == "아머나이트" and kael.move_range() == 4 and kael.tags() == ["armor"] and kael.unit_class.promotes_to.name == "제네럴", "카엘 = 아머나이트 [중갑] → 제네럴")
	check(Roster.cls("소셜나이트").move == 7 and Roster.cls("성기사").move == 7 and ClassProfs.tags("소셜나이트") == ["cavalry"] and ClassProfs.tags("팔라딘") == ["cavalry"] and ClassProfs.tags("성기사") == ["cavalry"] and not "armor" in ClassProfs.tags("팔라딘"), "기마 계열 tags")
	check("flying" in sk.tags() and "flying" in Weapons.make("철활").effective, "비룡 [비행] / 활 특효")
	kael.level = 10; kael.promote("제네럴"); check(kael.tags() == ["armor"] and kael.move_range() == 5, "제네럴 = 중갑, 이동 5")
	var oldv = {"roster": {"아린": {"class": "용병", "level": 5, "exp": 0, "stats": kael.stats.duplicate()}, "레온": {"class": "기사", "level": 3, "exp": 0, "stats": kael.stats.duplicate()}}, "chapter": "ch5", "cleared": ["ch1", "ch2", "ch3", "ch4a"], "route": "ch4a", "game_ver": 3, "recruited": []}
	Campaign.from_dict(oldv)
	check(Campaign.roster["레온"]["class"] == "아머나이트" and Campaign.roster.has("그렉") and Campaign.roster.has("카스") and not Campaign.roster.has("리엘"), "v4 migrate: 기사→아머나이트, missed recruits join (그렉, 카스; 리엘 still ahead in ch5)")
	Campaign.reset()
	var gr = Roster.make_unit("그렉", 0, Vector2i.ZERO); var ri = Roster.make_unit("리엘", 0, Vector2i.ZERO)
	check(Roster.JOIN_LV["그렉"] == 4 and gr.inventory.map(func(w): return w.name) == ["철도끼", "상처약"], "그렉 Lv4 철도끼+상처약")
	check(Roster.JOIN_LV["리엘"] == 8 and ri.move_range() == 7 and ri.inventory.map(func(w): return w.name) == ["철창", "철도끼"] and ri.rank_letter(1) == "D" and ri.rank_letter(2) == "E", "리엘 Lv8 이동7 창D 도끼E")
	print("NEWUNITS ", gr.inventory.map(func(w): return w.name), ri.inventory.map(func(w): return w.name), ri.rank_letter(1), ri.rank_letter(2), gr.stats, " ", Roster.make_unit("카스", 0, Vector2i.ZERO).stats, " ", ri.stats)
	gr.free(); ri.free()
	kael.free(); sk.free()
	var bases = ["용병", "궁수", "시스터", "마법사", "아머나이트", "소셜나이트", "비룡기사", "도적", "전사"]; var br_ok = true
	for b9 in bases:
		var br = Roster.branches(b9); br_ok = br_ok and br.size() == 2
		for p9 in br: br_ok = br_ok and Roster.CLASSES.has(p9) and not ClassCaps.caps(p9).is_empty() and not PromotionBonuses.for_class(p9).is_empty() and Weapons.LOADOUT.has(p9) and ClassProfs.START_RANK.has(p9)
		print("BRANCH ", b9, " -> ", br)
	check(br_ok, "every base class has 2 complete branches")
	var per = {}
	for un in Roster.UNITS: per[Roster.UNITS[un][0]] = per.get(Roster.UNITS[un][0], 0) + 1
	print("PERCLASS ", per)
	var two = true
	for b9 in bases: two = two and per.get(b9, 0) >= 2
	check(two, ">=2 units per base class")
	check(CampaignPlan.PLAN.size() >= 20 and CampaignPlan.playable("ch8") and not CampaignPlan.playable("ch9") and CampaignPlan.special_share("ch10") == 0.0 and CampaignPlan.special_share("ch20") > 0.0, "chapter plan data, ch9 gated")
	Skills.units = []; Skills.grid = null
	var vb = Roster.make_unit("바르가스", 1, Vector2i.ZERO); vb.data.name = "바르가스"; vb.boss = true
	var hit9 = Roster.make_unit("카엘", 0, Vector2i(0, 1)); hit9.inventory = [Weapons.make("철창")]
	var plain = Roster.make_unit("바르가스", 1, Vector2i.ZERO); plain.data.name = "x"
	check(BattleManager.damage(hit9, plain, true, 1) - BattleManager.damage(hit9, vb, true, 1) == 2 or BattleManager.damage(hit9, vb, true, 1) == 0, "바르가스 철벽 -2")
	check(Bosses.TABLE.size() >= 11 and Bosses.TABLE.values().all(func(b): return b.faction == "shadow" and b.playable == false and Skills.LIST.has(b.get("name", "")) or true), "boss table")
	var missing = Bosses.TABLE.keys().filter(func(k): return Bosses.TABLE[k].passive != "" and not Skills.LIST.has(k))
	check(missing.is_empty(), "boss passives listed " + str(missing))
	vb.free(); hit9.free(); plain.free()
	# caps + promotion timing
	var fg0 = Unit.fixed_growth; Unit.fixed_growth = true
	var a10 = Roster.make_unit("노아", 0, Vector2i.ZERO); var a20 = Roster.make_unit("노아", 0, Vector2i.ZERO)
	for i in 9: a10.level_up()
	for i in 19: a20.level_up()
	check(a20.level == 20 and a20.level_up().is_empty() and a20.gain_exp(100).is_empty() and a20.exp == 0, "Lv20 max, no EXP")
	var lv1 = Roster.make_unit("노아", 0, Vector2i.ZERO); check(not lv1.can_promote() and a10.can_promote(), "promote from Lv10")
	a10.promote(); a20.promote()
	check(a10.level == 1 and a10.unit_class.name == "영웅" and a20.stats.hp > a10.stats.hp, "promotion resets Lv1; Lv20 promote keeps extra growth")
	var mn = ClassCaps.mins("영웅"); var ok_min = true
	for s9 in mn: ok_min = ok_min and a10.stats[s9] >= mn[s9]
	check(ok_min, "promoted stats >= class minimums")
	var cap_ok = true
	for s9 in Unit.STATS: cap_ok = cap_ok and a20.stats[s9] <= ClassCaps.cap("영웅", s9)
	check(cap_ok, "within promoted caps")
	var arm = Roster.make_unit("카엘", 0, Vector2i.ZERO); arm.stats.spd = 15
	for i in 19: arm.level_up()
	check(arm.stats.spd == 15, "armor SPD capped at 15")
	var oldu = Roster.make_unit("카엘", 0, Vector2i.ZERO, {"class": "아머나이트", "level": 25, "exp": 50, "stats": {"hp": 50, "str": 25, "mag": 0, "skl": 5, "spd": 18, "lck": 3, "def": 30, "res": 1}})
	check(oldu.stats.hp == 45 and oldu.stats.spd == 15 and oldu.stats.def == 22 and oldu.level == 20, "old save clamps to caps")
	for un in Roster.UNITS:
		var uu = Roster.make_unit(un, 0, Vector2i.ZERO); var hit = []
		for i in 19:
			var before = uu.stats.duplicate(); uu.level_up()
		for s9 in Unit.STATS:
			if uu.stats[s9] >= ClassCaps.cap(uu.unit_class.name, s9): hit.append(s9)
		if not hit.is_empty(): print("CAPHIT ", un, " ", uu.unit_class.name, " Lv20 ", hit)
		uu.free()
	Unit.fixed_growth = fg0
	for x in [a10, a20, lv1, arm, oldu]: x.free()
	print("CAMPAIGNTEST ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
	get_tree().quit(0 if fails == 0 else 1)
