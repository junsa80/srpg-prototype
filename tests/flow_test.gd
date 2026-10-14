extends Node
## Run: godot --headless res://tests/flow_test.tscn -- --flowtest
func _ready() -> void:
	Campaign.reset()
	var ok = true
	var ch = load("res://scenes/test_chapter.tscn").instantiate(); add_child(ch)
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
	var ch2 = load("res://scenes/test_chapter.tscn").instantiate(); add_child(ch2)
	await get_tree().process_frame
	var kael: Unit = ch2._unit_named("카엘"); var a2: Unit = ch2._unit_named("아린")
	print("카엘 awakened=", kael.awakened, " hp=", kael.stats.hp, " | 아린 awakened=", a2.awakened, " lv=", a2.level, " exp=", a2.exp)
	var sera: Unit = ch2._unit_named("세라")
	print("아린 items ", ch2._items_text(a2), " | 세라 items ", ch2._items_text(sera))
	ok = ok and ch2._items_text(a2) == "철검 %d/40" % Campaign.roster["아린"].items[0].uses and Campaign.roster["아린"].items[0].uses < 40 and sera.staff() != null
	ok = ok and kael.awakened and kael.stats.hp == 27 and not a2.awakened and a2.exp == Campaign.roster["아린"].exp
	# touch staff flow: tap 세라, tap injured adjacent 카엘, confirm
	kael.hp = 5; kael.cell = sera.cell + Vector2i(0, -1)
	ch2.tap(sera.cell); ch2.tap(kael.cell); var preview = ch2.info.text; ch2._on_confirm()
	print("heal preview: ", preview.replace("\n", " | "), " -> 카엘 hp ", kael.hp, " 힐 uses ", sera.staff().uses)
	ok = ok and kael.hp == 5 + 10 + sera.eff("mag") and sera.staff().uses == 29 and sera.has_acted
	for u in ch2.units: if u.team == 1: u.hp = 0
	ch2._check_end()
	ok = ok and not Campaign.attempts.has("ch1")
	print("after clear attempts: ", Campaign.attempts)
	print("FLOWTEST ", "PASS" if ok else "FAIL")
	Campaign.reset()
	get_tree().quit(0 if ok else 1)
