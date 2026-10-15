class_name Icons extends RefCounted
## Procedural 16x16 GBA-style weapon icons: one shape per weapon type, tinted per weapon (iron/steel/silver/
## killer/brave/effective/magic...). Cached ImageTextures, nearest filtering.
## Legend: k outline, m metal (tint), l highlight (tint light), h handle, g gold guard, p page, r red, s gem
const SHAPES = {
	0: ["..............kk", ".............kmk", "............kmlk", "...........kmlk.", "..........kmlk..", ".........kmlk...",
		"........kmlk....", ".......kmlk.....", "..kk..kmlk......", "..kgkkmlk.......", "...kggmk........", "....kgk.........",
		"...khkgk........", "..khk.kgk.......", ".khk...kk.......", ".kk.............", ],
	1: ["............kkkk", "...........kllmk", "...........klmk.", "..........kmmkk.", ".........khkk...", "........khk.....",
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

static func of(w: WeaponData) -> Texture2D:
	if w == null: return null
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
	var rows: Array = SHAPES.get(t, SHAPES[0])
	for y in 16:
		for x in 16:
			var ch = rows[y][x] if x < rows[y].length() else "."
			if pal.has(ch): img.set_pixel(x, y, pal[ch])
	var tex = ImageTexture.create_from_image(img); _cache[key] = tex
	return tex

## TextureRect helper (nearest, scaled).
static func rect(w: WeaponData, px = 32) -> TextureRect:
	var r = TextureRect.new(); r.texture = of(w); r.custom_minimum_size = Vector2(px, px)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; r.size_flags_vertical = Control.SIZE_SHRINK_CENTER; r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

## Put a weapon icon on a Button.
static func on_button(b: Button, w: WeaponData) -> Button:
	if w == null: return b
	b.icon = of(w); b.expand_icon = true; b.add_theme_constant_override("icon_max_width", 44); b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return b
