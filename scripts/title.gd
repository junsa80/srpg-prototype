extends Control
## Title / main menu: dedicated Ashen Crown key art, primary actions + secondary helper row.
var box: VBoxContainer

func _ready() -> void:
	DisplayServer.window_set_title("잿빛 왕관: 새벽의 서약")
	if "--flowtest" in OS.get_cmdline_user_args() or "ch2" in _hash() or "combat" in _hash() or "base" in _hash() or "nodialog" in _hash():
		get_tree().change_scene_to_file.call_deferred("res://scenes/battle.tscn"); return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg = ColorRect.new(); add_child(bg); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); bg.color = Color8(12, 14, 22)
	# Dedicated citadel key art; retain the latest primary / secondary action layout.
	var art = TextureRect.new(); add_child(art); art.name = "TitleArt"
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var key = load("res://assets/title/ashen-crown-keyart-v1.png")
	art.texture = key if key else load("res://assets/battle/bg/fort.png")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR; art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Bottom-heavy dim so gold title + buttons stay readable on the dawn sky
	var dim = ColorRect.new(); add_child(dim); dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.05, 0.1, 0.42); dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var safe = SafeArea.insets(get_viewport())
	var layout = VBoxContainer.new(); add_child(layout); layout.name = "TitleLayout"
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 28; layout.offset_right = -28; layout.offset_top = safe.x + 20; layout.offset_bottom = -safe.y - 20
	layout.add_theme_constant_override("separation", 10)
	var spacer = Control.new(); spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL; spacer.custom_minimum_size.y = 24; layout.add_child(spacer)
	var t = ItemMenus.label("잿빛 왕관", 56, Color8(248, 216, 112)); t.autowrap_mode = TextServer.AUTOWRAP_OFF
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_outline_color", Color8(20, 16, 28)); t.add_theme_constant_override("outline_size", 10)
	layout.add_child(t)
	var sub = ItemMenus.label("새벽의 서약 · Ashen Crown", 26, Color8(220, 228, 240)); sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_outline_color", Color8(16, 16, 24)); sub.add_theme_constant_override("outline_size", 6)
	layout.add_child(sub)
	var promise = ItemMenus.label("동료와 함께 마을을 지키는 전술 RPG", 26, Color8(236, 229, 211))
	promise.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; layout.add_child(promise)
	box = VBoxContainer.new(); layout.add_child(box); box.name = "TitleActions"
	box.add_theme_constant_override("separation", 10)
	_main()
	Sfx.start_bgm()

func _hash() -> String:
	return str(JavaScriptBridge.eval("location.hash", true)) if OS.has_feature("web") else ""

func _clear() -> void:
	for c in box.get_children(): c.queue_free()

func _has_save() -> bool: return SaveManager.latest_slot() >= 0 or (FileAccess.file_exists(Campaign.PATH) and (Campaign.cleared.size() > 0 or Campaign.roster.size() > 0))

func _main() -> void:
	_clear()
	# —— Primary ——
	var cont = ItemMenus.big("이어하기", 92, 34); cont.name = "Continue"; cont.disabled = not _has_save(); cont.pressed.connect(_continue); box.add_child(cont)
	var info_t = ""
	var ls = SaveManager.latest_slot()
	if ls >= 0:
		var m = SaveManager.slot_metadata()[ls]
		info_t = "  %s · %s · %s" % [m.chapter_title, ("턴 %d" % m.turn) if m.in_battle else "거점", m.timestamp]
	if Campaign.mode_tag() != "": info_t += "  " + Campaign.mode_tag()
	box.add_child(ItemMenus.label(info_t if info_t != "" else "  저장된 진행이 없으면 비활성", 24, Color8(200, 190, 230)))
	var ng = ItemMenus.big("새 게임", 92, 34); ng.name = "NewGame"; ng.pressed.connect(_new_game_confirm); box.add_child(ng)
	# —— Secondary helper line ——
	box.add_child(ItemMenus.label("불러오기 · 설정 · 기록", 24, Color8(168, 176, 200)))
	var sec = HBoxContainer.new(); sec.add_theme_constant_override("separation", 8); sec.name = "TitleSecondary"; box.add_child(sec)
	var ld = ItemMenus.big("불러오기", 88, 26); ld.name = "Load"; ld.pressed.connect(func(): Menus.slots(self, "load", null, _goto)); sec.add_child(ld)
	if Campaign.has_update_offer(): _update_offer.call_deferred()
	var st = ItemMenus.big("설정", 88, 26); st.name = "Settings"; st.pressed.connect(func(): Menus.settings(self)); sec.add_child(st)
	var manage = ItemMenus.big("기록", 88, 26); manage.name = "Records"; manage.pressed.connect(_records); sec.add_child(manage)

func _records() -> void:
	var o = Menus.overlay(self, "환생 · 기록 관리"); var cl: CanvasLayer = o[0]; var v: VBoxContainer = o[1]
	cl.name = "TitleRecords"
	var list = Menus.scroll(v)
	list.add_child(ItemMenus.label("저장 파일의 내보내기·가져오기는 불러오기에서 이용할 수 있어요.", 26))
	var ld = ItemMenus.big("불러오기 · 저장 파일 관리", 96, 30); list.add_child(ld); ld.pressed.connect(func(): Menus.slots(self, "load", null, _goto))
	if _has_save() and Campaign.roster.size() > 0:
		var rb = ItemMenus.big("환생 (★%d → ★%d)" % [Campaign.cycle, Campaign.cycle + 1], 96, 30); rb.name = "Rebirth"; list.add_child(rb)
		rb.pressed.connect(func(): Menus.rebirth_select(self, func(): _goto("res://scenes/battle.tscn")))
	var wipe = ItemMenus.big("완전 초기화 새 게임", 96, 28); wipe.name = "Wipe"; list.add_child(wipe)
	wipe.add_theme_color_override("font_color", Color8(255, 130, 130)); wipe.pressed.connect(_wipe_confirm)
	Menus.close_btn(v, cl)

## One-time offer after a game update (old save loaded): free restart at Ch1 keeping everything. Declining = continue normally.
func _update_offer() -> void:
	var taken = [false]
	var cl = Menus.confirm(self, "게임이 업데이트되었습니다.\n\n업데이트 재시작 (레벨·숙련도 유지)\nCh1부터 무료로 다시 시작합니다.\n레벨·능력치·숙련도·아이템·골드 유지\n(환생 ★ 증가 없음 · 적 보통 난이도)\n\n한 번만 표시됩니다.", "업데이트 재시작", func():
		taken[0] = true; Campaign.update_restart(); _goto("res://scenes/battle.tscn"), "그대로 계속")
	cl.name = "UpdateOffer"
	cl.tree_exiting.connect(func():
		if not taken[0] and Campaign.update_offer > 0: Campaign.decline_update())

func _goto(scene: String) -> void: get_tree().change_scene_to_file(scene)

func _continue() -> void:
	Sfx.play("select")
	var ls = SaveManager.latest_slot()
	if ls >= 0:
		var scene = SaveManager.apply(ls)
		if scene != "": _goto(scene); return
	_goto("res://scenes/base.tscn" if Campaign.cleared.size() > 0 else "res://scenes/battle.tscn")

func _new_game_confirm() -> void:
	Sfx.play("select")
	if not _has_save(): _new_game(); return
	Menus.confirm(self, "새로 시작할까요?\n(저장 슬롯은 그대로 남습니다)", "새로 시작", _new_game)

func _new_game() -> void:
	var o = Menus.overlay(self, "어떻게 시작할까요?"); var cl = o[0]; var v = o[1]
	cl.name = "FirstPlayChoice"
	var art = TextureRect.new(); v.add_child(art); art.texture = Sprites.portrait("아린")
	art.custom_minimum_size.y = 240; art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	v.add_child(ItemMenus.label("마을을 지키는 첫 전투.\n동료와 함께 한 수씩 길을 열어 보세요.", 30))
	for choice in [[true, "안내받으며 시작", "선택 · 이동 · 공격 · 턴 종료만 짧게. 언제든 스킵할 수 있어요."], [false, "바로 플레이", "기본 편성으로 바로 출전. 도움이 필요하면 메뉴 → 게임 방법."]]:
		var guided: bool = choice[0]
		var b = ItemMenus.big(choice[1], 100, 32); b.name = "GuidedStart" if guided else "DirectStart"; v.add_child(b)
		v.add_child(ItemMenus.label(choice[2], 26, Color8(192, 205, 220)))
		b.pressed.connect(func():
			Campaign.reset(); SaveManager.delete_slot(0)
			Campaign.set_meta("first_play", true); Campaign.set_meta("guided_start", guided)
			cl.queue_free(); _goto("res://scenes/battle.tscn"))
	Menus.close_btn(v, cl, null, "돌아가기")

## 완전 초기화: wipes campaign + every save slot. Two confirmations (danger).
func _wipe_confirm() -> void:
	Menus.confirm(self, "!! 완전 초기화 !!\n모든 진행·저장 슬롯·환생 기록이\n삭제됩니다.", "삭제 진행", func():
		Menus.confirm(self, "정말로 삭제할까요?\n되돌릴 수 없습니다!", "영구 삭제", func():
			Campaign.wipe_all(); Menus.toast(self, "모든 데이터를 삭제했습니다"); _main()))
