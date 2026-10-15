extends SceneTree
## Run: godot --headless --script res://tests/selftest.gd
func _init() -> void:
	var ok = true
	ok = ok and WeaponData.triangle(0, 2) == 1 and WeaponData.triangle(2, 1) == 1 and WeaponData.triangle(1, 0) == 1 and WeaponData.triangle(0, 1) == -1
	var c = ClassData.new(); var d = UnitData.new(); d.unit_class = c
	var w = WeaponData.new(); d.weapon = w
	var a = Unit.new(); a.setup(d, 0, Vector2i(0, 0))
	var axe = WeaponData.new(); axe.type = WeaponData.Type.AXE
	var d2 = UnitData.new(); d2.unit_class = c; d2.weapon = axe
	var b = Unit.new(); b.setup(d2, 1, Vector2i(1, 0))
	var f = BattleManager.forecast(a, b)
	print("forecast: ", f)
	ok = ok and f.triangle == 1 and f.def_hp_after <= f.def_hp_before
	Unit.fixed_growth = true; var g = a.level_up(); print("fixed lvup: ", g)
	print("2RN true hit for 70: ", BattleManager.true_hit(70))
	var pal = ClassData.new(); pal.name = "팔라딘"; c.promotes_to = pal
	a.level = 10; var hp0 = a.stats.hp; var mv0 = a.move_range(); a.promote()
	print("promote: hp +", a.stats.hp - hp0, " move +", a.move_range() - mv0)
	ok = ok and a.stats.hp - hp0 >= 4 and a.move_range() - mv0 == 1   # >= : promoted minimums may raise more
	# EXP: kill gives > 20, 100 EXP => level up
	var lv0 = b.level; b.exp = 95; var ups = b.gain_exp(10); ok = ok and b.level == lv0 + 1 and b.exp == 5
	ok = ok and BattleManager.exp_for(a, b, true, true) > 20
	# 각성 eligibility
	var C = root.get_node_or_null("Campaign")
	if C:
		C.attempts = {"t": [["아린", "노아"]]}
		ok = ok and C.is_awakened("t", "카엘") and not C.is_awakened("t", "노아") and not C.is_awakened("none", "카엘")
		print("awaken check ok")
	print("SELFTEST ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
