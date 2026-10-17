extends Node
## Run: godot --headless res://tests/menu_test.tscn -- --flowtest
func _ready() -> void:
	var ok = true
	Campaign.reset()
	for i in SaveManager.SLOTS: SaveManager.delete_slot(i)
	Campaign.chapter = "ch2"; Campaign.ensure_roster()
	var ch = load("res://scenes/battle.tscn").instantiate(); add_child(ch); await get_tree().process_frame
	var luke: Unit = null
	ch.deploy_party(["아린", "노아", "리나", "세라", "루크", "카엘"])
	luke = ch._unit_named("루크"); luke.cell = Vector2i(3, 2); ch.selected = luke; ch.moved = true; ch._do_open()
	var aren: Unit = ch._unit_named("아린"); aren.hp = 7; aren.has_acted = true; aren.poison = 2
	var boss = ch.units.filter(func(u): return u.boss)[0]; boss.hp = 11
	ch.tm.turn = 3
	ok = ok and SaveManager.save(2, ch.CHAPTER, ch.tm.turn, ch.payload())
	if not ok and not has_meta("f"): set_meta("f", 1); print("FAILAT 15")
	var m = SaveManager.slot_metadata()[2]
	print("meta ", m)
	ok = ok and m.turn == 3 and m.in_battle and m.chapter_title.begins_with("2장") and m.lead.begins_with("아린 Lv")
	if not ok and not has_meta("f"): set_meta("f", 1); print("FAILAT 18")
	# overwrite + delete
	ok = ok and SaveManager.save(3, ch.CHAPTER, 1, ch.payload()); SaveManager.delete_slot(3); ok = ok and SaveManager.slot_metadata()[3].is_empty()
	if not ok and not has_meta("f"): set_meta("f", 1); print("FAILAT 20")
	ok = ok and not FileAccess.file_exists("user://save_2.json.tmp") and not FileAccess.file_exists("user://save_2.json.bak")
	if not ok and not has_meta("f"): set_meta("f", 1); print("FAILAT 21")
	ch.queue_free(); await get_tree().process_frame
	Campaign.reset()
	var scene = SaveManager.apply(2)
	ok = ok and scene == "res://scenes/battle.tscn" and Campaign.chapter == "ch2"
	if not ok and not has_meta("f"): set_meta("f", 1); print("FAILAT 25")
	var c2 = load(scene).instantiate(); add_child(c2); await get_tree().process_frame
	var a2: Unit = c2._unit_named("아린"); var b2 = c2.units.filter(func(u): return u.boss)[0]
	print("restored turn ", c2.tm.turn, " 아린 hp ", a2.hp, " acted ", a2.has_acted, " poison ", a2.poison, " boss hp ", b2.hp, " door open ", not c2.grid.walls.has(Vector2i(2, 2)), " lineup ", c2.deployed)
	ok = ok and c2.tm.turn == 3 and a2.hp == 7 and a2.has_acted and a2.poison == 2 and b2.hp == 11 and b2.boss and not c2.grid.walls.has(Vector2i(2, 2)) and "카엘" in c2.deployed
	if not ok and not has_meta("f"): set_meta("f", 1); print("FAILAT 29")
	# map tap: empty tile / enemy tile never opens the battle menu; ally select + cancel still works
	c2._clear(); var foe2: Unit = c2.units.filter(func(u): return u.team == 1 and u.hp > 0)[0]
	var empty = Vector2i(-1, -1)
	for y in range(c2.grid.size.y):
		for x in range(c2.grid.size.x):
			var cc = Vector2i(x, y)
			if empty.x < 0 and c2.grid.in_bounds(cc) and not c2.grid.walls.has(cc) and not c2.grid.water.has(cc) and c2._unit_at(cc) == null: empty = cc
	c2.tap(empty); ok = ok and c2.ui.get_node_or_null("BattleMenu") == null and c2.selected == null and c2.terrain_win.visible
	c2.tap(foe2.cell); ok = ok and c2.ui.get_node_or_null("BattleMenu") == null and not c2.grid.highlight_move.is_empty()
	c2.tap(empty); ok = ok and c2.ui.get_node_or_null("BattleMenu") == null and c2.grid.highlight_move.is_empty()
	var free_ally: Unit = c2.units.filter(func(u): return u.team == 0 and u.hp > 0 and not u.has_acted)[0]
	c2.tap(free_ally.cell); ok = ok and c2.selected == free_ally
	c2._on_cancel(); ok = ok and c2.selected == null and c2.ui.get_node_or_null("BattleMenu") == null
	if not ok and not has_meta("f"): set_meta("f", 1); print("FAILAT tap-no-menu")
	# menus build without errors
	c2.open_menu(); ok = ok and c2.ui.get_node_or_null("BattleMenu") != null
	c2.open_status(b2); Menus.unit_list(c2.ui, c2.units); Menus.settings(c2.ui); Menus.slots(c2.ui, "load", null, func(s): pass)
	await get_tree().process_frame
	# settings persistence
	Settings.bgm = 3; Settings.growth_fixed = true; Settings.save(); ok = ok and Unit.fixed_growth
	Settings.growth_fixed = false; Settings.bgm = 7; Settings.save()
	for i in SaveManager.SLOTS: SaveManager.delete_slot(i)
	Campaign.reset()
	print("MENUTEST ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
