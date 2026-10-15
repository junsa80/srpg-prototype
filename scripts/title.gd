extends Control
## Title / main menu: 이어하기, 새 게임, 설정 (음소거·전투 연출). Big touch buttons, ornate frames.
var box: VBoxContainer

func _ready() -> void:
	if "--flowtest" in OS.get_cmdline_user_args() or "ch2" in _hash() or "combat" in _hash() or "base" in _hash() or "nodialog" in _hash():
		get_tree().change_scene_to_file.call_deferred("res://scenes/battle.tscn"); return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg = ColorRect.new(); add_child(bg); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); bg.color = Color8(20, 16, 36)
	var art = TextureRect.new(); add_child(art); art.texture = load("res://assets/portraits/그림자 지휘관.png")
	art.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE); art.offset_top = 80; art.offset_bottom = 560
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; art.modulate = Color(1, 1, 1, 0.55)
	var t = ItemMenus.label("그림자 군단", 72, Color8(248, 216, 112)); t.autowrap_mode = TextServer.AUTOWRAP_OFF
	t.add_theme_color_override("font_outline_color", Color8(16, 8, 24)); t.add_theme_constant_override("outline_size", 14)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; add_child(t); t.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE); t.offset_top = 470; t.offset_bottom = 560
	var sub = ItemMenus.label("Shadow Legion Tactics", 26, Color8(200, 190, 230)); sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub); sub.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE); sub.offset_top = 560; sub.offset_bottom = 600
	box = VBoxContainer.new(); add_child(box); box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	box.offset_left = 90; box.offset_right = -90; box.offset_top = -600; box.offset_bottom = -80; box.add_theme_constant_override("separation", 12)
	_main()
	Sfx.start_bgm()

func _hash() -> String:
	return str(JavaScriptBridge.eval("location.hash", true)) if OS.has_feature("web") else ""

func _clear() -> void:
	for c in box.get_children(): c.queue_free()

func _has_save() -> bool: return SaveManager.latest_slot() >= 0 or (FileAccess.file_exists(Campaign.PATH) and (Campaign.cleared.size() > 0 or Campaign.roster.size() > 0))

func _main() -> void:
	_clear()
	var cont = ItemMenus.big("이어하기", 90, 34); cont.name = "Continue"; cont.disabled = not _has_save(); cont.pressed.connect(_continue); box.add_child(cont)
	var info_t = ""
	var ls = SaveManager.latest_slot()
	if ls >= 0:
		var m = SaveManager.slot_metadata()[ls]
		info_t = "  %s · %s · %s" % [m.chapter_title, ("턴 %d" % m.turn) if m.in_battle else "거점", m.timestamp]
	if Campaign.mode_tag() != "": info_t += "  " + Campaign.mode_tag()
	box.add_child(ItemMenus.label(info_t, 22, Color8(200, 190, 230)))
	var ng = ItemMenus.big("새 게임", 90, 34); ng.name = "NewGame"; ng.pressed.connect(_new_game_confirm); box.add_child(ng)
	var ld = ItemMenus.big("불러오기", 90, 34); ld.name = "Load"; ld.pressed.connect(func(): Menus.slots(self, "load", null, _goto)); box.add_child(ld)
	if _has_save() and Campaign.roster.size() > 0:   # 환생 anytime once a save exists
		var rb = ItemMenus.big("환생 (★%d → ★%d)" % [Campaign.cycle, Campaign.cycle + 1], 90, 34); rb.name = "Rebirth"; box.add_child(rb)
		rb.pressed.connect(func(): Menus.rebirth_select(self, func(): _goto("res://scenes/battle.tscn")))
	var st = ItemMenus.big("설정", 90, 34); st.name = "Settings"; st.pressed.connect(func(): Menus.settings(self)); box.add_child(st)
	var wipe = ItemMenus.big("완전 초기화 새 게임", 80, 28); wipe.name = "Wipe"; box.add_child(wipe)
	wipe.add_theme_color_override("font_color", Color8(255, 110, 110)); wipe.add_theme_color_override("font_hover_color", Color8(255, 150, 150))
	wipe.pressed.connect(_wipe_confirm)

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
	Campaign.reset(); SaveManager.delete_slot(0); _goto("res://scenes/battle.tscn")

## 완전 초기화: wipes campaign + every save slot. Two confirmations (danger).
func _wipe_confirm() -> void:
	Menus.confirm(self, "!! 완전 초기화 !!\n모든 진행·저장 슬롯·환생 기록이\n삭제됩니다.", "삭제 진행", func():
		Menus.confirm(self, "정말로 삭제할까요?\n되돌릴 수 없습니다!", "영구 삭제", func():
			Campaign.wipe_all(); Menus.toast(self, "모든 데이터를 삭제했습니다"); _main()))
