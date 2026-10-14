class_name Grid extends Node2D
const CELL = 80
@export var size = Vector2i(9, 12)
var astar = AStarGrid2D.new()
var walls = {}
var forest = {}
var highlight_move = []
var highlight_attack = []

func _ready() -> void:
	astar.region = Rect2i(Vector2i.ZERO, size)
	astar.cell_size = Vector2(CELL, CELL)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.update()
	for w in [Vector2i(4, 4), Vector2i(4, 5), Vector2i(2, 7), Vector2i(6, 7)]:
		walls[w] = true; astar.set_point_solid(w)
	for f in [Vector2i(1, 5), Vector2i(1, 6), Vector2i(7, 5), Vector2i(7, 6), Vector2i(3, 8), Vector2i(5, 8)]: forest[f] = true

func is_forest(c: Vector2i) -> bool: return forest.has(c)
func in_bounds(c: Vector2i) -> bool: return astar.is_in_boundsv(c)
func cell_to_pos(c: Vector2i) -> Vector2: return Vector2(c) * CELL + Vector2(CELL, CELL) / 2
func pos_to_cell(p: Vector2) -> Vector2i: return Vector2i(floor(p.x / CELL), floor(p.y / CELL))

## BFS reachable cells within move, blocked by walls and enemy units (allies passable).
func movement_range(from: Vector2i, move: int, blockers: Dictionary, occupied: Dictionary) -> Array:
	var dist = {from: 0}; var q = [from]; var out = []
	while q.size() > 0:
		var c: Vector2i = q.pop_front()
		if not occupied.has(c) or c == from: out.append(c)
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if not in_bounds(n) or walls.has(n) or blockers.has(n) or dist.has(n): continue
			if dist[c] + 1 > move: continue
			dist[n] = dist[c] + 1; q.append(n)
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

func _draw() -> void:
	for x in size.x:
		for y in size.y:
			var r = Rect2(x * CELL, y * CELL, CELL, CELL)
			draw_rect(r, Color(0.35, 0.3, 0.25) if walls.has(Vector2i(x, y)) else (Color(0.12, 0.32, 0.15) if forest.has(Vector2i(x, y)) else Color(0.25, 0.45, 0.25)))
			draw_rect(r, Color(0, 0, 0, 0.3), false, 1)
	for c in highlight_attack: draw_rect(Rect2(Vector2(c) * CELL, Vector2(CELL, CELL)), Color(1, 0, 0, 0.3))
	for c in highlight_move: draw_rect(Rect2(Vector2(c) * CELL, Vector2(CELL, CELL)), Color(0, 0.4, 1, 0.4))
