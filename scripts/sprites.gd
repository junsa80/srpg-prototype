class_name Sprites extends RefCounted
## Unit/tile art: Kenney "Tiny Dungeon"/"Tiny Town" (CC0, see CREDITS.md) via AtlasTexture.
## Drop-in: if assets/units/<name>.png exists (32x32 frames, see ASSETS.md) it is used instead.
const TOWN = "res://assets/kenney/tiny_town.png"
const DUNGEON = "res://assets/kenney/tiny_dungeon.png"
const UNIT_TILE = {"아린": 85, "노아": 98, "리나": 112, "세라": 99, "엘리아": 100, "미라": 84, "카엘": 97, "루크": 86,
	"에일린": 88, "레온": 96, "그림자 병사": 87, "그림자 창병": 96, "그림자 궁병": 112, "그림자 술사": 111,
	"그림자 지휘관": 110, "바르가스": 109}
const TILE = {"plain": [TOWN, 0], "flower": [TOWN, 2], "grass2": [TOWN, 1], "tree": [TOWN, 16], "tree2": [TOWN, 28],
	"fort": [TOWN, 43], "floor": [TOWN, 109], "wall": [DUNGEON, 40], "roof": [TOWN, 64], "house": [TOWN, 65],
	"door": [DUNGEON, 45], "side": [DUNGEON, 34], "chest": [DUNGEON, 89], "chest_open": [DUNGEON, 91], "fence": [TOWN, 80]}
static var _atlas_cache = {}

static func atlas(sheet: String, idx: int) -> AtlasTexture:
	var key = sheet + str(idx)
	if _atlas_cache.has(key): return _atlas_cache[key]
	var a = AtlasTexture.new(); a.atlas = load(sheet); a.region = Rect2((idx % 12) * 16, (idx / 12) * 16, 16, 16)
	_atlas_cache[key] = a; return a

## User tiles override: assets/tiles/<kind>.png (32x32). Used for outdoor grass/flowers/forest.
static func tile_tex(kind: String) -> Texture2D:
	var p = "res://assets/tiles/%s.png" % kind
	if ResourceLoader.exists(p):
		if not _atlas_cache.has(p):  # wrap in AtlasTexture (direct CompressedTexture2D draw rendered blank in GL compat here)
			var tx = load(p); var a = AtlasTexture.new(); a.atlas = tx; a.region = Rect2(Vector2.ZERO, tx.get_size()); _atlas_cache[p] = a
		return _atlas_cache[p]
	var t = TILE[kind]; return atlas(t[0], t[1])

static func has_user_tile(kind: String) -> bool: return ResourceLoader.exists("res://assets/tiles/%s.png" % kind)

## User/drop-in sprite sheet: assets/units/<unit name or class>.png, N frames of 32x32 laid out horizontally.
static func user_sheet(u: Unit):
	var cands = [u.data.name + "@" + u.unit_class.name, u.data.name, u.unit_class.name]
	if u.team != 0: cands.insert(2, u.unit_class.name + "_적")   # generic enemy: red-palette class sheet (GBA team colours)
	for n in cands:   # 세라@성기사 = class-specific look
		var path = "res://assets/units/%s.png" % n
		if ResourceLoader.exists(path): return load(path)
	return null

static func unit_frame(u: Unit, frame: int) -> Texture2D:
	var sh = user_sheet(u)
	if sh == null: return unit_tex(u)
	var n = maxi(1, sh.get_width() / sh.get_height())
	var key = "%s#%d#%d" % [sh.resource_path, frame % n, n]
	if _atlas_cache.has(key): return _atlas_cache[key]
	var a = AtlasTexture.new(); a.atlas = sh; var h = sh.get_height(); a.region = Rect2((frame % n) * h, 0, h, h)
	_atlas_cache[key] = a; return a

static func unit_tex(u: Unit) -> Texture2D:
	if user_sheet(u) != null: return unit_frame(u, 0)
	var key = u.data.name if UNIT_TILE.has(u.data.name) else u.unit_class.name
	if UNIT_TILE.has(key): return atlas(DUNGEON, UNIT_TILE[key])
	return tex(u, 0)

## Generic NPC speakers -> shared portrait type (assets/portraits/npc_<type>.png). A speaker's own file always wins.
const NPC_ALIAS = {
	"촌장": "oldman", "노인": "oldman", "둥지지기 노인": "oldman", "어부": "oldman",
	"노파": "woman", "피난민": "woman", "어머니": "woman",
	"마을 사람": "youngman", "마을 청년": "youngman", "시민": "youngman", "대장장이": "youngman", "견습 마법사": "youngman", "설원 사냥꾼": "youngman", "갇힌 비룡 조련사": "youngman",
	"노르드 병사": "soldier", "경비병": "soldier",
	"수녀": "nun",
	"항구 상인": "merchant",
}
static func portrait(n: String) -> Texture2D:
	var path = "res://assets/portraits/%s.png" % n
	if n == "아린": path = "res://assets/portraits/arin-v3.png"
	if ResourceLoader.exists(path): return load(path)
	if NPC_ALIAS.has(n):   # missing npc_<type>.png -> null (no picture), never an error
		path = "res://assets/portraits/npc_%s.png" % NPC_ALIAS[n]
		if ResourceLoader.exists(path): return load(path)
	return null
## Procedural 16x16 GBA-style pixel sprites (generated in code; no external art). Cached ImageTextures.
## Legend: k outline, h hair, s skin, b body (team), d body dark, l light, w weapon, m metal, c cape, e eye
const BODY = [
	"................",
	".....kkkkk......",
	"....khhhhhk.....",
	"...khhhhhhhk....",
	"...khsssshhk....",
	"...kssesesk.....",
	"....ksssssk.....",
	"....kkbbbkk.....",
	"...kbblbbbdk....",
	"..ksbbblbbdsk...",
	"..ksbbbbbbdsk...",
	"...kddbbbddk....",
	"....kbbkbbk.....",
	"....kddkddk.....",
	"....kmmkmmk.....",
	"................",
]
const ARMOR = [
	"................",
	"....kkkkkkk.....",
	"...kmmmmmmmk....",
	"...kmhhhhhmk....",
	"...kmsesesmk....",
	"...kmssssmk.....",
	"..kkmmmmmmmkk...",
	".kbbmmbbbmmbbk..",
	".kbbmbblbbmbbk..",
	".kmbbbblbbbbmk..",
	".kmbbbbbbbbbmk..",
	"..kddbbbbbddk...",
	"...kbbbkbbbk....",
	"...kdddkdddk....",
	"...kmmmkmmmk....",
	"................",
]
const ROBE = [
	"................",
	"....kkkkkk......",
	"...khhhhhhk.....",
	"..khhhhhhhhk....",
	"..khsssssshk....",
	"...kseseesk.....",
	"...kssssssk.....",
	"...kkbbbbkk.....",
	"..kbbblbbbbk....",
	"..ksbblbbbsk....",
	"..kbbbbbbbbbk...",
	"..kbbbbbbbbbk...",
	".kdbbbbbbbbbdk..",
	".kddddddddddk...",
	"..kkkkkkkkkk....",
	"................",
]
## weapon overlays: list of [x, y, char]
static func _weapon_px(kind: String) -> Array:
	var p = []
	match kind:
		"sword":
			for i in 6: p.append([13, 3 + i, "l"])
			p.append([12, 9, "w"]); p.append([14, 9, "w"]); p.append([13, 10, "w"])
		"lance":
			for i in 13: p.append([13, 1 + i, "w"])
			p.append([13, 0, "l"]); p.append([12, 1, "l"]); p.append([14, 1, "l"])
		"bow":
			for i in 9: p.append([1 + (1 if i in [0, 8] else 0), 4 + i, "w"])
			for i in 9: p.append([3, 4 + i, "l"])
		"tome":
			p.append_array([[12, 9, "w"], [13, 9, "w"], [12, 10, "w"], [13, 10, "w"], [14, 9, "l"], [14, 10, "l"]])
		"staff":
			for i in 12: p.append([13, 2 + i, "w"])
			p.append_array([[12, 1, "l"], [13, 1, "l"], [14, 1, "l"], [13, 0, "l"]])
		"axe":
			for i in 10: p.append([13, 3 + i, "w"])
			p.append_array([[11, 3, "l"], [12, 3, "l"], [11, 4, "l"], [12, 4, "l"], [11, 5, "l"], [12, 5, "l"]])
		"dagger":
			p.append_array([[13, 8, "l"], [13, 9, "l"], [13, 10, "w"]])
	return p

const TEAM = [  # body, dark, light
	[Color8(56, 104, 232), Color8(24, 48, 144), Color8(152, 200, 255)],
	[Color8(216, 48, 48), Color8(120, 16, 32), Color8(255, 160, 136)],
	[Color8(144, 144, 144), Color8(88, 88, 88), Color8(200, 200, 200)],  # greyed
]
const SHADOW = [Color8(96, 40, 128), Color8(48, 16, 72), Color8(200, 120, 255)]
static var _cache = {}

static func hair_for(n: String) -> Color:
	var h = {"아린": Color8(168, 96, 40), "노아": Color8(40, 40, 56), "리나": Color8(96, 168, 64), "세라": Color8(248, 232, 168),
		"엘리아": Color8(248, 216, 96), "미라": Color8(176, 88, 200), "카엘": Color8(200, 200, 216), "루크": Color8(232, 120, 40),
		"에일린": Color8(232, 88, 120), "레온": Color8(120, 72, 40)}
	if h.has(n): return h[n]
	return Color8(32, 24, 40)

static func kind_for(u: Unit) -> Array:  # [body template, weapon kind]
	var w = u.weapon(); var c = u.unit_class.name
	var kind = "sword"
	if w:
		kind = {WeaponData.Type.SWORD: "sword", WeaponData.Type.LANCE: "lance", WeaponData.Type.AXE: "axe",
			WeaponData.Type.BOW: "bow", WeaponData.Type.TOME: "tome"}.get(w.type, "sword")
	elif u.staff(): kind = "staff"
	if c in ["도적", "어쌔신", "로그"]: kind = "dagger" if kind == "sword" else kind
	var body = "body"
	if c in ["아머나이트", "제네럴", "그레이트나이트", "그림자 창병", "그림자 지휘관"]: body = "armor"
	elif c in ["마법사", "세이지", "메이지나이트", "그림자 술사", "발키리"] or kind == "tome": body = "robe"
	return [body, kind]

## frame 0/1/2 idle bob; team 0 player 1 enemy; grey when acted.
static func tex(u: Unit, frame: int, grey = false) -> ImageTexture:
	var k = kind_for(u)
	var key = "%s|%s|%s|%d|%d|%s" % [u.data.name, k[0], k[1], u.team, frame, grey]
	if _cache.has(key): return _cache[key]
	var tmpl = {"body": BODY, "armor": ARMOR, "robe": ROBE}[k[0]]
	var pal = TEAM[2] if grey else (SHADOW if u.has_tag("dark") and not u.boss else TEAM[u.team])
	if u.boss and not grey: pal = [Color8(40, 24, 48), Color8(16, 8, 24), Color8(232, 56, 56)]
	var cols = {"k": Color8(16, 16, 24), "h": hair_for(u.data.name) if not grey else Color8(120, 120, 120),
		"s": Color8(248, 208, 168) if not u.has_tag("dark") else Color8(72, 56, 88), "b": pal[0], "d": pal[1], "l": pal[2],
		"w": Color8(136, 96, 48), "m": Color8(176, 184, 200), "e": Color8(24, 24, 48) if not u.has_tag("dark") else Color8(255, 64, 64),
		"c": pal[1]}
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var dy = 1 if frame == 1 else 0
	for y in 16:
		for x in 16:
			var ch = tmpl[y][x]
			if ch == ".": continue
			var ty = y + (dy if y < 12 else 0)
			if ty < 16: img.set_pixel(x, ty, cols[ch])
	for p in _weapon_px(k[1]):
		var c2 = cols[p[2]]
		if p[2] == "l": c2 = Color8(232, 232, 248) if k[1] != "tome" else pal[2]
		var yy = p[1] + dy
		if yy < 16: img.set_pixel(p[0], yy, c2)
	if frame == 2 and k[1] in ["tome", "staff"]: img.set_pixel(12, 8, Color8(255, 255, 160))
	var t = ImageTexture.create_from_image(img)
	_cache[key] = t
	return t

## Terrain tile textures (16x16).
static func tile(kind: String, variant: int) -> ImageTexture:
	var key = "tile|%s|%d" % [kind, variant]
	if _cache.has(key): return _cache[key]
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var rng = RandomNumberGenerator.new(); rng.seed = hash(key)
	var base = {"plain": Color8(112, 184, 72), "forest": Color8(64, 136, 56), "fort": Color8(168, 152, 128), "throne": Color8(168, 152, 128),
		"wall": Color8(104, 96, 104), "door": Color8(144, 88, 40), "side": Color8(80, 72, 88), "chest": Color8(112, 184, 72), "chest_open": Color8(112, 184, 72)}.get(kind, Color8(112, 184, 72))
	img.fill(base)
	match kind:
		"plain", "chest", "chest_open":
			for i in 6: img.set_pixel(rng.randi_range(0, 15), rng.randi_range(0, 15), Color8(152, 208, 96))
			for i in 3: img.set_pixel(rng.randi_range(0, 15), rng.randi_range(0, 15), Color8(88, 152, 56))
		"forest":
			for t in [[4, 3], [11, 5], [6, 10]]:
				for yy in range(-3, 4):
					for xx in range(-3, 4):
						if abs(xx) + abs(yy) <= 3 and t[0] + xx in range(16) and t[1] + yy in range(16):
							img.set_pixel(t[0] + xx, t[1] + yy, Color8(32, 96, 40) if yy < 1 else Color8(24, 72, 32))
				img.set_pixel(t[0], mini(15, t[1] + 4), Color8(104, 64, 32))
		"wall":
			for y in 16:
				for x in 16:
					if y % 4 == 0 or (x + (4 if (y / 4) % 2 else 0)) % 8 == 0: img.set_pixel(x, y, Color8(64, 56, 72))
		"fort", "throne":
			for y in 16:
				for x in 16:
					if x % 8 == 0 or y % 8 == 0: img.set_pixel(x, y, Color8(128, 112, 96))
			if kind == "throne":
				for y in range(3, 14):
					for x in range(4, 12): img.set_pixel(x, y, Color8(176, 32, 48) if y > 6 else Color8(216, 176, 48))
		"door":
			for y in 16:
				for x in 16:
					if x % 4 == 0: img.set_pixel(x, y, Color8(96, 56, 24))
			for y in range(6, 10): img.set_pixel(12, y, Color8(232, 200, 64))
		"side":
			for y in range(2, 14):
				for x in range(3, 13): img.set_pixel(x, y, Color8(32, 24, 40))
	if kind == "chest" or kind == "chest_open":
		for y in range(6, 13):
			for x in range(3, 13): img.set_pixel(x, y, Color8(176, 112, 32) if kind == "chest" else Color8(96, 64, 32))
		for x in range(3, 13): img.set_pixel(x, 8, Color8(232, 200, 64))
		if kind == "chest": img.set_pixel(8, 9, Color8(255, 255, 160))
	var t = ImageTexture.create_from_image(img)
	_cache[key] = t
	return t
