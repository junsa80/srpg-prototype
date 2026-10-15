class_name RebirthUI extends RefCounted
## 환생 screen: difficulty, perk toggles within the 환생 포인트 budget, and the separate 노가다 모드.
static func open(parent: Node, on_done: Callable) -> CanvasLayer:
	var o = Menus.overlay(parent, "환생 (현재 ★%d)" % Campaign.cycle, 16, 30, 30); var cl: CanvasLayer = o[0]; var v: VBoxContainer = o[1]; cl.name = "RebirthSelect"
	var list = Menus.scroll(v)
	var st = {"o": Campaign.rb_defaults(), "adv": false, "unit_i": 0, "stat_i": 1}
	var units = Campaign.roster.keys()
	var stats = Menus.STAT_NAMES.keys()
	var refill = [null]
	refill[0] = func():
		for c in list.get_children(): c.queue_free()
		var opt: Dictionary = st.o; var pts = Campaign.rb_points(); var cost = Campaign.rb_cost(opt)
		var hd = ItemMenus.label("환생 포인트 %d / %d  (사용 %d)\n장 클리어 1pt, 완결 +%d, 최대 %d · 회차 간 누적 없음" % [pts - cost, pts, cost, Campaign.RB_FULL, Campaign.RB_CAP], 24, Color8(255, 216, 128)); list.add_child(hd); hd.name = "RB_points"
		list.add_child(ItemMenus.label("난이도" + ("" if Campaign.full_clear() else "  (진행 중 환생: 현재 난이도까지)"), 24, Color8(160, 200, 255)))
		var dr = HBoxContainer.new(); list.add_child(dr)
		for i in 3:
			var b = Menus._small(("▶" if opt.diff == i else "") + Campaign.DIFFS[i], 0); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; b.name = "RB_diff%d" % i
			b.disabled = i > Campaign.max_diff(); var ii = i; dr.add_child(b)
			b.pressed.connect(func(): opt.diff = ii; refill[0].call())
		list.add_child(ItemMenus.label("적 Lv +0 / +2 / +4 (매우 어려움은 AI 강화). 상위 난이도는 완결 후 해금", 20, Color8(200, 200, 220)))
		var tog = func(key: String, label: String, c: int):
			var on = opt[key]
			var b = ItemMenus.big("%s %s (%dpt)" % ["■" if on else "□", label, c], 80, 24); b.name = "RB_" + key; list.add_child(b)
			b.disabled = not on and cost + c > pts
			b.pressed.connect(func(): opt[key] = not opt[key]; refill[0].call())
		tog.call("gold", "골드 일부 유지 (30%%, 최대 3000G → %dG)" % mini(3000, Campaign.gold * 30 / 100), Campaign.PERK_COST.gold)
		tog.call("ranks", "무기 랭크 유지 (한 단계 낮춤)", Campaign.PERK_COST.ranks)
		tog.call("supports", "지원 대화 유지", 0)
		list.add_child(ItemMenus.label("특수 무기 유지 (최대 2개, 개당 %dpt)" % Campaign.PERK_COST.weapon, 24, Color8(160, 200, 255)))
		var sp = Campaign.special_owned()
		if sp.is_empty(): list.add_child(ItemMenus.label("  (보유한 특수 무기 없음)", 20, Color8(180, 180, 190)))
		for n in sp:
			var on = n in opt.weapons
			var b = ItemMenus.big("%s %s" % ["■" if on else "□", n], 72, 22); b.name = "RB_w_" + n; Icons.on_button(b, Weapons.make(n)); list.add_child(b)
			b.disabled = not on and (opt.weapons.size() >= 2 or cost + Campaign.PERK_COST.weapon > pts)
			var nn = n
			b.pressed.connect(func():
				if nn in opt.weapons: opt.weapons.erase(nn)
				else: opt.weapons.append(nn)
				refill[0].call())
		list.add_child(ItemMenus.label("시작 아이템 보따리 (1개 선택, %dpt)" % Campaign.PERK_COST.bundle, 24, Color8(160, 200, 255)))
		var br = GridContainer.new(); br.columns = 2; list.add_child(br)
		for k in [""] + Campaign.BUNDLES.keys():
			var on = opt.bundle == k
			var b = Menus._small(("▶" if on else "") + (k if k != "" else "없음"), 0); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; b.name = "RB_b_" + (k if k != "" else "none"); br.add_child(b)
			b.disabled = not on and k != "" and opt.bundle == "" and cost + Campaign.PERK_COST.bundle > pts
			var kk = k
			b.pressed.connect(func(): opt.bundle = kk; refill[0].call())
		var adv = ItemMenus.big("%s 고급 (비추천): 능력치 보너스" % ("■" if st.adv else "□"), 72, 22); adv.name = "RB_adv"; list.add_child(adv)
		adv.add_theme_color_override("font_color", Color8(255, 150, 120))
		adv.pressed.connect(func():
			st.adv = not st.adv
			if not st.adv: opt.stat = {}
			refill[0].call())
		if st.adv:
			list.add_child(ItemMenus.label("! 밸런스를 해칠 수 있습니다. 회차마다 한 유닛의 한 능력치 +1, 유닛당 누적 최대 +%d. 성장률 보너스는 없습니다. (%dpt)" % [Campaign.STAT_CAP, Campaign.PERK_COST.stat], 20, Color8(255, 170, 140)))
			if units.size():
				var un = units[st.unit_i % units.size()]; var sn = stats[st.stat_i % stats.size()]
				var have = 0
				for s in Campaign.rb_bonus.get(un, {}).get("stats", {}): have += int(Campaign.rb_bonus[un].stats[s])
				var r = HBoxContainer.new(); list.add_child(r)
				var bu = Menus._small("유닛: " + un, 0); bu.size_flags_horizontal = Control.SIZE_EXPAND_FILL; bu.name = "RB_unit"; r.add_child(bu)
				bu.pressed.connect(func():
					st.unit_i += 1
					opt.stat = {}
					refill[0].call())
				var bs = Menus._small("능력치: " + Menus.STAT_NAMES[sn], 0); bs.size_flags_horizontal = Control.SIZE_EXPAND_FILL; bs.name = "RB_stat"; r.add_child(bs)
				bs.pressed.connect(func():
					st.stat_i += 1
					opt.stat = {}
					refill[0].call())
				var on = not opt.stat.is_empty()
				var ba = ItemMenus.big("%s %s %s +1 적용 (누적 %d/%d)" % ["■" if on else "□", un, Menus.STAT_NAMES[sn], have, Campaign.STAT_CAP], 72, 22); ba.name = "RB_stat_on"; list.add_child(ba)
				ba.disabled = not on and (have >= Campaign.STAT_CAP or cost + Campaign.PERK_COST.stat > pts)
				ba.pressed.connect(func(): opt.stat = {} if on else {"unit": un, "stat": sn}; refill[0].call())
		var go = ItemMenus.big("환생 시작 — 1장부터", 92, 30); go.name = "RB_go"; list.add_child(go)
		go.pressed.connect(func(): Menus.confirm(parent, "환생할까요?\n진행 중인 장은 사라지고 1장부터 시작합니다.\n(저장 슬롯은 남습니다)", "환생", func():
			if Campaign.rebirth_std(opt): SaveManager.delete_slot(0); cl.queue_free(); on_done.call()))
		list.add_child(ItemMenus.label("— 별도 모드 —", 22, Color8(200, 200, 220)))
		var gr = ItemMenus.big("노가다 모드 환생 (전부 유지, 적 Lv +%d/회)" % Campaign.CYCLE_LV, 80, 22); gr.name = "RB_grind"; list.add_child(gr)
		gr.pressed.connect(func(): Menus.confirm(parent, "노가다 모드로 환생할까요?\n레벨·아이템·골드·동료 전부 유지,\n적 Lv +%d. 저장에 [노가다] 표시." % Campaign.CYCLE_LV, "환생", func(): Campaign.rebirth(); SaveManager.delete_slot(0); cl.queue_free(); on_done.call()))
	refill[0].call()
	Menus.close_btn(v, cl)
	return cl
