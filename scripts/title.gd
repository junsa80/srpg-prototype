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
	box.offset_left = 90; box.offset_right = -90; box.offset_top = -520; box.offset_bottom = -80; box.add_theme_constant_override("separation", 18)
	_main()
	Sfx.start_bgm()

func _hash() -> String:
	return str(JavaScriptBridge.eval("location.hash", true)) if OS.has_feature("web") else ""

func _clear() -> void:
	for c in box.get_children(): c.queue_free()

func _has_save() -> bool: return FileAccess.file_exists(Campaign.PATH) and (Campaign.cleared.size() > 0 or Campaign.roster.size() > 0)

func _main() -> void:
	_clear()
	var cont = ItemMenus.big("이어하기", 110, 36); cont.disabled = not _has_save(); cont.pressed.connect(_continue); box.add_child(cont)
	var info = ItemMenus.label(("  다음: %s · %dG" % [ChapterData.CHAPTERS.get(Campaign.chapter, {}).get("title", ""), Campaign.gold]) if _has_save() else "", 22, Color8(200, 190, 230))
	box.add_child(info)
	var ng = ItemMenus.big("새 게임", 110, 36); ng.pressed.connect(_new_game_confirm); box.add_child(ng)
	var st = ItemMenus.big("설정", 110, 36); st.pressed.connect(_settings); box.add_child(st)

func _continue() -> void:
	Sfx.play("select")
	if Campaign.cleared.size() > 0:
		get_tree().change_scene_to_file("res://scenes/base.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/battle.tscn")

func _new_game_confirm() -> void:
	Sfx.play("select")
	if not _has_save(): _new_game(); return
	_clear()
	box.add_child(ItemMenus.label("저장된 진행을 지우고 새로 시작할까요?", 30))
	var y = ItemMenus.big("예, 새로 시작", 110, 34); y.pressed.connect(_new_game); box.add_child(y)
	var n = ItemMenus.big("아니요", 110, 34); n.pressed.connect(_main); box.add_child(n)

func _new_game() -> void:
	Campaign.reset(); get_tree().change_scene_to_file("res://scenes/battle.tscn")

func _settings() -> void:
	Sfx.play("select"); _clear()
	var m = ItemMenus.big("음악·효과음: " + ("끔" if Sfx.muted else "켬"), 110, 34)
	m.pressed.connect(func(): Sfx.toggle_mute(); _settings()); box.add_child(m)
	var anim = not FileAccess.file_exists("user://anim_off")
	var a = ItemMenus.big("전투 연출: " + ("켬" if anim else "끔"), 110, 34)
	a.pressed.connect(func():
		if anim: FileAccess.open("user://anim_off", FileAccess.WRITE).store_string("1")
		else: DirAccess.remove_absolute("user://anim_off")
		_settings()); box.add_child(a)
	var b = ItemMenus.big("← 돌아가기", 110, 34); b.pressed.connect(_main); box.add_child(b)
