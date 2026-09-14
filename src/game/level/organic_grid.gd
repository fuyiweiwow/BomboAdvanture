# res://src/game/level/organic_grid.gd
# Organic terrain layout via a "rooms + noise" hybrid.
#
# Produces an indestructible-wall ("stone") layout that reads as natural,
# with no visible grid/lattice:
#   1. carve a set of random non-overlapping rooms
#   2. connect rooms with L-bend corridors (random orientation)
#   3. scatter extra stone blobs using a coarse value-noise field so clusters
#      look organic rather than rectilinear
#   4. flood-fill to guarantee the walkable area is a single connected region
#
# Cell values:
#   EMPTY = walkable
#   STONE = indestructible wall
#   BLOCK = breakable block (reserved; caller fills these in)
class_name OrganicGrid
extends RefCounted

const EMPTY := 0
const STONE := 1
const BLOCK := 2


static func generate(width: int, height: int, rng: RandomNumberGenerator, opts: Dictionary = {}) -> Array:
	var stone_ratio := clampf(float(opts.get("stone_ratio", 0.30)), 0.05, 0.55)
	var room_min := clampi(int(opts.get("room_min", 3)), 2, 8)
	var room_max := clampi(int(opts.get("room_max", 7)), room_min, 12)
	var rooms_wanted := clampi(int(opts.get("rooms", 0)), 0, 60)

	var grid := _empty_grid(width, height)

	var rooms := _carve_rooms(grid, width, height, room_min, room_max, rooms_wanted, rng)
	if rooms.is_empty():
		# fallback: single central room
		var rx := width / 2 - 2
		var ry := height / 2 - 2
		for x in range(rx, rx + 4):
			for y in range(ry, ry + 4):
				if _in_bounds(grid, x, y):
					grid[x][y] = EMPTY
		rooms.append(Rect2i(rx, ry, 4, 4))

	for i in range(rooms.size() - 1):
		_carve_corridor(grid, _room_center(rooms[i]), _room_center(rooms[i + 1]), rng)

	_scatter_stone(grid, width, height, stone_ratio, rng)

	_ensure_connectivity(grid, width, height, rng)

	return grid


static func _empty_grid(width: int, height: int) -> Array:
	var grid: Array = []
	for x in range(width):
		var col: Array = []
		col.resize(height)
		for y in range(height):
			col[y] = STONE
		grid.append(col)
	return grid


static func _carve_rooms(grid: Array, width: int, height: int, room_min: int, room_max: int, rooms_wanted: int, rng: RandomNumberGenerator) -> Array:
	var rooms: Array = []
	var attempts := 0
	var hard_cap := 300
	while rooms.size() < rooms_wanted or (rooms_wanted == 0 and rooms.size() == 0):
		attempts += 1
		if attempts > hard_cap:
			break
		var rw := rng.randi_range(room_min, room_max)
		var rh := rng.randi_range(room_min, room_max)
		var rx := rng.randi_range(2, maxi(3, width - rw - 2))
		var ry := rng.randi_range(2, maxi(3, height - rh - 2))
		var r := Rect2i(rx, ry, rw, rh)
		if _room_overlaps(r, rooms, 1):
			continue
		for x in range(r.position.x, r.position.x + r.size.x):
			for y in range(r.position.y, r.position.y + r.size.y):
				grid[x][y] = EMPTY
		rooms.append(r)
		if rooms_wanted > 0 and rooms.size() >= rooms_wanted:
			break
	return rooms


static func _room_overlaps(r: Rect2i, rooms: Array, pad: int) -> bool:
	for other in rooms:
		var o: Rect2i = other
		if r.position.x < o.end.x + pad and r.end.x + pad > o.position.x \
				and r.position.y < o.end.y + pad and r.end.y + pad > o.position.y:
			return true
	return false


static func _room_center(r: Rect2i) -> Vector2i:
	return Vector2i(r.position.x + r.size.x / 2, r.position.y + r.size.y / 2)


static func _carve_corridor(grid: Array, a: Vector2i, b: Vector2i, rng: RandomNumberGenerator) -> void:
	if rng.randi_range(0, 1) == 0:
		_hcarve(grid, a.x, b.x, a.y)
		_vcarve(grid, b.x, a.y, b.y)
	else:
		_vcarve(grid, a.x, a.y, b.y)
		_hcarve(grid, a.x, b.x, b.y)


static func _hcarve(grid: Array, x0: int, x1: int, y: int) -> void:
	for x in range(mini(x0, x1), maxi(x0, x1) + 1):
		if _in_bounds(grid, x, y):
			grid[x][y] = EMPTY


static func _vcarve(grid: Array, x: int, y0: int, y1: int) -> void:
	for y in range(mini(y0, y1), maxi(y0, y1) + 1):
		if _in_bounds(grid, x, y):
			grid[x][y] = EMPTY


static func _scatter_stone(grid: Array, width: int, height: int, ratio: float, rng: RandomNumberGenerator) -> void:
	# coarse value-noise field sampled per cell
	var scale := 2.6
	var nw := int(ceil(float(width) / scale)) + 3
	var nh := int(ceil(float(height) / scale)) + 3
	var noise: Array = []
	for i in range(nw):
		var col: Array = []
		for j in range(nh):
			col.append(rng.randf())
		noise.append(col)

	var threshold := 1.0 - ratio
	for x in range(1, width - 1):
		for y in range(1, height - 1):
			if grid[x][y] != STONE:
				continue
			var v := _value_noise(noise, float(x) / scale, float(y) / scale)
			if v < threshold:
				grid[x][y] = EMPTY  # thin the stone so it forms organic gaps


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


static func _ensure_connectivity(grid: Array, width: int, height: int, rng: RandomNumberGenerator) -> void:
	# flood-fill from the first EMPTY cell; any unreachable EMPTY pocket gets
	# carved back to reachable (re-cast as corridors toward the main area).
	var root := _first_empty(grid, width, height)
	if root.x < 0:
		return
	var visited := _flood(grid, root, width, height)
	for x in range(1, width - 1):
		for y in range(1, height - 1):
			if grid[x][y] == EMPTY and not visited.has(Vector2i(x, y)):
				# this pocket is isolated: keep it (it's just decorative stone
				# we accidentally thinned) -> re-stone it so unreachable holes
				# never appear as fake open space.
				grid[x][y] = STONE


static func _first_empty(grid: Array, width: int, height: int) -> Vector2i:
	for x in range(1, width - 1):
		for y in range(1, height - 1):
			if grid[x][y] == EMPTY:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


static func _flood(grid: Array, root: Vector2i, width: int, height: int) -> Dictionary:
	var visited: Dictionary = {}
	var stack: Array = [root]
	visited[root] = true
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
				stack.append(nxt)
	return visited


static func _in_bounds(grid: Array, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < grid.size() and y < grid[x].size()
