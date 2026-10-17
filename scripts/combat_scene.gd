class_name CombatScene extends CanvasLayer
## GBA-style side-view battle screen. Replays BattleManager.events (state already resolved — purely visual,
## never touches stats/RNG). Layout adapts to the visible viewport height (phones are taller than 720x1280).
## Speed: Settings.anim_fast → 2x. Tap anywhere → fast-forward (4x). [건너뛰기] → near-instant (12x).
signal done
var root: Control; var bg: ColorRect; var flash: ColorRect
var spr = {}      # Unit -> TextureRect
var home = {}     # Unit -> Vector2 rest position
var bars = {}     # Unit -> [fill, lag, Label]
var shown_hp = {}
var frames = {}   # Unit -> Array[Texture2D] (idle bob)
var spd = 1.0
var tweens: Array = []
var W = 720.0; var H = 1280.0
var AY = 0.0      # arena ground line (feet)
var SZ = 288.0    # sprite size
var BAR_W = 300.0
var skip_btn: Button
const STAT_NAMES = {"hp": "HP", "str": "힘", "mag": "마력", "skl": "기술", "spd": "속도", "lck": "행운", "def": "수비", "res": "마방"}
const ALLY = Color8(40, 64, 136); const FOE = Color8(144, 40, 52); const EDGE = Color8(232, 200, 112)
const GROUND = {"grass": Color8(96, 160, 72), "snow": Color8(220, 228, 240), "sand": Color8(216, 184, 120), "castle": Color8(120, 112, 128)}
const TERRAIN_TINT = {"forest": Color8(56, 112, 56), "mountain": Color8(136, 112, 88), "fort": Color8(140, 128, 120), "throne": Color8(150, 60, 70),
	"village": Color8(176, 144, 96), "bridge": Color8(150, 110, 70), "pillar": Color8(130, 120, 140), "light": Color8(236, 224, 150)}

func _ready() -> void:
	layer = 15; visible = false

func _clear() -> void:
	for c in get_children(): c.queue_free()
	spr = {}; bars = {}; shown_hp = {}; home = {}; frames = {}; tweens = []

func _lbl(t: String, sz: int, col = Color.WHITE) -> Label:
	var l = Label.new(); l.text = t; l.add_theme_font_size_override("font_size", sz); l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color8(16, 16, 24)); l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE; return l

func _rect(parent: Node, col: Color, pos: Vector2, size: Vector2) -> ColorRect:
	var r = ColorRect.new(); r.color = col; r.position = pos; r.size = size; r.mouse_filter = Control.MOUSE_FILTER_IGNORE; parent.add_child(r); return r

func _panel(col: Color, pos: Vector2, size: Vector2) -> ColorRect:
	var edge = _rect(root, EDGE, pos - Vector2(3, 3), size + Vector2(6, 6))
	var p = _rect(edge, col, Vector2(3, 3), size)
	return p

## Tween that follows the current playback speed (and is sped up when the player taps).
func _tw() -> Tween:
	var t = create_tween(); t.set_speed_scale(spd); tweens.append(t)
	if tweens.size() > 24: tweens = tweens.filter(func(x): return x.is_valid())
	return t

func _set_speed(v: float) -> void:
	if v <= spd: return
	spd = v
	for t in tweens: if t.is_valid(): t.set_speed_scale(spd)

func _wait(t: float) -> void:
	await get_tree().create_timer(t / spd).timeout

func _side_right(u: Unit, a: Unit, d: Unit) -> bool:
	if a.team == d.team: return u == a          # heal: healer on the right
	return u.team == 0                          # allies on the right (GBA FE), enemies/NPC on the left

func _terrain_of(u: Unit) -> String:
	var b = get_parent()
	if b and "grid" in b and b.grid: return str(b.grid.terrain.get(u.cell, ""))
	return ""

func _ground_kind() -> String:
	var b = get_parent()
	if b and "grid" in b and b.grid: return str(b.grid.ground)
	return "grass"

func _setup(a: Unit, d: Unit) -> void:
	_clear(); visible = true; spd = 2.0 if Settings.anim_fast else 1.0
	var vs = get_viewport().get_visible_rect().size
	W = maxf(720.0, vs.x); H = maxf(1100.0, vs.y)
	root = Control.new(); add_child(root); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.gui_input.connect(func(e):
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed: _set_speed(4.0))
	bg = _rect(root, Color8(16, 20, 40), Vector2(-60, -60), Vector2(W + 120, H + 120))   # oversized so screen shake never shows the map
	# vertical layout: plates | arena | hp panels | info, centred in the visible height
	var plate_h = 96.0; var arena_h = clampf(H * 0.42, 460.0, 680.0); var hp_h = 150.0
	var total = plate_h + 16 + arena_h + 16 + hp_h + 70
	var top = maxf(24.0, (H - total) * 0.45)
	var arena_y = top + plate_h + 16
	AY = arena_y + arena_h - 70
	SZ = clampf(arena_h * 0.56, 256.0, 320.0)
	# arena: sky gradient bands + far hills + ground tinted by the defender's terrain
	var sky_cols = [Color8(56, 96, 176), Color8(72, 120, 200), Color8(96, 148, 216), Color8(128, 172, 228)]
	var band = (AY - arena_y) / sky_cols.size()
	for i in sky_cols.size(): _rect(root, sky_cols[i], Vector2(-60, arena_y + band * i), Vector2(W + 120, band + 1))
	var g = GROUND.get(_ground_kind(), GROUND.grass)
	var t = TERRAIN_TINT.get(_terrain_of(d), g)
	var hills = Polygon2D.new(); root.add_child(hills); hills.color = g.darkened(0.35)
	var pts = PackedVector2Array([Vector2(-60, AY)])
	for i in 9: pts.append(Vector2(-60 + (W + 120) * i / 8.0, AY - 60 - 40 * sin(i * 1.7)))
	pts.append(Vector2(W + 60, AY)); hills.polygon = pts
	_rect(root, g, Vector2(-60, AY), Vector2(W + 120, arena_y + arena_h - AY))
	_rect(root, g.darkened(0.2), Vector2(-60, AY), Vector2(W + 120, 6))
	var dist = absi(a.cell.x - d.cell.x) + absi(a.cell.y - d.cell.y)
	var gap = 0.0 if dist <= 1 else 150.0   # ranged: units stand further apart
	for u in [a, d]:
		var right = _side_right(u, a, d)
		var off = minf(gap * 0.5 + SZ * 0.5, W * 0.5 - SZ * 0.42)   # keep both units on screen (sprites have side margins)
		var cx = W * 0.5 + off * (1 if right else -1)
		var plat = _rect(root, (t if u == d else g).darkened(0.1), Vector2(cx - SZ * 0.55, AY - 6), Vector2(SZ * 1.1, 22))
		_rect(plat, (t if u == d else g).lightened(0.15), Vector2(0, 0), Vector2(SZ * 1.1, 5))
		var shadow = _rect(root, Color(0, 0, 0, 0.25), Vector2(cx - SZ * 0.32, AY - 8), Vector2(SZ * 0.64, 10))
		shadow.name = "shadow"
		var tr = TextureRect.new(); root.add_child(tr); tr.texture = Sprites.unit_tex(u); tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if u.team == 1 and u.has_tag("dark"): tr.self_modulate = Color(0.85, 0.7, 1.0)
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.size = Vector2(SZ, SZ); tr.pivot_offset = Vector2(SZ * 0.5, SZ); tr.flip_h = not right
		var lift = 60.0 if "flying" in u.tags() else 0.0
		tr.position = Vector2(cx - SZ * 0.5, AY - SZ - lift + SZ * 0.06)
		spr[u] = tr; home[u] = tr.position
		var fr = []
		if Sprites.user_sheet(u) != null:
			for i in 3: fr.append(Sprites.unit_frame(u, i))
		frames[u] = fr
		# name/weapon plate (top) and HP panel (bottom)
		var px = W * 0.5 + 6 if right else 10.0; var pw = W * 0.5 - 16
		var plate = _panel(ALLY if u.team == 0 else FOE, Vector2(px, top), Vector2(pw, plate_h))
		var nm = _lbl(u.data.name, 32); plate.add_child(nm); nm.position = Vector2(14, 4)
		var w = u.weapon() if a.team != d.team else (u.staff() if u == a else null)
		var wname = w.name if w else "-"
		var wl = HBoxContainer.new(); plate.add_child(wl); wl.position = Vector2(14, 50); wl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if w: var ic = Icons.rect(w, 34); ic.mouse_filter = Control.MOUSE_FILTER_IGNORE; wl.add_child(ic)
		wl.add_child(_lbl(" " + wname, 24, Color8(240, 228, 160)))
		var hp_y = arena_y + arena_h + 16
		var hb = _panel(ALLY if u.team == 0 else FOE, Vector2(px, hp_y), Vector2(pw, hp_h))
		var num = _lbl("", 40); hb.add_child(num); num.position = Vector2(14, 4)
		BAR_W = pw - 28
		var back = _rect(hb, Color8(12, 12, 20), Vector2(14, 60), Vector2(BAR_W, 26))
		var lag = _rect(back, Color8(232, 72, 56), Vector2(3, 3), Vector2(BAR_W - 6, 20))
		var fill = _rect(back, Color8(88, 232, 96), Vector2(3, 3), Vector2(BAR_W - 6, 20))
		var st = _lbl("", 22, Color8(220, 224, 240)); hb.add_child(st); st.position = Vector2(14, 98)
		st.text = _stat_line(u, a, d)
		bars[u] = [fill, lag, num]
	flash = _rect(root, Color(1, 1, 1, 0), Vector2(-60, -60), Vector2(W + 120, H + 120))
	var hint = _lbl("화면을 누르면 빨리 감기", 20, Color8(200, 204, 224)); root.add_child(hint); hint.position = Vector2(20, arena_y + arena_h + 16 + hp_h + 22)
	skip_btn = Button.new(); skip_btn.text = "건너뛰기 ▶▶"; skip_btn.name = "CombatSkip"; skip_btn.add_theme_font_size_override("font_size", 26)
	root.add_child(skip_btn); skip_btn.size = Vector2(220, 60); skip_btn.position = Vector2(W - 236, arena_y + arena_h + 16 + hp_h + 10)
	skip_btn.pressed.connect(func(): _set_speed(12.0))
	_idle_loop()

## 위력/명중/치명 for this unit, captured before the exchange (weapon may have broken since).
func _stat_line(u: Unit, a: Unit, d: Unit) -> String:
	var f: Dictionary = BattleManager.pre_fc
	if a.team == d.team or f.is_empty(): return ""
	var p = "atk_" if u == a else "def_"
	if int(f.get(p + "dmg", -1)) < 0: return "위력 -  명중 -  치명 -"
	return "위력 %d%s  명중 %d  치명 %d" % [f[p + "dmg"], " ×2" if f.get(p + "x2", false) else "", f[p + "hit"], f[p + "crit"]]

func _idle_loop() -> void:
	var k = 0
	while visible and is_inside_tree():
		await get_tree().create_timer(0.28).timeout
		if not visible: return
		k += 1
		for u in spr:
			if is_instance_valid(spr[u]) and frames[u].size() > 1: spr[u].texture = frames[u][k % frames[u].size()]

func _set_hp(u: Unit, v: float) -> void:
	shown_hp[u] = v
	var b = bars[u]; var ratio = clampf(v / u.stats.hp, 0, 1)
	b[0].size.x = (BAR_W - 6) * ratio
	b[0].color = Color8(88, 232, 96) if ratio > 0.5 else (Color8(248, 200, 48) if ratio > 0.25 else Color8(240, 64, 48))
	b[2].text = "HP %d / %d" % [int(round(v)), u.stats.hp]

func _shake(strength: float, dur: float) -> Tween:
	var tw = _tw()
	for i in 6: tw.tween_property(root, "position", Vector2(randf_range(-strength, strength), randf_range(-strength * 0.6, strength * 0.6)), dur / 6)
	tw.tween_property(root, "position", Vector2.ZERO, 0.03)
	return tw

func _float(text: String, at: Vector2, col: Color, sz = 60) -> void:
	var l = _lbl(text, sz, col); root.add_child(l); l.position = at; l.pivot_offset = Vector2(40, 30); l.scale = Vector2(1.6, 1.6)
	var tw = _tw(); tw.tween_property(l, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK)
	tw.tween_property(l, "position:y", at.y - 80, 0.5); tw.parallel().tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.25)
	tw.tween_callback(l.queue_free)

func _center(u: Unit) -> Vector2: return home[u] + Vector2(SZ * 0.5, SZ * 0.5)

func _flash(col: Color, peak: float, dur: float) -> void:
	flash.color = Color(col.r, col.g, col.b, peak)
	var tw = _tw(); tw.tween_property(flash, "color:a", 0.0, dur)

## Weapon-type swing. Returns when the blow lands (target reaction follows).
func _attack_motion(x: Unit, y: Unit, w: WeaponData, crit: bool) -> void:
	var sx: TextureRect = spr[x]; var hx = home[x]
	var dir = 1.0 if home[y].x > hx.x else -1.0
	var t = w.type if w else WeaponData.Type.SWORD
	if crit:   # GBA-style crit wind-up: attacker flashes twice
		for i in 2:
			sx.modulate = Color(3, 3, 2.4); await _wait(0.06); sx.modulate = Color.WHITE; await _wait(0.06)
	match t:
		WeaponData.Type.BOW:
			var tw = _tw(); tw.tween_property(sx, "position:x", hx.x - dir * 18, 0.12); await tw.finished
			Sfx.play("cursor")
			await _projectile(x, y, Color8(240, 232, 200), Vector2(46, 6), 0.22)
			var bk = _tw(); bk.tween_property(sx, "position:x", hx.x, 0.12)
		WeaponData.Type.TOME:
			var col = Color8(255, 240, 150) if w and (w.light or w.name.contains("라이트")) else (Color8(150, 200, 255) if w and w.name.contains("썬더") else (Color8(170, 90, 230) if x.has_tag("dark") else Color8(255, 120, 60)))
			sx.modulate = Color(1.6, 1.4, 1.8)
			var tw = _tw(); tw.tween_property(sx, "position:y", hx.y - 16, 0.14); await tw.finished
			await _projectile(x, y, col, Vector2(30, 30), 0.26)
			_burst(_center(y), col)
			sx.modulate = Color.WHITE
			var bk = _tw(); bk.tween_property(sx, "position:y", hx.y, 0.14)
		_:
			var reach = absf(home[y].x - hx.x) - SZ * 0.55
			var wind = _tw(); wind.tween_property(sx, "position:x", hx.x - dir * 22, 0.08); await wind.finished
			var tw = _tw()
			if t == WeaponData.Type.AXE:   # hop and chop
				tw.tween_property(sx, "position", Vector2(hx.x + dir * reach, hx.y - 50), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tw.tween_property(sx, "position:y", hx.y, 0.06)
			elif t == WeaponData.Type.LANCE:   # long straight thrust
				tw.tween_property(sx, "position:x", hx.x + dir * (reach + 30), 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
			else:   # sword: quick dash
				tw.tween_property(sx, "position:x", hx.x + dir * reach, 0.13).set_trans(Tween.TRANS_QUAD)
			await tw.finished
			_slash(_center(y), dir, t)

func _return(x: Unit) -> void:
	var sx: TextureRect = spr[x]
	if sx.position.distance_to(home[x]) < 1.0: return
	var bk = _tw(); bk.tween_property(sx, "position", home[x], 0.16).set_trans(Tween.TRANS_QUAD)

func _projectile(x: Unit, y: Unit, col: Color, size: Vector2, dur: float) -> void:
	var p = _rect(root, col, Vector2.ZERO, size); p.pivot_offset = size * 0.5
	var from = _center(x) - size * 0.5; var to = _center(y) - size * 0.5
	p.position = from
	if size.x == size.y: p.rotation = PI / 4.0   # magic: diamond orb
	var tw = _tw(); tw.tween_property(p, "position", to, dur).set_trans(Tween.TRANS_SINE)
	if size.x == size.y: tw.parallel().tween_property(p, "rotation", PI * 2.25, dur)
	await tw.finished
	p.queue_free()

func _burst(at: Vector2, col: Color) -> void:
	for i in 8:
		var s = _rect(root, col.lightened(0.3), at - Vector2(8, 8), Vector2(16, 16)); s.rotation = PI / 4
		var ang = i * TAU / 8.0
		var tw = _tw(); tw.tween_property(s, "position", at + Vector2(cos(ang), sin(ang)) * 110 - Vector2(8, 8), 0.28)
		tw.parallel().tween_property(s, "modulate:a", 0.0, 0.28); tw.tween_callback(s.queue_free)

func _slash(at: Vector2, dir: float, t: int) -> void:
	var s = _rect(root, Color(1, 1, 0.9, 0.95), Vector2.ZERO, Vector2(SZ * 0.9, 10)); s.pivot_offset = Vector2(SZ * 0.45, 5)
	s.position = at - s.pivot_offset
	s.rotation = 0.0 if t == WeaponData.Type.LANCE else (-0.9 * dir if t == WeaponData.Type.AXE else -0.6 * dir)
	s.scale = Vector2(0.2, 1)
	var tw = _tw(); tw.tween_property(s, "scale", Vector2(1, 0.4), 0.1); tw.tween_property(s, "modulate:a", 0.0, 0.1); tw.tween_callback(s.queue_free)

func _sparkle(u: Unit) -> void:
	for i in 10:
		var s = _rect(root, Color8(160, 255, 180), _center(u) + Vector2(randf_range(-SZ * 0.35, SZ * 0.35), randf_range(0, SZ * 0.4)), Vector2(10, 10))
		s.rotation = PI / 4
		var tw = _tw(); tw.tween_property(s, "position:y", s.position.y - 160, 0.6).set_delay(i * 0.04)
		tw.parallel().tween_property(s, "modulate:a", 0.0, 0.6).set_delay(i * 0.04); tw.tween_callback(s.queue_free)

func play(a: Unit, d: Unit, events: Array, exp_events: Array, start_hp: Dictionary) -> void:
	_setup(a, d)
	for u in [a, d]:
		_set_hp(u, start_hp.get(u, u.hp)); bars[u][1].size.x = bars[u][0].size.x   # lag bar starts at current HP
	await _wait(0.3)
	for ev in events:
		if ev.type == "heal":
			Sfx.play("heal"); _sparkle(ev.y)
			if spr.has(ev.x): spr[ev.x].modulate = Color(1.5, 1.6, 1.5)
			_float("+%d" % ev.amt, _center(ev.y) + Vector2(-30, -SZ * 0.4), Color8(120, 255, 140))
			await _tick(ev.y, ev.y_hp)
			if spr.has(ev.x): spr[ev.x].modulate = Color.WHITE
			await _wait(0.3)
			continue
		var x: Unit = ev.x; var y: Unit = ev.y
		var sy: TextureRect = spr[y]
		await _attack_motion(x, y, ev.get("w", null), ev.crit)
		var dir = 1.0 if home[y].x > home[x].x else -1.0
		var label_at = _center(y) + Vector2(-40, -SZ * 0.45)
		if ev.hit:
			Sfx.play("crit" if ev.crit else "hit")
			sy.modulate = Color(5, 5, 5)
			if ev.crit:
				_flash(Color.WHITE, 0.7, 0.25)
				_float("치명!", label_at + Vector2(-20, -70), Color8(255, 220, 64), 52)
			_float(str(ev.dmg) if ev.dmg > 0 else "노 데미지", label_at, Color8(255, 255, 255) if ev.dmg > 0 else Color8(200, 200, 210), 64 if ev.dmg > 0 else 40)
			var kb = _tw(); kb.tween_property(sy, "position:x", home[y].x + dir * (34 if ev.crit else 14), 0.05); kb.tween_property(sy, "position:x", home[y].x, 0.14)
			var shake = _shake(22.0 if ev.crit else 8.0, 0.26 if ev.crit else 0.18)
			await _wait(0.12 if ev.crit else 0.07)   # hit-stop
			sy.modulate = Color.WHITE
			_return(x)
			await _tick(y, ev.y_hp)
			if shake.is_valid() and shake.is_running(): await shake.finished
		else:
			Sfx.play("miss"); _float("MISS", label_at, Color8(190, 214, 255), 52)
			var dodge = _tw(); dodge.tween_property(sy, "position:x", home[y].x + dir * 56, 0.09).set_trans(Tween.TRANS_QUAD)
			dodge.tween_property(sy, "position:x", home[y].x, 0.16)
			_return(x)
			await dodge.finished
		if ev.get("x_hp", -1) >= 0 and abs(shown_hp.get(x, ev.x_hp) - ev.x_hp) >= 0.5: await _tick(x, ev.x_hp)   # lifesteal etc.
		if ev.y_hp <= 0:
			for i in 3:
				sy.modulate = Color(4, 4, 4); await _wait(0.05); sy.modulate = Color.WHITE; await _wait(0.05)
			var fade = _tw(); fade.tween_property(sy, "modulate:a", 0.0, 0.4); fade.parallel().tween_property(sy, "scale", Vector2(1.1, 0.2), 0.4)
			await fade.finished
		await _wait(0.16)
	if skip_btn: skip_btn.visible = false
	for ee in exp_events: await _exp(ee)
	await _wait(0.25)
	visible = false; _clear(); done.emit()

## HP drains smoothly; a red "lag" bar trails behind (GBA-style damage readout).
func _tick(u: Unit, to_hp: int) -> void:
	var from = shown_hp.get(u, float(u.hp))
	if abs(from - to_hp) < 0.5: return
	var b = bars[u]
	var tw = _tw(); tw.tween_method(func(v): _set_hp(u, v), from, float(to_hp), clampf(abs(from - to_hp) * 0.04, 0.2, 0.7))
	await tw.finished
	if to_hp > from: b[1].size.x = b[0].size.x; return
	var lt = _tw(); lt.tween_property(b[1], "size:x", b[0].size.x, 0.25).set_delay(0.08)

func _exp(ee: Dictionary) -> void:
	var u: Unit = ee.unit
	var box = _panel(Color8(16, 24, 56), Vector2(W * 0.5 - 250, AY - 60), Vector2(500, 110))
	var l = _lbl("EXP", 30, Color8(255, 232, 128)); box.add_child(l); l.position = Vector2(16, 8)
	var back = _rect(box, Color8(8, 8, 16), Vector2(16, 56), Vector2(400, 30))
	var fill = _rect(back, Color8(248, 216, 64), Vector2(2, 2), Vector2(396 * ee.before / 100.0, 26))
	var num = _lbl(str(ee.before), 30); box.add_child(num); num.position = Vector2(428, 50)
	var target = ee.before + ee.gained
	var tw = _tw()
	tw.tween_method(func(v): fill.size.x = 396 * fmod(v, 100.0) / 100.0 if v < 100 or fmod(v, 100.0) > 0.01 else 396.0; num.text = str(int(v) % 100), float(ee.before), float(target), 0.6)
	await tw.finished
	await _wait(0.3)
	box.get_parent().queue_free()
	for i in ee.ups.size():
		await _levelup(u, ee.level_before + i + 1, ee.ups[i])

func _levelup(u: Unit, lv: int, gains: Dictionary) -> void:
	Sfx.play("levelup")
	var p = _panel(Color8(24, 32, 88), Vector2(W * 0.5 - 280, maxf(40.0, AY - 560)), Vector2(560, 620))
	var t = _lbl("레벨 업!  %s  Lv %d" % [u.data.name, lv], 40, Color8(255, 232, 128)); p.add_child(t); t.position = Vector2(30, 24)
	var i = 0
	for s in Unit.STATS:
		var g = gains.get(s, 0)
		var col = Color8(120, 255, 140) if g > 0 else Color.WHITE
		var row = _lbl("%s   %d%s" % [STAT_NAMES[s], u.stats[s], ("   +%d" % g) if g > 0 else ""], 34, col)
		p.add_child(row); row.position = Vector2(60 + (i % 2) * 260, 110 + (i / 2) * 110)
		if g > 0:
			row.scale = Vector2(1.4, 1.4); var tw = _tw(); tw.tween_property(row, "scale", Vector2.ONE, 0.25)
			await _wait(0.12)
		i += 1
	await _wait(1.3)
	p.get_parent().queue_free()
