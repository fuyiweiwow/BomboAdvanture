# res://src/game/level/world_map_generator.gd
# Generates ONE continuous world map from a tree of themed zones.
#
# The key idea: zones are laid out on a 2D grid, but the *terrain* is generated
# once over the whole world — rooms + winding corridors + noise-thinned stone —
# so there are no per-zone walls or "doorways". Adjacent zones flow into each
# other seamlessly; a zone is only a logical region carrying a theme (floor
# tint, breakable set) and its monster spawns.
#
# Layout:
#   - zones are placed on a 2D cell grid (root near centre, children on free
#     sides of their parent) -> a tree
#   - one room is carved near each zone's centre, then the tree edges are joined
#     by *winding* corridors (midpoint-jittered L-bends), so rooms connect
#     organically rather than via straight spines
#   - value-noise thins the surrounding stone so it reads as natural rock
#   - a flood-fill guarantees the whole map is a single connected region
#
# Output is a single map JSON (Level.new compatible) plus zone metadata:
#   basic: width/height of the WHOLE world, begin at the root room centre
#   floor: per-zone floor points (theme tint)
#   obstacle: walls (per-zone wall tile) + breakables (per-zone breakable tile)
#   districts: per-zone monster spawns (world coords)
#   zones: { id, parent, children, ox, oy, w, h, cx, cy, theme_name }
class_name WorldMapGenerator
extends RefCounted

const EMPTY := 0
const STONE := 1
const BLOCK := 2

const ZW := 21
const ZH := 15


static func generate(params: Dictionary) -> Dictionary:
	var count := clampi(int(params.get("count", 5)), 1, 20)
	var seed_val := int(params.get("seed", 0))
	var rng := RandomNumberGenerator.new()
	if seed_val == 0:
		rng.randomize()
		seed_val = rng.randi_range(1, 999999999)
	else:
		rng.seed = seed_val

	var zw := clampi(int(params.get("zone_width", ZW)), 11, 60)
	var zh := clampi(int(params.get("zone_height", ZH)), 11, 40)

	# 1. tree + 2D grid layout
	var ids: Array = []
	for i in range(count):
		ids.append("z%02d" % i)
	var parent_of: Dictionary = {}
	var children_of: Dictionary = {}
	for i in range(count):
		children_of[ids[i]] = []
	for i in range(1, count):
		var p_idx := rng.randi_range(0, i - 1)
		parent_of[ids[i]] = ids[p_idx]
		children_of[ids[p_idx]].append(ids[i])

	var cell_pos := _layout(ids, parent_of, rng)
	var min_x := 0
	var min_y := 0
	for id in cell_pos:
		var p: Vector2i = cell_pos[id]
		min_x = mini(min_x, p.x)
		min_y = mini(min_y, p.y)
	var gw := 0
	var gh := 0
	for id in cell_pos:
		var p: Vector2i = cell_pos[id]
		gw = maxi(gw, p.x - min_x + 1)
		gh = maxi(gh, p.y - min_y + 1)
	var total_w := gw * zw
	var total_h := gh * zh

	# per-zone world origins (in cell coords)
	var origins: Dictionary = {}
	for id in ids:
		var p: Vector2i = cell_pos[id]
		origins[id] = Vector2i((p.x - min_x) * zw, (p.y - min_y) * zh)

	# 2. whole-world organic terrain
	var grid := _empty_grid(total_w, total_h)
	var centers: Dictionary = {}
	for id in ids:
		var o: Vector2i = origins[id]
		centers[id] = _carve_room(grid, o.x, o.y, zw, zh, rng)
	for i in range(1, count):
		_carve_winding(grid, centers[ids[i]], centers[parent_of[ids[i]]], rng)
	_carve_extra_rooms(grid, total_w, total_h, rng)
	_scatter_stone(grid, total_w, total_h, float(params.get("stone_ratio", 0.30)), rng)
	var passages := _fortify_seams(grid, total_w, total_h, origins, zw, zh, parent_of, ids, rng)
	_ensure_connected(grid, total_w, total_h, centers[ids[0]])
	_clear_spawn(grid, total_w, total_h, centers[ids[0]])

	# per-zone themes -> floor / wall / breakable / monsters
	var theme_of: Dictionary = {}
	for i in range(count):
		theme_of[ids[i]] = _theme(i, params)

	# spawn protection area (3x3 around root centre) — no breakables, always open
	var spawn_guard: Dictionary = {}
	var spawn_c: Vector2i = centers[ids[0]]
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			spawn_guard[Vector2i(spawn_c.x + dx, spawn_c.y + dy)] = true

	return _stitch(ids, origins, zw, zh, total_w, total_h, grid, parent_of, children_of, theme_of, centers, spawn_guard, passages, count, seed_val)


static func _layout(ids: Array, parent_of: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var cell_pos: Dictionary = {ids[0]: Vector2i(0, 0)}
	for i in range(1, ids.size()):
		var pid = parent_of[ids[i]]
		var p: Vector2i = cell_pos[pid]
		var placed := false
		for dir in _shuffled_dirs(rng):
			var q: Vector2i = p + _dir_vec(dir)
			if _occupied(cell_pos, q):
				continue
			cell_pos[ids[i]] = q
			placed = true
			break
		if not placed:
			cell_pos[ids[i]] = p
	return cell_pos


static func _empty_grid(w: int, h: int) -> Array:
	var grid: Array = []
	for x in range(w):
		var col: Array = []
		col.resize(h)
		for y in range(h):
			col[y] = STONE
		grid.append(col)
	return grid


static func _carve_room(grid: Array, ox: int, oy: int, zw: int, zh: int, rng: RandomNumberGenerator) -> Vector2i:
	var rw := rng.randi_range(5, maxi(5, zw - 6))
	var rh := rng.randi_range(4, maxi(4, zh - 5))
	var rx := ox + (zw - rw) / 2
	var ry := oy + (zh - rh) / 2
	for x in range(rx, rx + rw):
		for y in range(ry, ry + rh):
			if x >= 0 and y >= 0 and x < grid.size() and y < grid[x].size():
				grid[x][y] = EMPTY
	return Vector2i(rx + rw / 2, ry + rh / 2)


static func _carve_winding(grid: Array, a: Vector2i, b: Vector2i, rng: RandomNumberGenerator) -> void:
	# Midpoint-jittered two-segment path so corridors curve organically.
	var mx := (a.x + b.x) / 2 + rng.randi_range(-4, 4)
	var my := (a.y + b.y) / 2 + rng.randi_range(-4, 4)
	mx = clampi(mx, 1, grid.size() - 2)
	my = clampi(my, 1, grid[0].size() - 2)
	_carve_l(grid, a, Vector2i(mx, my), rng)
	_carve_l(grid, Vector2i(mx, my), b, rng)


static func _carve_l(grid: Array, a: Vector2i, b: Vector2i, rng: RandomNumberGenerator) -> void:
	if rng.randi_range(0, 1) == 0:
		_hcarve(grid, a.x, b.x, a.y)
		_vcarve(grid, b.x, a.y, b.y)
	else:
		_vcarve(grid, a.x, a.y, b.y)
		_hcarve(grid, a.x, b.x, b.y)


static func _hcarve(grid: Array, x0: int, x1: int, y: int) -> void:
	for x in range(mini(x0, x1), maxi(x0, x1) + 1):
		if x >= 0 and y >= 0 and x < grid.size() and y < grid[x].size():
			grid[x][y] = EMPTY


static func _vcarve(grid: Array, x: int, y0: int, y1: int) -> void:
	for y in range(mini(y0, y1), maxi(y0, y1) + 1):
		if x >= 0 and y >= 0 and x < grid.size() and y < grid[x].size():
			grid[x][y] = EMPTY


static func _carve_extra_rooms(grid: Array, w: int, h: int, rng: RandomNumberGenerator) -> void:
	# a few extra scattered rooms make the world less sparse
	for i in range(6):
		var rw := rng.randi_range(3, 6)
		var rh := rng.randi_range(3, 5)
		var rx := rng.randi_range(2, maxi(3, w - rw - 2))
		var ry := rng.randi_range(2, maxi(3, h - rh - 2))
		for x in range(rx, rx + rw):
			for y in range(ry, ry + rh):
				if x >= 0 and y >= 0 and x < grid.size() and y < grid[x].size():
					grid[x][y] = EMPTY


static func _scatter_stone(grid: Array, w: int, h: int, ratio: float, rng: RandomNumberGenerator) -> void:
	var scale := 2.6
	var nw := int(ceil(float(w) / scale)) + 3
	var nh := int(ceil(float(h) / scale)) + 3
	var noise: Array = []
	for i in range(nw):
		var col: Array = []
		for j in range(nh):
			col.append(rng.randf())
		noise.append(col)
	var threshold := 1.0 - ratio
	for x in range(1, w - 1):
		for y in range(1, h - 1):
			if grid[x][y] != STONE:
				continue
			var v := _value_noise(noise, float(x) / scale, float(y) / scale)
			if v < threshold:
				grid[x][y] = EMPTY


static func _value_noise(noise: Array, fx: float, fy: float) -> float:
	var x0: int = int(floor(fx))
	var y0: int = int(floor(fy))
	if x0 < 0 or y0 < 0 or x0 + 1 >= noise.size() or y0 + 1 >= noise[x0].size():
		return 0.0
	var tx: float = fx - floor(fx)
	var ty: float = fy - floor(fy)
	var sx: float = tx * tx * (3.0 - 2.0 * tx)
	var sy: float = ty * ty * (3.0 - 2.0 * ty)
	var n00: float = noise[x0][y0]
	var n10: float = noise[x0 + 1][y0]
	var n01: float = noise[x0][y0 + 1]
	var n11: float = noise[x0 + 1][y0 + 1]
	var a: float = lerpf(n00, n10, sx)
	var b: float = lerpf(n01, n11, sx)
	return lerpf(a, b, sy)


# Seal every adjacent-zone seam into mountain wall, then cut one wide "pass"
# (canyon) per tree edge. Each tree edge gets a gate type:
#   open   — no barrier, walk through freely
#   clear  — a door that opens once the parent zone's monsters are cleared
#   key    — a locked door; kill the zone's key holder to get a key
#   hidden — the pass is disguised as breakable blocks (bomb to reveal)
# Non-tree adjacency is fully walled (mountain), so travel follows the tree.
static func _fortify_seams(grid: Array, w: int, h: int, origins: Dictionary, zw: int, zh: int, parent_of: Dictionary, ids: Array, rng: RandomNumberGenerator) -> Dictionary:
	var passages: Dictionary = {}
	for id in ids:
		passages[id] = []

	# 1. seal ALL physical adjacencies into mountain wall
	var keys: Array = origins.keys()
	for i in range(keys.size()):
		for j in range(i + 1, keys.size()):
			var a: Vector2i = origins[keys[i]]
			var b: Vector2i = origins[keys[j]]
			if a.x + zw == b.x:
				var lo := maxi(a.y, b.y)
				var hi := mini(a.y + zh, b.y + zh)
				if hi > lo:
					_seal_h(grid, a.x + zw - 1, b.x, lo, hi)
			elif b.x + zw == a.x:
				var lo := maxi(a.y, b.y)
				var hi := mini(a.y + zh, b.y + zh)
				if hi > lo:
					_seal_h(grid, b.x + zw - 1, a.x, lo, hi)
			elif a.y + zh == b.y:
				var lo := maxi(a.x, b.x)
				var hi := mini(a.x + zw, b.x + zw)
				if hi > lo:
					_seal_v(grid, a.y + zh - 1, b.y, lo, hi)
			elif b.y + zh == a.y:
				var lo := maxi(a.x, b.x)
				var hi := mini(a.x + zw, b.x + zw)
				if hi > lo:
					_seal_v(grid, b.y + zh - 1, a.y, lo, hi)

	# 2. carve one pass per tree edge, with a gate type
	for i in range(1, ids.size()):
		var child = ids[i]
		var parent = parent_of[child]
		var pc: Vector2i = origins[parent]
		var cc: Vector2i = origins[child]
		var gate := _pick_gate_type(rng)
		var px := 0
		var py := 0
		var pdir := ""
		var cdir := ""
		if cc.x > pc.x:
			var lo := maxi(pc.y, cc.y)
			var hi := mini(pc.y + zh, cc.y + zh)
			var y := rng.randi_range(lo + 2, hi - 3)
			_carve_pass_h(grid, pc.x + zw - 1, cc.x, y, w)
			px = pc.x + zw - 1
			py = y
			pdir = "R"
			cdir = "L"
		elif cc.x < pc.x:
			var lo := maxi(pc.y, cc.y)
			var hi := mini(pc.y + zh, cc.y + zh)
			var y := rng.randi_range(lo + 2, hi - 3)
			_carve_pass_h(grid, cc.x + zw - 1, pc.x, y, w)
			px = pc.x
			py = y
			pdir = "L"
			cdir = "R"
		elif cc.y > pc.y:
			var lo := maxi(pc.x, cc.x)
			var hi := mini(pc.x + zw, cc.x + zw)
			var x := rng.randi_range(lo + 2, hi - 3)
			_carve_pass_v(grid, x, pc.y + zh - 1, cc.y, h)
			px = x
			py = pc.y + zh - 1
			pdir = "D"
			cdir = "U"
		else:
			var lo := maxi(pc.x, cc.x)
			var hi := mini(pc.x + zw, cc.x + zw)
			var x := rng.randi_range(lo + 2, hi - 3)
			_carve_pass_v(grid, x, cc.y + zh - 1, pc.y, h)
			px = x
			py = pc.y
			pdir = "U"
			cdir = "D"

		passages[parent].append({"target": child, "gate": gate, "x": px, "y": py, "dir": pdir})
		passages[child].append({"target": parent, "gate": "open", "x": px, "y": py, "dir": cdir})

	return passages


static func _pick_gate_type(rng: RandomNumberGenerator) -> String:
	var r := rng.randi_range(0, 99)
	if r < 30:
		return "clear"
	if r < 50:
		return "open"
	if r < 70:
		return "key"
	return "hidden"


static func _has_key_gate(passages: Array) -> bool:
	for p in passages:
		if str(p.get("gate", "")) == "key":
			return true
	return false


static func _seal_h(grid: Array, col_a: int, col_b: int, y0: int, y1: int) -> void:
	for y in range(y0, y1):
		grid[col_a][y] = STONE
		grid[col_b][y] = STONE


static func _seal_v(grid: Array, row_a: int, row_b: int, x0: int, x1: int) -> void:
	for x in range(x0, x1):
		grid[x][row_a] = STONE
		grid[x][row_b] = STONE


static func _carve_pass_h(grid: Array, col_a: int, col_b: int, y: int, w: int) -> void:
	for dy in range(2):
		var yy := y + dy
		if yy < 0 or yy >= grid[col_a].size():
			continue
		grid[col_a][yy] = EMPTY
		grid[col_b][yy] = EMPTY
		_canyon_h(grid, col_a, col_b, yy, w)


static func _carve_pass_v(grid: Array, x: int, row_a: int, row_b: int, h: int) -> void:
	for dx in range(2):
		var xx := x + dx
		if xx < 0 or xx >= grid.size():
			continue
		grid[xx][row_a] = EMPTY
		grid[xx][row_b] = EMPTY
		_canyon_v(grid, xx, row_a, row_b, h)


static func _canyon_h(grid: Array, col_a: int, col_b: int, y: int, w: int) -> void:
	for d in range(1, 6):
		var x := col_a - d
		if x < 0:
			break
		if grid[x][y] == EMPTY:
			break
		grid[x][y] = EMPTY
	for d in range(1, 6):
		var x := col_b + d
		if x >= w:
			break
		if grid[x][y] == EMPTY:
			break
		grid[x][y] = EMPTY


static func _canyon_v(grid: Array, x: int, row_a: int, row_b: int, h: int) -> void:
	for d in range(1, 6):
		var y := row_a - d
		if y < 0:
			break
		if grid[x][y] == EMPTY:
			break
		grid[x][y] = EMPTY
	for d in range(1, 6):
		var y := row_b + d
		if y >= h:
			break
		if grid[x][y] == EMPTY:
			break
		grid[x][y] = EMPTY


static func _ensure_connected(grid: Array, w: int, h: int, root: Vector2i) -> void:
	var visited := _flood(grid, w, h, root)
	for x in range(1, w - 1):
		for y in range(1, h - 1):
			if grid[x][y] == EMPTY and not visited.has(Vector2i(x, y)):
				grid[x][y] = STONE


# Clear a walkable spawn area (3x3) at the root zone centre, so the hero's
# begin point is guaranteed to be open floor, never wall or breakable.
static func _clear_spawn(grid: Array, w: int, h: int, center: Vector2i) -> void:
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var x := center.x + dx
			var y := center.y + dy
			if x >= 0 and y >= 0 and x < w and y < h:
				grid[x][y] = EMPTY


static func _flood(grid: Array, w: int, h: int, start: Vector2i) -> Dictionary:
	var reached: Dictionary = {}
	if grid[start.x][start.y] != EMPTY:
		# find any empty cell
		for x in range(1, w - 1):
			for y in range(1, h - 1):
				if grid[x][y] == EMPTY:
					start = Vector2i(x, y)
					break
			if grid[start.x][start.y] == EMPTY:
				break
	reached[start] = true
	var stack: Array = [start]
	while not stack.is_empty():
		var cur: Vector2i = stack.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nxt: Vector2i = cur + d
			if nxt.x < 0 or nxt.y < 0 or nxt.x >= w or nxt.y >= h:
				continue
			if reached.has(nxt):
				continue
			if grid[nxt.x][nxt.y] == EMPTY:
				reached[nxt] = true
				stack.append(nxt)
	return reached


static func _stitch(ids: Array, origins: Dictionary, zw: int, zh: int, total_w: int, total_h: int, grid: Array, parent_of: Dictionary, children_of: Dictionary, theme_of: Dictionary, centers: Dictionary, spawn_guard: Dictionary, passages: Dictionary, count: int, seed_val: int) -> Dictionary:
	var floor_points: Dictionary = {}
	var wall_pts: Dictionary = {}     # wall_name -> points
	var breakable_pts: Dictionary = {} # breakable_name -> points
	var zone_monsters: Dictionary = {} # zone id -> npc list
	var zone_meta: Array = []

	for i in range(count):
		var id = ids[i]
		zone_monsters[id] = []
		var o: Vector2i = origins[id]
		var theme: Dictionary = theme_of[id]
		var floor_name := str(theme.get("floor", "elem220"))
		var wall_name := str(theme.get("wall", "elem212"))
		var breakable_pool = theme.get("breakable", ["elem225", "elem226", "elem227"])
		if breakable_pool == null or (breakable_pool is Array and breakable_pool.is_empty()):
			breakable_pool = ["elem225", "elem226", "elem227"]

		if not floor_points.has(floor_name):
			floor_points[floor_name] = []
		if not wall_pts.has(wall_name):
			wall_pts[wall_name] = []
		if not breakable_pts.has("_pool_" + id):
			breakable_pts["_pool_" + id] = {"pool": breakable_pool, "cells": []}

		for x in range(o.x, o.x + zw):
			for y in range(o.y, o.y + zh):
				if x < 0 or y < 0 or x >= total_w or y >= total_h:
					continue
				floor_points[floor_name].append({"x": x, "y": y})
				if grid[x][y] == STONE:
					wall_pts[wall_name].append({"x": x, "y": y})

		# breakables for this zone (placed on EMPTY cells, connectivity-safe)
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_val + i * 7919
		var placed_break := _place_zone_breakables(grid, o.x, o.y, zw, zh, total_w, total_h, breakable_pool, float(theme.get("density", 0.25)), rng, spawn_guard)
		for cell in placed_break:
			breakable_pts["_pool_" + id]["cells"].append({"x": int(cell.x), "y": int(cell.y), "name": str(placed_break[cell])})

		# monsters
		var key_needed := _has_key_gate(passages.get(id, []))
		var key_assigned := false
		for spec in _monster_specs(theme.get("monsters", [])):
			var remain := int(spec.get("max", 0))
			var candidates: Array = []
			for x in range(o.x + 1, o.x + zw - 1):
				for y in range(o.y + 1, o.y + zh - 1):
					if grid[x][y] == EMPTY:
						candidates.append(Vector2i(x, y))
			_shuffle(rng, candidates)
			for c in candidates:
				if remain <= 0:
					break
				var entry := {"name": str(spec.get("name", "")), "x": int(c.x), "y": int(c.y)}
				if key_needed and not key_assigned:
					entry["drops_key"] = true
					key_assigned = true
				zone_monsters[id].append(entry)
				remain -= 1

		zone_meta.append({
			"id": id, "parent": parent_of.get(id, ""), "children": children_of[id],
			"ox": o.x, "oy": o.y, "w": zw, "h": zh,
			"cx": centers[id].x, "cy": centers[id].y,
			"theme_name": str(theme.get("name", "")),
			"passages": passages.get(id, []),
		})

	# assemble breakables by real name
	var breakable_by_name: Dictionary = {}
	for key in breakable_pts:
		for c in breakable_pts[key]["cells"]:
			var nm := str(c["name"])
			if not breakable_by_name.has(nm):
				breakable_by_name[nm] = []
			breakable_by_name[nm].append({"x": int(c["x"]), "y": int(c["y"])})

	var obstacle: Array = []
	for nm in wall_pts:
		if not wall_pts[nm].is_empty():
			obstacle.append({"type": "exploration", "name": str(nm), "points": wall_pts[nm]})
	for nm in breakable_by_name:
		if not breakable_by_name[nm].is_empty():
			obstacle.append({"type": "exploration", "name": str(nm), "points": breakable_by_name[nm]})

	var floor_arr: Array = []
	for nm in floor_points:
		floor_arr.append({"type": "exploration", "name": str(nm), "points": floor_points[nm]})

	var begin: Vector2i = centers[ids[0]]

	# districts: one per zone, each holding that zone's monsters + its gate info
	var districts: Array = []
	for id in ids:
		var o: Vector2i = origins[id]
		districts.append({
			"id": id,
			"square": {"x1": o.x, "y1": o.y, "x2": o.x + zw - 1, "y2": o.y + zh - 1},
			"npcs": zone_monsters[id],
			"passages": passages.get(id, []),
		})

	return {
		"basic": {
			"name": "world", "width": total_w, "height": total_h,
			"scroll": [0, 0], "music": "",
			"begin": [begin.x, begin.y], "finish": [-1, -1],
		},
		"floors": [],
		"floor": floor_arr,
		"obstacle": obstacle,
		"obstacles": [],
		"districts": districts,
		"zones": zone_meta,
	}


static func _place_zone_breakables(grid: Array, ox: int, oy: int, zw: int, zh: int, total_w: int, total_h: int, pool: Array, density: float, rng: RandomNumberGenerator, guard: Dictionary) -> Dictionary:
	var names: Dictionary = {}
	if pool.is_empty():
		return names
	var candidates: Array = []
	for x in range(ox + 1, ox + zw - 1):
		for y in range(oy + 1, oy + zh - 1):
			if grid[x][y] == EMPTY:
				candidates.append(Vector2i(x, y))
	_shuffle(rng, candidates)
	var target := int(float(candidates.size()) * density)
	var placed := 0
	for c in candidates:
		if placed >= target:
			break
		if guard.has(c):
			continue
		grid[c.x][c.y] = BLOCK
		if _world_connected(grid, total_w, total_h):
			names[c] = str(_pick(rng, pool))
			placed += 1
		else:
			grid[c.x][c.y] = EMPTY
	return names


static func _world_connected(grid: Array, w: int, h: int) -> bool:
	var root := Vector2i(-1, -1)
	for x in range(1, w - 1):
		for y in range(1, h - 1):
			if grid[x][y] == EMPTY:
				root = Vector2i(x, y)
				break
		if root.x >= 0:
			break
	if root.x < 0:
		return true
	var visited := _flood(grid, w, h, root)
	var total := 0
	for x in range(1, w - 1):
		for y in range(1, h - 1):
			if grid[x][y] == EMPTY:
				total += 1
	return visited.size() == total


static func _theme(i: int, params: Dictionary) -> Dictionary:
	if params.has("recipe") and params["recipe"] is Dictionary:
		return (params["recipe"] as Dictionary).duplicate()
	return {"name": "default", "floor": "elem220", "wall": "elem212", "breakable": ["elem225", "elem226", "elem227"], "monsters": []}


static func _monster_specs(monster_pool, count_max = 0) -> Array:
	var specs: Array = []
	if not (monster_pool is Array):
		return specs
	var default_max: int = count_max if count_max > 0 else 5
	for entry in monster_pool:
		if entry is Dictionary:
			var nm := str(entry.get("name", ""))
			var mx := int(entry.get("max", entry.get("count", default_max)))
			if nm != "":
				specs.append({"name": nm, "max": maxi(0, mx)})
		else:
			specs.append({"name": str(entry), "max": default_max})
	return specs


static func _dir_vec(dir: String) -> Vector2i:
	match dir:
		"R": return Vector2i(1, 0)
		"L": return Vector2i(-1, 0)
		"U": return Vector2i(0, -1)
		"D": return Vector2i(0, 1)
	return Vector2i.ZERO


static func _occupied(cell_pos: Dictionary, q: Vector2i) -> bool:
	for k in cell_pos:
		if cell_pos[k] == q:
			return true
	return false


static func _shuffled_dirs(rng: RandomNumberGenerator) -> Array:
	var dirs := ["R", "L", "U", "D"]
	for i in range(dirs.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = dirs[i]
		dirs[i] = dirs[j]
		dirs[j] = t
	return dirs


static func _pick(rng: RandomNumberGenerator, arr: Array):
	if arr.is_empty():
		return ""
	return arr[rng.randi_range(0, arr.size() - 1)]


static func _shuffle(rng: RandomNumberGenerator, arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = arr[i]
		arr[i] = arr[j]
		arr[j] = t
