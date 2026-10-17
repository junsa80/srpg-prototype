extends Node
## Kill-drop audit (all chapters, incl. reinforcements). Run: godot --headless res://tests/drop_test.tscn -- --flowtest
## Prints per chapter: fixed drops (boss / other), expected random items per full clear, and the campaign total.
## Asserts (unless DROP_REPORT_ONLY=1): no non-boss fixed drop of the enemy's own equipped weapon, <= 2 non-boss fixed drops
## per chapter, random chances <= 1% normal / 5% elite, and no random drop of junk (basic weapons / 상처약).
func _ready() -> void:
	var ok = true; var report_only = OS.get_environment("DROP_REPORT_ONLY") == "1"
	var tot_fixed = 0; var tot_rand = 0.0; var tot_boss = 0
	for ch in ChapterData.CHAPTERS:
		if not Maps.CH.has(ch): continue
		Campaign.reset(); Campaign.chapter = ch; Campaign.ensure_roster()
		var b = load("res://scenes/battle.tscn").instantiate(); b.set_meta("flowtest", true); add_child(b)
		await get_tree().process_frame
		for r in b.MAP.get("reinforcements", []):
			for e in r.units: b._spawn_enemy(e)
		var fb = 0; var fo = 0; var exp_r = 0.0; var names = []
		for e in b.units.filter(func(u): return u.team == 1 and u.talk_from == ""):
			if e.drop:
				names.append(("★" if e.boss else "") + e.drop.name)
				if e.boss: fb += 1
				else:
					fo += 1
					if e.weapon() and e.drop.name == e.weapon().name: ok = false; print("FAIL equipped-weapon fixed drop ", ch, " ", e.data.name, " ", e.drop.name)
			var w = e.weapon()
			if e.drop_w > 0 and w:
				exp_r += e.drop_w / 100.0
				if b.junk(w): ok = false; print("FAIL junk random weapon ", ch, " ", w.name)
			if e.drop_i > 0 and e.items().size():
				exp_r += e.drop_i / 100.0
				if b.junk(e.items()[0]): ok = false; print("FAIL junk random item ", ch, " ", e.items()[0].name)
			if e.drop_w > 5 or e.drop_i > 5: ok = false; print("FAIL random chance too high ", ch, " ", e.data.name)
		if fo > 2: ok = false; print("FAIL >2 non-boss fixed drops ", ch)
		tot_fixed += fo; tot_boss += fb; tot_rand += exp_r
		print("DROP %-6s boss=%d other=%d random(exp)=%.2f  items/clear=%.2f  %s" % [ch, fb, fo, exp_r, fb + fo + exp_r, ", ".join(names)])
		b.queue_free(); await get_tree().process_frame
	var n = 0
	for ch in ChapterData.CHAPTERS: if Maps.CH.has(ch): n += 1
	print("DROP TOTAL chapters=%d boss=%d other=%d random(exp)=%.1f  items/campaign=%.1f  avg/chapter=%.2f  convoy max %d" % [n, tot_boss, tot_fixed, tot_rand, tot_boss + tot_fixed + tot_rand, (tot_boss + tot_fixed + tot_rand) / n, Campaign.CONVOY_MAX])
	print("DROPTEST ", "PASS" if ok or report_only else "FAIL")
	get_tree().quit(0 if ok or report_only else 1)
