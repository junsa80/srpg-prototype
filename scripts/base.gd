extends Control
## 거점 (between-chapter base): 상점 / 수송 / 장비 / 출전 / 출격. Touch UI, all state in Campaign.
const PRICES = {"철단검": 300, "강철단검": 500, "철도끼": 270, "강철도끼": 360, "철검": 460, "강철검": 600, "철창": 360, "강철창": 480, "철활": 540, "강철활": 720,
	"파이어": 560, "라이트": 600, "썬더": 700, "힐": 600, "은검": 1500, "은창": 1200, "은활": 1600, "엘파이어": 1200, "멘드": 1000}
## Shop stock is staged (2026-10-15): early = iron/basic tomes & staff; after Ch3 clear = steel + utility; after Ch5 clear = silver/killer/advanced staves.
const BASIC = ["철단검", "철검", "철창", "철도끼", "철활", "파이어", "라이트", "힐"]
const STEEL = ["강철단검", "강철검", "강철창", "강철도끼", "강철활", "썬더"]
const SILVER = ["은검", "은창", "은활", "엘파이어", "멘드", "킬러소드", "킬러랜스", "킬러보우", "해커", "피지오"]
const MID_AFTER = "ch3"; const LATE_AFTER = "ch5"
## Utility weapons: sold from the Ch2 base onward (after Ch1 clear).
const UTILITY = {"투창": 750, "손도끼": 600, "아머킬러": 900, "호스슬레이어": 950, "볼트": 900, "윈드소드": 1100, "해머": 800, "해커": 1200,
	"킬러소드": 1300, "킬러랜스": 1200, "킬러보우": 1400, "피지오": 1500}
## Items: 상처약 always; keys from the Ch2 base on.
const ITEM_PRICES = {"상처약": 300, "문 열쇠": 500, "상자 열쇠": 700}
var body: VBoxContainer; var gold_lbl: Label; var title: Label
var sel_unit = ""
var dialogue: DialogueBox

## 야영 대화: first arrival at the base after a chapter clear.
func _camp() -> void:
	if Campaign.cleared.is_empty(): return
	var last: String = Campaign.cleared.back()
	if last in Campaign.camp_seen or not ChapterData.CAMP.has(last): return
	Campaign.camp_seen.append(last); Campaign.save_campaign()
	if "--flowtest" in OS.get_cmdline_user_args() or "nodialog" in preload("res://scripts/battle.gd").demo_flags(): return
	await dialogue.play(ChapterData.CAMP[last].filter(func(l): return l[0] == "" or Campaign.roster.has(l[0]) or not Roster.UNITS.has(l[0])))

# ---------------- 지원 대화
func _supports() -> void:
	_clear(); Sfx.play("select")
	var open = Campaign.supports_open()
	body.add_child(ItemMenus.label("지원 대화 (%d/%d 해금) — 장을 클리어하면 늘어납니다" % [open.size(), ChapterData.SUPPORTS.size()], 26, Color8(255, 216, 128)))
	for sp in ChapterData.SUPPORTS:
		var ok = sp in open
		var b = ItemMenus.big(("%s · %s — %s%s" % [sp.a, sp.b, sp.title, "  NEW" if ok and not sp.id in Campaign.supports_seen else ""]) if ok else "??? (잠김)", 80, 26)
		b.name = "S_" + sp.id; b.disabled = not ok
		b.pressed.connect(func():
			if not sp.id in Campaign.supports_seen: Campaign.supports_seen.append(sp.id); Campaign.save_campaign()
			await dialogue.play(sp.lines); _supports())
		body.add_child(b)

func _ready() -> void:
	if "ch2" in preload("res://scripts/battle.gd").demo_flags() and Campaign.chapter == "ch1":   # dev: #base+ch2 shows the Ch2 shop
		Campaign.chapter = "ch2"; Campaign.cleared = ["ch1"]; Campaign.gold = 3000
	Campaign.ensure_roster()
	var bg = ColorRect.new(); add_child(bg); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); bg.color = Color8(24, 20, 40)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var v = VBoxContainer.new(); add_child(v); v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 16; v.offset_right = -16; v.offset_top = 16; v.offset_bottom = -16; v.add_theme_constant_override("separation", 10)
	var head = Panel.new(); head.custom_minimum_size.y = 110; head.add_theme_stylebox_override("panel", Ornate.frame()); v.add_child(head)
	title = ItemMenus.label("거점", 34, Color8(248, 216, 112)); title.autowrap_mode = TextServer.AUTOWRAP_OFF; head.add_child(title); title.position = Vector2(20, 10)
	gold_lbl = ItemMenus.label("", 28); gold_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF; head.add_child(gold_lbl); gold_lbl.position = Vector2(20, 62)
	var tabs = GridContainer.new(); tabs.columns = 5; v.add_child(tabs)
	tabs.add_theme_constant_override("h_separation", 8); tabs.add_theme_constant_override("v_separation", 8)
	for t in [["상점", _shop], ["수송", _convoy], ["장비", _equip], ["상태", _status], ["저장", _save], ["지원", _supports], ["설정", func(): Menus.settings(self)],
			["환생", func(): Menus.rebirth_select(self, func(): get_tree().change_scene_to_file("res://scenes/battle.tscn"))],
			["타이틀", func(): Menus.confirm(self, "타이틀로 돌아갈까요?\n(거점 상태는 자동 저장됩니다)", "타이틀로", func(): get_tree().change_scene_to_file("res://scenes/title.tscn"))], ["출격 ▶", _sortie]]:
		var b = ItemMenus.big(t[0], 88, 28); b.name = "T_" + t[0].replace(" ▶", ""); b.pressed.connect(t[1]); tabs.add_child(b)
	var sc = TouchScroll.new(); sc.size_flags_vertical = Control.SIZE_EXPAND_FILL; v.add_child(sc)
	body = VBoxContainer.new(); body.size_flags_horizontal = Control.SIZE_EXPAND_FILL; body.add_theme_constant_override("separation", 8); sc.add_child(body)
	dialogue = DialogueBox.new(); add_child(dialogue)
	_refresh_head(); _shop()
	_camp.call_deferred()
	SaveManager.autosave(Campaign.chapter, 0, {"campaign": Campaign.to_dict(), "battle": {}})
	if not "--flowtest" in OS.get_cmdline_user_args(): Sfx.start_bgm()

func _refresh_head() -> void:
	var nxt = ChapterData.CHAPTERS.get(Campaign.chapter, {}).get("title", Campaign.chapter)
	title.text = "거점 — 다음: " + nxt + (("  " + Campaign.mode_tag()) if Campaign.mode_tag() != "" else "")
	gold_lbl.text = "소지금 %dG   수송대 %d/%d" % [Campaign.gold, Campaign.convoy.size(), Campaign.CONVOY_MAX]

func _clear() -> void:
	for c in body.get_children(): c.name = "old_%d" % c.get_instance_id(); c.queue_free()   # rename so new node names stay unique
	if is_instance_valid(hdr_unit): hdr_unit.queue_free()   # display/convoy unit: changes already recorded
	hdr_unit = null
	_refresh_head()

func _unit(n: String) -> Unit:  # temp unit from roster entry (caller must free)
	return Roster.make_unit(n, 0, Vector2i.ZERO, Campaign.entry(n))

func _save_unit(u: Unit) -> void:
	Campaign.record_progress(u); u.free()

# ---------------- 상점
func _shop() -> void:
	_clear(); Sfx.play("select")
	var row = HBoxContainer.new(); body.add_child(row)
	var p = TextureRect.new(); p.texture = Sprites.portrait("상인"); p.custom_minimum_size = Vector2(96, 96)
	p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; row.add_child(p)
	var line = ItemMenus.label("상인: \"좋은 물건 있을 때 사 가!\"  구입한 무기는 수송대로.", 24, Color8(255, 232, 176))
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(line)
	var u = _unit_header(_shop)
	_filter_toggle(_shop)
	var nxt = ["강철 무기·특수 무기: 3장 클리어 후 입고", "은·킬러 무기, 멘드·피지오: 5장 클리어 후 입고", ""][stage()]
	if nxt != "": body.add_child(ItemMenus.label("다음 입고 — " + nxt, 22, Color8(180, 180, 200)))
	var shown = 0
	for n in stock():
		var w = Weapons.make(n)
		var reason = u.block_reason(w)
		if Settings.usable_only and reason != "": continue
		shown += 1
		var b = ItemMenus.big("%s  %dG\n위력%d 명중%d 치명%d 무게%d 내구%d · %s" % [n, price(n), w.might, w.hit, w.crit, w.weight, w.max_uses, ("× " + reason) if reason != "" else Weapons.effect_text(w)], 96, 22)
		if w.is_item(): b.text = "%s  %dG\n아이템 · %s" % [n, price(n), w.desc]
		if reason != "": b.add_theme_color_override("font_color", Color8(150, 140, 130))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT; Icons.on_button(b, w); b.name = "Buy_" + n
		b.disabled = Campaign.gold < price(n)
		b.pressed.connect(func(): confirm_buy(n))
		body.add_child(b)
	if shown == 0: body.add_child(ItemMenus.label("%s이(가) 쓸 수 있는 물건이 없습니다." % u.data.name, 24))

# ---------------- 선택 유닛 머리글 (초상화 + ◀ ▶ + 좌우 스와이프) — 상점/수송/장비 공용
var hdr_unit: Unit = null
func unit_names() -> Array: return Roster.joined_by(Campaign.chapter)
func cycle_unit(d: int) -> void:
	var ns = unit_names()
	var i = ns.find(sel_unit)
	sel_unit = ns[(maxi(i, 0) + d + ns.size()) % ns.size()] if i >= 0 else ns[0]
	Sfx.play("cursor")
func _unit_header(refresh: Callable) -> Unit:
	if not sel_unit in unit_names(): sel_unit = unit_names()[0]
	var u = _unit(sel_unit); u.visible = false; add_child(u); hdr_unit = u
	var pn = Panel.new(); pn.add_theme_stylebox_override("panel", Ornate.frame()); pn.custom_minimum_size.y = 190; pn.name = "UnitHeader"; body.add_child(pn)
	var h = HBoxContainer.new(); pn.add_child(h); h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 10; h.offset_right = -10; h.offset_top = 10; h.offset_bottom = -10; h.add_theme_constant_override("separation", 10)
	var prev = ItemMenus.big("◀", 96, 36); prev.name = "UPrev"; prev.custom_minimum_size = Vector2(84, 0); prev.size_flags_horizontal = 0; h.add_child(prev)
	var pt = TextureRect.new(); pt.texture = Sprites.portrait(sel_unit) if Sprites.portrait(sel_unit) else Sprites.unit_tex(u)
	pt.custom_minimum_size = Vector2(170, 170); pt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; pt.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; pt.name = "UPortrait"; h.add_child(pt)
	var w = u.weapon() if u.weapon() else u.staff()
	var info = ItemMenus.label("%s\n%s Lv%d\nHP %d  %s\n%s" % [sel_unit, u.unit_class.name, u.level, u.stats.hp, ("장비 " + w.name) if w else "장비 없음", Menus._wtypes(u)], 24)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL; info.name = "UInfo"; h.add_child(info)
	var nx = ItemMenus.big("▶", 96, 36); nx.name = "UNext"; nx.custom_minimum_size = Vector2(84, 0); nx.size_flags_horizontal = 0; h.add_child(nx)
	prev.pressed.connect(func(): cycle_unit(-1); refresh.call())
	nx.pressed.connect(func(): cycle_unit(1); refresh.call())
	var sw = {"x": -1.0}
	pn.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed: sw.x = ev.position.x
			elif sw.x >= 0:
				var dx = ev.position.x - sw.x; sw.x = -1.0
				if absf(dx) > 90: cycle_unit(-1 if dx > 0 else 1); refresh.call())
	return u
func _filter_toggle(refresh: Callable) -> void:
	var b = ItemMenus.big("사용 가능한 것만 보기: " + ("ON" if Settings.usable_only else "OFF"), 64, 24); b.name = "UsableOnly"
	b.pressed.connect(func(): Settings.usable_only = not Settings.usable_only; Settings.save(); Sfx.play("select"); refresh.call())
	body.add_child(b)

## Purchase confirmation: icon, name, price, gold before -> after, 구매/취소.
func confirm_buy(n: String) -> CanvasLayer:
	Sfx.play("select")
	var w = Weapons.make(n); var p = price(n)
	var o = Menus.overlay(self, "구매 확인", 50, 360, 360); var cl: CanvasLayer = o[0]; var v: VBoxContainer = o[1]; cl.name = "BuyConfirm"
	var h = HBoxContainer.new(); h.alignment = BoxContainer.ALIGNMENT_CENTER; h.add_theme_constant_override("separation", 16); v.add_child(h)
	h.add_child(Icons.rect(w, 64))
	var nl = ItemMenus.label("%s\n%s" % [n, Weapons.ITEMS.get(n, {}).get("desc", "") if w.is_item() else Weapons.effect_text(w)], 30, Color8(255, 236, 160)); nl.autowrap_mode = TextServer.AUTOWRAP_OFF; h.add_child(nl)
	var gl = ItemMenus.label("가격 %dG\n소지금 %dG → %dG\n수량 1 (수송대로 보냅니다)" % [p, Campaign.gold, Campaign.gold - p], 28); gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gl.size_flags_vertical = Control.SIZE_EXPAND_FILL; v.add_child(gl)
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 16); v.add_child(row)
	var no = Menus._small("취소", 160); no.name = "BuyNo"; row.add_child(no); no.pressed.connect(func(): Sfx.play("cancel"); cl.queue_free())
	var yes = Menus._small("구매", 160); yes.name = "BuyYes"; row.add_child(yes)
	yes.disabled = Campaign.gold < p
	yes.pressed.connect(func(): cl.queue_free(); buy(n); _shop(); _refresh_head())
	return cl

static func price(n: String) -> int: return PRICES.get(n, UTILITY.get(n, ITEM_PRICES.get(n, 9999)))

static func stage() -> int: return 2 if LATE_AFTER in Campaign.cleared else (1 if MID_AFTER in Campaign.cleared else 0)
func stock() -> Array:
	var out = BASIC.duplicate()
	if stage() >= 1: out.append_array(STEEL); out.append_array(UTILITY.keys().filter(func(n): return not n in SILVER))
	if stage() >= 2: out.append_array(SILVER)
	out.append("상처약")
	if Campaign.chapter != "ch1": out.append_array(["문 열쇠", "상자 열쇠"])
	return out

func buy(n: String) -> bool:
	if not n in stock(): return false
	if Campaign.gold < price(n): return false
	if Campaign.convoy.size() >= Campaign.CONVOY_MAX: return false
	Campaign.gold -= price(n); Campaign.to_convoy(Weapons.make(n)); Sfx.play("levelup"); return true

# ---------------- 수송 (선택 유닛: 맡기기/꺼내기, ◀ ▶ 로 유닛 전환)
func _convoy() -> void:
	_clear(); Sfx.play("select")
	var u = _unit_header(_convoy)
	_filter_toggle(_convoy)
	var list = VBoxContainer.new(); list.add_theme_constant_override("separation", 8); list.name = "ConvoyList"; body.add_child(list)
	ItemMenus._fill_convoy(list, u, func(): Campaign.record_progress(u, true); _refresh_head())

func _find_close(panel: Control) -> Button:
	var bs = panel.find_children("*", "Button", true, false)
	for b in bs:
		if b.text == "닫기": return b
	return bs[-1]

func _unit_buttons(cb: Callable) -> void:
	var g = GridContainer.new(); g.columns = 2; body.add_child(g)
	g.add_theme_constant_override("h_separation", 8); g.add_theme_constant_override("v_separation", 8)
	for n in Roster.joined_by(Campaign.chapter):
		var e = Campaign.entry(n)
		var b = ItemMenus.big("%s  Lv%d %s" % [n, int(e.get("level", 1)), e.get("class", Roster.UNITS[n][0])], 80, 24)
		b.pressed.connect(func(): cb.call(n)); g.add_child(b)

# ---------------- 장비 (equip / trade / promote)
func _equip() -> void:
	_clear(); Sfx.play("select")
	body.add_child(ItemMenus.label("유닛을 선택하세요", 26))
	_unit_buttons(func(n): sel_unit = n; _equip_unit())

func _equip_unit() -> void:
	_clear()
	_unit_header(_equip_unit)
	var u = _unit(sel_unit)
	body.add_child(ItemMenus.label("EXP %d" % u.exp, 24, Color8(160, 200, 255)))
	body.add_child(ItemMenus.label("탭=장착 / [→]=다른 유닛에게 주기", 22, Color8(180, 180, 200)))
	for w in u.inventory:
		var h = HBoxContainer.new(); body.add_child(h)
		var usable = u.can_use(w)
		var b = ItemMenus.weapon_btn(w, u, "▶ " if w == u.weapon() or w == u.staff() and u.weapon() == null else "")
		b.disabled = not usable or w.is_staff()
		var wref = w
		b.pressed.connect(func(): equip_item(sel_unit, u.inventory.find(wref)); _equip_unit())
		h.add_child(b)
		var t = ItemMenus.big("→", 80, 30); t.custom_minimum_size.x = 100; t.size_flags_horizontal = 0
		t.pressed.connect(func(): _trade_pick(u.inventory.find(wref))); h.add_child(t)
	if u.can_promote():
		var pb = ItemMenus.big("전직 (%s)" % " / ".join(Roster.branches(u.unit_class.name)), 90, 30); pb.name = "Promote"
		pb.pressed.connect(func(): _promote_pick(sel_unit)); body.add_child(pb)
	elif u.unit_class.promotes_to != null:
		body.add_child(ItemMenus.label("전직: Lv%d부터 가능 (Lv20 전직 시 성장분 이득)" % ClassCaps.PROMOTE_MIN_LV, 22, Color8(180, 180, 200)))
	var back = ItemMenus.big("← 유닛 목록", 80, 26); back.pressed.connect(_equip); body.add_child(back)
	u.free()

## Promotion branch compare: both classes' bonus, caps, weapons, move, tags.
func _promote_pick(n: String) -> void:
	_clear()
	var u = _unit(n)
	body.add_child(ItemMenus.label("%s Lv%d %s — 전직할 클래스를 고르세요" % [n, u.level, u.unit_class.name], 28))
	if u.level < ClassCaps.MAX_LEVEL: body.add_child(ItemMenus.label("Lv%d에 전직하면 남은 레벨업 %d회분 성장을 잃습니다 (레벨 1로 초기화)." % [u.level, ClassCaps.MAX_LEVEL - u.level], 20, Color8(255, 200, 140)))
	for cn in Roster.branches(u.unit_class.name):
		var c = Roster.cls(cn); var b = PromotionBonuses.for_class(cn); var cp = ClassCaps.caps(cn)
		var bon = []
		for s in Unit.STATS:
			if b.has(s): bon.append("%s+%d" % [Menus.STAT_NAMES[s], b[s]])
		var caps = []
		for s in Unit.STATS: caps.append("%s %d" % [Menus.STAT_NAMES[s], cp.get(s, 0)])
		var tg = ClassProfs.tags(cn).map(func(t): return Weapons.TAG_NAMES.get(t, t))
		var txt = "[%s]  이동 %d%s\n무기: %s\n보너스: %s\n상한: %s" % [cn, c.move + int(b.get("move", 0)), ("  " + " ".join(tg.map(func(t): return "[" + t + "]"))) if not tg.is_empty() else "",
			"·".join(c.weapon_types.map(func(t): return Weapons.TYPE_NAMES.get(int(t), "?"))), ", ".join(bon), " ".join(caps)]
		var bt = ItemMenus.big(txt, 210, 22); bt.name = "Branch_" + cn; bt.alignment = HORIZONTAL_ALIGNMENT_LEFT; bt.autowrap_mode = TextServer.AUTOWRAP_WORD
		bt.pressed.connect(func(): promote(n, cn); _equip_unit()); body.add_child(bt)
	var back = ItemMenus.big("← 취소", 80, 26); back.pressed.connect(_equip_unit); body.add_child(back)
	u.free()

func equip_item(n: String, idx: int) -> void:
	var u = _unit(n)
	if idx >= 0 and idx < u.inventory.size(): u.equip(u.inventory[idx])
	_save_unit(u)

func _trade_pick(idx: int) -> void:
	_clear()
	body.add_child(ItemMenus.label("누구에게 줄까요?", 28))
	_unit_buttons(func(n): trade(sel_unit, idx, n); _equip_unit())

func trade(from_n: String, idx: int, to_n: String) -> bool:
	if from_n == to_n: return false
	var a = _unit(from_n); var b = _unit(to_n)
	var ok = idx >= 0 and idx < a.inventory.size() and b.inventory.size() < Unit.MAX_ITEMS
	if ok:
		var w = a.inventory[idx]; a.inventory.remove_at(idx); b.give(w)
	_save_unit(a); _save_unit(b); return ok

func promote(n: String, alt := "") -> bool:
	var u = _unit(n)
	var ok = u.can_promote()
	if ok: u.promote(alt); Sfx.play("levelup")
	_save_unit(u); return ok

# ---------------- 상태 / 저장
var temp_units: Array = []
func _status() -> void:
	for u in temp_units: if is_instance_valid(u): u.queue_free()
	temp_units = []
	for n in Roster.joined_by(Campaign.chapter):
		var u = _unit(n); u.visible = false; add_child(u); temp_units.append(u)
	Menus.unit_list(self, temp_units, "부대 상태")

func _save() -> void:
	Menus.slots(self, "save", func(): return [Campaign.chapter, 0, {"campaign": Campaign.to_dict(), "battle": {}}])

# ---------------- 출전
func _deploy() -> void:
	_clear(); Sfx.play("select")
	var size = Maps.CH.get(Campaign.chapter, {}).get("deploy_size", 5)
	if Campaign.deploy.size() != size: Campaign.deploy = Maps.CH.get(Campaign.chapter, {}).get("default_deploy", []).duplicate()
	body.add_child(ItemMenus.label("출전 유닛 %d/%d (아린 고정)" % [Campaign.deploy.size(), size], 28))
	for n in Roster.joined_by(Campaign.chapter):
		var on = n in Campaign.deploy
		var b = ItemMenus.big(("● " if on else "○ ") + n, 80, 28)
		b.disabled = n == "아린"
		b.pressed.connect(func():
			if on: Campaign.deploy.erase(n)
			elif Campaign.deploy.size() < size: Campaign.deploy.append(n)
			Campaign.save_campaign(); _deploy())
		body.add_child(b)

func _sortie() -> void:
	if not Maps.CH.has(Campaign.chapter):
		_clear()
		body.add_child(ItemMenus.label("제1부 완결! 축하합니다.\n21장 이후는 준비 중입니다 (To be continued).\n\n[환생]으로 1장부터 다시 시작할 수 있습니다 (표준/강화 선택).", 28))
		var rb = ItemMenus.big("환생 — ★%d 시작" % (Campaign.cycle + 1), 96, 32); rb.name = "Rebirth"; body.add_child(rb)
		rb.pressed.connect(func(): Menus.rebirth_select(self, func(): get_tree().change_scene_to_file("res://scenes/battle.tscn")))
		return
	Campaign.save_campaign(); Campaign.set_meta("from_base", true); Campaign.resume = {}
	get_tree().change_scene_to_file("res://scenes/battle.tscn")
