extends Node
## Run: godot --headless res://tests/weapons_test.tscn -- --flowtest
var ok = true
func chk(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n); ok = ok and c

func mk(n: String, team: int, w: String, cell: Vector2i) -> Unit:
	var u = Roster.make_unit(n, team, cell); u.inventory = [Weapons.make(w)]; add_child(u); return u

func _ready() -> void:
	Campaign.reset()
	Skills.grid = null; Skills.units = []
	var aren = mk("아린", 0, "철검", Vector2i(0, 0))
	var armor = mk("그림자 중갑병", 1, "철창", Vector2i(0, 1))
	var d0 = BattleManager.damage(aren, armor)
	aren.wexp[0] = 70; aren.inventory = [Weapons.make("아머킬러")]
	chk("아머킬러 usable at C", aren.can_use(aren.inventory[0]))
	var d1 = BattleManager.damage(aren, armor)
	chk("effective = might x3 (%d vs %d)" % [d1, d0], d1 == maxi(0, aren.eff("str") + 8 * 3 + 0 - armor.eff("def") - 1) and BattleManager.is_effective(aren, armor))
	# rank gating
	aren.wexp[0] = 30
	chk("아린 D: 강철검 ok", aren.can_use(Weapons.make("강철검")))
	chk("아린 D: 은검 blocked w/ reason", not aren.can_use(Weapons.make("은검")) and "랭크 부족" in aren.block_reason(Weapons.make("은검")))
	var luke = mk("루크", 0, "철검", Vector2i(3, 3))
	chk("도적 light-only blocks heavy sword", "경량" in luke.block_reason(Weapons.make("아머킬러")) or "랭크" in luke.block_reason(Weapons.make("아머킬러")))
	luke.wexp[0] = 250
	chk("도적 S still can't use 아머킬러 (heavy)", "경량" in luke.block_reason(Weapons.make("아머킬러")))
	chk("도적 can use 레이피어 at C+", luke.can_use(Weapons.make("레이피어")))
	chk("기사 can't use swords", "병종" in mk("카엘", 0, "철창", Vector2i(5, 5)).block_reason(Weapons.make("철검")))
	# rank bonuses
	aren.inventory = [Weapons.make("철검")]
	var foe = mk("그림자 병사", 1, "철도끼", Vector2i(0, 1)); armor.cell = Vector2i(9, 9)
	aren.wexp[0] = 30; var h_d = BattleManager.hit_rate(aren, foe)
	aren.wexp[0] = 70; var h_c = BattleManager.hit_rate(aren, foe)
	aren.wexp[0] = 180; var b_a = BattleManager.bonus(aren)
	chk("rank C +5 hit (%d->%d)" % [h_d, h_c], h_c == mini(100, h_d + 5))
	chk("rank A +2 might +10 hit +5 crit (+용병 hit10)", b_a.might == 2 and b_a.hit == 20 and b_a.crit == 5 and b_a.rank == "A")
	# rank up announcement
	aren.wexp[0] = 68; aren.hp = 99; aren.stats.hp = 99; foe.hp = 99; foe.stats.hp = 99
	var log = BattleManager.resolve(aren, foe)
	chk("rank up D->C announced", BattleManager.rank_ups.size() == 1 and "랭크 C" in BattleManager.rank_ups[0] and aren.rank_letter(0) == "C")
	# brave
	aren.wexp[0] = 180; aren.inventory = [Weapons.make("용사의 검")]
	var f = BattleManager.forecast(aren, foe)
	chk("brave: >=2 strikes (%d)" % f.atk_count, f.atk_count >= 2 and f.atk_count % 2 == 0)
	# magic sword: range 2 uses mag vs res
	var ws = Weapons.make("윈드소드"); chk("윈드소드 1-2 magic", ws.max_range == 2 and ws.magic)
	# light: weight ignored
	luke.inventory = [Weapons.make("레이피어")]; luke.stats.str = 0
	chk("light weapon: no AS penalty", BattleManager.attack_speed(luke) == luke.eff("spd"))
	# bows vs flying
	var rina = mk("리나", 0, "철활", Vector2i(0, 0)); var fly = mk("그림자 비룡", 1, "철창", Vector2i(0, 2))
	chk("bow effective vs flying", BattleManager.is_effective(rina, fly))
	# 특효 display helpers (multiplier constant the formula uses)
	chk("EFF_MULT = 3", BattleManager.EFF_MULT == 3)
	chk("eff_label 철활", Weapons.eff_label(Weapons.make("철활")) == "특효: 비행" and Weapons.eff_label(Weapons.make("철검")) == "")
	chk("weak flying = 활 (%s)" % Weapons.weak_text(["flying"]), Weapons.weak_text(["flying"]) == "활")
	var wa = Weapons.weak_names("armor"); var wc = Weapons.weak_names("cavalry")
	chk("weak armor (%s)" % str(wa), "아머킬러" in wa and "해머" in wa and "볼트" in wa and "레이피어" in wa and "파멸의 도끼" in wa and not "활" in wa)
	chk("weak cavalry (%s)" % str(wc), "호스슬레이어" in wc and "레이피어" in wc and "그림자 창 우르" in wc)
	chk("rina badge = flying", rina.eff_weapon_tags() == ["flying"] and fly.eff_weapon_tags().is_empty())
	# physio range
	chk("피지오 range 1-4", Weapons.make("피지오").max_range == 4)
	# proficiency: 성기사 staff heal +2
	var sera = mk("세라", 0, "힐", Vector2i(1, 1))
	chk("시스터 staff prof +2", BattleManager.heal_amount(sera, sera.inventory[0]) == 10 + sera.eff("mag") + 2)
	# persistence + migration
	Campaign.record_progress(aren, false)
	var js = JSON.parse_string(JSON.stringify(Campaign.to_dict()))
	Campaign.from_dict(js)
	var back = Roster.make_unit("아린", 0, Vector2i.ZERO, Campaign.entry("아린"))
	chk("wexp persisted through JSON (%s)" % str(back.wexp), back.rank_letter(0) == "A")
	var old = Campaign.entry("아린").duplicate(); old.erase("wexp")
	var mig = Roster.make_unit("아린", 0, Vector2i.ZERO, old)
	chk("old save migrates to class start rank D", mig.rank_letter(0) == "D")
	# promotion broadens
	var kael = Roster.make_unit("카엘", 0, Vector2i.ZERO); kael.level = 10; kael.promote("제네럴")
	chk("아머나이트->제네럴: sword rank D, lance C", kael.rank_letter(0) == "D" and kael.rank_letter(1) == "C")
	# icons
	chk("icons per type/tint", Icons.of(Weapons.make("철검")) != Icons.of(Weapons.make("킬러소드")) and Icons.of(Weapons.make("철활")).get_width() == 16)
	var miss = []
	for n in Weapons.LIST:   # every catalog weapon/item has its own drawn 16x16 icon (tools/make_icons.py)
		var p = "res://assets/icons/%s.png" % Icons.icon_id(Weapons.make(n))
		if not ResourceLoader.exists(p) or not Icons.ICON_ID.has(n): miss.append(n)
	chk("drawn icon for every weapon/item " + str(miss), miss.is_empty())
	chk("icon sizes snap to 16x integer", Icons.px_snap(40) == 32 and Icons.px_snap(64) == 64 and Icons.px_snap(24) == 16)
	print("WEAPONTEST ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
