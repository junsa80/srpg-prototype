class_name Grid extends Node2D
## Square grid with ASCII-map terrain. Legend:
##  . plain  # wall  F forest  T fort  H throne  D locked door  C chest  S side door (reinforcement spawn)
##  ~ river (flyers only)  = bridge  ^ mountain  V village  X cracked wall (breakable)  E escape point  R ruins/pillar
const CELL = 80
const TERRAIN = {  # def, avo, heal% per turn
	"forest": [0, 20, 0], "fort": [2, 20, 20], "throne": [2, 20, 20], "mountain": [1, 30, 0], "village": [0, 10, 0],
	"bridge": [0, 0, 0], "pillar": [1, 20, 0],
}
## Ground move cost by terrain for walkers (flyers always 1, can cross river/walls-of-water).
const COST = {"forest": 2, "mountain": 3, "pillar": 2}
var theme = ""     # user tile set per map ("snow" ch5, "castle" ch6): assets/tiles/<theme>_<kind>.png
var ground = "grass"   # grass / snow / sand / castle — set per map
var water = {}         # river cells (impassable for walkers)
@export var size = Vector2i(9, 12)
var astar = AStarGrid2D.new()
var walls = {}
var terrain = {}       # cell -> "forest"/"fort"/"throne"/"door"/"chest"/"side"
var interior = {}      # indoor floor cells (fort maps)
var outdoor_walls = true
var forest = {}        # kept for older code/tests (forest cells)
var highlight_move = []
var highlight_attack = []
var highlight_heal = []
var warnings = []      # cells showing reinforcement warning
var danger = []        # enemy threat cells (danger zone toggle)
var arrow: Array = []  # movement path cells
var cursor = Vector2i(-1, -1)
var t_anim = 0.0

func _ready() -> void:
	if astar.region.size == Vector2i.ZERO: _rebuild()

func load_map(rows: Array) -> void:
	size = Vector2i(rows[0].length(), rows.size()); walls = {}; terrain = {}; forest = {}; interior = {}; water = {}
	for y in rows.size():
		for x in rows[y].length():
			var c = Vector2i(x, y)
			match rows[y][x]:
				"#": walls[c] = true
				"F": terrain[c] = "forest"; forest[c] = true
				"T": terrain[c] = "fort"
				"H": terrain[c] = "throne"
				"D": terrain[c] = "door"; walls[c] = true
				"C": terrain[c] = "chest"
				"S": terrain[c] = "side"
				"~": terrain[c] = "river"; water[c] = true
				"=": terrain[c] = "bridge"
				"^": terrain[c] = "mountain"
				"V": terrain[c] = "village"
				"X": terrain[c] = "crack"; walls[c] = true
				"E": terrain[c] = "escape"
				"R": terrain[c] = "pillar"
	# indoor = enclosed region above the first all-wall row containing a gap (fort maps start with a wall border)
	outdoor_walls = rows[0].count("#") < rows[0].length()
	if not outdoor_walls:
		var gate_row = -1
		for y in rows.size():
			if rows[y].begins_with("#####"): gate_row = y; break
		for y in range(gate_row + 1 if gate_row >= 0 else 0):
			for x in size.x:
				if not walls.has(Vector2i(x, y)): interior[Vector2i(x, y)] = true
	_rebuild(); queue_redraw()

func _rebuild() -> void:
	astar.region = Rect2i(Vector2i.ZERO, size)
	astar.cell_size = Vector2(CELL, CELL)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.update()
	for w in walls: astar.set_point_solid(w)
	for w in water: astar.set_point_solid(w)

func open_door(c: Vector2i) -> void:
	walls.erase(c); terrain.erase(c); astar.set_point_solid(c, false); queue_redraw()

func break_wall(c: Vector2i) -> void: open_door(c)

func ruin_village(c: Vector2i) -> void: terrain[c] = "ruin"; queue_redraw()
func visit_village(c: Vector2i) -> void: terrain[c] = "village_done"; queue_redraw()

func open_chest(c: Vector2i) -> void:
	terrain[c] = "chest_open"; queue_redraw()

func is_forest(c: Vector2i) -> bool: return forest.has(c)
func terrain_bonus(c: Vector2i) -> Array: return TERRAIN.get(terrain.get(c, ""), [0, 0, 0])
func in_bounds(c: Vector2i) -> bool: return astar.is_in_boundsv(c)
func cell_to_pos(c: Vector2i) -> Vector2: return Vector2(c) * CELL + Vector2(CELL, CELL) / 2
func pos_to_cell(p: Vector2) -> Vector2i: return Vector2i(floor(p.x / CELL), floor(p.y / CELL))
func pixel_size() -> Vector2: return Vector2(size) * CELL

## BFS reachable cells within move, blocked by walls and enemy units (allies passable).
func movement_range(from: Vector2i, move: int, blockers: Dictionary, occupied: Dictionary, fly = false) -> Array:
	var dist = {from: 0}; var q = [from]; var out = []
	while q.size() > 0:
		var c: Vector2i = q.pop_front()
		if not occupied.has(c) or c == from: out.append(c)
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if not in_bounds(n) or blockers.has(n) or dist.has(n): continue
			if walls.has(n): continue
			if water.has(n) and not fly: continue
			var cost = 1 if fly else COST.get(terrain.get(n, ""), 1)
			if dist[c] + cost > move: continue
			dist[n] = dist[c] + cost; q.append(n)
	return out

func attack_range(cells: Array, min_r: int, max_r: int) -> Array:
	var set = {}
	for c in cells:
		for dx in range(-max_r, max_r + 1):
			for dy in range(-max_r, max_r + 1):
				var dd: int = abs(dx) + abs(dy)
				var t: Vector2i = c + Vector2i(dx, dy)
				if dd >= min_r and dd <= max_r and in_bounds(t): set[t] = true
	return set.keys()

func path(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	return astar.get_id_path(a, b)

const COLORS = {"forest": Color(0.12, 0.32, 0.15), "fort": Color(0.55, 0.5, 0.42), "throne": Color(0.6, 0.15, 0.2),
	"door": Color(0.45, 0.28, 0.1), "chest": Color(0.25, 0.45, 0.25), "chest_open": Color(0.25, 0.45, 0.25), "side": Color(0.3, 0.3, 0.35)}

## Themed tile if the map has a theme and the file exists, else null.
func _tt(kind: String):
	if theme != "" and Sprites.has_user_tile(theme + "_" + kind): return Sprites.tile_tex(theme + "_" + kind)
	return null

func _draw() -> void:
	var f = Unit.FONT
	for x in size.x:
		for y in size.y:
			var c = Vector2i(x, y); var r = Rect2(x * CELL, y * CELL, CELL, CELL)
			var t = terrain.get(c, "")
			var v = (x * 7 + y * 13) % 11
			var indoor = interior.has(c)
			var fl = _tt("floor2" if v % 4 == 0 else "floor")
			var sp = _tt(["plain", "plain2", "plain3"][v % 3]) if not indoor else null
			if (indoor or ground == "castle") and fl: draw_texture_rect(fl, r, false)
			elif indoor or ground == "castle": draw_texture_rect(Sprites.tile_tex("floor"), r, false)
			elif ground == "snow" and sp: draw_texture_rect(sp, r, false)
			elif ground == "snow":
				draw_rect(r, Color8(226, 234, 244) if v % 3 else Color8(208, 220, 236))
				if v == 0: draw_circle(r.position + Vector2(20, 24), 3, Color.WHITE)
			elif ground == "sand":
				draw_rect(r, Color8(226, 196, 130) if v % 3 else Color8(214, 182, 116))
				if v == 2: draw_line(r.position + Vector2(14, 50), r.position + Vector2(44, 46), Color8(190, 156, 96), 3)
			else: draw_texture_rect(Sprites.tile_tex("flower" if v == 0 else ("grass2" if v == 3 else "plain")), r, false)
			var vw = ("village_wall2" if v % 2 else "village_wall") if outdoor_walls and ground == "grass" and theme == "" and Sprites.has_user_tile("village_wall") else ""
			if walls.has(c) and t != "door" and t != "crack": draw_texture_rect(_tt("wall") if _tt("wall") else Sprites.tile_tex(vw if vw != "" else ("house" if outdoor_walls else "wall")), r, false)
			if walls.has(c) and t != "door" and _tt("wall"):   # phone readability: walls darker than the stone floor
				draw_rect(r, Color(0.04, 0.02, 0.1, 0.5)); draw_rect(r, Color8(20, 14, 30), false, 2)
			elif walls.has(c) and t == "crack": draw_texture_rect(Sprites.tile_tex("house" if outdoor_walls else "wall"), r, false)
			var th = {"throne": "throne", "mountain": "rock", "pillar": "pillar"}
			if th.has(t) and _tt(th[t]) != null:
				draw_texture_rect(_tt(th[t]), r, false); continue
			if t == "mountain" and ground == "grass" and theme == "" and Sprites.has_user_tile("village_rock"):
				draw_texture_rect(Sprites.tile_tex("village_rock"), r, false); continue
			match t:
				"forest":
					if _tt("tree"): draw_texture_rect(_tt("tree" if v % 2 else "tree2"), r, false)
					elif Sprites.has_user_tile("forest"): draw_texture_rect(Sprites.tile_tex(["forest", "forest2", "forest3"][v % 3]), r, false)
					else: draw_texture_rect(Sprites.tile_tex("tree" if v % 2 else "tree2"), r, false)
				"fort": draw_texture_rect(_tt("fort") if _tt("fort") else Sprites.tile_tex("fort"), r, false)
				"throne":
					draw_rect(r.grow(-10), Color8(160, 24, 40)); draw_rect(Rect2(r.position + Vector2(22, 8), Vector2(36, 30)), Color8(216, 176, 48))
					draw_rect(r.grow(-10), Color8(248, 216, 96), false, 3)
				"door", "side", "chest", "chest_open": draw_texture_rect(_tt(t) if _tt(t) else Sprites.tile_tex(t), r, false)
				"river":
					draw_rect(r, Color8(56, 112, 200))
					var ph = t_anim * 2.0 + x + y
					for i in 3: draw_line(r.position + Vector2(10 + i * 22, 30 + sin(ph + i) * 6), r.position + Vector2(24 + i * 22, 30 + sin(ph + i) * 6), Color8(150, 200, 255), 3)
				"bridge":
					draw_rect(r, Color8(56, 112, 200)); draw_rect(r.grow_individual(0, -8, 0, -8), Color8(150, 104, 56))
					for i in 5: draw_line(r.position + Vector2(i * 16 + 8, 8), r.position + Vector2(i * 16 + 8, CELL - 8), Color8(96, 64, 32), 2)
				"mountain":
					draw_colored_polygon(PackedVector2Array([r.position + Vector2(6, 72), r.position + Vector2(40, 10), r.position + Vector2(74, 72)]), Color8(130, 112, 96))
					draw_colored_polygon(PackedVector2Array([r.position + Vector2(30, 28), r.position + Vector2(40, 10), r.position + Vector2(50, 28)]), Color8(240, 240, 250) if ground == "snow" else Color8(176, 160, 140))
					draw_polyline(PackedVector2Array([r.position + Vector2(6, 72), r.position + Vector2(40, 10), r.position + Vector2(74, 72)]), Color8(60, 48, 40), 3)
				"village", "village_done":
					var vk = "village_done" if t == "village_done" else "village_house"
					draw_texture_rect(Sprites.tile_tex(vk if ground == "grass" and Sprites.has_user_tile(vk) else "house"), r, false)
					if t == "village": draw_rect(r.grow(-3), Color8(255, 216, 96), false, 3)
				"ruin":
					draw_rect(r.grow(-12), Color8(70, 56, 48)); draw_line(r.position + Vector2(14, 14), r.position + Vector2(66, 66), Color8(30, 20, 20), 4)
				"crack":
					draw_line(r.position + Vector2(40, 6), r.position + Vector2(30, 34), Color8(20, 16, 20), 3); draw_line(r.position + Vector2(30, 34), r.position + Vector2(48, 52), Color8(20, 16, 20), 3)
					draw_line(r.position + Vector2(48, 52), r.position + Vector2(36, 76), Color8(20, 16, 20), 3)
				"escape":
					draw_rect(r.grow(-4), Color(0.2, 0.9, 0.4, 0.35)); draw_string(f, r.position + Vector2(8, 50), "탈출", HORIZONTAL_ALIGNMENT_CENTER, 64, 22, Color8(230, 255, 230))
				"pillar":
					draw_rect(Rect2(r.position + Vector2(24, 8), Vector2(32, 64)), Color8(180, 172, 160)); draw_rect(Rect2(r.position + Vector2(18, 4), Vector2(44, 10)), Color8(200, 192, 180))
	var dset = {}
	for c in danger: dset[c] = true
	for c in danger:   # all-enemy threat: purple fill + outer border (distinct from one enemy's red range)
		var r0 = Rect2(Vector2(c) * CELL, Vector2(CELL, CELL)); draw_rect(r0, Color(0.75, 0.1, 0.75, 0.3))
		var bc = Color(0.95, 0.35, 0.95, 0.9)
		if not dset.has(c + Vector2i(0, -1)): draw_line(r0.position, r0.position + Vector2(CELL, 0), bc, 3)
		if not dset.has(c + Vector2i(0, 1)): draw_line(r0.position + Vector2(0, CELL), r0.end, bc, 3)
		if not dset.has(c + Vector2i(-1, 0)): draw_line(r0.position, r0.position + Vector2(0, CELL), bc, 3)
		if not dset.has(c + Vector2i(1, 0)): draw_line(r0.position + Vector2(CELL, 0), r0.end, bc, 3)
	for c in highlight_attack: draw_rect(Rect2(Vector2(c) * CELL, Vector2(CELL, CELL)).grow(-2), Color(1, 0.15, 0.1, 0.4))
	for c in highlight_move: draw_rect(Rect2(Vector2(c) * CELL, Vector2(CELL, CELL)).grow(-2), Color(0.2, 0.5, 1, 0.5))
	for c in highlight_heal: draw_rect(Rect2(Vector2(c) * CELL, Vector2(CELL, CELL)), Color(0.2, 1, 0.3, 0.4))
	_draw_arrow()
	if cursor.x >= 0:  # animated FE-style corner cursor
		var p0 = Vector2(cursor) * CELL; var o = 4 + 4 * abs(sin(t_anim * 5.0)); var L = 18
		var col = Color8(255, 248, 200)
		for cn in [[Vector2(-o, -o), Vector2(1, 1)], [Vector2(CELL + o, -o), Vector2(-1, 1)], [Vector2(-o, CELL + o), Vector2(1, -1)], [Vector2(CELL + o, CELL + o), Vector2(-1, -1)]]:
			var q = p0 + cn[0]
			draw_line(q, q + Vector2(L * cn[1].x, 0), col, 5); draw_line(q, q + Vector2(0, L * cn[1].y), col, 5)
	for c in warnings:
		var p = Vector2(c) * CELL
		draw_rect(Rect2(p, Vector2(CELL, CELL)), Color(1, 0.2, 0.1, 0.55))
		draw_colored_polygon(PackedVector2Array([p + Vector2(40, 10), p + Vector2(70, 40), p + Vector2(40, 70)]), Color(1, 0.9, 0.1))
		draw_string(f, p + Vector2(4, 30), "증원!", HORIZONTAL_ALIGNMENT_LEFT, 76, 20, Color.WHITE)

func _process(dt: float) -> void:
	t_anim += dt
	if cursor.x >= 0 or not warnings.is_empty() or not water.is_empty(): queue_redraw()

func _draw_arrow() -> void:
	if arrow.size() < 2: return
	var pts = PackedVector2Array()
	for c in arrow: pts.append(cell_to_pos(c))
	draw_polyline(pts, Color8(16, 16, 24), 22); draw_polyline(pts, Color8(80, 168, 255), 14)
	var end = pts[pts.size() - 1]; var dir = (end - pts[pts.size() - 2]).normalized(); var n = Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([end + dir * 22, end - dir * 6 + n * 20, end - dir * 6 - n * 20]), Color8(80, 168, 255))

## A* path that ignores units but respects walls (for arrow/slide).
func move_path(a: Vector2i, b: Vector2i, allowed: Array) -> Array:
	# BFS restricted to allowed cells so the arrow matches the blue range
	var prev = {a: a}; var q = [a]; var allow = {}
	for c in allowed: allow[c] = true
	allow[a] = true
	while q.size() > 0:
		var c = q.pop_front()
		if c == b: break
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var nb = c + d
			if allow.has(nb) and not prev.has(nb): prev[nb] = c; q.append(nb)
	if not prev.has(b): return [a, b]
	var out = [b]
	while out[0] != a: out.push_front(prev[out[0]])
	return out
