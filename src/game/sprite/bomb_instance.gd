# res://src/game/sprite/bomb_instance.gd
# Port of game/sprite/bomb_instance.py
class_name BombInstance
extends Updatable

const DEAD = -1
const NORMAL = 0

static var sound_played = false

var bomb: Dictionary = {}
var power: int = 0
var damage: int = 0
var player = null
var bomb_instances_list: Array = []
var effects_front: Array = []

var state: int = NORMAL
var bomb_timer: int = 0
var bomb_frame_idx: int = 0
var cx: int = 0
var cy: int = 0
var bomb_timer_alive: int = 0
var bomb_timer_explode: int = 0

func _init(nx: int, ny: int, bomb_instances_list_: Array, bomb_: Dictionary, power_: int, damage_: int, player_ = null):
	super._init(nx, ny)
	bomb = bomb_
	power = power_
	damage = damage_
	player = player_
	bomb_instances_list = bomb_instances_list_
	effects_front = []
	state = NORMAL
	bomb_timer = 0
	bomb_frame_idx = 0
	cx = 0
	cy = 0
	bomb_timer_alive = Time.get_ticks_msec()
	setup()
	update()

func setup() -> void:
	bomb_instances_list.append(self)
	Game.current_level.recal_npc_paths = true

static func get_type(at: int, length: int) -> int:
	if length == 1:
		return 1
	if at == length:
		return 2
	var half_length = length / 2
	if at == half_length:
		return 5
	elif at < half_length:
		return 3
	else:
		return 4

func update() -> void:
	if state == DEAD:
		return
	var current_time = Time.get_ticks_msec()
	if state == NORMAL:
		throw()
		update_pos(current_time)
		update_frame(current_time)
		update_to_explode(current_time)
		update_effects(current_time)
		if_hide()
		update_time_old = current_time

func update_pos(current_time: int) -> void:
	if throwing:
		return
	var cl = Game.current_level
	var block: Array = cl.block
	if cl.slide_orientation.has(Vector2i(x, y)):
		var r = get_ruld_block()
		var right = r[0]; var right_grid = r[1]; var top = r[2]; var top_grid = r[3]
		var left = r[4]; var left_grid = r[5]; var bottom = r[6]; var bottom_grid = r[7]
		var so: Array = cl.slide_orientation[Vector2i(x, y)]
		slide(update_time_old, false, so[0], float(so[1]), top, bottom, left, right, block, top_grid, bottom_grid, left_grid, right_grid, cl)
		var g = current_grid(x_pos, y_pos)
		x = g.x; y = g.y

func update_frame(current_time: int) -> void:
	if state == NORMAL and not bomb.is_empty() and current_time - bomb_timer > int(bomb.get("INTERVAL", 300)):
		var lEN = bomb["STAND"].size()
		bomb_frame_idx = (bomb_frame_idx + 1) % lEN
		cx = bomb["STAND"][bomb_frame_idx].cx
		cy = bomb["STAND"][bomb_frame_idx].cy
		bomb_timer = current_time

func update_to_explode(current_time: int) -> void:
	if current_time - bomb_timer_alive > G.BOMB_EXPLODE_TIME:
		explode()

func update_effects(current_time: int) -> void:
	for e in effects_front:
		if e.has_method("update"):
			e.update()

func switch_state(new_state: int) -> void:
	state = new_state
	bomb_frame_idx = 0
	if new_state == DEAD:
		uninstall()

func get_explode_length(point: Vector2i, direction: String, current_len: int, max_len: int) -> int:
	if current_len >= max_len:
		return 0
	var cl = Game.current_level
	var block: Array = cl.block_flame
	var ois: Dictionary = cl.obstacle_instances
	if direction == "R":
		var next_point = Vector2i(point.x + 1, point.y)
		if next_point.x >= cl.map_x:
			return 0
		if block[1][next_point.x][next_point.y] > 0:
			if ois.has(next_point):
				var an_obstacle = ois[next_point]
				if an_obstacle.obstacle["BREAKABLE"]:
					return 0 if block[1][next_point.x][next_point.y] == 2 else 1
			return 0
		return 1 + get_explode_length(next_point, "R", current_len + 1, max_len)
	if direction == "U":
		var next_point = Vector2i(point.x, point.y - 1)
		if next_point.y < 0:
			return 0
		if block[0][next_point.x][next_point.y + 1] > 0:
			if ois.has(next_point):
				var an_obstacle = ois[next_point]
				if an_obstacle.obstacle["BREAKABLE"]:
					return 0 if block[0][next_point.x][next_point.y + 1] == 2 else 1
			return 0
		return 1 + get_explode_length(next_point, "U", current_len + 1, max_len)
	if direction == "L":
		var next_point = Vector2i(point.x - 1, point.y)
		if next_point.x < 0:
			return 0
		if block[1][next_point.x + 1][next_point.y] > 0:
			if ois.has(next_point):
				var an_obstacle = ois[next_point]
				if an_obstacle.obstacle["BREAKABLE"]:
					return 0 if block[1][next_point.x + 1][next_point.y] == 2 else 1
			return 0
		return 1 + get_explode_length(next_point, "L", current_len + 1, max_len)
	if direction == "D":
		var next_point = Vector2i(point.x, point.y + 1)
		if next_point.y >= cl.map_y:
			return 0
		if block[0][next_point.x][next_point.y] > 0:
			if ois.has(next_point):
				var an_obstacle = ois[next_point]
				if an_obstacle.obstacle["BREAKABLE"]:
					return 0 if block[0][next_point.x][next_point.y] == 2 else 1
			return 0
		return 1 + get_explode_length(next_point, "D", current_len + 1, max_len)
	return 0

func explode() -> void:
	if state != NORMAL:
		return
	if throwing:
		return
	switch_state(DEAD)
	bomb_timer_explode = Time.get_ticks_msec()
	if not sound_played:
		# sound_player.play("flame") -- TODO
		sound_played = true
	var cl = Game.current_level
	var ois: Dictionary = cl.obstacle_instances
	var fis: Array = cl.flame_instances
	var point = Vector2i(x, y)
	cl.bomb_instances.erase(self)
	var f: Array = FlameLoader.get_flame("FLAME_C")
	if ois.has(point):
		ois[point].die()
	fis.append(FlameInstance.new(point.x, point.y, f, 0))
	for b in cl.get_bomb_instance(point.x, point.y):
		b.explode()
	if not has_orient(cl.grid_damage_orientations, point, "C"):
		add_orient(cl.grid_damage_orientations, point, "C")
		if bomb_timer_explode - cl.grid_damage_time[point] < cl.accumulation_time:
			cl.grid_damage_blood[point] += damage
		else:
			cl.grid_damage_blood[point] = damage
			cl.grid_damage_time[point] = bomb_timer_explode
	if cl.me.x == x and cl.me.y == y:
		exEff()
	var lEN = get_explode_length(point, "R", 0, power)
	for i in range(1, lEN + 1):
		var p = Vector2i(x + i, y)
		if ois.has(p):
			ois[p].die()
		f = FlameLoader.get_flame("FLAME_R")
		fis.append(FlameInstance.new(p.x, p.y, f, get_type(i, lEN)))
		for b in cl.get_bomb_instance(p.x, p.y):
			b.explode()
		if not has_orient(cl.grid_damage_orientations, p, "R"):
			add_orient(cl.grid_damage_orientations, p, "R")
			if bomb_timer_explode - cl.grid_damage_time[p] < cl.accumulation_time:
				cl.grid_damage_blood[p] += damage
			else:
				cl.grid_damage_blood[p] = damage
				cl.grid_damage_time[p] = bomb_timer_explode
		if cl.me.x == p.x and cl.me.y == p.y:
			exEff()
	lEN = get_explode_length(point, "U", 0, power)
	for i in range(1, lEN + 1):
		var p = Vector2i(x, y - i)
		if ois.has(p):
			ois[p].die()
		f = FlameLoader.get_flame("FLAME_U")
		fis.append(FlameInstance.new(p.x, p.y, f, get_type(i, lEN)))
		for b in cl.get_bomb_instance(p.x, p.y):
			b.explode()
		if not has_orient(cl.grid_damage_orientations, p, "U"):
			add_orient(cl.grid_damage_orientations, p, "U")
			if bomb_timer_explode - cl.grid_damage_time[p] < cl.accumulation_time:
				cl.grid_damage_blood[p] += damage
			else:
				cl.grid_damage_blood[p] = damage
				cl.grid_damage_time[p] = bomb_timer_explode
		if cl.me.x == p.x and cl.me.y == p.y:
			exEff()
	lEN = get_explode_length(point, "L", 0, power)
	for i in range(1, lEN + 1):
		var p = Vector2i(x - i, y)
		if ois.has(p):
			ois[p].die()
		f = FlameLoader.get_flame("FLAME_L")
		fis.append(FlameInstance.new(p.x, p.y, f, get_type(i, lEN)))
		for b in cl.get_bomb_instance(p.x, p.y):
			b.explode()
		if not has_orient(cl.grid_damage_orientations, p, "L"):
			add_orient(cl.grid_damage_orientations, p, "L")
			if bomb_timer_explode - cl.grid_damage_time[p] < cl.accumulation_time:
				cl.grid_damage_blood[p] += damage
			else:
				cl.grid_damage_blood[p] = damage
				cl.grid_damage_time[p] = bomb_timer_explode
		if cl.me.x == p.x and cl.me.y == p.y:
			exEff()
	lEN = get_explode_length(point, "D", 0, power)
	for i in range(1, lEN + 1):
		var p = Vector2i(x, y + i)
		if ois.has(p):
			ois[p].die()
		f = FlameLoader.get_flame("FLAME_D")
		fis.append(FlameInstance.new(p.x, p.y, f, get_type(i, lEN)))
		for b in cl.get_bomb_instance(p.x, p.y):
			b.explode()
		if not has_orient(cl.grid_damage_orientations, p, "D"):
			add_orient(cl.grid_damage_orientations, p, "D")
			if bomb_timer_explode - cl.grid_damage_time[p] < cl.accumulation_time:
				cl.grid_damage_blood[p] += damage
			else:
				cl.grid_damage_blood[p] = damage
				cl.grid_damage_time[p] = bomb_timer_explode
		if cl.me.x == p.x and cl.me.y == p.y:
			exEff()
	cl.grid_damage_frame = 2

static func has_orient(dict: Dictionary, point: Vector2i, orient: String) -> bool:
	if not dict.has(point):
		return false
	return dict[point].has(orient)

static func add_orient(dict: Dictionary, point: Vector2i, orient: String) -> void:
	if not dict.has(point):
		dict[point] = {}
	dict[point][orient] = true

func draw(ci: CanvasItem) -> void:
	if state == NORMAL and not bomb.is_empty() and bomb["STAND"].size() > 0:
		var fr: Frame = bomb["STAND"][bomb_frame_idx]
		fr.draw(ci, float(x) * G.GAME_SQUARE - 2.0, float(y) * G.GAME_SQUARE - 10.0)
	for s in effects_front:
		if s.has_method("draw"):
			s.draw(ci)

func exEff() -> void:
	pass

func set_restoration(to_x: int, to_y: int) -> void:
	x = to_x
	y = to_y

func uninstall() -> void:
	bomb_instances_list.erase(self)
	Game.current_level.recal_npc_paths = true
	if player != null:
		if player.has_method("restore_a_bomb"):
			player.restore_a_bomb()
