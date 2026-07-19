# res://src/game/level/level.gd
# Port of game/level/level.py
class_name Level
extends RefCounted

var times_num: int = 0
var frames_num: int = 0
var me = null
var your_name: String = ""
var map_name: String = ""
var map_json: Dictionary = {}
var map_x: int = 0
var map_y: int = 0
var map_x_pos: int = 0
var map_y_pos: int = 0
var map_grids: Array = []
var scroll_x_pos: float = 0.0
var scroll_y_pos: float = 0.0
var scroll_x_pos_max: float = 0.0
var scroll_y_pos_max: float = 0.0
var map_title: String = ""
var map_time: int = 0
var map_init_time: int = 0
var map_remaining_time: int = 0
var map_music: String = ""
var map_music_volume: float = 1.0
var finish_at: Vector2i = Vector2i(-1, -1)

var current_time: int = 0
var floor_image: Image = null
var floor_texture: Texture2D = null
var flame_instances: Array = []
var item_instances: Dictionary = {}      # (x,y) -> ItemInstance
var obstacle_instances: Dictionary = {}   # (x,y) -> ObstacleInstance
var obstacle_instances_update: Array = []
var obstacle_instances_need_to_update: bool = true
var bomb_instances: Array = []
var ui_instances_bot: Array = []
var ui_instances_top: Array = []
var block: Array = []
var block_flame: Array = []
var slide_orientation: Dictionary = {}    # (x,y) -> [m, n]
var grid_damage_blood: Dictionary = {}    # (x,y) -> int
var grid_damage_time: Dictionary = {}     # (x,y) -> int
var grid_damage_orientations: Dictionary = {}  # (x,y) -> {orient:true}
var grid_damage_frame: int = 0
var accumulation_time: int = 0
var grid_bomb_time_at: Dictionary = {}

var skill_instances: Array = []
var effects_behind: Array = []
var effects_front: Array = []
var effects_screen: Array = []

var npcs: Array = []
var ghosts: Array = []
var recal_npc_paths: bool = true
var recal_ghost_paths: bool = true
var display_name_card: bool = false
var display_npc_blood: bool = false
var district_idx: int = 0
var district_square: Dictionary = {}
var district_square_grid: Dictionary = {}
var district_alarming: bool = false
var district_all_finished: bool = false
var finish_flag: bool = false

func _init(your_name_: String, map_name_: String, me_, accumulation_time_: int):
	Game.current_level = self
	me = me_
	your_name = your_name_
	map_name = map_name_
	accumulation_time = accumulation_time_
	load_map_json()
	load_floor()
	load_obstacle()
	load_music()
	# load_ui() -- TODO: port game/ui/*

func load_map_json() -> void:
	var path = G.GAME_ROOT + "map/" + map_name + ".json"
	var mj: Variant = Utils.load_json(path)
	if mj == null:
		push_error("Level: missing map %s" % path)
		return
	map_json = mj
	me.set_xy(int(map_json["basic"]["begin"][0]), int(map_json["basic"]["begin"][1]))
	map_x = int(map_json["basic"]["width"])
	map_y = int(map_json["basic"]["height"])
	map_x_pos = map_x * G.GAME_SQUARE - 1
	map_y_pos = map_y * G.GAME_SQUARE - 1
	map_grids = []
	for gx in range(map_x):
		for gy in range(map_y):
			map_grids.append(Vector2i(gx, gy))
	scroll_x_pos = float(int(map_json["basic"]["scroll"][0])) * G.GAME_SQUARE
	scroll_y_pos = float(int(map_json["basic"]["scroll"][1])) * G.GAME_SQUARE
	scroll_x_pos_max = maxf(0.0, float(map_x_pos - G.MAIN_AREA_X_POS))
	scroll_y_pos_max = maxf(0.0, float(map_y_pos - G.MAIN_AREA_Y_POS))
	map_init_time = Time.get_ticks_msec()
	map_music = str(map_json["basic"].get("music", ""))
	flame_instances = []
	item_instances = {}
	obstacle_instances = {}
	obstacle_instances_update = []
	bomb_instances = []
	ui_instances_bot = []
	ui_instances_top = []
	block = []
	block_flame = []
	for orient in range(2):
		var layer: Array = []
		for gx in range(map_x + 1):
			var col: Array = []
			col.resize(map_y + 1)
			for gy in range(map_y + 1):
				col[gy] = 0
			layer.append(col)
		block.append(layer)
		var layer2: Array = []
		for gx in range(map_x + 1):
			var col: Array = []
			col.resize(map_y + 1)
			for gy in range(map_y + 1):
				col[gy] = 0
			layer2.append(col)
		block_flame.append(layer2)
	for gx in range(map_x):
		for gy in range(map_y):
			grid_damage_blood[Vector2i(gx, gy)] = 0
			grid_damage_time[Vector2i(gx, gy)] = 0
			grid_damage_orientations[Vector2i(gx, gy)] = {}
			grid_bomb_time_at[Vector2i(gx, gy)] = 0
	district_square_grid = {"x1": 0, "x2": 0, "y1": 0, "y2": 0}
	district_square = {"x1": 0, "x2": 0, "y1": 0, "y2": 0}
	if map_json["basic"].has("finish"):
		finish_at = Vector2i(int(map_json["basic"]["finish"][0]), int(map_json["basic"]["finish"][1]))

func load_floor() -> void:
	floor_image = Image.create(map_x_pos, map_y_pos, false, Image.FORMAT_RGBA8)
	floor_image.fill(Color(0, 0, 0, 0))
	if map_json.has("floors"):
		for f in map_json["floors"]:
			var tex = FloorLoader.get_floor(str(f["type"]), str(f["name"]))
			if tex == null:
				continue
			var img = tex.get_image()
			if img == null:
				img = Utils.load_image(G.RES_IMG_ROOT + "mapElem/" + str(f["type"]) + "/" + str(f["name"]) + ".png")
			if img == null:
				continue
			var fimg = img.duplicate()
			fimg.resize(G.BLOCK_SIZE, G.BLOCK_SIZE)
			for sq in f["squares"]:
				for gx in range(int(sq["x1"]), int(sq["x2"]) + 1):
					for gy in range(int(sq["y1"]), int(sq["y2"]) + 1):
						floor_image.blit_rect(fimg, Rect2(0, 0, fimg.get_width(), fimg.get_height()), Vector2(gx * G.GAME_SQUARE, gy * G.GAME_SQUARE))
	if map_json.has("floor"):
		for f in map_json["floor"]:
			var tex = FloorLoader.get_floor(str(f["type"]), str(f["name"]))
			if tex == null:
				continue
			var img = tex.get_image()
			if img == null:
				img = Utils.load_image(G.RES_IMG_ROOT + "mapElem/" + str(f["type"]) + "/" + str(f["name"]) + ".png")
			if img == null:
				continue
			var fimg = img.duplicate()
			fimg.resize(G.BLOCK_SIZE, G.BLOCK_SIZE)
			for point in f["points"]:
				floor_image.blit_rect(fimg, Rect2(0, 0, fimg.get_width(), fimg.get_height()), Vector2(int(point["x"]) * G.GAME_SQUARE, int(point["y"]) * G.GAME_SQUARE))
	floor_texture = ImageTexture.create_from_image(floor_image)

func load_obstacle() -> void:
	if map_json.has("obstacles"):
		for o in map_json["obstacles"]:
			var obs = ObstacleLoader.get_obstacle(str(o["type"]), str(o["name"]))
			for sq in o["squares"]:
				for gx in range(int(sq["x1"]), int(sq["x2"]) + 1):
					for gy in range(int(sq["y1"]), int(sq["y2"]) + 1):
						ObstacleInstance.new(gx, gy, obstacle_instances, obs)
	if map_json.has("obstacle"):
		for o in map_json["obstacle"]:
			var obs = ObstacleLoader.get_obstacle(str(o["type"]), str(o["name"]))
			for point in o["points"]:
				ObstacleInstance.new(int(point["x"]), int(point["y"]), obstacle_instances, obs)

func load_music() -> void:
	# TODO: port game/music + game/sound
	pass

func load_district_and_enemies() -> void:
	if npcs.size() > 0:
		return
	me.district_locked = false
	if district_idx >= map_json["districts"].size():
		district_square = {"x1": 0, "x2": 0, "y1": 0, "y2": 0}
		district_square_grid = {"x1": 0, "x2": 0, "y1": 0, "y2": 0}
		district_all_finished = true
		return
	district_idx += 1
	var a_district: Dictionary = map_json["districts"][district_idx - 1]
	district_square = a_district["square"].duplicate()
	district_square_grid["x1"] = district_square["x1"]
	district_square_grid["x2"] = district_square["x2"]
	district_square_grid["y1"] = district_square["y1"]
	district_square_grid["y2"] = district_square["y2"]
	district_square["x1"] = float(district_square["x1"]) * G.GAME_SQUARE + G.HALF_GAME_SQUARE
	district_square["x2"] = float(district_square["x2"]) * G.GAME_SQUARE + G.HALF_GAME_SQUARE
	district_square["y1"] = float(district_square["y1"]) * G.GAME_SQUARE + G.HALF_GAME_SQUARE
	district_square["y2"] = float(district_square["y2"]) * G.GAME_SQUARE + G.HALF_GAME_SQUARE
	for g in ghosts.duplicate():
		if g.time == 0:
			ghosts.erase(g)
	for n in a_district["npcs"]:
		npcs.append(Npc.new(str(n["name"]), Vector2i(int(n["x"]), int(n["y"]))))

func update() -> void:
	current_time = Time.get_ticks_msec()
	if score_board != null and map_time > 0:
		map_remaining_time = int(ceil(float(map_time * 1000 - current_time + map_init_time) / 1000.0)) + 1
	if current_time - map_init_time > 3000:
		load_district_and_enemies()
	grid_damage_frame -= 1
	for b in bomb_instances.duplicate():
		b.update()
	for n in npcs.duplicate():
		if n.remain_blood <= 0:
			npcs.erase(n)
		else:
			n.update()
	recal_npc_paths = false
	for g in ghosts.duplicate():
		if g.remain_time <= 0:
			ghosts.erase(g)
		else:
			g.update()
	recal_ghost_paths = false
	me.update()
	pass_map()
	for f in flame_instances.duplicate():
		if f.state == -1:
			flame_instances.erase(f)
		else:
			f.update()
	for key in item_instances.keys().duplicate():
		var i = item_instances[key]
		if i.state == -2:
			item_instances.erase(key)
		else:
			i.update()
	if obstacle_instances_need_to_update:
		update_obstacles_update_list()
	for o in obstacle_instances_update:
		o.update()
	for s in skill_instances:
		if s.has_method("update"):
			s.update()
	for e in effects_behind:
		if e.has_method("update"):
			e.update()
	for e in effects_front:
		if e.has_method("update"):
			e.update()
	for e in effects_screen:
		if e.has_method("update"):
			e.update()
	for u in ui_instances_top:
		if u.has_method("update"):
			u.update()
	for u in ui_instances_bot:
		if u.has_method("update"):
			u.update()
	# reset per-frame bomb sound flag
	BombInstance.sound_played = false
	for gx in range(map_x):
		for gy in range(map_y):
			grid_damage_orientations[Vector2i(gx, gy)] = {}

# Draw the world (floor + entities) in WORLD coordinates.
# Called by a translated WorldRoot node so scroll is handled by the transform.
func draw_world(ci: CanvasItem) -> void:
	if floor_texture != null:
		ci.draw_texture(floor_texture, Vector2(0, 0))
	_draw_district_boundary(ci)
	for e in effects_behind:
		if e.has_method("draw"):
			e.draw(ci)
	var seq: Array = []
	if me != null:
		seq.append(me)
	seq.append_array(npcs)
	seq.append_array(ghosts)
	seq.append_array(bomb_instances)
	seq.append_array(obstacle_instances_update)
	seq.append_array(flame_instances)
	seq.append_array(item_instances.values())
	seq.sort_custom(_sort_by_y)
	for d in seq:
		if d.has_method("draw"):
			d.draw(ci)
	for e in effects_front:
		if e.has_method("draw"):
			e.draw(ci)

static func _sort_by_y(a, b) -> bool:
	return a.get_y() < b.get_y()

func _draw_district_boundary(ci: CanvasItem) -> void:
	var dg = district_square_grid
	if dg["x1"] >= dg["x2"] or dg["y1"] >= dg["y2"]:
		return
	var mask = Color(0, 0, 0, 0.7)
	var l = dg["x1"] * G.GAME_SQUARE
	var r = (dg["x2"] + 1) * G.GAME_SQUARE
	var t = dg["y1"] * G.GAME_SQUARE
	var b = (dg["y2"] + 1) * G.GAME_SQUARE
	if l > 0:
		ci.draw_rect(Rect2(0, 0, l, map_y_pos), mask)
	if r < map_x_pos:
		ci.draw_rect(Rect2(r, 0, map_x_pos - r, map_y_pos), mask)
	if t > 0:
		ci.draw_rect(Rect2(l, 0, r - l, t), mask)
	if b < map_y_pos:
		ci.draw_rect(Rect2(l, b, r - l, map_y_pos - b), mask)

func update_obstacles_update_list() -> void:
	obstacle_instances_need_to_update = false
	obstacle_instances_update.clear()
	var x0 = int(scroll_x_pos / G.GAME_SQUARE)
	var x1 = int((scroll_x_pos + G.MAIN_AREA_X_POS) / G.GAME_SQUARE) + 1
	var y0 = int(scroll_y_pos / G.GAME_SQUARE)
	var y1 = int((scroll_y_pos + G.MAIN_AREA_Y_POS) / G.GAME_SQUARE) + 1
	for gx in range(x0, x1 + 1):
		for gy in range(y0, y1 + 1):
			var key = Vector2i(gx, gy)
			if obstacle_instances.has(key):
				obstacle_instances_update.append(obstacle_instances[key])

func pass_map() -> void:
	if district_all_finished:
		if finish_at.x >= 0:
			if me.x == finish_at.x and me.y == finish_at.y:
				finish_flag = true
		else:
			finish_flag = true

func scroll_map() -> void:
	if me.x_pos > scroll_x_pos + G.R_SCROLL:
		scroll_x_pos = maxf(0.0, minf(me.x_pos - G.R_SCROLL, scroll_x_pos_max))
	elif me.x_pos < scroll_x_pos + G.L_SCROLL:
		scroll_x_pos = maxf(0.0, minf(me.x_pos - G.L_SCROLL, scroll_x_pos_max))
	if me.y_pos > scroll_y_pos + G.D_SCROLL:
		scroll_y_pos = maxf(0.0, minf(me.y_pos - G.D_SCROLL, scroll_y_pos_max))
	elif me.y_pos < scroll_y_pos + G.U_SCROLL:
		scroll_y_pos = maxf(0.0, minf(me.y_pos - G.U_SCROLL, scroll_y_pos_max))

func alarm_district() -> void:
	if district_alarming:
		return
	district_alarming = true
	# TODO: DistrictAlarm effect

func get_bomb_instance(x: int, y: int) -> Array:
	var bs: Array = []
	for b in bomb_instances:
		if b.x == x and b.y == y and not b.throwing:
			bs.append(b)
	return bs

var score_board = null  # TODO: port UI score board

func get_an_npc(name: String, point: Vector2i):
	return Npc.new(name, point)
