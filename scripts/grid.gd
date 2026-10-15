class_name Grid extends Node2D
## Square grid with ASCII-map terrain. Legend:
##  . plain  # wall  F forest  T fort  H throne  D locked door  C chest  S side door (reinforcement spawn)
const CELL = 80
const TERRAIN = {  # def, avo, heal% per turn
	"forest": [0, 20, 0], "fort": [2, 20, 20], "throne": [2, 20, 20],
}
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
	size = Vector2i(rows[0].length(), rows.size()); walls = {}; terrain = {}; forest = {}; interior = {}
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

func open_door(c: Vector2i) -> void:
	walls.erase(c); terrain.erase(c); astar.set_point_solid(c, false); queue_redraw()

func open_chest(c: Vector2i) -> void:
	terrain[c] = "chest_open"; queue_redraw()

func is_forest(c: Vector2i) -> bool: return forest.has(c)
func terrain_bonus(c: Vector2i) -> Array: return TERRAIN.get(terrain.get(c, ""), [0, 0, 0])
func in_bounds(c: Vector2i) -> bool: return astar.is_in_boundsv(c)
func cell_to_pos(c: Vector2i) -> Vector2: return Vector2(c) * CELL + Vector2(CELL, CELL) / 2
func pos_to_cell(p: Vector2) -> Vector2i: return Vector2i(floor(p.x / CELL), floor(p.y / CELL))
func pixel_size() -> Vector2: return Vector2(size) * CELL

## BFS reachable cells within move, blocked by walls and enemy units (allies passable).
func movement_range(from: Vector2i, move: int, blockers: Dictionary, occupied: Dictionary) -> Array:
	var dist = {from: 0}; var q = [from]; var out = []
	while q.size() > 0:
		var c: Vector2i = q.pop_front()
		if not occupied.has(c) or c == from: out.append(c)
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if not in_bounds(n) or walls.has(n) or blockers.has(n) or dist.has(n): continue
			var cost = 2 if forest.has(n) else 1
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

func _draw() -> void:
	var f = Unit.FONT
	for x in size.x:
		for y in size.y:
			var c = Vector2i(x, y); var r = Rect2(x * CELL, y * CELL, CELL, CELL)
			var t = terrain.get(c, "")
			var v = (x * 7 + y * 13) % 11
			var indoor = interior.has(c)
			draw_texture_rect(Sprites.tile_tex("floor" if indoor else ("flower" if v == 0 else ("grass2" if v == 3 else "plain"))), r, false)
			if walls.has(c) and t != "door": draw_texture_rect(Sprites.tile_tex("house" if outdoor_walls else "wall"), r, false)
			match t:
				"forest":
					if Sprites.has_user_tile("forest"): draw_texture_rect(Sprites.tile_tex(["forest", "forest2", "forest3"][v % 3]), r, false)
					else: draw_texture_rect(Sprites.tile_tex("tree" if v % 2 else "tree2"), r, false)
				"fort": draw_texture_rect(Sprites.tile_tex("fort"), r, false)
				"throne":
					draw_rect(r.grow(-10), Color8(160, 24, 40)); draw_rect(Rect2(r.position + Vector2(22, 8), Vector2(36, 30)), Color8(216, 176, 48))
					draw_rect(r.grow(-10), Color8(248, 216, 96), false, 3)
				"door", "side", "chest", "chest_open": draw_texture_rect(Sprites.tile_tex(t), r, false)
	for c in danger: draw_rect(Rect2(Vector2(c) * CELL, Vector2(CELL, CELL)), Color(0.75, 0.1, 0.75, 0.3))
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
	if cursor.x >= 0 or not warnings.is_empty(): queue_redraw()

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
