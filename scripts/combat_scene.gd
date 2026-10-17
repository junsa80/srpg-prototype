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
var SZ = 128.0    # unit box width (= RW); used for reach / effects
## Battle unit size: map sheet frames are 32x32. Head rows (0..15) drawn at PX, body rows (16..31) at PX x (PX+1)
## (taller body = less chibi), so the unit box is 128 x 144 on every phone. Integer factors only -> crisp pixels.
## Pose images (assets/battle/<id>/{ready,attack,hit,dodge}.png) are drawn at the largest integer scale that fits RH;
## ideal canvas 64x72 (-> exactly 2x = 128x144), facing RIGHT, feet on the bottom row, transparent background.
const PX = 4
var RW = 128.0; var RH = 144.0
var poses = {}    # Unit -> {pose: Texture2D} (only when pose images exist)
var parts = {}    # Unit -> Array of [TextureRect, row0, row1] (map-sprite rig, idle frame swaps)
var auras = {}    # Unit -> Control (boss aura) / scarf node
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
	spr = {}; bars = {}; shown_hp = {}; home = {}; frames = {}; tweens = []; poses = {}; parts = {}; auras = {}

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

## GBA FE (6/7/8) battle-screen structure, original art: [enemy plate | ally plate] (name + weapon icon/name) on top,
## 240x160 terrain backdrop at an integer scale with a terrain platform under each unit (enemy left, ally right),
## bottom panel per side = outer HIT/DMG/CRT box + inner ▲▼/특효 + big HP number and a segmented HP tick bar.
## Frames: blue = player side, red = enemy side.
const ALLY_EDGE = Color8(136, 184, 255); const FOE_EDGE = Color8(255, 136, 120)
var BS = 3            # backdrop pixel scale (240x160 -> 720x480 on a 720-wide screen)
var TICK_W = 7.0      # HP tick pitch (5 px tick + 2 px gap)
func _side_col(u: Unit) -> Color: return ALLY if u.team == 0 else FOE
func _side_edge(u: Unit) -> Color: return ALLY_EDGE if u.team == 0 else FOE_EDGE

## Framed GBA-style window: dark outline, side-coloured bevel, flat fill.
func _frame(col: Color, edge: Color, pos: Vector2, size: Vector2) -> ColorRect:
	var o = _rect(root, Color8(16, 12, 24), pos - Vector2(6, 6), size + Vector2(12, 12))
	var e = _rect(o, edge, Vector2(3, 3), size + Vector2(6, 6))
	_rect(e, edge.darkened(0.35), Vector2(3, size.y + 3), Vector2(size.x + 3, 3))   # lower bevel shadow
	var p = _rect(e, col, Vector2(3, 3), size)
	_rect(p, col.lightened(0.12), Vector2(0, 0), Vector2(size.x, 4))                 # top highlight
	return p

func _setup(a: Unit, d: Unit) -> void:
	_clear(); visible = true; spd = 2.0 if Settings.anim_fast else 1.0
	var vs = get_viewport().get_visible_rect().size
	W = maxf(720.0, vs.x); H = maxf(1100.0, vs.y)
	BS = maxi(3, int(W / 240.0)) if W <= 960.0 else 3
	root = Control.new(); add_child(root); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.gui_input.connect(func(e):
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed: _set_speed(4.0))
	bg = _rect(root, Color8(16, 20, 40), Vector2(-60, -60), Vector2(W + 120, H + 120))   # oversized so screen shake never shows the map
	# vertical stack: plates | arena (160*BS) | bottom panels | hint+skip, centred; never under a notch / status bar
	var plate_h = 100.0; var arena_h = 160.0 * BS; var hp_h = 232.0; var btn_h = 64.0
	var total = plate_h + 14 + arena_h + 14 + hp_h + 16 + btn_h
	var top = maxf(_safe_top() + 18.0, (H - total) * 0.45)
	var arena_y = top + plate_h + 14
	AY = arena_y + 130.0 * BS   # feet line = native y 130 of the 240x160 backdrop (on the platforms)
	SZ = RW
	# underlay (fills the sides when the screen is wider than the backdrop): sky bands + ground
	var g = GROUND.get(_ground_kind(), GROUND.grass)
	var sky_cols = [Color8(56, 96, 176), Color8(72, 120, 200), Color8(96, 148, 216), Color8(128, 172, 228)]
	var band = (arena_y + 104.0 * BS - arena_y) / sky_cols.size()
	for i in sky_cols.size(): _rect(root, sky_cols[i], Vector2(-60, arena_y + band * i), Vector2(W + 120, band + 1))
	_rect(root, g, Vector2(-60, arena_y + 104.0 * BS), Vector2(W + 120, 56.0 * BS))
	var bgt = bg_texture(_terrain_of(d), _ground_kind())
	if bgt:   # original 240x160 backdrop, integer scale, centred
		var bt = TextureRect.new(); root.add_child(bt); bt.texture = bgt; bt.mouse_filter = Control.MOUSE_FILTER_IGNORE; bt.name = "BattleBG"
		bt.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; bt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; bt.stretch_mode = TextureRect.STRETCH_SCALE
		bt.size = Vector2(240.0 * BS, 160.0 * BS); bt.position = Vector2(roundf((W - bt.size.x) * 0.5), arena_y)
	var dist = absi(a.cell.x - d.cell.x) + absi(a.cell.y - d.cell.y)
	var gap = 0.0 if dist <= 1 else 160.0   # ranged: units stand further apart (each on its own platform)
	var pw = W * 0.5 - 18.0
	for u in [a, d]:
		var right = _side_right(u, a, d)
		var off = minf(gap * 0.5 + RW * 0.78, W * 0.5 - RW * 0.6)
		var cx = W * 0.5 + off * (1 if right else -1)
		var pt = platform_texture(_terrain_of(u), _ground_kind())
		if pt:
			var plat = TextureRect.new(); root.add_child(plat); plat.texture = pt; plat.name = "PlatformR" if right else "PlatformL"; plat.mouse_filter = Control.MOUSE_FILTER_IGNORE
			plat.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; plat.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; plat.stretch_mode = TextureRect.STRETCH_SCALE
			plat.size = pt.get_size() * BS; plat.position = Vector2(roundf(cx - plat.size.x * 0.5), AY - 6.0 * BS)
		else:
			var pr = _rect(root, g.darkened(0.1), Vector2(cx - RW * 0.75, AY - 6), Vector2(RW * 1.5, 16)); _rect(pr, g.lightened(0.15), Vector2.ZERO, Vector2(RW * 1.5, 4))
		var shadow = _rect(root, Color(0, 0, 0, 0.28), Vector2(cx - RW * 0.36, AY - 4), Vector2(RW * 0.72, 8))
		shadow.name = "shadow"
		var rig = _make_rig(u, right)
		var lift = 40.0 if "flying" in u.tags() else 0.0
		rig.position = Vector2(cx - RW * 0.5, AY - RH - lift + 4)
		spr[u] = rig; home[u] = rig.position
		_pose(u, "ready")
		var fr = []
		if Sprites.user_sheet(u) != null and not poses.has(u):
			for i in 3: fr.append(Sprites.unit_frame(u, i))
		frames[u] = fr
		var px = W * 0.5 + 9.0 if right else 9.0
		var col = _side_col(u); var edge = _side_edge(u)
		# --- top plate: name + weapon icon (16x16 at 3x) + weapon name in its triangle colour
		var plate = _frame(col, edge, Vector2(px, top), Vector2(pw, plate_h)); plate.name = "Plate"
		var nm = _lbl(u.data.name, 32); plate.add_child(nm); nm.position = Vector2(14, 2)
		var w = u.weapon() if a.team != d.team else (u.staff() if u == a else null)
		var wname = w.name if w else "-"
		var wl = HBoxContainer.new(); plate.add_child(wl); wl.position = Vector2(10, 46); wl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wl.add_theme_constant_override("separation", 8)
		if w: var ic = Icons.rect(w, 48); ic.name = "WIcon"; wl.add_child(ic)
		var wlab = _lbl(wname, 26, Icons.tri_text(w, Color8(248, 240, 208))); wlab.name = "WName"; wl.add_child(wlab)
		# --- bottom panel
		var other = d if u == a else a
		var ow = other.weapon() if a.team != d.team else null
		var tv = WeaponData.triangle(w.type, ow.type) if (w and ow and not w.is_item() and not ow.is_item()) else 0
		var hp_y = arena_y + arena_h + 14
		var hb = _frame(col, edge, Vector2(px, hp_y), Vector2(pw, hp_h)); hb.name = "HPPanel"
		var sbw = 160.0; var sbx = (pw - sbw - 8) if right else 8.0   # HIT/DMG/CRT box on the outer edge (GBA)
		var sb = _rect(hb, col.darkened(0.45), Vector2(sbx, 10), Vector2(sbw, 112)); sb.name = "StatBox"
		_rect(sb, edge.darkened(0.2), Vector2(0, 0), Vector2(sbw, 2)); _rect(sb, edge.darkened(0.2), Vector2(0, 110), Vector2(sbw, 2))
		var sv = _stat_vals(u, a, d)
		var rows = [["HIT", sv[1]], ["DMG", sv[0]], ["CRT", sv[2]]]
		for ri in 3:
			var kl = _lbl(rows[ri][0], 24, Color8(232, 216, 152)); sb.add_child(kl); kl.position = Vector2(10, 4 + ri * 35)
			var vl = _lbl(rows[ri][1], 28); vl.name = "S_" + rows[ri][0]; sb.add_child(vl)
			vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; vl.size = Vector2(80, 34); vl.position = Vector2(sbw - 90, 1 + ri * 35)
		if sv[3]: var x2 = _lbl("×2", 22, Color8(255, 224, 64)); x2.name = "X2"; sb.add_child(x2); x2.position = Vector2(80, 40)
		var ix = 8.0 if right else sbw + 20.0   # inner area (toward the centre): ▲▼ and 특효
		if tv != 0:   # weapon triangle: ▲ advantage (gold) / ▼ disadvantage (grey)
			var ta = _lbl(("▲" if tv > 0 else "▼"), 52, Color8(255, 224, 64) if tv > 0 else Color8(176, 176, 196)); ta.name = "Tri"
			hb.add_child(ta); ta.position = Vector2(ix + 4, 0)
			var tt = _lbl("유리" if tv > 0 else "불리", 24, ta.get_theme_color("font_color")); hb.add_child(tt); tt.position = Vector2(ix + 70, 18)
		if a.team != d.team and w and not w.is_item() and BattleManager.is_effective(u, other):   # 특효 banner (real multiplier)
			var ef = _lbl("특효! ×%d" % BattleManager.EFF_MULT, 28, Color8(255, 80, 72)); ef.name = "Eff"
			hb.add_child(ef); ef.position = Vector2(ix + 4, 70)
		# HP: big number + segmented tick bar (1 tick = 1 HP, up to 30 per row)
		var hpk = _lbl("HP", 24, Color8(232, 216, 152)); hb.add_child(hpk); hpk.position = Vector2(12, 150)
		var num = _lbl("", 56); hb.add_child(num); num.position = Vector2(48, 128); num.name = "HPNum"
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; num.size = Vector2(76, 70)
		var mh = maxi(1, u.stats.hp); var per = 30; var nrows = mini(3, int(ceil(mh / float(per))))
		var bar_x = 134.0; var bar_w = pw - bar_x - 12.0
		TICK_W = floorf(bar_w / per)
		var th = 26.0 if nrows == 1 else (17.0 if nrows == 2 else 12.0)
		var bar_h = nrows * th + (nrows - 1) * 4 + 8
		var back = _rect(hb, Color8(16, 12, 24), Vector2(bar_x, 132 + (82 - bar_h) * 0.5), Vector2(TICK_W * mini(mh, per) + 6, bar_h)); back.name = "HPBar"
		var ticks = []
		for i in mini(mh, per * 3):
			var r = i / per; var c = i % per
			ticks.append(_rect(back, Color8(48, 44, 64), Vector2(4 + c * TICK_W, 4 + r * (th + 4)), Vector2(TICK_W - 2, th)))
		bars[u] = [ticks, null, num]
	flash = _rect(root, Color(1, 1, 1, 0), Vector2(-60, -60), Vector2(W + 120, H + 120))
	var by = arena_y + arena_h + 14 + hp_h + 16
	var hint = _lbl("화면을 누르면 빨리 감기", 20, Color8(200, 204, 224)); root.add_child(hint); hint.position = Vector2(20, by + 18)
	skip_btn = Button.new(); skip_btn.text = "건너뛰기 ▶▶"; skip_btn.name = "CombatSkip"; skip_btn.add_theme_font_size_override("font_size", 26)
	root.add_child(skip_btn); skip_btn.size = Vector2(220, 60); skip_btn.position = Vector2(W - 236, by)
	skip_btn.pressed.connect(func(): _set_speed(12.0))
	_idle_loop()

## Top inset (notch / status bar) in viewport units; 0 where the platform reports none.
func _safe_top() -> float:
	var ss = DisplayServer.screen_get_size(); var sa = DisplayServer.get_display_safe_area()
	var vs = get_viewport().get_visible_rect().size
	if ss.y <= 0 or sa.size.y <= 0: return 0.0
	return clampf(sa.position.y * vs.y / float(ss.y), 0.0, 200.0)

## [DMG, HIT, CRT, doubles] strings for the panel (captured before the exchange).
func _stat_vals(u: Unit, a: Unit, d: Unit) -> Array:
	var f: Dictionary = BattleManager.pre_fc
	if a.team == d.team or f.is_empty(): return ["--", "--", "--", false]
	var p = "atk_" if u == a else "def_"
	if int(f.get(p + "dmg", -1)) < 0: return ["--", "--", "--", false]
	return [str(f[p + "dmg"]), str(f[p + "hit"]), str(f[p + "crit"]), bool(f.get(p + "x2", false))]

const MOUNTED = ["소셜나이트", "비룡기사", "드래곤마스터", "성기사", "팔라딘", "발키리", "그레이트나이트", "레인저", "메이지나이트", "드래곤나이트", "그림자 기병", "그림자 비룡", "그림자 기사", "그림자 비룡기사"]
const POSES = ["ready", "attack", "hit", "dodge"]
static var _sil: Shader
static var _exists = {}
static func _has(path: String) -> bool:
	if not _exists.has(path): _exists[path] = ResourceLoader.exists(path)
	return _exists[path]

## Pose images: assets/battle/<이름@클래스 | 이름 | 클래스>/<pose>.png. Missing poses fall back to ready, then to the map sprite rig.
static func pose_set(u: Unit) -> Dictionary:
	for id in [u.data.name + "@" + u.unit_class.name, u.data.name, u.unit_class.name]:
		var got = {}
		for p in POSES:
			var path = "res://assets/battle/%s/%s.png" % [id, p]
			if _has(path): got[p] = load(path)
		if got.has("ready"): return got
	return {}

## Backdrop (assets/battle/bg, 240x160 originals): the defender's terrain picks a scene, else the map's ground.
const BG_OF_TERRAIN = {"forest": "forest", "mountain": "mountain", "fort": "fort", "throne": "castle", "pillar": "castle", "light": "castle", "village": "village"}
const BG_OF_GROUND = {"grass": "plain", "snow": "snow", "sand": "desert", "castle": "castle"}
static func bg_texture(terrain: String, ground: String) -> Texture2D:
	var keys = []
	if terrain != "": keys.append(terrain); keys.append(BG_OF_TERRAIN.get(terrain, ""))
	keys.append(ground); keys.append(BG_OF_GROUND.get(ground, "plain")); keys.append("plain")
	for k in keys:
		var path = "res://assets/battle/bg/%s.png" % k
		if k != "" and _has(path): return load(path)
	return null

## Platform under each combatant (assets/battle/platform, 64x16), from that unit's own tile.
const PLAT_OF_TERRAIN = {"forest": "forest", "mountain": "rock", "fort": "stone", "throne": "floor", "pillar": "floor", "light": "floor", "bridge": "wood", "village": "grass"}
const PLAT_OF_GROUND = {"grass": "grass", "snow": "snow", "sand": "sand", "castle": "floor"}
static func platform_texture(terrain: String, ground: String) -> Texture2D:
	var k = PLAT_OF_TERRAIN.get(terrain, PLAT_OF_GROUND.get(ground, "grass"))
	if ground == "snow" and k in ["grass", "forest"]: k = "snow"
	if ground == "sand" and k == "grass": k = "sand"
	var path = "res://assets/battle/platform/%s.png" % k
	return load(path) if _has(path) else null

func _sil_mat(col: Color) -> ShaderMaterial:
	if _sil == null:
		_sil = Shader.new(); _sil.code = "shader_type canvas_item;\nuniform vec4 tint : source_color;\nvoid fragment() { COLOR = vec4(tint.rgb, texture(TEXTURE, UV).a * tint.a); }"
	var m = ShaderMaterial.new(); m.shader = _sil; m.set_shader_parameter("tint", col); return m

func _sub(tex: Texture2D, r0: int, r1: int) -> Texture2D:
	if not (tex is AtlasTexture): return tex
	var a = AtlasTexture.new(); a.atlas = tex.atlas
	a.region = Rect2(tex.region.position + Vector2(0, r0), Vector2(tex.region.size.x, r1 - r0)); return a

## One drawable copy of the unit (main body, rim outline or aura all use this).
func _layer(u: Unit, mat: Material) -> Control:
	var c = Control.new(); c.mouse_filter = Control.MOUSE_FILTER_IGNORE; c.size = Vector2(RW, RH)
	var add = func(tex: Texture2D, pos: Vector2, size: Vector2, r0: int, r1: int):
		var tr = TextureRect.new(); tr.texture = tex; tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE; tr.position = pos; tr.size = size; tr.material = mat; c.add_child(tr)
		if not parts.has(u): parts[u] = []
		parts[u].append([tr, r0, r1])
	if poses.has(u):
		var t: Texture2D = poses[u].ready; var k = maxf(1.0, floorf(RH / t.get_height()))
		var sz = t.get_size() * k
		add.call(t, Vector2((RW - sz.x) * 0.5, RH - sz.y), sz, -1, -1)
		return c
	var base = Sprites.unit_tex(u)
	if false and base is AtlasTexture:   # 2026-10-17: FE-silhouette sheets drawn whole (no head/body stretch) so battle = map art
		add.call(_sub(base, 0, 16), Vector2(0, 0), Vector2(32 * PX, 16 * PX), 0, 16)                     # head: PX x PX
		add.call(_sub(base, 16, 32), Vector2(0, 16 * PX), Vector2(32 * PX, 16 * (PX + 1)), 16, 32)       # body: PX x (PX+1)
	else:
		add.call(base, Vector2(0, RH - 32 * PX), Vector2(32 * PX, 32 * PX), 0, 32)
	return c

## Battle rig: [aura] + rim/outline x4 + [scarf] + body, mirrored for the left side, with a combat lean.
func _make_rig(u: Unit, right: bool) -> Control:
	var pset = pose_set(u)
	if not pset.is_empty(): poses[u] = pset
	var rig = Control.new(); rig.mouse_filter = Control.MOUSE_FILTER_IGNORE; rig.size = Vector2(RW, RH); rig.pivot_offset = Vector2(RW * 0.5, RH)
	root.add_child(rig)
	var inner = Control.new(); inner.name = "inner"; inner.mouse_filter = Control.MOUSE_FILTER_IGNORE; inner.size = Vector2(RW, RH)
	inner.pivot_offset = Vector2(RW * 0.5, RH); rig.add_child(inner)
	inner.scale.x = 1.0 if right else -1.0   # map sheets + pose images face LEFT (player side, GBA FE); left-side units are mirrored
	var foe = u.team != 0
	if u.boss:   # faint dark aura, slowly pulsing
		var aura = _layer(u, _sil_mat(Color(0.45, 0.1, 0.6, 0.45))); inner.add_child(aura)
		aura.pivot_offset = Vector2(RW * 0.5, RH); aura.scale = Vector2(1.16, 1.1)
		var at = aura.create_tween().set_loops(); at.tween_property(aura, "modulate:a", 0.35, 0.7); at.tween_property(aura, "modulate:a", 1.0, 0.7)
	var rim = Color(0.95, 0.16, 0.2, 0.9) if foe else Color(1.0, 0.93, 0.62, 0.95)   # enemies: red rim light; allies: crisp gold outline
	for o in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
		var l = _layer(u, _sil_mat(rim)); l.position = o; inner.add_child(l)
	if not foe and not poses.has(u) and not (u.unit_class.name in MOUNTED):   # heroic scarf flutter behind the shoulders
		var sc = Control.new(); sc.mouse_filter = Control.MOUSE_FILTER_IGNORE; inner.add_child(sc); sc.position = Vector2(RW * 0.64, 16 * PX + 2)
		var col = Color8(200, 40, 48)
		for i in 3:
			var seg = ColorRect.new(); seg.color = col.darkened(i * 0.12); seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			seg.size = Vector2(PX * 4.0, PX * 2.0 - (PX * 0.5 if i == 2 else 0.0)); seg.position = Vector2(PX * 3.5 * i, i * PX * 0.75); sc.add_child(seg)
		sc.pivot_offset = Vector2(0, PX)
		var st = sc.create_tween().set_loops(); st.tween_property(sc, "rotation", 0.28, 0.32).set_trans(Tween.TRANS_SINE); st.tween_property(sc, "rotation", -0.06, 0.32).set_trans(Tween.TRANS_SINE)
		auras[u] = sc
	var body = _layer(u, null); body.name = "body"; inner.add_child(body)
	if foe:
		body.modulate = Color(0.72, 0.62, 0.78) if u.has_tag("dark") else Color(0.82, 0.78, 0.86)   # darker, colder palette
	rig.set_meta("lean", (0.07 if foe else 0.025) * (-1.0 if right else 1.0))   # forward lean toward the opponent
	inner.rotation = rig.get_meta("lean")
	return rig

## Pose switch, timed by the motions: ready (rest) / attack (wind-up..blow) / hit (impact) / dodge (miss).
## With pose images: texture swap. Without: the map-sprite rig leans further in / recoils instead.
func _pose(u: Unit, p: String) -> void:
	if not spr.has(u) or not is_instance_valid(spr[u]): return
	var rig: Control = spr[u]; var inner: Control = rig.get_node("inner"); var lean: float = rig.get_meta("lean")
	rig.set_meta("pose", p)
	if poses.has(u):
		var t: Texture2D = poses[u].get(p, poses[u].ready)
		for pr in parts.get(u, []): pr[0].texture = t
		inner.rotation = 0.0
		return
	match p:
		"attack": inner.rotation = lean * 2.2
		"hit": inner.rotation = -lean * 1.6
		"dodge": inner.rotation = -lean * 0.8
		_: inner.rotation = lean

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
			if poses.has(u) or not is_instance_valid(spr[u]) or frames.get(u, []).size() < 2: continue
			var f: Texture2D = frames[u][k % frames[u].size()]
			for pr in parts.get(u, []):
				if is_instance_valid(pr[0]): pr[0].texture = _sub(f, pr[1], pr[2]) if pr[2] - pr[1] < 32 else f

func _set_hp(u: Unit, v: float) -> void:
	shown_hp[u] = v
	var b = bars[u]; var ratio = clampf(v / maxf(1.0, u.stats.hp), 0, 1); var lit = int(round(v))
	var on = Color8(120, 236, 112) if ratio > 0.5 else (Color8(248, 208, 56) if ratio > 0.25 else Color8(244, 72, 56))
	for i in b[0].size(): b[0][i].color = on if i < lit else Color8(48, 44, 64)
	b[2].text = str(maxi(0, lit))

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

func _center(u: Unit) -> Vector2: return home[u] + Vector2(RW * 0.5, RH * 0.5)

func _flash(col: Color, peak: float, dur: float) -> void:
	flash.color = Color(col.r, col.g, col.b, peak)
	var tw = _tw(); tw.tween_property(flash, "color:a", 0.0, dur)

## Weapon-type swing. Returns when the blow lands (target reaction follows).
func _attack_motion(x: Unit, y: Unit, w: WeaponData, crit: bool) -> void:
	var sx: Control = spr[x]; var hx = home[x]
	var dir = 1.0 if home[y].x > hx.x else -1.0
	var t = w.type if w else WeaponData.Type.SWORD
	_pose(x, "attack")
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
	var sx: Control = spr[x]
	_pose(x, "ready")
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
		_set_hp(u, start_hp.get(u, u.hp))
	await _wait(0.3)
	for ev in events:
		if ev.type == "heal":
			Sfx.play("heal"); _sparkle(ev.y)
			if spr.has(ev.x): spr[ev.x].modulate = Color(1.5, 1.6, 1.5); _pose(ev.x, "attack")
			_float("+%d" % ev.amt, _center(ev.y) + Vector2(-30, -SZ * 0.4), Color8(120, 255, 140))
			await _tick(ev.y, ev.y_hp)
			if spr.has(ev.x): spr[ev.x].modulate = Color.WHITE; _pose(ev.x, "ready")
			await _wait(0.3)
			continue
		var x: Unit = ev.x; var y: Unit = ev.y
		var sy: Control = spr[y]
		await _attack_motion(x, y, ev.get("w", null), ev.crit)
		var dir = 1.0 if home[y].x > home[x].x else -1.0
		var label_at = _center(y) + Vector2(-40, -SZ * 0.45)
		if ev.hit:
			Sfx.play("crit" if ev.crit else "hit")
			sy.modulate = Color(5, 5, 5); _pose(y, "hit")
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
			if ev.y_hp > 0: _pose(y, "ready")
			if shake.is_valid() and shake.is_running(): await shake.finished
		else:
			Sfx.play("miss"); _float("MISS", label_at, Color8(190, 214, 255), 52); _pose(y, "dodge")
			var dodge = _tw(); dodge.tween_property(sy, "position:x", home[y].x + dir * 56, 0.09).set_trans(Tween.TRANS_QUAD)
			dodge.tween_property(sy, "position:x", home[y].x, 0.16)
			_return(x)
			await dodge.finished
			_pose(y, "ready")
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

## HP drains tick by tick (GBA-style segmented bar + number).
func _tick(u: Unit, to_hp: int) -> void:
	var from = shown_hp.get(u, float(u.hp))
	if abs(from - to_hp) < 0.5: return
	var b = bars[u]
	var tw = _tw(); tw.tween_method(func(v): _set_hp(u, v), from, float(to_hp), clampf(abs(from - to_hp) * 0.04, 0.2, 0.7))
	await tw.finished

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
