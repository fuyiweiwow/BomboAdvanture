# res://src/game/sprite/obstacle_instance.gd
# Port of game/sprite/obstacle_instance.py
class_name ObstacleInstance
extends Updatable

const DEAD = -2
const DYING = -1
const NORMAL = 0
const TRIGGERING = 1
const PUSHING = 2

var obstacle: Dictionary = {}
var state: int = NORMAL
var obstacle_can_hide: bool = false
var obstacle_is_background: bool = false
var obstacle_can_push: bool = false
var obstacle_trigger: bool = false
var obstacle_instances_dict: Dictionary = {}
var has_drawn: bool = false
var has_updated: bool = false
var is_pushing: int = 0
var push_begin: int = 0
var push_time: int = 500
var contact_damage: int = 0

var obstacle_timer: int = 0
var obstacle_frame_idx: int = 0
var cx: int = 0
var cy: int = 0

func _init(nx: int, ny: int, obstacle_instances_dict_: Dictionary, obstacle_: Dictionary):
	super._init(nx, ny)
	obstacle = obstacle_
	state = NORMAL
	obstacle_instances_dict = obstacle_instances_dict_
	has_drawn = false
	has_updated = false
	is_pushing = 0
	push_begin = 0
	push_time = 500
	contact_damage = 0
	obstacle_timer = 0
	obstacle_frame_idx = 0
	cx = 0
	cy = 0
	setup()
	update()

func setup() -> void:
	var cl = Game.current_level
	for gx in range(obstacle["WIDTH"]):
		for gy in range(obstacle["HEIGHT"]):
			obstacle_instances_dict[Vector2i(gx + x, gy + y)] = self
	var n_orient = min(obstacle["BLOCK"].size(), obstacle["BLOCK_FLAME"].size())
	for orient in range(n_orient):
		if orient >= cl.block.size() or orient >= cl.block_flame.size():
			break
		var brow = obstacle["BLOCK"][orient]
		var frow = obstacle["BLOCK_FLAME"][orient]
		for gx in range(brow.size()):
			if gx + x < 0 or gx + x >= cl.block[orient].size():
				continue
			var brow_col = brow[gx]
			var frow_col = frow[gx] if gx < frow.size() else null
			for gy in range(brow_col.size()):
				if gy + y < 0 or gy + y >= cl.block[orient][gx + x].size():
					continue
				cl.block[orient][gx + x][gy + y] += int(brow_col[gy])
				if frow_col != null and gy < frow_col.size():
					cl.block_flame[orient][gx + x][gy + y] += int(frow_col[gy])
	if obstacle["CAN_HIDE"]:
		obstacle_can_hide = true
	if obstacle.has("SLIDE"):
		cl.slide_orientation[Vector2i(x, y)] = [int(obstacle["SLIDE"][0]), int(obstacle["SLIDE"][1])]
	if obstacle.has("TRIGGER"):
		obstacle_trigger = true
	if obstacle.has("BACKGROUND") and bool(obstacle["BACKGROUND"]):
		obstacle_is_background = true
	if obstacle.has("CAN_PUSH") and bool(obstacle["CAN_PUSH"]):
		obstacle_can_push = true
		if obstacle.has("PUSH_TIME"):
			push_time = int(obstacle["PUSH_TIME"])
	if obstacle.has("CONTACT"):
		contact_damage = int(obstacle["CONTACT"])

func trigger() -> void:
	if not obstacle.has("TRIGGER"):
		return
	if state == DEAD or state == DYING:
		return
	switch_state(TRIGGERING)

func update() -> void:
	if state == DEAD:
		return
	if not has_updated:
		var current_time = Game.current_level.current_time
		update_frame(current_time)
		update_push()
		update_contact_damage()
		has_updated = true
		has_drawn = false

func update_frame(current_time: int) -> void:
	if current_time - obstacle_timer > int(obstacle["INTERVAL"]):
		var category = get_category()
		var lEN = obstacle[category].size()
		if lEN == 0:
			frame_loop()
			return
		if obstacle_frame_idx + 1 == lEN:
			frame_loop()
		obstacle_frame_idx = (obstacle_frame_idx + 1) % lEN
		cx = obstacle[category][obstacle_frame_idx].cx
		cy = obstacle[category][obstacle_frame_idx].cy
		obstacle_timer = current_time

func push(direction: String) -> void:
	if state == DYING or state == DEAD:
		return
	if not obstacle_can_push:
		return
	var cl = Game.current_level
	cl.me.try_damage(contact_damage)
	if is_pushing == 0:
		is_pushing = 1
		push_begin = Time.get_ticks_msec()
		switch_state(PUSHING)
	is_pushing += 1
	if Time.get_ticks_msec() - push_begin >= push_time:
		if direction == "R":
			if not obstacle_instances_dict.has(Vector2i(x + 1, y)) and cl.get_bomb_instance(x + 1, y).size() == 0:
				uninstall(); x += 1; setup()
		elif direction == "U":
			if not obstacle_instances_dict.has(Vector2i(x, y - 1)) and cl.get_bomb_instance(x, y - 1).size() == 0:
				uninstall(); y -= 1; setup()
		elif direction == "L":
			if not obstacle_instances_dict.has(Vector2i(x - 1, y)) and cl.get_bomb_instance(x - 1, y).size() == 0:
				uninstall(); x -= 1; setup()
		elif direction == "D":
			if not obstacle_instances_dict.has(Vector2i(x, y + 1)) and cl.get_bomb_instance(x, y + 1).size() == 0:
				uninstall(); y += 1; setup()
		cl.obstacle_instances_need_to_update = true

func update_push() -> void:
	if not obstacle_can_push:
		return
	if is_pushing == 0:
		push_begin = 0
		switch_state(NORMAL)
	else:
		is_pushing -= 1

func update_contact_damage() -> void:
	if state == DYING or state == DEAD:
		return
	if not obstacle_can_push:
		return
	var me = Game.current_level.me
	if me.x == x and me.y == y:
		me.try_damage(contact_damage)

func get_category() -> String:
	var category = "STAND"
	if state == DYING:
		category = "DIE"
	elif state == TRIGGERING:
		category = "TRIGGER"
	elif state == PUSHING:
		if not obstacle.has("PUSH"):
			category = "STAND"
		else:
			category = "PUSH"
	return category

func frame_loop() -> void:
	if state == DYING:
		switch_state(DEAD)
		uninstall()
		Game.current_level.obstacle_instances_need_to_update = true
	if state == TRIGGERING:
		switch_state(NORMAL)

func switch_state(new_state: int) -> void:
	if state == DYING and new_state != DEAD:
		return
	state = new_state
	obstacle_frame_idx = -1
	obstacle_timer = 0

func die() -> void:
	if state == DEAD or state == DYING:
		return
	if not bool(obstacle["BREAKABLE"]):
		return
	switch_state(DYING)
	obstacle_can_hide = false

func draw(ci: CanvasItem) -> void:
	if not has_drawn:
		if not obstacle.has(get_category()):
			has_updated = false
			has_drawn = true
			return
		var category = get_category()
		if obstacle[category].size() > 0:
			var idx = obstacle_frame_idx if obstacle_frame_idx >= 0 else 0
			var fr: Frame = obstacle[category][idx]
			fr.draw(ci, float(x) * G.GAME_SQUARE, float(y) * G.GAME_SQUARE)
		has_updated = false
		has_drawn = true

func get_y() -> float:
	if not obstacle_is_background:
		return float(y) + float(obstacle["HEIGHT"]) - 1.0
	return 0.0

func uninstall() -> void:
	var cl = Game.current_level
	for gx in range(obstacle["WIDTH"]):
		for gy in range(obstacle["HEIGHT"]):
			obstacle_instances_dict.erase(Vector2i(gx + x, gy + y))
	var n_orient = min(obstacle["BLOCK"].size(), obstacle["BLOCK_FLAME"].size())
	for orient in range(n_orient):
		if orient >= cl.block.size() or orient >= cl.block_flame.size():
			break
		var brow: Array = obstacle["BLOCK"][orient]
		var frow: Array = obstacle["BLOCK_FLAME"][orient]
		for gx in range(brow.size()):
			if gx + x < 0 or gx + x >= cl.block[orient].size():
				continue
			var brow_col = brow[gx]
			var frow_col = frow[gx] if gx < frow.size() else null
			for gy in range(brow_col.size()):
				if gy + y < 0 or gy + y >= cl.block[orient][gx + x].size():
					continue
				cl.block[orient][gx + x][gy + y] -= int(brow_col[gy])
				if frow_col != null and gy < frow_col.size():
					cl.block_flame[orient][gx + x][gy + y] -= int(frow_col[gy])
	if obstacle.has("SLIDE"):
		cl.slide_orientation.erase(Vector2i(x, y))
	cl.recal_npc_paths = true
