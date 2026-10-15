extends SceneTree
## Run: godot --headless --script res://tests/skills_test.gd
var fails = []
func chk(name, cond):
	if not cond: fails.append(name)
	print(("OK   " if cond else "FAIL ") + name)

func mk(n: String, wname: String, cell: Vector2i, team = 0, tags = []) -> Unit:
	var c = ClassData.new(); c.name = "용병"
	c.base_stats = {"hp": 30, "str": 8, "mag": 8, "skl": 8, "spd": 8, "lck": 4, "def": 5, "res": 5}
	var d = UnitData.new(); d.name = n; d.unit_class = c; d.weapon = Weapons.make(wname); d.tags = PackedStringArray(tags)
	var u = Unit.new(); u.setup(d, team, cell); return u

func base_pair(an: String, aw = "철검", dn = "적", dw = "철검") -> Array:
	var a = mk(an, aw, Vector2i(0, 0)); var d = mk(dn, dw, Vector2i(1, 0), 1)
	Skills.units = [a, d]; return [a, d]

func _init() -> void:
	var p; var q
	# weapons
	var w = Weapons.make("은검"); chk("은검 stats", w.might == 12 and w.hit == 85 and w.crit == 5 and w.weight == 6 and w.uses == 20)
	chk("힐 heal10 staff", Weapons.make("힐").is_staff() and Weapons.make("힐").heal == 10 and Weapons.make("멘드").heal == 20)
	chk("loadout 시스터", Weapons.loadout("시스터").map(func(x): return x.name) == ["힐", "철단검"])
	chk("loadout 팔라딘", Weapons.loadout("팔라딘").map(func(x): return x.name) == ["철검", "철창"])
	p = base_pair("X"); var u0 = p[0].weapon().uses; BattleManager.resolve(p[0], p[1]); chk("durability decrements", p[0].weapon() == null or p[0].weapon().uses < u0)
	var br = mk("X", "철검", Vector2i(0, 0)); br.weapon().uses = 1; br.use_item(br.weapon()); chk("weapon breaks", br.weapon() == null)
	# AS with weight
	var heavy = mk("X", "강철검", Vector2i(0, 0)); heavy.stats.str = 4; chk("AS weight penalty", BattleManager.attack_speed(heavy) == 8 - 4)
	var mi = mk("미라", "엘파이어", Vector2i(0, 0)); mi.stats.mag = 1; var ot = mk("Y", "엘파이어", Vector2i(0, 0)); ot.stats.mag = 1
	chk("미라 weight -2", BattleManager.attack_speed(mi) == BattleManager.attack_speed(ot) + 2)
	# skills
	var hit_base; var dmg_base
	p = base_pair("X"); hit_base = BattleManager.hit_rate(p[0], p[1]); dmg_base = BattleManager.damage(p[0], p[1])
	p = base_pair("리나"); chk("리나 hit+10", BattleManager.hit_rate(p[0], p[1]) == mini(100, hit_base + 10))
	p = base_pair("카엘"); p[0].flags["moved"] = true; chk("카엘 hit+10 moved", BattleManager.hit_rate(p[0], p[1]) == mini(100, hit_base + 10))
	p = base_pair("리안", "철창", "적", "철창"); q = base_pair("X", "철창", "적", "철창"); chk("리안 lance hit+10", BattleManager.hit_rate(p[0], p[1]) == mini(100, BattleManager.hit_rate(q[0], q[1]) + 10))
	p = base_pair("X", "철검", "카이"); chk("카이 avo+5", BattleManager.hit_rate(p[0], p[1]) == hit_base - 5)
	p = base_pair("X", "철검", "섀도우"); chk("섀도우 avo+5 move+1", BattleManager.hit_rate(p[0], p[1]) == hit_base - 5 and p[1].move_range() == 6)
	p = base_pair("엘런"); chk("엘런 move+1", p[0].move_range() == 6)
	p = base_pair("토르"); chk("토르 +2", BattleManager.damage(p[0], p[1]) == dmg_base + 2)
	p = base_pair("아서"); chk("아서 +2 initiating only", BattleManager.damage(p[0], p[1], true) == dmg_base + 2 and BattleManager.damage(p[0], p[1], false) == dmg_base)
	p = base_pair("루나"); chk("루나 2nd hit +2", BattleManager.damage(p[0], p[1], true, 2) == dmg_base + 2 and BattleManager.damage(p[0], p[1], true, 1) == dmg_base)
	p = base_pair("하론"); chk("하론 ignore 30% def", BattleManager.damage(p[0], p[1]) == 13 - 4)
	p = base_pair("X", "철검", "드레이크"); chk("드레이크 phys -2", BattleManager.damage(p[0], p[1]) == dmg_base - 2)
	p = base_pair("X", "철검", "브렌"); chk("브렌 def+2 melee", BattleManager.damage(p[0], p[1]) == dmg_base - 2)
	p = base_pair("X", "철검", "가렌"); chk("가렌 def+3 spd-1", p[1].eff("def") == 8 and p[1].eff("spd") == 7)
	p = base_pair("세라핀"); chk("세라핀 spd+2", p[0].eff("spd") == 10)
	p = base_pair("엘리아", "파이어"); chk("엘리아 mag+2", p[0].eff("mag") == 10)
	var mb = base_pair("X", "파이어"); var mdmg = BattleManager.damage(mb[0], mb[1])
	p = base_pair("오르린", "파이어"); chk("오르린 res-3", BattleManager.damage(p[0], p[1]) == mdmg + 3)
	p = base_pair("X", "파이어", "루미나"); chk("루미나 magic -2", BattleManager.damage(p[0], p[1]) == mdmg - 2)
	var ai = mk("아이린", "파이어", Vector2i(0, 0)); var dk = mk("적", "철검", Vector2i(1, 0), 1, ["dark"]); Skills.units = [ai, dk]
	chk("아이린 +3 vs dark", BattleManager.damage(ai, dk) == mdmg + 3)
	p = base_pair("마크"); q = base_pair("X"); chk("마크 crit+10", BattleManager.crit_rate(p[0], p[1]) == BattleManager.crit_rate(q[0], q[1]) + 10)
	p = base_pair("루크"); chk("루크 crit+15", BattleManager.crit_rate(p[0], p[1]) == BattleManager.crit_rate(q[0], q[1]) + 15)
	p = base_pair("노아"); chk("노아 crit dmg+3", Skills.crit_dmg_bonus(p[0]) == 3)
	p = base_pair("X", "철검", "니아"); chk("니아 vantage", BattleManager.strike_order(p[0], p[1])[0][0] == p[1])
	p = base_pair("X", "철검", "실라"); p[1].stats.spd = 10; chk("실라 vantage if faster", BattleManager.strike_order(p[0], p[1])[0][0] == p[1])
	p = base_pair("X", "철검", "실라"); chk("실라 no vantage if equal", BattleManager.strike_order(p[0], p[1])[0][0] == p[0])
	p = base_pair("아린"); p[0].stats.spd = 10; chk("아린 extra double order", BattleManager.strike_order(p[0], p[1], true).size() == 3)
	chk("아린 10% / 에일린 15%", Skills.extra_double_chance(p[0]) == 0.1 and Skills.extra_double_chance(mk("에일린", "철검", Vector2i.ZERO)) == 0.15)
	# auras
	var a = mk("X", "철검", Vector2i(0, 0)); var leon = mk("레온", "철검", Vector2i(0, 1)); var gab = mk("가브리엘", "철검", Vector2i(1, 1))
	Skills.units = [a, leon]; chk("레온 adj def+2", a.eff("def") == 7)
	Skills.units = [a, gab]; a.cell = Vector2i(1, 0); chk("가브리엘 adj def+1 res+1", a.eff("def") == 6 and a.eff("res") == 6)
	var e = mk("적", "철검", Vector2i(2, 0), 1); var sel = mk("셀레나", "철검", Vector2i(1, 2))
	Skills.units = [a, e]; var h0 = BattleManager.hit_rate(a, e); var hv0 = BattleManager.hit_rate(e, a)
	Skills.units = [a, e, sel]; chk("셀레나 hit+5 avo+5 within 2", BattleManager.hit_rate(a, e) == mini(100, h0 + 5) and BattleManager.hit_rate(e, a) == hv0 - 5)
	# 리엘 forest
	var g = Grid.new(); g.forest[Vector2i(1, 0)] = true; Skills.grid = g
	p = base_pair("X", "철검", "리엘"); q = base_pair("X", "철검", "Z"); chk("리엘 forest avo+10", BattleManager.hit_rate(q[0], q[1]) - BattleManager.hit_rate(p[0], p[1]) == 10)
	Skills.grid = null; g.free()
	var kz = mk("카이젠", "철검", Vector2i.ZERO); kz.flags["kaizen"] = true; chk("카이젠 res+2", kz.eff("res") == 7)
	# lifesteal & poison deterministic via chance funcs
	chk("아리아 20%", Skills.lifesteal_magic(mk("아리아", "파이어", Vector2i.ZERO)) == 0.2)
	chk("벤 20% poison", Skills.poison_chance(mk("벤", "철검", Vector2i.ZERO)) == 0.2)
	chk("세라 heal 5", Skills.end_turn_heal(mk("세라", "철검", Vector2i.ZERO)) == 5)
	chk("39 skills listed", Skills.LIST.size() == 39)
	# staff heal
	var se = mk("세라", "철검", Vector2i(0, 0)); se.inventory.append(Weapons.make("힐")); var hurt = mk("노아", "철검", Vector2i(0, 1)); hurt.hp = 5
	BattleManager.heal(se, hurt); chk("staff heal = 10 + mag(8)", hurt.hp == 23 and se.staff().uses == 29)
	print("SKILLTEST ", "PASS" if fails.is_empty() else "FAIL " + str(fails))
	quit(0 if fails.is_empty() else 1)
