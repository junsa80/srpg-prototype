extends Node
var ok = true
class TitleProbe extends "res://scripts/title.gd":
	var destination = ""
	func _ready() -> void: pass
	func _goto(scene: String) -> void: destination = scene
func chk(value: bool, label: String) -> void:
	if not value: print("FAILAT ", label)
	ok = ok and value
func frames() -> void:
	for i in 4: await get_tree().process_frame
func _ready() -> void:
	Campaign.reset(); Campaign.ensure_roster()
	var title = TitleProbe.new(); add_child(title)
	await frames()
	var before = Campaign.to_dict().duplicate(true); before.erase("playtime")
	title._new_game(); await frames()
	var after = Campaign.to_dict().duplicate(true); after.erase("playtime")
	chk(after == before, "choice-does-not-reset-progress")
	var choice = title.find_child("FirstPlayChoice", true, false)
	for size in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(430, 932)]:
		get_tree().root.size = size; await frames()
		for key in ["GuidedStart", "DirectStart"]:
			var button = choice.find_child(key, true, false)
			chk(title.get_viewport_rect().encloses(button.get_global_rect()), "choice-contained-" + key + str(size))
			chk(button.size.y >= 88, "choice-touch-size")
	choice.find_child("DirectStart", true, false).pressed.emit(); await frames()
	chk(title.destination == "res://scenes/battle.tscn" and Campaign.get_meta("guided_start", true) == false, "direct-start-choice")
	var b = load("res://scenes/battle.tscn").instantiate(); add_child(b); await frames()
	chk(b.first_entry and not is_instance_valid(b.first_guide) and not b.prep_active, "direct-no-guide-no-prep")
	b.queue_free(); await frames()
	title._new_game(); await frames()
	title.find_child("GuidedStart", true, false).pressed.emit(); await frames()
	b = load("res://scenes/battle.tscn").instantiate(); add_child(b); await frames()
	chk(is_instance_valid(b.first_guide), "guided-start")
	var guide = b.first_guide
	for size in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(430, 932)]:
		get_tree().root.size = size; await frames()
		chk(title.get_viewport_rect().encloses(guide.card.get_global_rect()), "guide-contained" + str(size))
		chk(guide.card.get_global_rect().encloses(guide.words.get_global_rect()), "guide-copy-contained")
		chk(guide.portrait.texture != null and guide.companion.texture != null, "both-speakers-illustrated")
	var a = b._unit_named("아린")
	b.tap(a.cell); await frames(); chk(guide.last_key == "move", "real-select-advances-guide")
	await b._move_selected(a.cell + Vector2i(0, -1)); await frames()
	chk(guide.last_key == "wait", "out-of-range-explains-wait")
	b._on_cancel(); await frames(); chk(not b.moved, "cancel-keeps-real-game-controls")
	b.tap(a.cell); await b._move_selected(a.cell)
	var enemy = b.units.filter(func(u): return u.team == 1)[0]
	enemy.cell = a.cell + Vector2i(0, -1)
	b.tap(enemy.cell); await frames(); chk(guide.last_key == "confirm", "real-target-advances-guide")
	guide.stop(); await frames(); chk(not is_instance_valid(b.first_guide) and b.selected == a, "skip-preserves-selection")
	var manual = FirstPlayGuide.manual(b); await frames()
	manual.find_child("RestartGuide", true, false).pressed.emit(); await frames()
	chk(is_instance_valid(b.first_guide), "manual-restarts-guide")
	b.first_guide.attacked = true; b._on_end_turn(); await frames()
	chk(not is_instance_valid(b.first_guide), "completion-cleans-overlay")
	var d = b.dialogue
	d.lines = [["", "마을에 저녁이 내려앉았다."]]; d.idx = 0; d._show()
	chk(not d.port_card.visible and not d.name_plate.visible and d.body.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "narration-distinct")
	d.lines = [["아린", "함께 가요."]]; d._show()
	chk(d.port_card.visible and d.name_plate.visible and d.body.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT, "speaker-illustrated")
	print("FIRSTPLAYTEST ", "PASS" if ok else "FAIL"); get_tree().quit(0 if ok else 1)
