# res://src/game/level/map_generator.gd
# Generates a random but terrain-reasonable level map as a map-JSON Dictionary.
#
# The output is compatible with:
#   - Level (which accepts an in-memory map via the optional map_data argument)
#   - the existing map JSON format under assets/map/*.json
#
# Generation guarantees:
#   - a solid indestructible border
#   - an interior lattice of indestructible pillars (classic bomberman grid)
#   - breakable blocks scattered so that the walkable area always stays connected
#   - monsters placed on reachable, non-adjacent cells with a per-monster max count
class_name MapGenerator
extends RefCounted

const EMPTY := 0
const WALL := 1
const BREAKABLE := 2

const DEFAULT_FLOOR_TYPE := "exploration"
const DEFAULT_FLOOR_NAME := "elem220"
const DEFAULT_WALL_NAME := "elem212"
const DEFAULT_INTERACTIVE := ["elem225", "elem226", "elem227"]


# Params (aligned with the level editor's generator_params):
#   width, height, seed, begin, finish, breakable_density,
#   floor_type, obstacle_type, floor_texture_pool, obstacle_pool,
#   interactive_pool, monster_pool (Array of String or {name,max}), monster_count_max
static func generate(params: Dictionary) -> Dictionary:
	var width := clampi(int(params.get("width", 21)), 5, 100)
	var height := clampi(int(params.get("height", 15)), 5, 100)

	var rng := RandomNumberGenerator.new()
	var seed_val = params.get("seed", null)
	if seed_val == null or int(seed_val) == 0:
		rng.randomize()
	else:
		rng.seed = int(seed_val)

	var floor_type := str(params.get("floor_type", DEFAULT_FLOOR_TYPE))
	var obstacle_type := str(params.get("obstacle_type", DEFAULT_FLOOR_TYPE))
	var floor_name := str(_pick(rng, _pool(params.get("floor_texture_pool", null), DEFAULT_FLOOR_NAME)))
	var wall_name := str(_pick(rng, _pool(params.get("obstacle_pool", null), DEFAULT_WALL_NAME)))
	var interactive_pool := _pool(params.get("interactive_pool", null), "")
	if interactive_pool.is_empty():
		interactive_pool = DEFAULT_INTERACTIVE.duplicate()

	var begin := _vec2i(params.get("begin", [1, 1]), Vector2i(1, 1))
	begin.x = clampi(begin.x, 1, width - 2)
	begin.y = clampi(begin.y, 1, height - 2)
	var finish := _vec2i(params.get("finish", [-1, -1]), Vector2i(-1, -1))

	var density := clampf(float(params.get("breakable_density", 0.25)), 0.0, 0.9)

	var monster_specs := _monster_specs(params.get("monster_pool", []), int(params.get("monster_count_max", 0)))

	var grid := _build_grid(width, height)
	var breakable_names := _place_breakables(grid, width, height, begin, density, interactive_pool, rng)
	var npcs := _place_monsters(grid, width, height, begin, monster_specs, rng)

	return _build_map_json(
		width, height, begin, finish,
		floor_type, floor_name, obstacle_type, wall_name, interactive_pool[0],
		grid, breakable_names, npcs
	)


static func _build_grid(width: int, height: int) -> Array:
	var grid: Array = []
	for x in range(width):
		var col: Array = []
		col.resize(height)
		for y in range(height):
			col[y] = EMPTY
		grid.append(col)
	for x in range(width):
		grid[x][0] = WALL
		grid[x][height - 1] = WALL
	for y in range(height):
		grid[0][y] = WALL
		grid[width - 1][y] = WALL
	# indestructible pillars at even-even interior coordinates form a connected lattice
	for x in range(2, width - 1, 2):
		for y in range(2, height - 1, 2):
			grid[x][y] = WALL
	return grid


static func _place_breakables(grid: Array, width: int, height: int, begin: Vector2i, density: float, pool: Array, rng: RandomNumberGenerator) -> Dictionary:
	var names: Dictionary = {}
	var candidates: Array = []
	for x in range(1, width - 1):
		for y in range(1, height - 1):
			if grid[x][y] != EMPTY:
				continue
			if abs(x - begin.x) <= 1 and abs(y - begin.y) <= 1:
				continue
			candidates.append(Vector2i(x, y))
	_shuffle(rng, candidates)
	var target := int(float(candidates.size()) * density)
	var placed := 0
	for cell in candidates:
		if placed >= target:
			break
		var c: Vector2i = cell
		grid[c.x][c.y] = BREAKABLE
		if _is_fully_connected(grid, width, height, begin):
			names[c] = str(_pick(rng, pool))
			placed += 1
		else:
			grid[c.x][c.y] = EMPTY
	return names


static func _place_monsters(grid: Array, width: int, height: int, begin: Vector2i, specs: Array, rng: RandomNumberGenerator) -> Array:
	var npcs: Array = []
	if specs.is_empty():
		return npcs
	var spawn_cells: Array = []
	for x in range(1, width - 1):
		for y in range(1, height - 1):
			if grid[x][y] != EMPTY:
				continue
			if abs(x - begin.x) + abs(y - begin.y) < 3:
				continue
			spawn_cells.append(Vector2i(x, y))
	_shuffle(rng, spawn_cells)
	for spec in specs:
		var name := str(spec.get("name", ""))
		var remain := int(spec.get("max", 0))
		while remain > 0 and not spawn_cells.is_empty():
			var cell: Vector2i = spawn_cells.pop_back()
			npcs.append({"name": name, "x": cell.x, "y": cell.y})
			remain -= 1
	return npcs


static func _is_fully_connected(grid: Array, width: int, height: int, begin: Vector2i) -> bool:
	var visited: Dictionary = {}
	var stack: Array = [begin]
	visited[begin] = true
	var count := 1
	while not stack.is_empty():
		var cur: Vector2i = stack.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nxt: Vector2i = cur + d
			if nxt.x < 0 or nxt.y < 0 or nxt.x >= width or nxt.y >= height:
				continue
			if visited.has(nxt):
				continue
			if grid[nxt.x][nxt.y] == EMPTY:
				visited[nxt] = true
				count += 1
				stack.append(nxt)
	var total := 0
	for x in range(width):
		for y in range(height):
			if grid[x][y] == EMPTY:
				total += 1
	return count == total


static func _build_map_json(width: int, height: int, begin: Vector2i, finish: Vector2i, floor_type: String, floor_name: String, obstacle_type: String, wall_name: String, default_breakable: String, grid: Array, breakable_names: Dictionary, npcs: Array) -> Dictionary:
	var wall_points: Array = []
	var breakable_points: Dictionary = {}
	for x in range(width):
		for y in range(height):
			var cell = grid[x][y]
			if cell == WALL:
				if x > 0 and y > 0 and x < width - 1 and y < height - 1:
					wall_points.append({"x": x, "y": y})
			elif cell == BREAKABLE:
				var nm := str(breakable_names.get(Vector2i(x, y), default_breakable))
				if not breakable_points.has(nm):
					breakable_points[nm] = []
				breakable_points[nm].append({"x": x, "y": y})

	var obstacle_entries: Array = []
	if not wall_points.is_empty():
		obstacle_entries.append({"type": obstacle_type, "name": wall_name, "points": wall_points})
	for nm in breakable_points.keys():
		obstacle_entries.append({"type": obstacle_type, "name": str(nm), "points": breakable_points[nm]})

	var border_squares: Array = [
		{"x1": 0, "y1": 0, "x2": width - 1, "y2": 0},
		{"x1": 0, "y1": height - 1, "x2": width - 1, "y2": height - 1},
		{"x1": 0, "y1": 0, "x2": 0, "y2": height - 1},
		{"x1": width - 1, "y1": 0, "x2": width - 1, "y2": height - 1},
	]

	return {
		"basic": {
			"name": "sandbox_generated",
			"width": width,
			"height": height,
			"scroll": [0, 0],
			"music": "",
			"begin": [begin.x, begin.y],
			"finish": [finish.x, finish.y],
		},
		"floors": [
			{"type": floor_type, "name": floor_name, "squares": [{"x1": 0, "y1": 0, "x2": width - 1, "y2": height - 1}]}
		],
		"floor": [],
		"obstacles": [
			{"type": obstacle_type, "name": wall_name, "squares": border_squares}
		],
		"obstacle": obstacle_entries,
		"districts": [
			{"square": {"x1": 0, "y1": 0, "x2": width - 1, "y2": height - 1}, "npcs": npcs}
		],
	}


static func _monster_specs(monster_pool, count_max: int) -> Array:
	var specs: Array = []
	if not (monster_pool is Array):
		return specs
	var default_max := count_max if count_max > 0 else 5
	for entry in monster_pool:
		if entry is Dictionary:
			var nm := str(entry.get("name", ""))
			var mx := int(entry.get("max", entry.get("count", default_max)))
			if nm != "":
				specs.append({"name": nm, "max": maxi(0, mx)})
		else:
			specs.append({"name": str(entry), "max": default_max})
	return specs


static func _pool(value, default_value) -> Array:
	if value is Array:
		var arr: Array = []
		for v in value:
			if v != null and str(v) != "":
				arr.append(str(v))
		if not arr.is_empty():
			return arr
	if default_value is Array:
		var out: Array = []
		for v in default_value:
			if v != null and str(v) != "":
				out.append(str(v))
		return out
	if default_value != null and str(default_value) != "":
		return [str(default_value)]
	return []


static func _pick(rng: RandomNumberGenerator, arr: Array):
	if arr.is_empty():
		return ""
	return arr[rng.randi_range(0, arr.size() - 1)]


static func _shuffle(rng: RandomNumberGenerator, arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


static func _vec2i(value, default: Vector2i) -> Vector2i:
	if value is Array:
		var arr: Array = value
		return Vector2i(int(arr[0]) if arr.size() > 0 else default.x, int(arr[1]) if arr.size() > 1 else default.y)
	if value is Vector2i:
		return value
	return default
