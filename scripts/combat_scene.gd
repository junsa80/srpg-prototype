class_name CombatScene extends CanvasLayer
## GBA-style side-view battle screen. Replays BattleManager.events (state already resolved).
signal done
var root: Control; var bg: ColorRect
var spr = {}      # Unit -> TextureRect
var bars = {}     # Unit -> [ColorRect fill, Label]
var shown_hp = {}
const STAT_NAMES = {"hp": "HP", "str": "힘", "mag": "마력", "skl": "기술", "spd": "속도", "lck": "행운", "def": "수비", "res": "마방"}

func _ready() -> void:
	layer = 15; visible = false

func _clear() -> void:
	for c in get_children(): c.queue_free()
	spr = {}; bars = {}; shown_hp = {}

func _lbl(t: String, sz: int, col = Color.WHITE) -> Label:
	var l = Label.new(); l.text = t; l.add_theme_font_size_override("font_size", sz); l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color8(16, 16, 24)); l.add_theme_constant_override("outline_size", 6); return l

func _setup(a: Unit, d: Unit) -> void:
	_clear(); visible = true
	root = Control.new(); add_child(root); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg = ColorRect.new(); root.add_child(bg); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); bg.color = Color8(24, 40, 72)
	var sky = ColorRect.new(); root.add_child(sky); sky.color = Color8(72, 120, 200); sky.position = Vector2(0, 260); sky.size = Vector2(720, 300)
	var ground = ColorRect.new(); root.add_child(ground); ground.color = Color8(88, 152, 64); ground.position = Vector2(0, 560); ground.size = Vector2(720, 140)
	for side in [[a, d], [d, a]]:
		var u: Unit = side[0]
		var right = u.team == 0
		var x = 430 if right else 70
		var plat = ColorRect.new(); root.add_child(plat); plat.color = Color8(168, 136, 88); plat.position = Vector2(x - 20, 560); plat.size = Vector2(260, 24)
		var t = TextureRect.new(); root.add_child(t); t.texture = Sprites.unit_tex(u)
		if u.team == 1 and u.has_tag("dark"): t.self_modulate = Color(0.85, 0.7, 1.0)
		t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; t.size = Vector2(224, 224); t.position = Vector2(x, 340)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; t.flip_h = not right
		spr[u] = t
		# name/weapon plate (top) and HP panel (bottom)
		var plate = ColorRect.new(); root.add_child(plate); plate.color = Color8(40, 56, 120) if right else Color8(136, 40, 48)
		plate.position = Vector2(370 if right else 10, 120); plate.size = Vector2(340, 110)
		var nm = _lbl(u.data.name, 34); plate.add_child(nm); nm.position = Vector2(14, 8)
		var wn = _lbl(u.weapon().name if u.weapon() else (u.staff().name if u.staff() else "-"), 24, Color8(232, 224, 160)); plate.add_child(wn); wn.position = Vector2(14, 60)
		var hpbox = ColorRect.new(); root.add_child(hpbox); hpbox.color = Color8(40, 56, 120) if right else Color8(136, 40, 48)
		hpbox.position = Vector2(370 if right else 10, 720); hpbox.size = Vector2(340, 120)
		var num = _lbl("", 40); hpbox.add_child(num); num.position = Vector2(14, 10)
		var back = ColorRect.new(); hpbox.add_child(back); back.color = Color8(16, 16, 24); back.position = Vector2(14, 72); back.size = Vector2(312, 26)
		var fill = ColorRect.new(); back.add_child(fill); fill.color = Color8(88, 232, 96); fill.position = Vector2(3, 3); fill.size = Vector2(306, 20)
		bars[u] = [fill, num]
	var f = BattleManager.forecast(a, d) if a.team != d.team else {}
	var info = _lbl("명중 %d  위력 %d  치명 %d" % [BattleManager.hit_rate(a, d), BattleManager.damage(a, d), BattleManager.crit_rate(a, d)] if a.team != d.team else "", 24)
	root.add_child(info); info.position = Vector2(20, 860)

func _set_hp(u: Unit, v: float) -> void:
	shown_hp[u] = v
	var b = bars[u]; var ratio = clampf(v / u.stats.hp, 0, 1)
	b[0].size.x = 306 * ratio
	b[0].color = Color8(88, 232, 96) if ratio > 0.5 else (Color8(248, 200, 48) if ratio > 0.25 else Color8(240, 64, 48))
	b[1].text = "HP %d / %d" % [int(round(v)), u.stats.hp]

func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func _shake(strength: float, dur: float) -> Tween:
	var tw = create_tween()
	for i in 8: tw.tween_property(root, "position", Vector2(randf_range(-strength, strength), randf_range(-strength, strength)), dur / 8)
	tw.tween_property(root, "position", Vector2.ZERO, 0.02)
	return tw

func _float(text: String, at: Vector2, col: Color) -> void:
	var l = _lbl(text, 56, col); root.add_child(l); l.position = at
	var tw = create_tween(); tw.tween_property(l, "position:y", at.y - 90, 0.6); tw.parallel().tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.3)
	tw.tween_callback(l.queue_free)

func play(a: Unit, d: Unit, events: Array, exp_events: Array, start_hp: Dictionary) -> void:
	_setup(a, d)
	for u in [a, d]: _set_hp(u, start_hp.get(u, u.hp))
	await _wait(0.35)
	for ev in events:
		if ev.type == "heal":
			Sfx.play("heal"); _float("+%d" % ev.amt, spr[ev.y].position + Vector2(60, 0), Color8(120, 255, 140))
			await _tick(ev.y, ev.y_hp)
			continue
		var x: Unit = ev.x; var y: Unit = ev.y
		var sx: TextureRect = spr[x]; var sy: TextureRect = spr[y]
		var home = sx.position; var dir = 1.0 if sy.position.x > sx.position.x else -1.0
		var tw = create_tween()
		tw.tween_property(sx, "position:x", home.x + dir * 150, 0.16).set_trans(Tween.TRANS_QUAD)
		await tw.finished
		if ev.hit:
			Sfx.play("crit" if ev.crit else "hit")
			sy.modulate = Color(4, 4, 4)
			if ev.crit:
				bg.color = Color8(248, 248, 248); _float("치명!", sy.position + Vector2(10, -60), Color8(255, 220, 64))
			_float(str(ev.dmg), sy.position + Vector2(70, 0), Color8(255, 255, 255))
			var shake = _shake(18.0 if ev.crit else 8.0, 0.25)
			await _wait(0.07); sy.modulate = Color.WHITE; bg.color = Color8(24, 40, 72)
			if shake.is_running(): await shake.finished
		else:
			Sfx.play("miss"); _float("MISS", sy.position + Vector2(40, 0), Color8(200, 220, 255))
			var dodge = create_tween(); dodge.tween_property(sy, "position:x", sy.position.x - dir * 40, 0.1); dodge.tween_property(sy, "position:x", sy.position.x, 0.12)
		var back = create_tween(); back.tween_property(sx, "position:x", home.x, 0.16)
		await _tick(y, ev.y_hp)
		if back.is_running(): await back.finished
		if ev.y_hp <= 0:
			var fade = create_tween(); fade.tween_property(sy, "modulate:a", 0.0, 0.5); await fade.finished
		await _wait(0.15)
	for ee in exp_events: await _exp(ee)
	await _wait(0.25)
	visible = false; _clear(); done.emit()

func _tick(u: Unit, to_hp: int) -> void:
	var from = shown_hp.get(u, float(u.hp))
	if abs(from - to_hp) < 0.5: return
	var tw = create_tween(); tw.tween_method(func(v): _set_hp(u, v), from, float(to_hp), clampf(abs(from - to_hp) * 0.04, 0.2, 0.7))
	await tw.finished

func _exp(ee: Dictionary) -> void:
	var u: Unit = ee.unit
	var box = ColorRect.new(); root.add_child(box); box.color = Color8(16, 24, 56); box.position = Vector2(110, 900); box.size = Vector2(500, 110)
	var l = _lbl("EXP", 30, Color8(255, 232, 128)); box.add_child(l); l.position = Vector2(16, 8)
	var back = ColorRect.new(); box.add_child(back); back.color = Color8(8, 8, 16); back.position = Vector2(16, 56); back.size = Vector2(400, 30)
	var fill = ColorRect.new(); back.add_child(fill); fill.color = Color8(248, 216, 64); fill.position = Vector2(2, 2); fill.size = Vector2(396 * ee.before / 100.0, 26)
	var num = _lbl(str(ee.before), 30); box.add_child(num); num.position = Vector2(428, 50)
	var target = ee.before + ee.gained
	var tw = create_tween()
	tw.tween_method(func(v): fill.size.x = 396 * fmod(v, 100.0) / 100.0 if v < 100 or fmod(v, 100.0) > 0.01 else 396.0; num.text = str(int(v) % 100), float(ee.before), float(target), 0.6)
	await tw.finished
	await _wait(0.3)
	box.queue_free()
	for i in ee.ups.size():
		await _levelup(u, ee.level_before + i + 1, ee.ups[i])

func _levelup(u: Unit, lv: int, gains: Dictionary) -> void:
	Sfx.play("levelup")
	var p = ColorRect.new(); root.add_child(p); p.color = Color8(24, 32, 88); p.position = Vector2(80, 200); p.size = Vector2(560, 620)
	var t = _lbl("레벨 업!  %s  Lv %d" % [u.data.name, lv], 40, Color8(255, 232, 128)); p.add_child(t); t.position = Vector2(30, 24)
	var i = 0
	for s in Unit.STATS:
		var g = gains.get(s, 0)
		var col = Color8(120, 255, 140) if g > 0 else Color.WHITE
		var row = _lbl("%s   %d%s" % [STAT_NAMES[s], u.stats[s] - (0 if lv < u.level else 0), ("   +%d" % g) if g > 0 else ""], 34, col)
		p.add_child(row); row.position = Vector2(60 + (i % 2) * 260, 110 + (i / 2) * 110)
		if g > 0:
			row.scale = Vector2(1.4, 1.4); var tw = create_tween(); tw.tween_property(row, "scale", Vector2.ONE, 0.25)
			await _wait(0.12)
		i += 1
	await _wait(1.3)
	p.queue_free()
