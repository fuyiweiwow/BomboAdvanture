# res://src/game/sprite/updatable.gd
# Port of game/sprite/updatable.py + game/sprite/throwable.py
# Base class for everything that lives on the grid: players, npcs, bombs,
# items, obstacles. Implements pixel<->grid conversion, the four-direction
# collision-aware movement, conveyor sliding, and throwable (parabola) motion.
class_name Updatable
extends RefCounted

var x: int = 0
var y: int = 0
var x_pos: float = 0.0
var y_pos: float = 0.0
var wall_walking: bool = false

# --- throwable state ---
var throwing: bool = false
var throwing_time_begin: int = 0
var throwing_time: int = 0
var direction: String = ""
var points: Array = []
var current_point: int = 0

var update_time_old: int = 0
var hidden: bool = false

func _init(x_: int, y_: int):
	x = x_
	y = y_
	x_pos = float(x) * G.GAME_SQUARE + G.HALF_GAME_SQUARE
	y_pos = float(y) * G.GAME_SQUARE + G.HALF_GAME_SQUARE

static func current_grid(xp: float, yp: float) -> Vector2i:
	return Vector2i(int(xp / G.GAME_SQUARE), int(yp / G.GAME_SQUARE))

# (updatable.if_hide) -- hide when standing on a hideable obstacle.
func if_hide() -> bool:
	var ret = false
	var ois: Dictionary = Game.current_level.obstacle_instances
	var key = Vector2i(x, y)
	if ois.has(key):
		var an_obstacle = ois[key]
		if an_obstacle.obstacle_can_hide:
			blank_img()
			ret = true
	hidden = ret
	return ret

func blank_img() -> void:
	# GDScript draws via CanvasItem; hiding is handled by setting a hidden flag.
	# Subclasses that draw check `hidden` themselves.
	pass

# (updatable.get_ruld_block) -- right/top/left/bottom pixel + grid edges.
func get_ruld_block() -> Array:
	var right = x_pos + G.HALF_GAME_SQUARE - 1
	var right_grid = int(right / G.GAME_SQUARE)
	var top = y_pos - G.HALF_GAME_SQUARE
	var top_grid = int(top / G.GAME_SQUARE)
	var left = x_pos - G.HALF_GAME_SQUARE
	var left_grid = int(left / G.GAME_SQUARE)
	var bottom = y_pos + G.HALF_GAME_SQUARE - 1
	var bottom_grid = int(bottom / G.GAME_SQUARE)
	return [right, right_grid, top, top_grid, left, left_grid, bottom, bottom_grid]

# (updatable.slide)
func slide(update_time_old_, district_locked: bool, orientation: int, slide_speed: float,
		top: float, bottom: float, left: float, right: float,
		block: Array, top_grid: int, bottom_grid: int, left_grid: int, right_grid: int,
		cl) -> void:
	slide_speed = minf(20.0, slide_speed * G.GAME_SQUARE / 1000.0 * float(Time.get_ticks_msec() - update_time_old_))
	if orientation == 1:
		movement_right(district_locked, slide_speed, top, bottom, right, block, top_grid, bottom_grid, cl)
	elif orientation == 2:
		movement_up(district_locked, slide_speed, top, left, right, block, left_grid, right_grid, cl)
	elif orientation == 3:
		movement_left(district_locked, slide_speed, top, bottom, left, block, top_grid, bottom_grid, cl)
	elif orientation == 4:
		movement_down(district_locked, slide_speed, bottom, left, right, block, left_grid, right_grid, cl)

# (updatable.movement_right)
func movement_right(district_locked: bool, speed: float, top: float, bottom: float, right: float,
		block: Array, top_grid: int, bottom_grid: int, cl) -> void:
	if int(right / G.GAME_SQUARE) != int((right + speed) / G.GAME_SQUARE):
		var right_screen = right + speed >= cl.map_x_pos
		var right_district = x_pos + speed >= cl.district_square["x2"]
		var right_block: int = block[1][x + 1][y]
		var right_block_top_0: int = block[0][x + 1][top_grid + 1] if (y != int(top / G.GAME_SQUARE)) else 0
		var right_block_top_1: int = block[1][x + 1][top_grid]
		var right_block_bottom_0: int = block[0][x + 1][bottom_grid] if (y != int(bottom / G.GAME_SQUARE)) else 0
		var right_block_bottom_1: int = block[1][x + 1][bottom_grid]
		var right_edge: int = int((right + speed) / G.GAME_SQUARE)
		var right_bomb: int = cl.get_bomb_instance(right_edge, y).size()
		var right_bomb_top: int = cl.get_bomb_instance(right_edge, top_grid).size()
		var right_bomb_bottom: int = cl.get_bomb_instance(right_edge, bottom_grid).size()
		if wall_walking and not right_screen:
			x_pos += speed
			cl.scroll_map()
		elif district_locked and right_district:
			x_pos += minf(speed, maxf(0.0, float(right_edge) * G.GAME_SQUARE - G.HALF_GAME_SQUARE - x_pos))
			collide_wall()
			collide_district()
		elif right_block > 0 or right_screen or right_bomb > 0:
			x_pos += minf(speed, maxf(0.0, float(right_edge) * G.GAME_SQUARE - G.HALF_GAME_SQUARE - x_pos))
			collide_wall()
			try_push("R")
		elif right_block_top_0 > 0 or right_block_top_1 > 0 or right_bomb_top > 0:
			y_pos = minf(y_pos + speed, float(y) * G.GAME_SQUARE + G.HALF_GAME_SQUARE)
			try_push("R", Vector2i(0, -1))
		elif right_block_bottom_0 > 0 or right_block_bottom_1 > 0 or right_bomb_bottom > 0:
			y_pos = maxf(y_pos - speed, float(y) * G.GAME_SQUARE + G.HALF_GAME_SQUARE)
			try_push("R", Vector2i(0, 1))
		else:
			x_pos += speed
			cl.scroll_map()
	elif int(x_pos / G.GAME_SQUARE) != int((x_pos + speed) / G.GAME_SQUARE):
		if cl.get_bomb_instance(x + 1, y).size() == 0 or wall_walking:
			x_pos += speed
			cl.scroll_map()
	else:
		x_pos += speed
		cl.scroll_map()

# (updatable.movement_up)
func movement_up(district_locked: bool, speed: float, top: float, left: float, right: float,
		block: Array, left_grid: int, right_grid: int, cl) -> void:
	if int(top / G.GAME_SQUARE) != int((top - speed) / G.GAME_SQUARE):
		var top_screen = top - speed < 0
		var top_district = y_pos - speed < cl.district_square["y1"]
		var top_block: int = block[0][x][y]
		var top_block_left_0: int = block[0][left_grid][y]
		var top_block_left_1: int = block[1][left_grid + 1][y - 1] if (x != int(left / G.GAME_SQUARE)) else 0
		var top_block_right_0: int = block[0][right_grid][y]
		var top_block_right_1: int = block[1][right_grid][y - 1] if (x != int(right / G.GAME_SQUARE)) else 0
		var top_edge: int = int((top - speed) / G.GAME_SQUARE)
		var top_bomb: int = cl.get_bomb_instance(x, top_edge).size()
		var top_bomb_left: int = cl.get_bomb_instance(left_grid, top_edge).size()
		var top_bomb_right: int = cl.get_bomb_instance(right_grid, top_edge).size()
		if wall_walking and not top_screen:
			y_pos -= speed
			cl.scroll_map()
		elif district_locked and top_district:
			y_pos -= minf(speed, maxf(0.0, float(top_edge) * G.GAME_SQUARE + G.HALF_GAME_SQUARE - y_pos))
			collide_wall()
			collide_district()
		elif top_block > 0 or top_screen or top_bomb > 0:
			y_pos -= minf(speed, maxf(0.0, float(top_edge) * G.GAME_SQUARE + G.HALF_GAME_SQUARE - y_pos))
			collide_wall()
			try_push("U")
		elif top_block_left_0 > 0 or top_block_left_1 > 0 or top_bomb_left > 0:
			x_pos = minf(x_pos + speed, float(x) * G.GAME_SQUARE + G.HALF_GAME_SQUARE)
			try_push("U", Vector2i(-1, 0))
		elif top_block_right_0 > 0 or top_block_right_1 > 0 or top_bomb_right > 0:
			x_pos = maxf(x_pos - speed, float(x) * G.GAME_SQUARE + G.HALF_GAME_SQUARE)
			try_push("U", Vector2i(1, 0))
		else:
			y_pos -= speed
			cl.scroll_map()
	elif int(y_pos / G.GAME_SQUARE) != int((y_pos - speed) / G.GAME_SQUARE):
		if cl.get_bomb_instance(x, y - 1).size() == 0 or wall_walking:
			y_pos -= speed
			cl.scroll_map()
	else:
		y_pos -= speed
		cl.scroll_map()

# (updatable.movement_left)
func movement_left(district_locked: bool, speed: float, top: float, bottom: float, left: float,
		block: Array, top_grid: int, bottom_grid: int, cl) -> void:
	if int(left / G.GAME_SQUARE) != int((left - speed) / G.GAME_SQUARE):
		var left_screen = left - speed < 0
		var left_district = x_pos - speed < cl.district_square["x1"]
		var left_block: int = block[1][x][y]
		var left_block_top_0: int = block[0][x - 1][top_grid + 1] if (y != int(top / G.GAME_SQUARE)) else 0
		var left_block_top_1: int = block[1][x][top_grid]
		var left_block_bottom_0: int = block[0][x - 1][bottom_grid] if (y != int(bottom / G.GAME_SQUARE)) else 0
		var left_block_bottom_1: int = block[1][x][bottom_grid]
		var left_edge: int = int((left - speed) / G.GAME_SQUARE)
		var left_bomb: int = cl.get_bomb_instance(left_edge, y).size()
		var left_bomb_top: int = cl.get_bomb_instance(left_edge, top_grid).size()
		var left_bomb_bottom: int = cl.get_bomb_instance(left_edge, bottom_grid).size()
		if wall_walking and not left_screen:
			x_pos -= speed
			cl.scroll_map()
		elif district_locked and left_district:
			x_pos -= minf(speed, maxf(0.0, x_pos - (float(left) * G.GAME_SQUARE + G.HALF_GAME_SQUARE)))
			collide_wall()
			collide_district()
		elif left_block > 0 or left_screen or left_bomb > 0:
			x_pos -= minf(speed, maxf(0.0, x_pos - (float(left) * G.GAME_SQUARE + G.HALF_GAME_SQUARE)))
			collide_wall()
			try_push("L")
		elif left_block_top_1 > 0 or left_block_top_0 > 0 or left_bomb_top > 0:
			y_pos = minf(y_pos + speed, float(y) * G.GAME_SQUARE + G.HALF_GAME_SQUARE)
			try_push("L", Vector2i(0, -1))
		elif left_block_bottom_1 > 0 or left_block_bottom_0 > 0 or left_bomb_bottom > 0:
			y_pos = maxf(y_pos - speed, float(y) * G.GAME_SQUARE + G.HALF_GAME_SQUARE)
			try_push("L", Vector2i(0, 1))
		else:
			x_pos -= speed
			cl.scroll_map()
	elif int(x_pos / G.GAME_SQUARE) != int((x_pos - speed) / G.GAME_SQUARE):
		if cl.get_bomb_instance(x - 1, y).size() == 0 or wall_walking:
			x_pos -= speed
			cl.scroll_map()
	else:
		x_pos -= speed
		cl.scroll_map()

# (updatable.movement_down)
func movement_down(district_locked: bool, speed: float, bottom: float, left: float, right: float,
		block: Array, left_grid: int, right_grid: int, cl) -> void:
	if int(bottom / G.GAME_SQUARE) != int((bottom + speed) / G.GAME_SQUARE):
		var bottom_block: int = block[0][x][y + 1]
		var bottom_district = y_pos + speed >= cl.district_square["y2"]
		var bottom_block_right_0: int = block[0][int(right / G.GAME_SQUARE)][y + 1]
		var bottom_block_right_1: int = block[1][int(right / G.GAME_SQUARE)][y + 1] if (x != int(right / G.GAME_SQUARE)) else 0
		var bottom_block_left_0: int = block[0][int(left / G.GAME_SQUARE)][y + 1]
		var bottom_block_left_1: int = block[1][int(left / G.GAME_SQUARE) + 1][y + 1] if (x != int(left / G.GAME_SQUARE)) else 0
		var bottom_screen = bottom + speed >= cl.map_y_pos
		var bottom_edge: int = int((bottom + speed) / G.GAME_SQUARE)
		var bottom_bomb: int = cl.get_bomb_instance(x, bottom_edge).size()
		var bottom_bomb_left: int = cl.get_bomb_instance(left_grid, bottom_edge).size()
		var bottom_bomb_right: int = cl.get_bomb_instance(right_grid, bottom_edge).size()
		if wall_walking and not bottom_screen:
			y_pos += speed
			cl.scroll_map()
		elif district_locked and bottom_district:
			y_pos += minf(speed, maxf(0.0, y_pos - (float(bottom_edge) * G.GAME_SQUARE + G.HALF_GAME_SQUARE)))
			collide_wall()
			collide_district()
		elif bottom_block > 0 or bottom_screen or bottom_bomb > 0:
			y_pos += minf(speed, maxf(0.0, y_pos - (float(bottom_edge) * G.GAME_SQUARE + G.HALF_GAME_SQUARE)))
			collide_wall()
			try_push("D")
		elif bottom_block_right_0 > 0 or bottom_block_right_1 > 0 or bottom_bomb_right > 0:
			x_pos = maxf(x_pos - speed, float(x) * G.GAME_SQUARE + G.HALF_GAME_SQUARE)
			try_push("D", Vector2i(1, 0))
		elif bottom_block_left_0 > 0 or bottom_block_left_1 > 0 or bottom_bomb_left > 0:
			x_pos = minf(x_pos + speed, float(x) * G.GAME_SQUARE + G.HALF_GAME_SQUARE)
			try_push("D", Vector2i(-1, 0))
		else:
			y_pos += speed
			cl.scroll_map()
	elif int(y_pos / G.GAME_SQUARE) != int((y_pos + speed) / G.GAME_SQUARE):
		if cl.get_bomb_instance(x, y + 1).size() == 0 or wall_walking:
			y_pos += speed
			cl.scroll_map()
	else:
		y_pos += speed
		cl.scroll_map()

func collide_wall() -> void:
	pass

func collide_district() -> void:
	pass

func try_push(_direction: String, _offset = Vector2i(0, 0)) -> void:
	pass

func get_y() -> float:
	return float(y)

# ===================== throwable =====================
func get_direction(to_x: int, to_y: int) -> String:
	if x == to_x:
		return "D" if to_y > y else "U"
	else:
		return "R" if to_x > x else "L"

func throw_to(to_x: int, to_y: int, dir: String, emit_obstacles = false) -> void:
	if throwing:
		return
	if to_x == x and to_y == y:
		return
	var cl = Game.current_level
	var real_x: int = (to_x + cl.map_x) % cl.map_x
	var real_y: int = (to_y + cl.map_y) % cl.map_y
	if not emit_obstacles and cl.obstacle_instances.has(Vector2i(real_x, real_y)):
		if dir == "R":
			throw_to(to_x - 1, to_y, "R")
		elif dir == "L":
			throw_to(to_x + 1, to_y, "L")
		elif dir == "U":
			throw_to(to_x, to_y + 1, "U")
		elif dir == "D":
			throw_to(to_x, to_y - 1, "D")
		return
	throwing = true
	throwing_time_begin = Time.get_ticks_msec()
	direction = dir
	set_restoration(real_x, real_y)
	var from_x_pos = x_pos
	var from_y_pos = y_pos
	var to_x_pos = float(to_x) * G.GAME_SQUARE + G.HALF_GAME_SQUARE
	var to_y_pos = float(to_y) * G.GAME_SQUARE + G.HALF_GAME_SQUARE
	get_points(Vector2(from_x_pos, from_y_pos), Vector2(to_x_pos, to_y_pos))

# Simplified parabola: sample points from -> to (vertical or horizontal arc).
func get_points(p1: Vector2, p2: Vector2) -> void:
	points = []
	if abs(p1.x - p2.x) < 1.0:
		var now_y = p1.y
		var diff = abs(now_y - p2.y)
		if direction == "U":
			while diff > 10.0:
				now_y -= 10.0
				if diff < 10.0:
					now_y = p2.y
				if now_y < 0:
					points.append(Vector2(p1.x, now_y + Game.current_level.map_y_pos))
				else:
					points.append(Vector2(p1.x, now_y))
				diff = abs(now_y - p2.y)
		else:
			while diff > 10.0:
				now_y += 10.0
				if diff < 10.0:
					now_y = p2.y
				if now_y > Game.current_level.map_y_pos:
					points.append(Vector2(p1.x, fmod(now_y, Game.current_level.map_y_pos)))
				else:
					points.append(Vector2(p1.x, now_y))
				diff = abs(now_y - p2.y)
	else:
		var dy = p2.y - p1.y
		var dx = p2.x - p1.x
		var a = 0.002 + (0.002 - (1.0 / 280000.0)) * abs(dx)
		var b = dy / dx - a * (p1.x + p2.x)
		var c = p1.y - a * p1.x * p1.x - b * p1.x
		var now_x = p1.x
		var diff = abs(now_x - p2.x)
		var step = 14.0
		if direction == "L":
			step = -14.0
		while diff > 10.0:
			var k = 2.0 * a * now_x + b
			now_x += step / sqrt(k * k + 1.0)
			if diff < 10.0:
				now_x = p2.x
			var now_y = a * now_x * now_x + b * now_x + c
			if now_x > Game.current_level.map_x_pos:
				points.append(Vector2(fmod(now_x, Game.current_level.map_x_pos), now_y))
			elif now_x < 0:
				points.append(Vector2(now_x + Game.current_level.map_x_pos, now_y))
			else:
				points.append(Vector2(now_x, now_y))
			diff = abs(now_x - p2.x)

func throw() -> void:
	if not throwing:
		return
	var current_time = Time.get_ticks_msec()
	if current_point < points.size() - 1:
		throwing_time = current_time
		current_point = mini(int(points.size()) - 1, (current_time - throwing_time_begin) / 20)
		x_pos = points[current_point].x
		y_pos = points[current_point].y
	else:
		throwing = false
		direction = ""
		points = []
		current_point = 0
		x_pos = float(x) * G.GAME_SQUARE + G.HALF_GAME_SQUARE
		y_pos = float(y) * G.GAME_SQUARE + G.HALF_GAME_SQUARE

func set_restoration(to_x: int, to_y: int) -> void:
	x = to_x
	y = to_y
