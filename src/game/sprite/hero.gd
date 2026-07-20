# res://src/game/sprite/hero.gd
# Port of game/sprite/hero.py
class_name Hero
extends Player

var hero_json: Dictionary = {}
var bomb_skin: Dictionary = {}
var bomb_decoration: String = ""
var icon_img: String = ""
var bomb: int = 0
var power: int = 0
var restore: int = 0
var damage: int = 0
var remain_bombs: int = 0
var bomb_time_old: int = 0

const DECORATION_CATEGORIES = ["cap", "hair", "eye", "ear", "mouth", "cladorn", "fpack", "npack", "thadorn", "footprint"]

func _init(hero_name: String, xy: Vector2i, color_: Color = C.CHARACTER_RED):
	super._init(hero_name, xy, color_)
	color = color_
	rooted = 0
	load_hero(hero_name)

func load_hero(hero_name: String) -> void:
	var path = G.GAME_ROOT + "hero/" + hero_name + ".json"
	hero_json = Utils.load_json(path)
	if hero_json == null:
		push_error("Hero.load_hero: missing %s" % path)
		return
	bomb_skin = BombLoader.get_bomb(str(hero_json["decorations"]["bomb_skin"]))
	icon_img = str(hero_json["icon_img"])
	blood = int(hero_json["blood"])
	speed = float(hero_json["speed"]) * G.GAME_SQUARE / 1000.0
	bomb = int(hero_json["bomb"])
	power = int(hero_json["power"])
	restore = int(hero_json["restore"])
	damage = int(hero_json["damage"])
	defense = int(hero_json["defense"])
	remain_blood = blood
	remain_bombs = bomb
	for s in hero_json["skills"]:
		skill_names.append(s["name"])
		skill_init_times.append(int(s["init"]) + Time.get_ticks_msec())
		skill_intervals.append(int(s["interval"]))
		skill_remains.append(int(s["max"]))
		skill_params.append(s.get("params", []))
	var decorations = load_decorations()
	var use_custom = hero_json.get("use_custom_textures", false)
	var custom_textures = {}
	if use_custom:
		var offsets = hero_json.get("custom_texture_offsets", {})
		custom_textures = HeroData.build_custom_textures_dict(hero_name, offsets)
	character = load_character(str(hero_json.get("character", "")), color, decorations, false, custom_textures)
	if hero_json["decorations"].get("bomb_effect", null) != null:
		bomb_decoration = str(hero_json["decorations"]["bomb_effect"])

func load_decorations() -> Dictionary:
	var decorations: Dictionary = {}
	for component in DECORATION_CATEGORIES:
		var name = hero_json["decorations"].get(component, null)
		if name == null:
			continue
		if component == "footprint":
			allow_footprint = true
			continue
		var path = G.FRAME_ROOT + component + "/" + str(name) + ".json"
		var j = Utils.load_json(path)
		if j != null:
			decorations[component.capitalize()] = j
	return decorations

func set_bomb() -> void:
	if state != NORMAL:
		return
	if remain_bombs <= 0:
		return
	if polymorph > 0:
		return
	var cl = Game.current_level
	var p = Vector2i(x, y)
	if cl.get_bomb_instance(p.x, p.y).size() > 0:
		return
	# sound_player.play("bomb")  -- TODO: port sound
	var b = BombInstance.new(p.x, p.y, cl.bomb_instances, bomb_skin, power, 999999 if Game.dev_mode else damage, self)
	if bomb_decoration != "":
		pass  # TODO: EffectInstance(bomb_decoration, b, ...)
	remain_bombs -= 1
	bomb_time_old = Time.get_ticks_msec()

func update() -> void:
	super.update()
	var current_time = Time.get_ticks_msec()
	time_restore_a_bomb(current_time)
	check_district_lock()

func stimulate_x_y_changed_trigger() -> void:
	super.stimulate_x_y_changed_trigger()
	if x_y_changed_trigger:
		var cl = Game.current_level
		cl.recal_npc_paths = true
		cl.recal_ghost_paths = true
		cl.obstacle_instances_need_to_update = true

func time_restore_a_bomb(current_time: int) -> void:
	if current_time - bomb_time_old > restore:
		bomb_time_old = current_time
		restore_a_bomb()

func restore_a_bomb() -> void:
	if remain_bombs >= bomb:
		return
	remain_bombs += 1

func half_body_damage(point: Vector2i, cl, current_time: int) -> void:
	if not half_body_safe(point, cl, current_time):
		try_damage(cl.grid_damage_blood[point])

func half_body_safe(point: Vector2i, cl, current_time: int) -> bool:
	var is_safe = false
	var l_pos = x_pos - float(x) * G.GAME_SQUARE
	var l_point = Vector2i(point.x - 1, point.y)
	if 0 <= l_pos and l_pos <= G.HALF_BODY_PIXEL:
		if current_time - cl.grid_damage_time[l_point] >= cl.accumulation_time:
			is_safe = true
	var r_pos = float(x + 1) * G.GAME_SQUARE - x_pos
	var r_point = Vector2i(point.x + 1, point.y)
	if 0 <= r_pos and r_pos <= G.HALF_BODY_PIXEL:
		if current_time - cl.grid_damage_time[r_point] >= cl.accumulation_time:
			is_safe = true
	var d_pos = float(y + 1) * G.GAME_SQUARE - y_pos
	var d_point = Vector2i(point.x, point.y + 1)
	if 0 <= d_pos and d_pos <= G.HALF_BODY_PIXEL:
		if current_time - cl.grid_damage_time[d_point] >= cl.accumulation_time:
			is_safe = true
	var u_pos = y_pos - float(y) * G.GAME_SQUARE
	var u_point = Vector2i(point.x, point.y - 1)
	if 0 <= u_pos and u_pos <= G.HALF_BODY_PIXEL:
		if current_time - cl.grid_damage_time[u_point] >= cl.accumulation_time:
			is_safe = true
	return is_safe

func check_district_lock() -> void:
	if district_locked:
		return
	var square: Dictionary = Game.current_level.district_square
	if square == null:
		return
	if square["x1"] <= x_pos and x_pos <= square["x2"] and square["y1"] <= y_pos and y_pos <= square["y2"]:
		district_locked = true
		collide_district()

func collide_district() -> void:
	Game.current_level.alarm_district()

func try_push(direction: String, offset = Vector2i(0, 0)) -> void:
	var oi: Dictionary = Game.current_level.obstacle_instances
	var d2p = {"R": Vector2i(x + 1, y), "U": Vector2i(x, y - 1), "L": Vector2i(x - 1, y), "D": Vector2i(x, y + 1)}
	var p = Vector2i(d2p[direction].x + offset.x, d2p[direction].y + offset.y)
	if oi.has(p):
		oi[p].push(direction)

func die() -> void:
	super.die()
	# sound_player.play("hero_dead") -- TODO
	for n in Game.current_level.npcs:
		n.resentful = false

func dev_use_skill(idx: int) -> void:
	if idx > skill_names.size() - 1:
		return
	if state == LOSE and skill_names[idx] != "RevivalCard":
		return
	if polymorph > 0:
		return
	_execute_skill(idx)

func use_skill(idx: int) -> void:
	if idx > skill_names.size() - 1:
		return
	if state == LOSE and skill_names[idx] != "RevivalCard":
		return
	if polymorph > 0:
		return
	var current_time = Time.get_ticks_msec()
	if current_time < int(skill_init_times[idx]) or int(skill_remains[idx]) == 0:
		return
	_execute_skill(idx)
	skill_remains[idx] = int(skill_remains[idx]) - 1
	skill_init_times[idx] = current_time + int(skill_intervals[idx])

func _execute_skill(idx: int) -> void:
	var name: String = skill_names[idx]
	match name:
		"BloodElixirSmall":
			remain_blood = mini(remain_blood + 800, blood)
		"BloodElixirMiddle":
			remain_blood = mini(remain_blood + 1500, blood)
		"BloodElixirLarge":
			remain_blood = mini(remain_blood + 3000, blood)
		"RevivalCard":
			if state == LOSE:
				var revive_hp = 1500
				if skill_params[idx].size() > 0:
					revive_hp = int(skill_params[idx][0])
				remain_blood = mini(revive_hp, blood)
				switch_state(NORMAL)
				protected_time = 3000
		_:
			pass
