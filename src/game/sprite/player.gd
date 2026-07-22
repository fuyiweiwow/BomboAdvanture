# res://src/game/sprite/player.gd
# Port of game/sprite/player.py
class_name Player
extends Updatable

# PlayerState
const NORMAL = 0
const WIN = 1
const LOSE = -1

const STAND_INTERVAL = 200
const WALK_INTERVAL = 100

# CHARACTER_COMPONENTS order (game/frame/character.py) -- used for draw order.
# No _m variants — tinting is applied at draw time via modulate Color.
const CHARACTER_COMPONENTS = {
	"R": ["Body", "Foot", "Leg", "Cloth", "Cladorn", "Face", "Hair", "Eye_Eyeball", "Eye_Iris", "Eye_Pupil", "Eye_Highlight", "Ear", "Mouth", "Cap", "Fhadorn", "Npack", "Fpack", "Thadorn"],
	"U": ["Body", "Foot", "Leg", "Cloth", "Cladorn", "Face", "Eye_Eyeball", "Eye_Iris", "Eye_Pupil", "Eye_Highlight", "Ear", "Mouth", "Hair", "Cap", "Fhadorn", "Npack", "Fpack", "Thadorn"],
	"L": ["Thadorn", "Body", "Foot", "Leg", "Cloth", "Cladorn", "Npack", "Face", "Hair", "Eye_Eyeball", "Eye_Iris", "Eye_Pupil", "Eye_Highlight", "Ear", "Mouth", "Cap", "Fhadorn", "Fpack"],
	"D": ["Fpack", "Npack", "Body", "Foot", "Leg", "Cloth", "Cladorn", "Face", "Hair", "Eye_Eyeball", "Eye_Iris", "Eye_Pupil", "Eye_Highlight", "Ear", "Mouth", "Cap", "Fhadorn", "Thadorn"],
}

var color: Color = C.CHARACTER_RED
var state: int = NORMAL
var x_old: int = 0
var y_old: int = 0
var x_y_changed_trigger: bool = false

var walking: bool = false
var walking_old: bool = false
var orientation: String = "D"
var orientation_old: String = ""
var motion_changed: bool = false

var blood: int = 0
var self_damage_blood: int = 0
var speed: float = 0.0
var defense: int = 0
var protected_time: int = 0
var remain_blood: int = 0
var district_locked: bool = false

var slow: int = 0
var slow_begin: int = 0
var slow_duration: int = 0
var slow_speed: float = 0.0
var rooted: int = 0
var rooted_begin: int = 0
var rooted_duration: int = 0
var reverse: int = 0
var reverse_begin: int = 0
var reverse_duration: int = 0
var polymorph: int = 0
var polymorph_begin: int = 0
var polymorph_duration: int = 0
var get_damage_frame: bool = false
var temporary_alpha: int = 255
var can_kick: bool = false

var slide_forces: Dictionary = {}        # id -> [orientation, slide_speed]
var skill_names: Array = []
var skill_init_times: Array = []
var skill_intervals: Array = []
var skill_remains: Array = []
var skill_params: Array = []
var skill_instances: Array = []
var effects_behind: Array = []
var effects_front: Array = []
var allow_footprint: bool = false
var footprint_instances: Array = []

var character: Dictionary = {}
var character_frame_idxs: Dictionary = {}
var character_frame_timers: Dictionary = {}
var character_frame_intervals: Dictionary = {}
var character_frame_intervals_stand: Dictionary = {}
var character_frame_intervals_walk: Dictionary = {}
var character_frame_trigger: bool = false
var cx: int = 0
var cy: int = 0
var STAND: String = ""

func _init(character_name: String, xy: Vector2i, color_: Color = C.CHARACTER_RED):
	super._init(xy.x, xy.y)
	color = color_
	x_old = xy.x
	y_old = xy.y

func load_character(character_name: String, color_: Color, decorations: Dictionary, is_ghost = false, custom_textures: Dictionary = {}, component_colors: Dictionary = {}) -> Dictionary:
	if not custom_textures.is_empty():
		var t = Time.get_ticks_msec()
		for component in CHARACTER_COMPONENTS["D"]:
			character_frame_idxs[component] = 0
			character_frame_timers[component] = t
			character_frame_intervals[component] = 200
			character_frame_intervals_stand[component] = STAND_INTERVAL
			character_frame_intervals_walk[component] = WALK_INTERVAL
		return CharacterLoader.get_character("", color_, decorations, is_ghost, custom_textures, component_colors)
	var j = Utils.load_json(G.FRAME_ROOT + "character/" + character_name + ".json")
	if j == null:
		return {}
	var t = Time.get_ticks_msec()
	for component in CHARACTER_COMPONENTS["D"]:
		character_frame_idxs[component] = 0
		character_frame_timers[component] = t
		character_frame_intervals[component] = j.get("INTERVAL", 200)
		character_frame_intervals_stand[component] = STAND_INTERVAL
		character_frame_intervals_walk[component] = WALK_INTERVAL
		if decorations.has(component):
			character_frame_intervals[component] = decorations[component].get("INTERVAL", 200)
	return CharacterLoader.get_character(character_name, color_, decorations, is_ghost, {}, component_colors)

func align_xy() -> void:
	set_xy(x, y)

func set_xy(nx: int, ny: int) -> void:
	x = nx
	y = ny
	x_pos = float(nx) * G.GAME_SQUARE + G.HALF_GAME_SQUARE
	y_pos = float(ny) * G.GAME_SQUARE + G.HALF_GAME_SQUARE

func set_motion(motion: String = "") -> void:
	if motion == "" or motion == "None" or speed == 0.0:
		walking = false
		motion_changed = false
		return
	if rooted > 0:
		return
	if reverse > 0:
		if motion == "U": motion = "D"
		elif motion == "D": motion = "U"
		elif motion == "L": motion = "R"
		elif motion == "R": motion = "L"
	motion_changed = not walking or orientation != motion
	walking = true
	orientation = motion

func stimulate_character_frame_trigger() -> void:
	if orientation_old != orientation or walking_old != walking:
		character_frame_trigger = true
	else:
		character_frame_trigger = false
	orientation_old = orientation
	walking_old = walking

func stimulate_x_y_changed_trigger() -> void:
	if x != x_old or y != y_old:
		x_y_changed_trigger = true
	else:
		x_y_changed_trigger = false
	x_old = x
	y_old = y

func update() -> void:
	var current_time = Time.get_ticks_msec()
	if state == NORMAL:
		update_frame(current_time)
		update_pos()
		if_obstacle_trigger()
		if_take_item()
		check_slow_time(current_time)
		check_rooted_time(current_time)
		check_reverse_time(current_time)
		check_polymorph_time(current_time)
	if state == LOSE:
		update_frame_dead(current_time)
	stimulate_x_y_changed_trigger()
	update_skills()
	update_effects()
	get_damage_frame = false
	grid_damage(current_time)
	stimulate_character_frame_trigger()
	if protected_time > 0:
		protected_time = maxi(0, protected_time - (current_time - update_time_old))
		# Blinking effect: 100ms on / 100ms off
		temporary_alpha = 255 if (current_time / 100) % 2 == 0 else 48
	else:
		temporary_alpha = 255
	update_time_old = current_time

func update_skills() -> void:
	for s in skill_instances:
		if s.has_method("update"):
			s.update()

func update_effects() -> void:
	for e in effects_behind:
		if e.has_method("update"):
			e.update()
	for e in effects_front:
		if e.has_method("update"):
			e.update()

func update_frame(current_time: int) -> void:
	if walking:
		character_frame_intervals = character_frame_intervals_walk
	else:
		character_frame_intervals = character_frame_intervals_stand
	for component in character_frame_idxs.keys():
		if not character.has(STAND + orientation):
			continue
		if not character[STAND + orientation].has(component):
			continue
		if motion_changed:
			character_frame_idxs[component] = 0
		if character_frame_trigger or current_time - character_frame_timers[component] > character_frame_intervals[component]:
			var stand_prefix = "" if walking else "STAND_"
			STAND = stand_prefix
			cx = character[STAND + orientation]["Cx"]
			cy = character[STAND + orientation]["Cy"]
			var frames: Array = character[STAND + orientation][component]
			if frames.is_empty():
				continue
			character_frame_idxs[component] = (character_frame_idxs[component] + 1) % frames.size()
			character_frame_timers[component] = current_time

func update_frame_dead(current_time: int) -> void:
	if not character.has("LOSE"):
		return
	for component in character_frame_idxs.keys():
		if not character["LOSE"].has(component):
			continue
		if current_time - character_frame_timers[component] > STAND_INTERVAL:
			cx = character["LOSE"]["Cx"]
			cy = character["LOSE"]["Cy"]
			var frames: Array = character["LOSE"][component]
			if frames.is_empty():
				continue
			character_frame_idxs[component] = (character_frame_idxs[component] + 1) % frames.size()
			character_frame_timers[component] = current_time

func update_pos() -> void:
	if rooted > 0:
		set_motion()
	var cl = Game.current_level
	var block: Array = cl.block
	if walking:
		var speed_px = speed * float(Time.get_ticks_msec() - update_time_old)
		speed_px = minf(speed_px, 20.0)
		if motion_changed:
			speed_px *= G.FIRST_FRAME_SHORTEN_RATE
		var r = get_ruld_block()
		var right = r[0]; var right_grid = r[1]; var top = r[2]; var top_grid = r[3]
		var left = r[4]; var left_grid = r[5]; var bottom = r[6]; var bottom_grid = r[7]
		if orientation == "R":
			movement_right(district_locked, speed_px, top, bottom, right, block, top_grid, bottom_grid, cl)
		elif orientation == "U":
			movement_up(district_locked, speed_px, top, left, right, block, left_grid, right_grid, cl)
		elif orientation == "L":
			movement_left(district_locked, speed_px, top, bottom, left, block, top_grid, bottom_grid, cl)
		elif orientation == "D":
			movement_down(district_locked, speed_px, bottom, left, right, block, left_grid, right_grid, cl)
		var g = current_grid(x_pos, y_pos)
		x = g.x; y = g.y
	if cl.slide_orientation.has(Vector2i(x, y)):
		var r = get_ruld_block()
		var right = r[0]; var right_grid = r[1]; var top = r[2]; var top_grid = r[3]
		var left = r[4]; var left_grid = r[5]; var bottom = r[6]; var bottom_grid = r[7]
		var so: Array = cl.slide_orientation[Vector2i(x, y)]
		slide(update_time_old, district_locked, so[0], float(so[1]), top, bottom, left, right, block, top_grid, bottom_grid, left_grid, right_grid, cl)
	var g = current_grid(x_pos, y_pos)
	x = g.x; y = g.y

func if_obstacle_trigger() -> void:
	if not x_y_changed_trigger:
		return
	var ois: Dictionary = Game.current_level.obstacle_instances
	var key = Vector2i(x, y)
	if ois.has(key):
		var an_obstacle = ois[key]
		if an_obstacle.obstacle_trigger:
			an_obstacle.trigger()

func if_take_item() -> bool:
	if not x_y_changed_trigger:
		return false
	var key = Vector2i(x, y)
	if Game.current_level.item_instances.has(key):
		Game.current_level.item_instances[key].player_get(self)
		return true
	return false

func grid_damage(current_time: int) -> void:
	var point = Vector2i(x, y)
	var cl = Game.current_level
	if point.x < 0 or point.y < 0:
		return
	if cl.grid_damage_frame >= 0 and current_time - cl.grid_damage_time[point] < cl.accumulation_time:
		half_body_damage(point, cl, current_time)

func half_body_damage(_point: Vector2i, _cl, _current_time: int) -> void:
	pass

func try_damage(damage_blood: int, _direction: String = "C") -> void:
	if state != NORMAL:
		return
	if protected_time > 0:
		return
	if damage_blood > defense:
		real_damage(damage_blood - defense)
	elif damage_blood > 0:
		real_damage(1)

func real_damage(damage_blood: int) -> void:
	remain_blood -= maxi(damage_blood, self_damage_blood)
	self_damage_blood = 0
	if remain_blood <= 0:
		remain_blood = 0
		switch_state(LOSE)
		die()
		return
	if protected_time <= 0:
		protected_time = 3000

func die() -> void:
	polymorph = 0
	footprint_instances.clear()
	for component in character_frame_idxs.keys():
		character_frame_idxs[component] = 0

func revive(heal_blood: int) -> void:
	switch_state(NORMAL)
	heal(heal_blood)
	real_damage(0)

func heal(heal_blood: int) -> void:
	if state != NORMAL:
		return
	remain_blood = mini(blood, remain_blood + heal_blood)
	remain_blood -= self_damage_blood
	self_damage_blood = 0

func slow_for(duration: int, speed_rate: float) -> void:
	if slow_begin != 0:
		return
	slow += 1
	slow_begin = Time.get_ticks_msec()
	slow_duration = duration
	slow_speed = speed_rate * speed
	speed -= slow_speed

func check_slow_time(current_time: int) -> void:
	if slow_begin != 0 and current_time - slow_begin > slow_duration:
		slow -= 1
		slow_begin = 0
		speed += slow_speed

func rooted_for(duration: int) -> void:
	if rooted_begin == 0:
		rooted += 1
	rooted_begin = Time.get_ticks_msec()
	rooted_duration = duration

func check_rooted_time(current_time: int) -> void:
	if rooted_begin != 0 and current_time - rooted_begin > rooted_duration:
		rooted -= 1
		rooted_begin = 0

func reverse_for(duration: int) -> void:
	if reverse_begin != 0:
		return
	reverse += 1
	reverse_begin = Time.get_ticks_msec()
	reverse_duration = duration

func check_reverse_time(current_time: int) -> void:
	if reverse_begin != 0 and current_time - reverse_begin > reverse_duration:
		reverse -= 1
		reverse_begin = 0

func polymorph_for(_duration: int) -> void:
	pass

func check_polymorph_time(_current_time: int) -> void:
	pass

func collide_wall() -> void:
	pass

func collide_district() -> void:
	pass

func try_push(_direction: String, _offset = Vector2i(0, 0)) -> void:
	pass

func switch_state(new_state: int) -> void:
	state = new_state
	character_frame_trigger = true
	if new_state == LOSE:
		for s in skill_instances.duplicate():
			skill_instances.erase(s)

func get_y() -> float:
	return float(y) + 0.1

# (player.draw) -- composited onto a CanvasItem (the main area).
# Tinting is applied at draw time via modulate Color instead of CPU pixel ops.
# Per-component colors from character["COLORS"] override the global color.
func draw(ci: CanvasItem) -> void:
	hidden = if_hide()
	if hidden:
		return
	var blink_alpha = float(temporary_alpha) / 255.0
	var comp_colors: Dictionary = character.get("COLORS", {})
	for s in effects_behind:
		if s.has_method("draw"):
			s.draw(ci)
	if state == NORMAL:
		for component in CHARACTER_COMPONENTS[orientation]:
			if not character.has(STAND + orientation):
				continue
			if not character[STAND + orientation].has(component):
				continue
			var frames: Array = character[STAND + orientation][component]
			if frames.is_empty():
				continue
			var idx: int = character_frame_idxs[component]
			if idx >= frames.size():
				idx = 0
				character_frame_idxs[component] = 0
			var fr: Frame = frames[idx]
			var comp_color: Color = comp_colors.get(component, color)
			comp_color.a = blink_alpha
			fr.draw(ci, x_pos + cx, y_pos + cy, comp_color)
	elif state == LOSE and character.has("LOSE"):
		for component in CHARACTER_COMPONENTS[orientation]:
			if not character["LOSE"].has(component):
				continue
			var frames: Array = character["LOSE"][component]
			if frames.is_empty():
				continue
			var fr: Frame = frames[character_frame_idxs[component]]
			var comp_color: Color = comp_colors.get(component, color)
			comp_color.a = blink_alpha
			fr.draw(ci, x_pos + cx, y_pos + cy, comp_color)
	for s in effects_front:
		if s.has_method("draw"):
			s.draw(ci)

func _draw_hp_bar(ci: CanvasItem, fill_color: Color) -> void:
	if blood <= 0:
		return
	var bar_w = 30.0
	var bar_h = 4.0
	var ratio = clampf(float(remain_blood) / float(blood), 0.0, 1.0)
	var bar_x = float(x) * G.GAME_SQUARE + G.HALF_GAME_SQUARE - bar_w * 0.5
	var bar_y = float(y) * G.GAME_SQUARE - 66.0
	ci.draw_rect(Rect2(bar_x - 1, bar_y - 1, bar_w + 2, bar_h + 2), Color(0, 0, 0, 0.5))
	ci.draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.1, 0.1, 0.1, 0.85))
	if ratio > 0.0:
		ci.draw_rect(Rect2(bar_x, bar_y, bar_w * ratio, bar_h), fill_color)
