class_name FirstPlayGuide extends CanvasLayer
## Optional contextual coach. Reads battle state; never executes a player action.
var battle: Node
var card: Panel
var heading: Label
var words: Label
var portrait: TextureRect
var companion: TextureRect
var ring: Panel
var attacked = false
var last_key = ""

func _ready() -> void:
	layer = 8; name = "FirstPlayGuide"
	card = Panel.new(); add_child(card); card.name = "GuideCard"
	card.add_theme_stylebox_override("panel", Ornate.frame(Color8(15, 29, 44, 250), Color8(180, 157, 107), 2))
	card.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	card.offset_left = 16; card.offset_right = -16; card.offset_top = SafeArea.insets(get_viewport()).x + 16; card.offset_bottom = card.offset_top + 226
	# This card consumes touches; every other part of the overlay is pass-through.
	heading = ItemMenus.label("첫 전투 · 기본 조작", 26, Color8(230, 200, 143)); card.add_child(heading)
	heading.position = Vector2(18, 16); heading.size = Vector2(420, 36)
	var skip = ItemMenus.big("안내 스킵", 88, 26); card.add_child(skip); skip.name = "SkipGuide"
	skip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	skip.offset_left = -194; skip.offset_right = -12; skip.offset_top = 8; skip.offset_bottom = 96
	skip.pressed.connect(stop)
	portrait = TextureRect.new(); card.add_child(portrait); portrait.position = Vector2(18, 76); portrait.size = Vector2(76, 66)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR; portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.texture = Sprites.portrait("노아")
	companion = TextureRect.new(); card.add_child(companion); companion.position = Vector2(18, 150); companion.size = Vector2(76, 66)
	companion.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; companion.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	companion.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR; companion.texture = Sprites.portrait("아린"); companion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words = ItemMenus.label("", 24); card.add_child(words); words.position = Vector2(110, 100)
	words.size = Vector2(550, 116); words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring = Panel.new(); add_child(ring); ring.name = "GuideTarget"; ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style = StyleBoxFlat.new(); style.bg_color = Color(1, 0.85, 0.45, 0.08); style.border_color = Color8(255, 221, 137); style.set_border_width_all(4); style.set_corner_radius_all(12)
	ring.add_theme_stylebox_override("panel", style)

func stop() -> void:
	visible = false; queue_free()

func finish() -> void:
	Menus.toast(battle.ui, "기본 조작 완료!\n궁금할 때는 메뉴 → 게임 방법")
	stop()

func _cell(c: Vector2i) -> void:
	var pt: Vector2 = battle.get_canvas_transform() * battle.grid.cell_to_pos(c)
	var side: float = Grid.CELL * battle.cam.zoom.x
	ring.position = pt - Vector2.ONE * side / 2; ring.size = Vector2.ONE * side
	# Avoid pointing behind the coach or the bottom HUD; panning remains available.
	ring.visible = ring.position.y > card.get_global_rect().end.y and ring.position.y + side < get_viewport().get_visible_rect().size.y - battle.PANEL_H - battle.sa.y

func _button(b: Button) -> void:
	ring.position = b.get_global_rect().position - Vector2(3, 3); ring.size = b.size + Vector2(6, 6); ring.visible = not b.disabled

func _say(key: String, title: String, who: String, text: String) -> void:
	heading.text = title
	if key == last_key: return
	last_key = key; words.text = text
	portrait.modulate = Color.WHITE if who == "노아" else Color(0.8, 0.85, 0.9)
	companion.modulate = Color.WHITE if who != "노아" else Color(0.8, 0.85, 0.9)

func _process(_dt: float) -> void:
	if not is_instance_valid(battle): return
	visible = not battle.busy and not battle.prep_active and not battle.dialogue.visible and battle.tm.phase == TurnManager.Phase.PLAYER
	if not visible: return
	ring.visible = false
	var u = battle.selected
	if u == null:
		var allies = battle.units.filter(func(a): return a.team == 0 and a.hp > 0 and not a.has_acted)
		if attacked or allies.is_empty():
			_say("end", "4 / 4 · 턴 마치기", "노아", "노아  준비가 끝나면 턴 종료.\n아린  이제 저쪽 차례군요.")
			_button(battle.btn_end); return
		_say("select", "1 / 4 · 동료 선택", "아린", "노아  파란 발판의 동료를 눌러.\n아린  좋아요. 한 명씩 가죠.")
		var ally = allies[0]
		_cell(ally.cell); return
	if not battle.moved:
		_say("move", "2 / 4 · 이동", u.data.name, "노아  파란 칸을 두 번 누르면 이동.\n아린  첫 번은 경로 확인이군요.")
		var cells = battle.grid.highlight_move.filter(func(c): return c != u.cell and battle._unit_at(c) == null)
		if battle.pending_dest != Vector2i(-1, -1): _cell(battle.pending_dest)
		elif cells.size():
			cells.sort_custom(func(a, b): return battle._dist(u.cell, a) + (100 if a.y >= u.cell.y else 0) < battle._dist(u.cell, b) + (100 if b.y >= u.cell.y else 0))
			_cell(cells[0])
		return
	if battle.pending_target != null:
		_say("confirm", "3 / 4 · 공격 확인", "아린", "노아  예상 피해를 보고 확인을 눌러.\n아린  불리하면 취소할게요.")
		_button(battle.btn_confirm); return
	var targets = battle.units.filter(func(a): return a.team == 1 and a.hp > 0 and BattleManager.in_range(u, a))
	if targets.size():
		_say("target", "3 / 4 · 공격할 적 선택", "노아", "노아  닿는 거리의 적을 눌러 봐.\n아린  공격 전에 결과부터 확인!")
		_cell(targets[0].cell)
	else:
		_say("wait", "2 / 4 · 이동 후 대기", "노아", "노아  아직 멀군. 확인을 눌러 대기.\n아린  다른 동료도 움직여 둘게요.")
		_button(battle.btn_confirm)

static func manual(b: Node) -> CanvasLayer:
	var o = Menus.overlay(b.ui, "게임 방법"); var cl: CanvasLayer = o[0]; var v: VBoxContainer = o[1]; cl.name = "FieldManual"
	var list = Menus.scroll(v)
	for entry in [
		["지금 목표", b.goal_text() + " · 아린이 쓰러지면 패배합니다."],
		["선택과 이동", "파란 발판의 동료 → 파란 칸 한 번으로 경로 확인 → 같은 칸을 다시 눌러 이동. 맵은 드래그, 확대는 +/−."],
		["공격과 대기", "이동 후 사거리 안의 적 → 예상 피해 확인 → 확인 버튼으로 공격. 적을 선택하지 않고 확인을 누르면 대기합니다. 취소로 이동을 되돌릴 수 있어요."],
		["턴 종료", "원하는 동료의 행동을 마치고 턴 종료를 누르세요. 아직 움직이지 않은 동료도 이번 턴을 마칩니다."],
		["체력과 회복", "HP는 체력. 다친 동료에게 치유사를 가까이 이동시킨 뒤 동료 → 확인으로 회복. 아이템에서도 상처약을 쓸 수 있어요."],
		["더 궁금하다면", "유닛을 길게 눌러 상태를 확인하세요. 메뉴의 전투 목표·상성표와 무기 설명은 필요할 때 찾아보면 됩니다."]]:
		list.add_child(ItemMenus.label(entry[0], 30, Menus.GOLD)); list.add_child(ItemMenus.label(entry[1], 28))
	var guide = ItemMenus.big("기본 조작 안내 켜기", 96, 30); list.add_child(guide); guide.name = "RestartGuide"
	guide.pressed.connect(func():
		cl.queue_free()
		var menu = b.find_child("BattleMenu", true, false)
		if menu: menu.queue_free()
		b._start_guide())
	var story = ItemMenus.big("이야기 도입 다시 보기", 96, 28); list.add_child(story)
	story.pressed.connect(func():
		cl.queue_free()
		var menu = b.find_child("BattleMenu", true, false)
		if menu: menu.queue_free()
		b.dialogue.play(ChapterData.PROLOGUE))
	Menus.close_btn(v, cl)
	return cl
