extends Control
## 거점 (between-chapter base): 상점 / 수송 / 장비 / 출전 / 출격. Touch UI, all state in Campaign.
const PRICES = {"철검": 460, "강철검": 600, "철창": 360, "강철창": 480, "철활": 540, "강철활": 720,
	"파이어": 560, "썬더": 700, "힐": 600, "은검": 1500, "은창": 1200, "은활": 1600, "엘파이어": 1200, "멘드": 1000}
const SILVER = ["은검", "은창", "은활", "엘파이어", "멘드"]  # unlocked after ch2 clear
var body: VBoxContainer; var gold_lbl: Label; var title: Label
var sel_unit = ""

func _ready() -> void:
	Campaign.ensure_roster()
	var bg = ColorRect.new(); add_child(bg); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); bg.color = Color8(24, 20, 40)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var v = VBoxContainer.new(); add_child(v); v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 16; v.offset_right = -16; v.offset_top = 16; v.offset_bottom = -16; v.add_theme_constant_override("separation", 10)
	var head = Panel.new(); head.custom_minimum_size.y = 110; head.add_theme_stylebox_override("panel", Ornate.frame()); v.add_child(head)
	title = ItemMenus.label("거점", 34, Color8(248, 216, 112)); title.autowrap_mode = TextServer.AUTOWRAP_OFF; head.add_child(title); title.position = Vector2(20, 10)
	gold_lbl = ItemMenus.label("", 28); gold_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF; head.add_child(gold_lbl); gold_lbl.position = Vector2(20, 62)
	var tabs = GridContainer.new(); tabs.columns = 4; v.add_child(tabs)
	tabs.add_theme_constant_override("h_separation", 8); tabs.add_theme_constant_override("v_separation", 8)
	for t in [["상점", _shop], ["수송", _convoy], ["장비", _equip], ["상태", _status], ["저장", _save], ["설정", func(): Menus.settings(self)],
			["타이틀", func(): Menus.confirm(self, "타이틀로 돌아갈까요?\n(거점 상태는 자동 저장됩니다)", "타이틀로", func(): get_tree().change_scene_to_file("res://scenes/title.tscn"))], ["출격 ▶", _sortie]]:
		var b = ItemMenus.big(t[0], 88, 28); b.name = "T_" + t[0].replace(" ▶", ""); b.pressed.connect(t[1]); tabs.add_child(b)
	var sc = ScrollContainer.new(); sc.size_flags_vertical = Control.SIZE_EXPAND_FILL; v.add_child(sc)
	body = VBoxContainer.new(); body.size_flags_horizontal = Control.SIZE_EXPAND_FILL; body.add_theme_constant_override("separation", 8); sc.add_child(body)
	_refresh_head(); _shop()
	SaveManager.autosave(Campaign.chapter, 0, {"campaign": Campaign.to_dict(), "battle": {}})
	if not "--flowtest" in OS.get_cmdline_user_args(): Sfx.start_bgm()

func _refresh_head() -> void:
	var nxt = ChapterData.CHAPTERS.get(Campaign.chapter, {}).get("title", Campaign.chapter)
	title.text = "거점 — 다음: " + nxt
	gold_lbl.text = "소지금 %dG   수송대 %d/%d" % [Campaign.gold, Campaign.convoy.size(), Campaign.CONVOY_MAX]

func _clear() -> void:
	for c in body.get_children(): c.queue_free()
	_refresh_head()

func _unit(n: String) -> Unit:  # temp unit from roster entry (caller must free)
	return Roster.make_unit(n, 0, Vector2i.ZERO, Campaign.entry(n))

func _save_unit(u: Unit) -> void:
	Campaign.record_progress(u); u.free()

# ---------------- 상점
func _shop() -> void:
	_clear(); Sfx.play("select")
	var row = HBoxContainer.new(); body.add_child(row)
	var p = TextureRect.new(); p.texture = Sprites.portrait("상인"); p.custom_minimum_size = Vector2(120, 120)
	p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; row.add_child(p)
	var line = ItemMenus.label("상인: \"그림자 놈들 때문에 장사가 말이 아니야. 좋은 물건 있을 때 사 가!\"", 26, Color8(255, 232, 176))
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(line)
	body.add_child(ItemMenus.label("구입한 무기는 수송대로 보냅니다.", 22, Color8(180, 180, 200)))
	for n in PRICES:
		var locked = n in SILVER and not "ch2" in Campaign.cleared
		var w = Weapons.make(n)
		var b = ItemMenus.big("%s   위력%d 명중%d 무게%d 내구%d   %dG%s" % [n, w.might, w.hit, w.weight, w.max_uses, PRICES[n], "  (2장 이후)" if locked else ""], 80, 24)
		b.disabled = locked or Campaign.gold < PRICES[n]
		b.pressed.connect(func(): buy(n); _shop())
		body.add_child(b)

func buy(n: String) -> bool:
	if Campaign.gold < PRICES[n] or (n in SILVER and not "ch2" in Campaign.cleared): return false
	if Campaign.convoy.size() >= Campaign.CONVOY_MAX: return false
	Campaign.gold -= PRICES[n]; Campaign.to_convoy(Weapons.make(n)); Sfx.play("levelup"); return true

# ---------------- 수송 (pick unit, then deposit/withdraw)
func _convoy() -> void:
	_clear(); Sfx.play("select")
	body.add_child(ItemMenus.label("수송대 (%d) — 유닛을 고르면 맡기기/꺼내기" % Campaign.convoy.size(), 26, Color8(255, 216, 128)))
	for it in Campaign.convoy: body.add_child(ItemMenus.label("· " + ItemMenus.dict_str(it), 24))
	_unit_buttons(func(n):
		var u = _unit(n); add_child(u)
		var panel = ItemMenus.convoy_panel(self, u, func(): pass)
		var close_btn: Button = _find_close(panel)
		close_btn.pressed.connect(func(): remove_child(u); _save_unit(u); panel.queue_free(); _convoy()))

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
	var u = _unit(sel_unit)
	body.add_child(ItemMenus.label("%s  Lv%d %s  EXP %d" % [u.data.name, u.level, u.unit_class.name, u.exp], 30, Color8(160, 200, 255)))
	body.add_child(ItemMenus.label("탭=장착 / [→]=다른 유닛에게 주기", 22, Color8(180, 180, 200)))
	for w in u.inventory:
		var h = HBoxContainer.new(); body.add_child(h)
		var usable = u.can_use(w)
		var b = ItemMenus.big(("▶ " if w == u.weapon() or w == u.staff() and u.weapon() == null else "") + ItemMenus.item_str(w) + ("" if usable else "  (사용 불가)"), 80, 24)
		b.disabled = not usable or w.is_staff()
		var wref = w
		b.pressed.connect(func(): equip_item(sel_unit, u.inventory.find(wref)); _equip_unit())
		h.add_child(b)
		var t = ItemMenus.big("→", 80, 30); t.custom_minimum_size.x = 100; t.size_flags_horizontal = 0
		t.pressed.connect(func(): _trade_pick(u.inventory.find(wref))); h.add_child(t)
	if u.can_promote():
		var pb = ItemMenus.big("전직 → %s" % u.unit_class.promotes_to.name, 90, 30)
		pb.pressed.connect(func(): promote(sel_unit); _equip_unit()); body.add_child(pb)
	var back = ItemMenus.big("← 유닛 목록", 80, 26); back.pressed.connect(_equip); body.add_child(back)
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

func promote(n: String) -> bool:
	var u = _unit(n)
	var ok = u.can_promote()
	if ok: u.promote(); Sfx.play("levelup")
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
		_clear(); body.add_child(ItemMenus.label("%s은(는) 아직 준비 중입니다." % ChapterData.CHAPTERS.get(Campaign.chapter, {}).get("title", "다음 장"), 30)); return
	Campaign.save_campaign(); Campaign.set_meta("from_base", true); Campaign.resume = {}
	get_tree().change_scene_to_file("res://scenes/battle.tscn")
