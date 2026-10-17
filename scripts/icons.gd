class_name Icons extends RefCounted
## Procedural 16x16 GBA-style weapon icons: one shape per weapon type, tinted per weapon (iron/steel/silver/
## killer/brave/effective/magic...). Cached ImageTextures, nearest filtering.
## Legend: k outline, m metal (tint), l highlight (tint light), h handle, g gold guard, p page, r red, s gem
const SHAPES = {
	0: ["..............kk", ".............kmk", "............kmlk", "...........kmlk.", "..........kmlk..", ".........kmlk...",
		"........kmlk....", ".......kmlk.....", "..kk..kmlk......", "..kgkkmlk.......", "...kggmk........", "....kgk.........",
		"...khkgk........", "..khk.kgk.......", ".khk...kk.......", ".kk.............", ],
	1: ["...........kkkkk", "..........klllmk", "..........kllmk.", ".........kmmmkk.", "........kgkkk...", "........khk.....",
		".......khk......", "......khk.......", ".....khk........", "....khk.........", "...khk..........", "..khk...........",
		".khk............", "khk.............", "kk..............", "................"],
	2: ["................", ".....kkkk.......", "....kmmllk......", "...kmmmlllk.....", "...kmmmllkhk....", "...kmmmlkhk.....",
		"....kmmkhk......", ".....kkhk.......", "......khk.......", ".....khk........", "....khk.........", "...khk..........",
		"..khk...........", ".khk............", ".kk.............", "................"],
	3: ["...kkk..........", "..khhhk.........", ".khk..kk........", ".kk....mk.......", "kh......mk......", "kh.......mk.....",
		"kh........mk....", "kh.........mk...", "kh........mk....", "kh.......mk.....", "kh......mk......", ".kk....mk.......",
		".khk..kk........", "..khhhk.........", "...kkk..........", "................"],
	4: ["................", "..kkkkkkkkkk....", "..kmmmmmmmmlk...", "..kmpppppppmk...", "..kmpkkkkppmk...", "..kmpppppppmk...",
		"..kmpkkkkkpmk...", "..kmpppppppmk...", "..kmpssspppmk...", "..kmpsssspppmk..", "..kmpppppppmk...", "..kmmmmmmmmmk...",
		"..kllllllllllk..", "..kkkkkkkkkkkk..", "................", "................"],
	5: ["..........kkk...", ".........kslsk..", "........kssssk..", "........ksssk...", ".......kgkkk....", "......khk.......",
		".....khk........", "....khk.........", "...khk..........", "..khk...........", ".khk............", "khk.............",
		"kk..............", "................", "................", "................"],
	6: ["................", "....kkkk........", "...kgggkk.......", "..kgk..kgk......", "..kgk..kgk......", "...kgggkgk......",
		"....kkkgk.......", "......kgk.......", "......kgk.......", "......kggk......", "......kgkk......", "......kggk......",
		"......kgk.......", "......kkk.......", "................", "................"],
	7: ["................", "......kkkk......", "......khhk......", ".......kk.......", "......kmmk......", ".....kmllmk.....",
		"....kmmmlmmk....", "....krrrrrrk....", "...krrrrrrrrk...", "...krrsrrrrrk...", "...krrrrrrrrk...", "...krrrrrrrrk...",
		"....krrrrrrk....", ".....kkkkkk.....", "................", "................"],
	8: ["................", "................", "......kkkk......", ".....kssssk.....", "......kssk......", "....kkgkkgkk....",
		"...kgk....kgk...", "..kgk......kgk..", "..kgk......kgk..", "..kgk......kgk..", "...kgk....kgk...", "....kkggggkk....",
		"......kkkk......", "................", "................", "................"],
}
const TINTS = {  # [metal, light]
	"iron": [Color8(150, 150, 160), Color8(220, 220, 228)], "steel": [Color8(96, 110, 140), Color8(170, 186, 214)],
	"silver": [Color8(200, 214, 236), Color8(255, 255, 255)], "killer": [Color8(200, 48, 56), Color8(255, 150, 140)],
	"brave": [Color8(232, 176, 40), Color8(255, 240, 150)], "eff": [Color8(56, 168, 88), Color8(170, 240, 170)],
	"fire": [Color8(200, 72, 40), Color8(255, 170, 80)], "thunder": [Color8(200, 180, 40), Color8(255, 250, 140)],
	"wind": [Color8(64, 176, 160), Color8(180, 250, 230)], "holy": [Color8(220, 220, 255), Color8(255, 255, 255)],
	"boss": [Color8(110, 40, 140), Color8(210, 130, 255)], "bow": [Color8(170, 120, 60), Color8(230, 190, 120)],
}
static var _cache = {}
## Weapon triangle colour code (Pokemon-style): 검 BLUE > 도끼 RED > 창 GREEN > 검. Display only — math is WeaponData.triangle().
const TRI = {0: Color8(56, 120, 248), 2: Color8(232, 56, 48), 1: Color8(40, 184, 80)}   # Type.SWORD / AXE / LANCE
const TRI_NAME = {0: "파랑", 2: "빨강", 1: "초록"}
static func tri_color(w) -> Color:
	if w == null or w.is_item(): return Color(0, 0, 0, 0)
	return TRI.get(int(w.type), Color(0, 0, 0, 0))
## Brighter variant for text on dark panels.
static func tri_text(w, fallback = Color8(240, 228, 160)) -> Color:
	var c = tri_color(w); return c.lightened(0.35) if c.a > 0 else fallback

static func tint_for(w: WeaponData) -> String:
	var n = w.name
	if "그림자" in n or "바르가스" in n: return "boss"
	if w.brave: return "brave"
	if w.crit >= 30: return "killer"
	if not w.effective.is_empty() and w.type != WeaponData.Type.BOW: return "eff"
	if w.type == WeaponData.Type.TOME: return "thunder" if ("썬더" in n or "볼트" in n) else "fire"
	if w.type == WeaponData.Type.STAFF: return "holy"
	if w.magic: return "wind"
	if "은" in n: return "silver"
	if "강철" in n or w.heavy: return "steel"
	return "iron"

## Original 16x16 pixel icons (tools/make_icons.py -> assets/icons/<id>.png), one per weapon/item; the procedural
## shapes below stay as the fallback for any name without a drawn icon.
const ICON_ID = {
	"철단검": "dagger_iron", "강철단검": "dagger_steel", "철검": "sword_iron", "강철검": "sword_steel", "은검": "sword_silver",
	"레이피어": "rapier", "아머킬러": "armorslayer", "킬러소드": "sword_killer", "용사의 검": "sword_brave", "윈드소드": "windsword",
	"철창": "lance_iron", "강철창": "lance_steel", "은창": "lance_silver", "호스슬레이어": "horseslayer", "투창": "javelin",
	"킬러랜스": "lance_killer", "용사의 창": "lance_brave", "그림자 창 우르": "lance_boss",
	"철도끼": "axe_iron", "손도끼": "handaxe", "강철도끼": "axe_steel", "해커": "axe_killer", "해머": "hammer", "파멸의 도끼": "axe_boss",
	"철활": "bow_iron", "강철활": "bow_steel", "은활": "bow_silver", "킬러보우": "bow_killer",
	"파이어": "tome_fire", "엘파이어": "tome_elfire", "썬더": "tome_thunder", "볼트": "tome_bolt", "라이트": "tome_light",
	"힐": "staff_heal", "멘드": "staff_mend", "피지오": "staff_physic", "해제의 지팡이": "staff_unlock",
	"상처약": "vulnerary", "엘릭서": "elixir", "문 열쇠": "key_door", "상자 열쇠": "key_chest", "마스터 키": "key_master",
	"힘의 반지": "ring_str", "스피드링": "ring_spd", "여신의 상": "goddess", "드래곤 실드": "dragon_shield",
}
const TYPE_KEY = {0: "sword", 1: "lance", 2: "axe", 3: "bow"}
## Icon id for any weapon: drawn name first, else type + tier (iron/steel/silver/killer/brave/boss) or tome element.
static func icon_id(w: WeaponData) -> String:
	if ICON_ID.has(w.name): return ICON_ID[w.name]
	var t = int(w.type)
	if t == WeaponData.Type.TOME:
		if w.light or "라이트" in w.name: return "tome_light"
		if "썬더" in w.name or "볼트" in w.name: return "tome_thunder"
		if "윈드" in w.name: return "tome_wind"
		if "그림자" in w.name or "다크" in w.name: return "tome_dark"
		return "tome_fire"
	if t == WeaponData.Type.STAFF: return "staff_heal"
	if t == WeaponData.Type.ITEM: return {"key": "key_door", "potion": "vulnerary", "ring": "ring_str", "staff": "staff_unlock"}.get(w.fx().get("icon", "potion"), "vulnerary")
	var tier = tint_for(w)
	if tier == "eff" or tier == "wind": tier = "iron"
	if tier == "brave" and t == WeaponData.Type.BOW: tier = "silver"
	return "%s_%s" % [TYPE_KEY.get(t, "sword"), tier]

static func of(w: WeaponData) -> Texture2D:
	if w == null: return null
	var path = "res://assets/icons/%s.png" % icon_id(w)
	if _cache.has(path): return _cache[path]
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path); _cache[path] = tex; return tex
	if w.is_item():
		var ic = w.fx().get("icon", "potion")
		if ic == "staff": return make(5, "holy")
		return make({"key": 6, "potion": 7, "ring": 8}[ic], "silver" if w.name == "마스터 키" else "iron")
	return make(int(w.type), tint_for(w))

static func make(t: int, tint: String) -> Texture2D:
	var key = "%d_%s" % [t, tint]
	if _cache.has(key): return _cache[key]
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var tc = TINTS[tint]
	var pal = {"k": Color8(24, 16, 32), "m": tc[0], "l": tc[1], "h": Color8(120, 72, 32), "g": Color8(232, 184, 48),
		"p": Color8(240, 228, 196), "r": Color8(200, 40, 40), "s": tc[1]}
	if t == 3: pal["m"] = Color8(230, 230, 230); pal["h"] = tc[0] if tint != "iron" else Color8(150, 100, 50)  # bowstring white, limb tinted
	if t == 5: pal["s"] = tc[0]
	if TRI.has(t):   # coloured rounded tile behind sword/lance/axe so the triangle reads at a glance
		var bgc: Color = TRI[t].darkened(0.15); var edge: Color = TRI[t].lightened(0.25)
		for y in 16:
			for x in 16:
				var corner = (x in [0, 15] and y in [0, 1, 14, 15]) or (y in [0, 15] and x in [0, 1, 14, 15])
				if corner: continue
				img.set_pixel(x, y, edge if (x in [0, 15] or y in [0, 15]) else bgc)
	var rows: Array = SHAPES.get(t, SHAPES[0])
	for y in 16:
		for x in 16:
			var ch = rows[y][x] if x < rows[y].length() else "."
			if pal.has(ch): img.set_pixel(x, y, pal[ch])
	var tex = ImageTexture.create_from_image(img); _cache[key] = tex
	return tex

## TextureRect helper (nearest, scaled).
## Integer pixel scale only (16 -> 32/48/64) so the 16x16 art stays crisp: sizes snap down to a multiple of 16.
static func px_snap(px: int) -> int: return maxi(16, (px / 16) * 16)
static func rect(w: WeaponData, px = 32) -> TextureRect:
	px = px_snap(px)
	var r = TextureRect.new(); r.texture = of(w); r.custom_minimum_size = Vector2(px, px)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; r.size_flags_vertical = Control.SIZE_SHRINK_CENTER; r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

## Put a weapon icon on a Button.
static func on_button(b: Button, w: WeaponData) -> Button:
	if w == null: return b
	b.icon = of(w); b.expand_icon = true; b.add_theme_constant_override("icon_max_width", 48); b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return b
