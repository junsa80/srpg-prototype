extends Node
## Run: godot --headless res://tests/flow_test.tscn -- --flowtest
func _ready() -> void:
	Campaign.reset()
	var ok = true
	var ch = load("res://scenes/battle.tscn").instantiate(); add_child(ch)
	await get_tree().process_frame
	var aren: Unit = ch._unit_named("아린")
	var enemy: Unit = ch.units.filter(func(u): return u.team == 1)[0]
	aren.exp = 90; aren.cell = enemy.cell + Vector2i(0, 1)
	var lv = aren.level
	BattleManager.resolve(aren, enemy)  # gains EXP (>=1) — 90 + >=10 if hit
	print("aren lv ", lv, "->", aren.level, " exp ", aren.exp, " saved=", Campaign.roster.get("아린"))
	ok = ok and Campaign.roster.has("아린")
	for u in ch.units: if u.team == 0: u.hp = 0
	ch._check_end()
	ok = ok and ch.game_over.visible and Campaign.attempts["ch1"].size() == 1
	print("game over visible: ", ch.game_over.visible, " attempts: ", Campaign.attempts)
	# swap: 노아 -> 카엘
	var lineup = ["아린", "카엘", "리나", "세라", "엘리아"]
	Campaign.deploy = lineup
	ch.queue_free(); await get_tree().process_frame
	var ch2 = load("res://scenes/battle.tscn").instantiate(); add_child(ch2)
	await get_tree().process_frame
	var kael: Unit = ch2._unit_named("카엘"); var a2: Unit = ch2._unit_named("아린")
	print("카엘 awakened=", kael.awakened, " hp=", kael.stats.hp, " | 아린 awakened=", a2.awakened, " lv=", a2.level, " exp=", a2.exp)
	var sera: Unit = ch2._unit_named("세라")
	print("아린 items ", ch2._items_text(a2), " | 세라 items ", ch2._items_text(sera))
	ok = ok and ch2._items_text(a2) == "▶철검 %d/40" % Campaign.roster["아린"].items[0].uses and Campaign.roster["아린"].items[0].uses < 40 and sera.staff() != null
	ok = ok and kael.awakened and kael.stats.hp == 27 and not a2.awakened and a2.exp == Campaign.roster["아린"].exp
	# touch staff flow: tap 세라, tap injured adjacent 카엘, confirm
	kael.hp = 5; kael.cell = sera.cell + Vector2i(0, -1)
	ch2.tap(sera.cell); await ch2._on_confirm(); ch2.tap(kael.cell); var preview = ch2.info.text; await ch2._on_confirm()
	print("heal preview: ", preview.replace("\n", " | "), " -> 카엘 hp ", kael.hp, " 힐 uses ", sera.staff().uses)
	ok = ok and kael.hp == 5 + 10 + sera.eff("mag") and sera.staff().uses == 29 and sera.has_acted
	for u in ch2.units: if u.team == 1: u.hp = 0
	ch2._check_end()
	ok = ok and not Campaign.attempts.has("ch1")
	print("after clear attempts: ", Campaign.attempts)
	ok = ok and Campaign.chapter == "ch2" and Campaign.gold >= 1000 and Campaign.roster.has("에일린") and Campaign.roster.has("레온")
	print("after ch1: chapter=", Campaign.chapter, " gold=", Campaign.gold, " roster=", Campaign.roster.keys())
	ch2.queue_free(); await get_tree().process_frame
	# ---- base: shop / trade / equip / promote
	var base = load("res://scenes/base.tscn").instantiate(); add_child(base); await get_tree().process_frame
	var g0 = Campaign.gold
	ok = ok and base.buy("강철검") and Campaign.gold == g0 - 600 and Campaign.convoy[-1].name == "강철검"
	ok = ok and not base.buy("은검")   # silver locked until ch2 cleared
	print("shop: gold ", g0, "->", Campaign.gold, " convoy ", Campaign.convoy)
	ok = ok and base.trade("세라", 1, "엘리아")  # give 힐 to 엘리아
	print("trade: 엘리아 items ", Campaign.roster["엘리아"].items, " 세라 ", Campaign.roster["세라"].items)
	ok = ok and Campaign.roster["엘리아"].items.size() == 2 and Campaign.roster["세라"].items.size() == 1
	# equip: give 노아 a 강철검 from convoy, equip it
	var noa = Roster.make_unit("노아", 0, Vector2i.ZERO, Campaign.entry("노아")); noa.give(Campaign.from_convoy(Campaign.convoy.size() - 1)); Campaign.record_progress(noa); noa.free()
	base.equip_item("노아", 1)
	ok = ok and Campaign.roster["노아"].items[0].name == "강철검"
	# promote 엘리아 (마법사 -> 세이지): staves + free 힐
	Campaign.roster["엘리아"].level = 10
	ok = ok and base.promote("엘리아")
	var el = Campaign.roster["엘리아"]
	print("promote 엘리아: ", el["class"], " items ", el.items)
	ok = ok and el["class"] == "세이지" and el.items.filter(func(i): return i.name == "힐").size() == 2
	var pal = Roster.make_unit("카엘", 0, Vector2i.ZERO, Campaign.entry("카엘")); pal.level = 10; pal.promote()
	print("promote 카엘: ", pal.unit_class.name, " items ", pal.inventory.map(func(w): return w.name), " sword usable ", pal.can_use(Weapons.make("철검")))
	ok = ok and pal.can_use(Weapons.make("철검")) and pal.can_use(Weapons.make("철창")); pal.free()
	base.queue_free(); await get_tree().process_frame
	# ---- chapter 2
	Campaign.deploy = ["아린", "노아", "리나", "세라", "에일린", "루크"]
	var c2 = load("res://scenes/battle.tscn").instantiate(); add_child(c2); await get_tree().process_frame
	var enemies = c2.units.filter(func(u): return u.team == 1)
	var boss = enemies.filter(func(u): return u.boss)
	print("ch2 map ", c2.grid.size, " enemies ", enemies.size(), " boss ", boss.map(func(b): return b.data.name), " players ", c2.units.filter(func(u): return u.team == 0).map(func(u): return u.data.name))
	ok = ok and c2.CHAPTER == "ch2" and c2.grid.size == Vector2i(12, 20) and enemies.size() == 9 and boss.size() == 1
	ok = ok and c2.grid.terrain_bonus(boss[0].cell) == [2, 20, 20]
	# boss never moves; guard holds
	var plan = EnemyAI.plan(boss[0], c2.units, c2.grid); ok = ok and plan.move_to == boss[0].cell
	var guard = enemies.filter(func(u): return u.guard)[0]; var gp = EnemyAI.plan(guard, c2.units, c2.grid)
	print("boss plan stays=", plan.move_to == boss[0].cell, " guard plan stays=", gp.move_to == guard.cell)
	ok = ok and gp.move_to == guard.cell
	# thief opens door and chest
	var luke: Unit = c2._unit_named("루크")
	luke.cell = Vector2i(3, 2); c2.selected = luke; c2.moved = true
	ok = ok and c2._openable(luke) == Vector2i(2, 2)
	c2._do_open(); ok = ok and not c2.grid.walls.has(Vector2i(2, 2))
	luke.has_acted = false; luke.cell = Vector2i(1, 1); c2.selected = luke; c2.moved = true
	c2._do_open()
	print("chest: luke items ", c2._items_text(luke), " terrain ", c2.grid.terrain.get(Vector2i(1, 1)))
	ok = ok and c2.grid.terrain[Vector2i(1, 1)] == "chest_open" and luke.inventory.any(func(w): return w.name == "강철검")
	# drop: kill archer with drop
	var archer = enemies.filter(func(u): return u.drop != null)[0]; var drop_name = archer.drop.name
	var aren2: Unit = c2._unit_named("아린"); archer.hp = 0
	print("drop: ", c2._handle_kills(aren2, archer), " -> ", c2._items_text(aren2))
	ok = ok and aren2.inventory.any(func(w): return w.name == drop_name)
	# weapon cycle on attack: give 아린 2 swords, target adjacent enemy
	aren2.give(Weapons.make("강철검")); var foe = enemies.filter(func(u): return u.hp > 0 and not u.boss)[0]
	aren2.cell = foe.cell + Vector2i(0, 1); c2.selected = aren2; c2.moved = true; aren2.has_acted = false
	c2.tap(foe.cell); var f1 = c2.info.text; c2._cycle_weapon(); var f2 = c2.info.text
	print("weapon cycle changes forecast: ", f1 != f2, " | ", f2.split("\n")[0])
	ok = ok and f1 != f2 and not c2.btn_weapon.disabled
	c2._clear()
	# reinforcements at turn 5 + warning on turn 4
	c2.tm.turn = 4; c2._update_warnings(); ok = ok and c2.grid.warnings.size() == 2
	c2.tm.turn = 5; var n0 = c2.units.size()
	for u in c2.units: if u.team == 0: u.hp = 999; u.stats.hp = 999
	await c2._run_enemy_phase()
	print("reinforcements: units ", n0, " -> ", c2.units.size())
	ok = ok and c2.units.size() == n0 + 2
	# boss kill = victory
	for b in boss: b.hp = 0
	ok = ok and c2._check_end() and "ch2" in Campaign.cleared
	print("ch2 clear: ", Campaign.cleared, " gold ", Campaign.gold)
	print("FLOWTEST ", "PASS" if ok else "FAIL")
	Campaign.reset()
	get_tree().quit(0 if ok else 1)
