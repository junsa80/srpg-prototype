extends Node
## Drop-rate report: per chapter, eligible enemies and seeded weapon drops (attempt seeds 0..9), before (8/15) vs now.
func _ready() -> void:
	for ch in ["ch1", "ch2", "ch3", "ch4a", "ch4b", "ch5", "ch6"]:
		var tot_old = 0; var tot_new = 0; var n = 0; var exp_old = 0.0; var exp_new = 0.0; var fixed = 0
		for s in 10:
			Campaign.reset(); Campaign.chapter = ch; Campaign.ensure_roster(); Campaign.drop_seeds[ch] = 12345 + s * 7777
			var b = load("res://scenes/battle.tscn").instantiate(); b.set_meta("flowtest", true); add_child(b)
			await get_tree().process_frame
			for e in b.units.filter(func(u): return u.team == 1):
				if e.drop: if s == 0: fixed += 1
				if e.drop_w <= 0: continue
				var elite = e.drop_w >= 12
				var old = 15 if elite else 8
				var r = b.roll(e, "w")
				if s == 0: n += 1; exp_old += old / 100.0; exp_new += e.drop_w / 100.0
				if r < old: tot_old += 1
				if r < e.drop_w: tot_new += 1
			b.queue_free(); await get_tree().process_frame
		print("DROP %s eligible=%d fixed=%d  expected/run old %.2f new %.2f  observed(10 seeds) old %d new %d" % [ch, n, fixed, exp_old, exp_new, tot_old, tot_new])
	get_tree().quit()
