class_name Menus extends RefCounted
## Shared full-screen touch menus (GBA FE style, ornate frames): confirm, settings, save/load slots, unit list, status.
const GOLD = Color8(248, 216, 112)
const TXT = Color8(248, 240, 224)
const DIM = Color8(180, 176, 200)
const STAT_NAMES = {"hp": "HP", "str": "힘", "mag": "마력", "skl": "기술", "spd": "속도", "lck": "행운", "def": "수비", "res": "마방"}
const STAT_CAP = 30
const WT_NAMES = {0: "검", 1: "창", 2: "도끼", 3: "활", 4: "마법", 5: "지팡이"}

## Full-screen overlay on its own CanvasLayer. Returns [layer, card VBox].
static func overlay(parent: Node, title: String, lay = 30, top = 40, bottom = 40) -> Array:
	var cl = CanvasLayer.new(); cl.layer = lay; parent.add_child(cl)
	var dim = ColorRect.new(); cl.add_child(dim); dim.color = Color(0, 0, 0, 0.72); dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card = Panel.new(); dim.add_child(card); card.add_theme_stylebox_override("panel", Ornate.frame())
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); card.offset_left = 18; card.offset_right = -18; var safe = SafeArea.insets(parent.get_viewport()); var available = parent.get_viewport().get_visible_rect().size.y - safe.x - safe.y
	card.offset_top = safe.x + minf(float(top), available * 0.2); card.offset_bottom = -safe.y - minf(float(bottom), available * 0.2)
	var v = VBoxContainer.new(); card.add_child(v); v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 20; v.offset_right = -20; v.offset_top = 18; v.offset_bottom = -18; v.add_theme_constant_override("separation", 12)
	if title != "":
		var t = ItemMenus.label(title, 38, GOLD); t.autowrap_mode = TextServer.AUTOWRAP_OFF; v.add_child(t)
	cl.set_meta("v", v)
	return [cl, v]

static func scroll(v: VBoxContainer) -> VBoxContainer:
	var sc = TouchScroll.new(); sc.size_flags_vertical = Control.SIZE_EXPAND_FILL; sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; v.add_child(sc)
	var list = VBoxContainer.new(); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; list.add_theme_constant_override("separation", 10); sc.add_child(list)
	return list

static func close_btn(v: VBoxContainer, cl: CanvasLayer, on_close = null, text = "닫기") -> Button:
	var b = ItemMenus.big(text, 96, 32); v.add_child(b)
	b.pressed.connect(func():
		Sfx.play("cancel"); cl.queue_free()
		if on_close is Callable and on_close.is_valid(): on_close.call())
	return b

static func confirm(parent: Node, text: String, yes: String, on_yes: Callable, no = "아니요") -> CanvasLayer:
	Sfx.play("select")
	var o = overlay(parent, "", 50, 420, 420); var cl: CanvasLayer = o[0]; var v: VBoxContainer = o[1]
	cl.name = "Confirm"
	var l = ItemMenus.label(text, 32); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; l.size_flags_vertical = Control.SIZE_EXPAND_FILL; v.add_child(l)
	var h = HBoxContainer.new(); h.add_theme_constant_override("separation", 16); v.add_child(h)
	var n = ItemMenus.big(no, 100, 32); n.pressed.connect(func(): Sfx.play("cancel"); cl.queue_free()); h.add_child(n)
	var y = ItemMenus.big(yes, 100, 32); y.pressed.connect(func(): Sfx.play("select"); cl.queue_free(); on_yes.call()); h.add_child(y)
	return cl

static func toast(parent: Node, text: String) -> void:
	var cl = CanvasLayer.new(); cl.layer = 60; parent.add_child(cl)
	var p = Panel.new(); cl.add_child(p); p.add_theme_stylebox_override("panel", Ornate.frame(Color8(40, 32, 64, 250)))
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER); p.offset_left = -260; p.offset_right = 260; p.offset_top = -60; p.offset_bottom = 60
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l = ItemMenus.label(text, 32, GOLD); p.add_child(l); l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if parent.is_inside_tree(): parent.get_tree().create_timer(1.4).timeout.connect(cl.queue_free)

## Horizontal bar.
static func bar(value: float, maxv: float, w = 220.0, h = 18.0, col = Color8(96, 200, 120)) -> Control:
	var c = Control.new(); c.custom_minimum_size = Vector2(w, h); c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bg = ColorRect.new(); c.add_child(bg); bg.color = Color8(16, 12, 28); bg.size = Vector2(w, h)
	var fg = ColorRect.new(); c.add_child(fg); fg.color = col; fg.size = Vector2(w * clampf(value / maxf(maxv, 1), 0, 1), h)
	var hl = ColorRect.new(); c.add_child(hl); hl.color = Color(1, 1, 1, 0.25); hl.size = Vector2(fg.size.x, 3)
	for r in [bg, fg, hl]: r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

# ------------------------------------------------------------------ settings
static func settings(parent: Node, on_close = null) -> CanvasLayer:
	Sfx.play("select")
	var o = overlay(parent, "설정"); var cl: CanvasLayer = o[0]; var v: VBoxContainer = o[1]; cl.name = "Settings"
	var list = scroll(v)
	_fill_settings(list)
	close_btn(v, cl, on_close)
	return cl

static func _row(list: VBoxContainer, name: String) -> HBoxContainer:
	var h = HBoxContainer.new(); h.add_theme_constant_override("separation", 10); h.custom_minimum_size.y = 96; list.add_child(h)
	var l = ItemMenus.label(name, 30); l.custom_minimum_size.x = 200; l.autowrap_mode = TextServer.AUTOWRAP_OFF; l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; h.add_child(l)
	return h

static func _small(t: String, w = 96) -> Button:
	var b = ItemMenus.big(t, 88, 34); b.custom_minimum_size.x = w; b.size_flags_horizontal = 0; return b

static func _fill_settings(list: VBoxContainer) -> void:
	for c in list.get_children(): c.queue_free()
	var refill = func(): Settings.save(); _fill_settings(list)
	for key in [["bgm", "배경음악"], ["sfx", "효과음"]]:
		var k = key[0]; var onk = k + "_on"
		var ht = _row(list, key[1])
		for opt in [[true, "켬"], [false, "끔"]]:
			var tb = _small(("▶" if Settings.get(onk) == opt[0] else "") + opt[1], 0); tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL; var tv = opt[0]; tb.name = k.to_upper() + "_" + opt[1]
			tb.pressed.connect(func(): Settings.set(onk, tv); Settings.save(); Sfx.play("select"); refill.call()); ht.add_child(tb)
		var h = _row(list, "  └ 음량"); h.modulate.a = 1.0 if Settings.get(onk) else 0.5
		var minus = _small("-"); minus.name = k + "_minus"; h.add_child(minus)
		var val = Settings.get(k)
		var mid = VBoxContainer.new(); mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL; mid.alignment = BoxContainer.ALIGNMENT_CENTER; h.add_child(mid)
		var vl = ItemMenus.label("%d / 10" % val, 26, GOLD); vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; mid.add_child(vl)
		var b = bar(val, 10, 180, 16, Color8(120, 176, 255)); b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; mid.add_child(b)
		var plus = _small("+"); plus.name = k + "_plus"; h.add_child(plus)
		minus.pressed.connect(func(): Settings.set(k, maxi(0, Settings.get(k) - 1)); Sfx.play("cursor"); refill.call())
		plus.pressed.connect(func(): Settings.set(k, mini(10, Settings.get(k) + 1)); Sfx.play("cursor"); refill.call())
	var h2 = _row(list, "텍스트 속도")
	for i in Settings.TEXT_SPEEDS.size():
		var b = _small(("▶" if i == Settings.text_speed else "") + Settings.TEXT_SPEEDS[i], 0); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 24); var idx = i
		b.pressed.connect(func(): Settings.text_speed = idx; Sfx.play("select"); refill.call()); h2.add_child(b)
	var h3 = _row(list, "성장 방식")
	for opt in [[false, "랜덤"], [true, "고정"]]:
		var b = _small(("▶" if Settings.growth_fixed == opt[0] else "") + opt[1], 0); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; var val = opt[0]
		b.pressed.connect(func(): Settings.growth_fixed = val; Sfx.play("select"); refill.call()); h3.add_child(b)
	list.add_child(ItemMenus.label("랜덤: 레벨업마다 성장률 확률로 상승 / 고정: 성장률을 누적해 평균값대로 상승", 20, DIM))
	var h4 = _row(list, "전투 연출")
	for opt in [[true, false, "켬"], [true, true, "빠르게"], [false, false, "끔"]]:
		var cur = Settings.anim == opt[0] and (not opt[0] or Settings.anim_fast == opt[1])
		var b = _small(("▶" if cur else "") + opt[2], 0); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; var val = opt[0]; var fast = opt[1]; b.name = "Anim_" + opt[2]
		b.pressed.connect(func(): Settings.anim = val; Settings.anim_fast = fast if val else Settings.anim_fast; Sfx.play("select"); refill.call()); h4.add_child(b)
	list.add_child(ItemMenus.label("켬/빠르게: 전투 장면 재생 (전투 중 화면 터치=빨리 감기, [건너뛰기]) / 끔: 맵에서 바로 결과", 20, DIM))
	var h6 = _row(list, "자동 턴 종료")
	for opt in [[true, "켬"], [false, "끔"]]:
		var b = _small(("▶" if Settings.auto_end == opt[0] else "") + opt[1], 0); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; var val = opt[0]; b.name = "AutoEnd_" + opt[1]
		b.pressed.connect(func(): Settings.auto_end = val; Sfx.play("select"); refill.call()); h6.add_child(b)
	list.add_child(ItemMenus.label("켬: 모든 아군이 행동하면 자동으로 턴 종료 / 끔: [턴 종료]를 직접 누름", 20, DIM))
	var h5 = _row(list, "무기 아이콘")
	for opt in [[true, "표시"], [false, "숨김"]]:
		var b = _small(("▶" if Settings.weapon_badge == opt[0] else "") + opt[1], 0); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; var val = opt[0]; b.name = "Badge_" + opt[1]
		b.pressed.connect(func():
			Settings.weapon_badge = val; Unit.show_badge = val; Settings.save(); Sfx.play("select"); refill.call()
			var tree = Engine.get_main_loop()
			if tree is SceneTree: tree.call_group("units", "queue_redraw"))
		h5.add_child(b)

# ------------------------------------------------------------------ save / load slots
## mode "save": payload_fn() -> [chapter, turn, payload]. mode "load": on_loaded(scene_path).
static func slots(parent: Node, mode: String, payload_fn = null, on_loaded = null, on_close = null) -> CanvasLayer:
	Sfx.play("select")
	var o = overlay(parent, "저장" if mode == "save" else "불러오기"); var cl: CanvasLayer = o[0]; var v: VBoxContainer = o[1]; cl.name = "Slots"
	var list = scroll(v)
	var ctx = {"cl": cl, "list": list, "mode": mode, "payload_fn": payload_fn, "on_loaded": on_loaded, "parent": parent}
	_fill_slots(ctx)
	close_btn(v, cl, on_close)
	return cl

static func _fill_slots(ctx: Dictionary) -> void:
	var list: VBoxContainer = ctx.list
	for c in list.get_children(): c.queue_free()
	list.add_child(ItemMenus.label("자동 저장은 장 시작·매 턴 시작에 기록됩니다." if ctx.mode == "load" else "슬롯을 탭해 저장 (이미 있으면 덮어쓰기 확인)", 22, DIM))
	var meta = SaveManager.slot_metadata()
	for i in SaveManager.SLOTS:
		var m: Dictionary = meta[i]; var slot = i
		var card = PanelContainer.new(); card.add_theme_stylebox_override("panel", Ornate.frame(Color8(30, 26, 52) if not m.is_empty() else Color8(22, 20, 32)))
		list.add_child(card)
		var h = HBoxContainer.new(); h.add_theme_constant_override("separation", 10); card.add_child(h)
		var b = Button.new(); b.flat = true; b.custom_minimum_size = Vector2(0, 150); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.name = "Slot%d" % i; b.alignment = HORIZONTAL_ALIGNMENT_LEFT; b.add_theme_font_size_override("font_size", 24)
		b.add_theme_color_override("font_color", TXT); b.add_theme_color_override("font_disabled_color", Color8(120, 112, 104))
		var head = ("자동 저장" if i == 0 else "슬롯 %d" % i)
		if m.get("corrupt", false):
			b.text = "%s\n  ⚠ 손상된 저장 (읽을 수 없음)\n  삭제 후 다시 저장하세요" % head; b.disabled = true; h.add_child(b)
			var dc = _small("삭제", 110); dc.name = "Del%d" % i; dc.custom_minimum_size.y = 140
			dc.pressed.connect(func(): confirm(ctx.cl, "손상된 %s을(를) 삭제할까요?" % head, "삭제", func(): SaveManager.delete_slot(slot); _fill_slots(ctx)))
			h.add_child(dc); continue
		if m.is_empty(): b.text = "%s\n  — 비어 있음 —" % head
		else:
			b.text = "%s   %s · %s\n  %s   플레이 %s\n  %s" % [head, m.chapter_title, ("턴 %d" % m.turn) if m.in_battle else "거점",
				m.lead, SaveManager.fmt_time(int(m.playtime)), m.timestamp]
			if m.get("recovered", false): b.text += "\n  (원본 손상 → 백업에서 복구됨)"
		h.add_child(b)
		if ctx.mode == "save":
			b.disabled = i == 0
			if i == 0: b.text += "\n  (자동 전용)"
			b.pressed.connect(func():
				if m.is_empty(): _do_save(ctx, slot)
				else: confirm(ctx.cl, "슬롯 %d에 덮어쓸까요?\n(%s)" % [slot, m.chapter_title], "덮어쓰기", func(): _do_save(ctx, slot)))
		else:
			b.disabled = m.is_empty()
			b.pressed.connect(func():
				confirm(ctx.cl, "%s을(를) 불러올까요?\n현재 진행 중인 내용은 사라집니다." % head, "불러오기", func():
					var scene = SaveManager.apply(slot)
					if scene != "": ctx.cl.queue_free(); ctx.on_loaded.call(scene)))
		if not m.is_empty() and i != 0 or (not m.is_empty() and ctx.mode == "load"):
			var d = _small("삭제", 110); d.name = "Del%d" % i; d.custom_minimum_size.y = 140; d.add_theme_font_size_override("font_size", 26)
			d.pressed.connect(func(): confirm(ctx.cl, "%s을(를) 삭제할까요?\n되돌릴 수 없습니다." % head, "삭제", func(): SaveManager.delete_slot(slot); _fill_slots(ctx)))
			h.add_child(d)
		if not m.is_empty():
			var ex = _small("내보\n내기", 110); ex.name = "Exp%d" % i; ex.custom_minimum_size.y = 140; ex.add_theme_font_size_override("font_size", 24)
			ex.pressed.connect(func(): _export_slot(ctx.cl, slot)); h.add_child(ex)
	var imp = ItemMenus.big("저장 코드 가져오기", 92, 30); imp.name = "Import"; list.add_child(imp)
	imp.pressed.connect(func(): _import_dialog(ctx))
	list.add_child(ItemMenus.label("내보내기/가져오기는 이 기기 안에서만 동작합니다 (클라우드 저장 미지원). 코드를 메모장 등에 보관하세요.", 20, DIM))

## Copy a slot's code to the clipboard and, on web, also download it as a .txt file.
static func _export_slot(parent: Node, slot: int) -> void:
	var code = SaveManager.export_text(slot)
	if code == "": toast(parent, "내보낼 수 없습니다"); return
	DisplayServer.clipboard_set(code)
	if OS.has_feature("web"): JavaScriptBridge.download_buffer(code.to_utf8_buffer(), "srpg_save_slot%d.txt" % slot, "text/plain")
	toast(parent, "저장 코드를 복사/다운로드했습니다"); Sfx.play("select")

static func _import_dialog(ctx: Dictionary) -> void:
	var o = overlay(ctx.cl, "저장 코드 가져오기"); var cl: CanvasLayer = o[0]; var v: VBoxContainer = o[1]; cl.name = "ImportSave"
	v.add_child(ItemMenus.label("내보낸 저장 코드를 붙여넣고 넣을 슬롯을 고르세요.", 22, DIM))
	var te = TextEdit.new(); te.name = "Code"; te.custom_minimum_size = Vector2(0, 260); te.add_theme_font_size_override("font_size", 20)
	te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY; v.add_child(te)
	var paste = ItemMenus.big("클립보드에서 붙여넣기", 80, 26); v.add_child(paste)
	paste.pressed.connect(func(): te.text = DisplayServer.clipboard_get())
	var h = HBoxContainer.new(); v.add_child(h)
	for sl in range(1, SaveManager.SLOTS):
		var b = _small("슬롯 %d" % sl, 0); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; b.name = "ImpSlot%d" % sl; h.add_child(b); var k = sl
		b.pressed.connect(func():
			confirm(cl, "슬롯 %d에 덮어쓸까요?" % k, "가져오기", func():
				var err = SaveManager.import_text(k, te.text)
				toast(ctx.cl, "슬롯 %d로 가져왔습니다" % k if err == "" else err); Sfx.play("levelup" if err == "" else "cancel")
				if err == "": cl.queue_free(); _fill_slots(ctx)))
	close_btn(v, cl)

static func _do_save(ctx: Dictionary, slot: int) -> void:
	var p: Array = ctx.payload_fn.call()
	var ok = SaveManager.save(slot, p[0], p[1], p[2])
	toast(ctx.cl, "슬롯 %d에 저장했습니다" % slot if ok else "저장 실패")
	Sfx.play("levelup" if ok else "cancel"); _fill_slots(ctx)

# ------------------------------------------------------------------ unit list
const SORT_MODES = ["기본", "미행동", "HP 위험", "내구도"]
static var list_sort = 0
## Allies first, then enemies; within a team: 0 as given, 1 unacted only (allies), 2 lowest HP% first, 3 lowest weapon uses first.
static func sort_units(arr: Array, mode: int) -> Array:
	var out = arr.duplicate()
	if mode == 1: out = out.filter(func(u): return u.team != 0 or not u.has_acted)
	var key = func(u):
		var w = u.weapon() if u.weapon() else u.staff()
		if mode == 2: return float(u.hp) / maxf(1.0, u.stats.hp)
		if mode == 3: return float(w.uses) if w and w.uses > 0 else 999.0
		return 0.0
	var idx = {}
	for i in out.size(): idx[out[i]] = i
	out.sort_custom(func(a, b):
		if a.team != b.team: return a.team < b.team
		var ka = key.call(a); var kb = key.call(b)
		return ka < kb if ka != kb else idx[a] < idx[b])
	return out
static func unit_list(parent: Node, units: Array, title = "유닛 목록", on_pick = null, on_jump = null) -> CanvasLayer:
	Sfx.play("select")
	var o = overlay(parent, title); var cl: CanvasLayer = o[0]; var v: VBoxContainer = o[1]; cl.name = "UnitList"
	var srt = HBoxContainer.new(); srt.name = "Sort"; v.add_child(srt); v.move_child(srt, 1)
	for m in SORT_MODES.size():
		var sb = _small(("▶" if m == list_sort else "") + SORT_MODES[m], 0); sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL; sb.name = "Sort%d" % m
		sb.add_theme_font_size_override("font_size", 22); var mm = m
		sb.pressed.connect(func(): list_sort = mm; cl.queue_free(); unit_list(parent, units, title, on_pick, on_jump)); srt.add_child(sb)
	var list = scroll(v)
	var alive = sort_units(units.filter(func(u): return u.hp > 0), list_sort)
	var last_team = -1
	for i in alive.size():
		var u: Unit = alive[i]
		if u.team != last_team:
			last_team = u.team; list.add_child(ItemMenus.label("— 아군 —" if u.team == 0 else "— 적군 —", 26, Color8(120, 176, 255) if u.team == 0 else Color8(255, 110, 110)))
		var b = Ornate.button(Button.new(), Color8(216, 176, 72) if u.team == 0 else Color8(200, 72, 72)); b.custom_minimum_size = Vector2(0, 104)
		b.name = "U_" + u.data.name; list.add_child(b)
		var h = HBoxContainer.new(); b.add_child(h); h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); h.offset_left = 12; h.offset_right = -12
		h.add_theme_constant_override("separation", 12); h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic = TextureRect.new(); ic.texture = Sprites.unit_tex(u); ic.custom_minimum_size = Vector2(72, 72); ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER; h.add_child(ic)
		var w = u.weapon() if u.weapon() else u.staff()
		var nm = ItemMenus.label("%s %s\n%s Lv%d" % [u.data.name, tag_text(u), u.unit_class.name, u.level], 22); nm.custom_minimum_size.x = 170; nm.autowrap_mode = TextServer.AUTOWRAP_OFF
		nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; h.add_child(nm)
		var wv = VBoxContainer.new(); wv.alignment = BoxContainer.ALIGNMENT_CENTER; wv.custom_minimum_size.x = 110; h.add_child(wv)
		if w: wv.add_child(Icons.rect(w, 32))
		var wl = ItemMenus.label(w.name if w else "-", 18); wl.autowrap_mode = TextServer.AUTOWRAP_OFF; wv.add_child(wl)
		for c in [wv] + wv.get_children(): c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var hv = VBoxContainer.new(); hv.alignment = BoxContainer.ALIGNMENT_CENTER; hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(hv)
		hv.add_child(ItemMenus.label("HP %d/%d  %s" % [u.hp, u.stats.hp, status_text(u, true)], 22, TXT))
		hv.add_child(bar(u.hp, u.stats.hp, 250, 14, _hp_col(u)))
		for c in [ic, nm, hv] + hv.get_children(): c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var idx = i
		b.pressed.connect(func():
			if on_pick is Callable: on_pick.call(u)
			status(cl, alive, idx, on_jump))
	close_btn(v, cl)
	return cl

static func _hp_col(u: Unit) -> Color:
	var r = float(u.hp) / maxf(u.stats.hp, 1)
	return Color8(96, 208, 120) if r > 0.5 else (Color8(240, 200, 64) if r > 0.25 else Color8(232, 72, 64))

## 환생 select (title / base / battle) -> RebirthUI.
static func rebirth_select(parent: Node, on_done: Callable) -> CanvasLayer: return RebirthUI.open(parent, on_done)

## [중갑] [기마] [비행] labels + what is effective against each.
## (약점 문구는 Weapons.weak_text — 무기 데이터에서 생성)
static func tag_text(u: Unit) -> String: return " ".join(u.tags().map(func(t): return "[%s]" % Weapons.TAG_NAMES.get(t, t)))

static func status_text(u: Unit, short = false) -> String:
	var s = []
	if u.awakened: s.append("각성" if short else "각성 (전 스탯+2, HP+5, 이번 장 한정)")
	if u.poison > 0: s.append("독 %d턴" % u.poison if short else "독 (턴 시작 HP-3, 남은 %d턴)" % u.poison)
	if u.has_acted and u.team == 0: s.append("행동 완료")
	if u.boss: s.append("보스")
	if u.team == 0 and not short and Campaign.carry_text(u.data.name) != "": s.append(Campaign.carry_text(u.data.name))
	if u.guard: s.append("경계" if short else "경계 (사거리 안에 들어오면 공격)")
	if u.team == 1:
		if u.drop: s.append("★드롭 %s" % u.drop.name)
		if u.drop_w > 0 and u.weapon(): s.append("드롭 %d%%" % u.drop_w if short else "드롭 ? %s %d%%" % [u.weapon().name, u.drop_w])
		if u.drop_i > 0 and u.items().size(): s.append("" if short else "드롭 ? %s %d%%" % [u.items()[0].name, u.drop_i])
	s = s.filter(func(x): return x != "")
	return " · ".join(s) if s.size() else ("" if short else "이상 없음")

# ------------------------------------------------------------------ status screen
## units: list to cycle through with ◀ ▶; idx = shown.
static func status(parent: Node, units: Array, idx: int, on_jump = null) -> CanvasLayer:
	Sfx.play("select")
	var o = overlay(parent, "", 40, 24, 24); var cl: CanvasLayer = o[0]; var v: VBoxContainer = o[1]; cl.name = "Status"
	var body = scroll(v); body.add_theme_constant_override("separation", 10)
	var ctx = {"units": units, "idx": idx, "body": body}
	_fill_status(ctx)
	var h = HBoxContainer.new(); h.add_theme_constant_override("separation", 12); v.add_child(h)
	var prev = ItemMenus.big("◀", 96, 34); var nxt = ItemMenus.big("▶", 96, 34); prev.name = "Prev"; nxt.name = "Next"
	prev.disabled = units.size() < 2; nxt.disabled = units.size() < 2
	prev.pressed.connect(func(): ctx.idx = (ctx.idx - 1 + units.size()) % units.size(); Sfx.play("cursor"); _fill_status(ctx))
	nxt.pressed.connect(func(): ctx.idx = (ctx.idx + 1) % units.size(); Sfx.play("cursor"); _fill_status(ctx))
	h.add_child(prev)
	if on_jump is Callable:   # battle: close everything and move the camera/cursor to the shown unit
		var j = ItemMenus.big("위치로", 96, 30); j.name = "Jump"; h.add_child(j)
		j.pressed.connect(func(): Sfx.play("select"); on_jump.call(ctx.units[ctx.idx]); cl.queue_free())
	var c = ItemMenus.big("닫기", 96, 32); c.pressed.connect(func(): Sfx.play("cancel"); cl.queue_free()); h.add_child(c)
	h.add_child(nxt)
	return cl

static func _fill_status(ctx: Dictionary) -> void:
	var body: VBoxContainer = ctx.body
	for ch in body.get_children(): ch.queue_free()
	var u: Unit = ctx.units[ctx.idx]
	var enemy = u.team != 0
	var top = HBoxContainer.new(); top.add_theme_constant_override("separation", 16); body.add_child(top)
	var frame = PanelContainer.new(); frame.add_theme_stylebox_override("panel", Ornate.frame(Color8(40, 32, 64) if not enemy else Color8(64, 24, 32), Color8(216, 176, 72) if not enemy else Color8(200, 72, 72)))
	frame.custom_minimum_size = Vector2(230, 230); top.add_child(frame)
	var pt = TextureRect.new(); pt.texture = Sprites.portrait(u.data.name) if Sprites.portrait(u.data.name) else (Sprites.portrait(u.unit_class.name) if Sprites.portrait(u.unit_class.name) else Sprites.unit_tex(u))
	pt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; pt.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; pt.custom_minimum_size = Vector2(196, 196); frame.add_child(pt)
	var info = VBoxContainer.new(); info.size_flags_horizontal = Control.SIZE_EXPAND_FILL; info.add_theme_constant_override("separation", 6); top.add_child(info)
	var nm = ItemMenus.label(u.data.name, 42, GOLD if not enemy else Color8(255, 140, 140)); nm.autowrap_mode = TextServer.AUTOWRAP_OFF; info.add_child(nm)
	info.add_child(ItemMenus.label("%s   %s" % [u.unit_class.name, "적군" if enemy else "아군"], 26, DIM))
	var lv = HBoxContainer.new(); info.add_child(lv)
	var ll = ItemMenus.label(("Lv %d/%d   EXP %s" % [u.level, ClassCaps.MAX_LEVEL, "--" if u.level >= ClassCaps.MAX_LEVEL else str(u.exp)]) if not enemy else ("Lv %d   EXP %d" % [u.level, u.exp]), 26); ll.autowrap_mode = TextServer.AUTOWRAP_OFF; ll.custom_minimum_size.x = 230; lv.add_child(ll)
	lv.add_child(bar(u.exp, 100, 150, 14, Color8(248, 216, 112)))
	var hp = HBoxContainer.new(); info.add_child(hp)
	var hl = ItemMenus.label("HP %d / %d" % [u.hp, u.stats.hp], 26); hl.autowrap_mode = TextServer.AUTOWRAP_OFF; hl.custom_minimum_size.x = 230; hp.add_child(hl)
	hp.add_child(bar(u.hp, u.stats.hp, 150, 14, _hp_col(u)))
	info.add_child(ItemMenus.label("이동 %d    무기: %s" % [u.move_range(), _wtypes(u)], 24))
	if not u.tags().is_empty(): info.add_child(ItemMenus.label(tag_text(u) + "  약점: " + Weapons.weak_text(u.tags()), 22, Color8(255, 150, 150)))
	# stats
	var sp = PanelContainer.new(); sp.add_theme_stylebox_override("panel", Ornate.frame(Color8(26, 22, 44))); body.add_child(sp)
	var g = GridContainer.new(); g.columns = 2; g.add_theme_constant_override("h_separation", 24); g.add_theme_constant_override("v_separation", 8); sp.add_child(g)
	for s in Unit.STATS:
		var row = HBoxContainer.new(); row.size_flags_horizontal = Control.SIZE_EXPAND_FILL; g.add_child(row)
		var val = u.stats[s] if s == "hp" else u.eff(s)
		var lab = ItemMenus.label(STAT_NAMES[s], 26, Color8(160, 200, 255)); lab.custom_minimum_size.x = 66; lab.autowrap_mode = TextServer.AUTOWRAP_OFF; row.add_child(lab)
		var num = ItemMenus.label(str(val), 28, TXT); num.custom_minimum_size.x = 46; num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; num.autowrap_mode = TextServer.AUTOWRAP_OFF; row.add_child(num)
		var sep = Control.new(); sep.custom_minimum_size.x = 8; row.add_child(sep)
		var capv = ClassCaps.cap(u.unit_class.name, s) if not u.boss else 0
		var at_cap = capv > 0 and capv < 999 and u.stats[s] >= capv
		if capv > 0 and capv < 999:
			num.text = "%d/%d" % [val, capv]; num.custom_minimum_size.x = 76
			if at_cap: num.add_theme_color_override("font_color", Color8(120, 255, 140)); num.text += "★"
		row.add_child(bar(val, capv if capv > 0 and capv < 999 else (STAT_CAP if s != "hp" else 60), 130, 16, Color8(120, 255, 140) if at_cap else (Color8(120, 176, 255) if not u.awakened else Color8(255, 200, 32))))
	# weapon ranks
	if not enemy:
		var rr = HBoxContainer.new(); rr.add_theme_constant_override("separation", 14); body.add_child(rr)
		var rl = ItemMenus.label("무기 랭크", 24, Color8(255, 216, 128)); rl.autowrap_mode = TextServer.AUTOWRAP_OFF; rr.add_child(rl)
		for t in u.unit_class.weapon_types:
			var cell = HBoxContainer.new(); cell.add_theme_constant_override("separation", 4); rr.add_child(cell)
			cell.add_child(Icons.rect(Weapons.make(Roster.IRON.get(t, "철검")), 40))
			var tn = ItemMenus.label(Weapons.TYPE_NAMES.get(int(t), "?"), 22, TXT); tn.autowrap_mode = TextServer.AUTOWRAP_OFF; cell.add_child(tn)
			var vv = VBoxContainer.new(); cell.add_child(vv)
			var lt = ItemMenus.label(u.rank_letter(t), 26, Color8(150, 225, 255)); lt.autowrap_mode = TextServer.AUTOWRAP_OFF; vv.add_child(lt)
			var r0 = maxi(0, u.rank(t)); var nxt = ClassProfs.WEXP[mini(r0 + 1, 5)]
			vv.add_child(bar(u.wexp.get(int(t), 0) - ClassProfs.WEXP[r0], maxi(1, nxt - ClassProfs.WEXP[r0]), 60, 8, Color8(150, 225, 255)))
			vv.alignment = BoxContainer.ALIGNMENT_CENTER
	# items
	body.add_child(ItemMenus.label("소지품 (%d/%d)" % [u.inventory.size(), Unit.MAX_ITEMS], 26, Color8(255, 216, 128)))
	if u.inventory.is_empty(): body.add_child(ItemMenus.label("  없음", 24, DIM))
	for w in u.inventory:
		var r = HBoxContainer.new(); body.add_child(r); r.add_theme_constant_override("separation", 6)
		var eq = w == u.weapon() or (u.weapon() == null and w == u.staff())
		var ok = u.can_use(w)
		r.add_child(ItemMenus.label("▶" if eq else " ", 22, GOLD)); r.add_child(Icons.rect(w, 40))
		var wl = ItemMenus.label("%s  위력%d 명중%d 치명%d 무게%d%s\n%s" % [w.name, w.might, w.hit, w.crit, w.weight, ("  " + Weapons.eff_label(w)) if not w.effective.is_empty() else "", w.desc if ok else "× " + u.block_reason(w)], 20, TXT if ok else DIM)
		wl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; wl.autowrap_mode = TextServer.AUTOWRAP_OFF; r.add_child(wl)
		var ul = ItemMenus.label("%d/%d" % [w.uses, w.max_uses], 22, TXT); ul.custom_minimum_size.x = 76; ul.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; r.add_child(ul)
		r.add_child(bar(w.uses, w.max_uses, 70, 12, Color8(200, 176, 120)))
	# skill + status
	var sk = Skills.LIST.get(u.data.name)
	body.add_child(ItemMenus.label("개인 스킬", 26, Color8(255, 216, 128)))
	body.add_child(ItemMenus.label("  " + (sk[0] if sk else "없음"), 24))
	body.add_child(ItemMenus.label("상태", 26, Color8(255, 216, 128)))
	body.add_child(ItemMenus.label("  " + status_text(u), 24, Color8(255, 200, 32) if u.awakened else TXT))
	if enemy and u.drop: body.add_child(ItemMenus.label("  ★ 처치 시 획득: " + u.drop.name, 24, GOLD))

static func _wtypes(u: Unit) -> String:
	if u.unit_class.weapon_types.is_empty(): return "/".join(u.inventory.map(func(w): return WT_NAMES.get(int(w.type), "?")))
	return "/".join(u.unit_class.weapon_types.map(func(t): return WT_NAMES.get(int(t), "?")))

## 상성표: weapon triangle + effectiveness reference.
static func triangle_chart(parent: Node) -> CanvasLayer:
	var o = overlay(parent, "상성표", 35, 120, 120); var cl: CanvasLayer = o[0]; var v: VBoxContainer = o[1]; cl.name = "TriChart"
	var list = scroll(v)
	list.add_child(ItemMenus.label("무기 상성 (유리: 명중 +15, 위력 +1)", 28, Color8(248, 216, 112)))
	for r in [[0, 2], [2, 1], [1, 0]]:
		var h = HBoxContainer.new(); h.add_theme_constant_override("separation", 12); list.add_child(h)
		h.add_child(Icons.rect(Weapons.make(["철검", "철창", "철도끼"][r[0]]), 40))
		var w0 = Weapons.make(["철검", "철창", "철도끼"][r[0]]); var w1 = Weapons.make(["철검", "철창", "철도끼"][r[1]])
		var l1 = ItemMenus.label("%s(%s)  ▲ 유리 →" % [Weapons.TYPE_NAMES[r[0]], Icons.TRI_NAME[r[0]]], 28, Icons.tri_text(w0)); l1.autowrap_mode = TextServer.AUTOWRAP_OFF; h.add_child(l1)
		h.add_child(Icons.rect(w1, 40))
		var l2 = ItemMenus.label("%s(%s)" % [Weapons.TYPE_NAMES[r[1]], Icons.TRI_NAME[r[1]]], 28, Icons.tri_text(w1)); l2.autowrap_mode = TextServer.AUTOWRAP_OFF; h.add_child(l2)
	list.add_child(ItemMenus.label("색으로 기억하기: 파랑(검) > 빨강(도끼) > 초록(창) > 파랑(검)", 26, Color8(255, 224, 64)))
	list.add_child(ItemMenus.label("반대 방향은 ▼ 불리 (명중 -15, 위력 -1).\n활·마법·지팡이는 상성 없음.\n예측 창의 무기 이름 옆 ▲/▼ 로 표시됩니다.", 24))
	list.add_child(ItemMenus.label("\n특효 (무기 위력 ×%d)" % BattleManager.EFF_MULT, 28, Color8(248, 216, 112)))
	list.add_child(ItemMenus.label("\n".join(["flying", "armor", "cavalry"].map(func(t): return "%s ← %s" % [Weapons.TAG_NAMES[t], Weapons.weak_text([t])])), 24))
	list.add_child(ItemMenus.label("맵: 무기 칸 옆 붉은 칩 = 특효 무기 소지 (날개=비행, 방패=중갑, 말굽=기마).\n아군을 탭하면 그 아군에게 특효로 닿는 적 머리 위에 빨간 '!'가 깜빡입니다.\n예측 창·전투 화면에 '특효! ×%d'가 크게 표시됩니다." % BattleManager.EFF_MULT, 22, Color8(255, 170, 160)))
	list.add_child(ItemMenus.label("\n마법 vs 물리", 28, Color8(248, 216, 112)))
	list.add_child(ItemMenus.label("마법·마법검은 상대의 마방으로, 물리는 수비로 계산.\n경량 무기는 무게로 공속이 떨어지지 않음, 중량 무기는 위력↑ 공속↓.", 24))
	close_btn(v, cl)
	return cl
