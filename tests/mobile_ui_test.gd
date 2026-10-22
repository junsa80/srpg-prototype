extends Node
## Engine geometry checks, not a substitute for browser touch/visual QA.
var ok = true

func chk(value: bool, tag: String) -> void:
	if not value: print("FAILAT ", tag)
	ok = ok and value

func frames() -> void:
	for i in 4: await get_tree().process_frame

func _ready() -> void:
	Campaign.reset()
	var t = load("res://scenes/title.tscn").instantiate(); add_child(t)
	await frames()
	for size in [Vector2i(360, 640), Vector2i(375, 667), Vector2i(390, 844), Vector2i(430, 932)]:
		get_tree().root.size = size
		await frames()
		var view = t.get_viewport_rect()
		for name in ["Continue", "NewGame", "Load", "Settings", "Records"]:
			var button = t.find_child(name, true, false)
			chk(button != null and view.encloses(button.get_global_rect()), "title-contained-" + name + str(size))
			chk(button.size.y >= 88, "title-touch-height-" + name)
		chk(t.find_child("Wipe", true, false) == null, "destructive-action-outside-main")
	var before = [Campaign.gold, Campaign.chapter, Campaign.roster.duplicate(true), Campaign.cleared.duplicate(), Campaign.cycle]
	t.find_child("Records", true, false).pressed.emit(); await frames()
	var records = t.find_child("TitleRecords", true, false)
	chk(records != null and records.find_child("Wipe", true, false) != null, "records-retains-reset")
	chk([Campaign.gold, Campaign.chapter, Campaign.roster, Campaign.cleared, Campaign.cycle] == before, "opening-records-preserves-progress")
	records.queue_free(); await frames()
	var confirm = Menus.confirm(t, "확인 전까지 기록은 바뀌지 않습니다.\n".repeat(9), "확인", func(): pass)
	await frames()
	var card = confirm.get_child(0).get_child(0)
	var children = confirm.get_meta("v").get_children()
	chk(card.get_global_rect().encloses(children[-1].get_global_rect()), "long-confirm-buttons-contained")
	chk(card.get_global_rect().encloses(children[0].get_global_rect()), "long-confirm-text-contained")
	confirm.queue_free(); t.queue_free(); await frames()
	var b = load("res://scenes/battle.tscn").instantiate(); add_child(b); await frames()
	var allies = b.units.filter(func(u): return u.team == 0)
	var foes = b.units.filter(func(u): return u.team == 1)
	b._fill_forecast(BattleManager.forecast(allies[0], foes[0]), allies[0], foes[0]); await frames()
	b.relayout_forecast([allies[0].cell, foes[0].cell])
	chk(b.fc_panel.get_rect().end.y <= b._view_size().y, "forecast-keeps-command-area-clear")
	var note = b.fc_panel.find_child("FcNote", true, false)
	chk(note.get_theme_font_size("font_size") >= 24, "forecast-note-readable")
	print("forecast rect=", b.fc_panel.get_global_rect(), " note=", note.get_global_rect(), " min=", note.get_minimum_size())
	chk(b.fc_panel.get_global_rect().encloses(note.get_global_rect()), "forecast-note-contained")
	var forecast_content = b.fc_panel.get_child(0)
	print("forecast content=", forecast_content.get_global_rect())
	chk(b.fc_panel.get_global_rect().encloses(forecast_content.get_global_rect()), "forecast-content-contained")
	chk(forecast_content.get_global_rect().end.y <= note.get_global_rect().position.y, "forecast-content-note-separated")
	var prep = PrepScreen.new(); b.add_child(prep); prep.run(b); await frames()
	var start = prep.find_child("P_시작", true, false)
	chk(start != null and b.get_viewport_rect().encloses(start.get_global_rect()), "prep-start-contained")
	chk(prep.panel.offset_bottom == -prep.safe.y, "prep-respects-home-bar")
	print("MOBILEUITEST ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
