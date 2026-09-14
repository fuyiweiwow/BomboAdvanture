# res://src/game/sprite/npc.gd
# Port of game/sprite/npc.py (core). Full A* pathfinding and the
# ~100 NPC skills are deferred (see TODOs); this gives working
# wander / greedy chase / contact damage / bomb placement.
class_name Npc
extends Player

var npc_json = {}
var chs_name: String = ""
var idx_motion = {0: "R", 1: "U", 2: "L", 3: "D"}
var contact: int = 0
var resent_dist: float = 0.0
var resentful: bool = false
var mocking: bool = false
var friendly: bool = false
var boss_mode: bool = false
var npc_time_init: int = 0
var wander_random: int = 10
var chase_path: Dictionary = {}
var npc_skill_time: int = 0
var bomb_skin: Dictionary = {}
var gifts = null
var death = null
var face_texture: Texture2D = null
var drops_key: bool = false
var npc_file_name: String = ""

func _init(npc_name: String, xy: Vector2i, color_: Color = C.CHARACTER_RED):
	super._init(npc_name, xy, color_)
	district_locked = true
	bomb_skin = BombLoader.get_bomb("bomb1")
	load_npc(npc_name, color_)

func load_npc(npc_name: String, color_: Color) -> void:
	npc_file_name = npc_name
	var path = G.GAME_ROOT + "npc/" + npc_name + ".json"
	npc_json = Utils.load_json(path)
	if npc_json == null:
		push_error("Npc.load_npc: missing %s" % path)
		return
	chs_name = str(npc_json["chs_name"])
	blood = int(npc_json["blood"])
	if npc_json.has("self_damage_blood"):
		self_damage_blood = int(npc_json["self_damage_blood"])
	speed = float(npc_json["speed"]) * G.GAME_SQUARE / 1000.0
	contact = int(npc_json["contact"])
	defense = int(npc_json["defense"])
	if npc_json.has("boss_mode"):
		boss_mode = bool(npc_json["boss_mode"])
	if npc_json.has("gifts"):
		gifts = npc_json["gifts"]
	if npc_json.has("death"):
		death = npc_json["death"]
	resent_dist = float(int(npc_json["resent_dist"])) * G.GAME_SQUARE
	if npc_json.has("skills"):
		for s in npc_json["skills"]:
			skill_names.append(s["name"])
			skill_init_times.append(int(s["init"]))
			skill_intervals.append(int(s["interval"]))
			skill_remains.append(int(s["max"]))
			skill_params.append(s.get("params", []))
	remain_blood = blood
	chase_path = {}
	npc_time_init = Time.get_ticks_msec()
	var decorations = _load_decorations()
	var component_colors = _build_component_colors()
	character = load_character(str(npc_json["character"]), color_, decorations, false, {}, component_colors)
	_extract_face_texture()

func _extract_face_texture() -> void:
	if not character.has("STAND_D"):
		return
	for comp_name in CHARACTER_COMPONENTS["D"]:
		if character["STAND_D"].has(comp_name) and character["STAND_D"][comp_name].size() > 0:
			var frame = character["STAND_D"][comp_name][0] as Frame
			if frame != null and frame.texture != null:
				face_texture = frame.texture
				return

func _load_decorations() -> Dictionary:
	var decorations: Dictionary = {}
	if not npc_json.has("decorations"):
		return decorations
	for component in Hero.DECORATION_CATEGORIES:
		var name = npc_json["decorations"].get(component, null)
		if name == null:
			continue
		if component == "footprint":
			allow_footprint = true
			continue
		var path = G.FRAME_ROOT + component + "/" + str(name) + ".json"
		var j = Utils.load_json(path)
		if j != null:
			decorations[_capitalize_key(component)] = j
	return decorations

func _capitalize_key(component: String) -> String:
	var parts = component.split("_")
	for i in parts.size():
		parts[i] = parts[i].capitalize()
	return "_".join(parts)

func _build_component_colors() -> Dictionary:
	var result: Dictionary = {}
	var colors_data = npc_json.get("colors", {})
	for comp_name in colors_data:
		var val = colors_data[comp_name]
		if val is Array:
			if val.size() >= 4:
				result[comp_name] = Color(val[0], val[1], val[2], val[3])
			else:
				result[comp_name] = Color(val[0], val[1], val[2])
		elif val is Color:
			result[comp_name] = val
	return result

func update() -> void:
	super.update()
	var current_time = Time.get_ticks_msec()
	wander_and_detect(current_time)
	chase_hero()
	contact_damage()
	try_using_skills()
	throw()

func wander_and_detect(current_time: int) -> void:
	if (resentful or mocking) and not friendly:
		return
	if current_time - npc_time_init < 300:
		return
	if current_time % 15 == 0:
		var motion: String = idx_motion[randi() % 4]
		set_motion(motion)
	else:
		set_motion(orientation)
	for i in skill_names.size():
		skill_init_times[i] = int(npc_json["skills"][i]["init"]) + current_time
	var me = Game.current_level.me
	if me.district_locked and me.state == NORMAL:
		if abs(me.x_pos - x_pos) < resent_dist and abs(me.y_pos - y_pos) < resent_dist:
			resentful = true
			Game.current_level.recal_npc_paths = true

func chase_hero() -> void:
	if not resentful and not mocking or friendly:
		return
	var me = Game.current_level.me
	var me_point = Vector2i(me.x, me.y)
	if Game.current_level.get_bomb_instance(me_point.x, me_point.y).size() > 0:
		set_motion()
		return
	# TODO: replace greedy step with aStar.cal_path for faithful pathfinding.
	var dx = me.x_pos - x_pos
	var dy = me.y_pos - y_pos
	if abs(dx) >= abs(dy):
		if dx > 0:
			set_motion("R")
		elif dx < 0:
			set_motion("L")
		elif dy > 0:
			set_motion("D")
		elif dy < 0:
			set_motion("U")
		else:
			set_motion()
	else:
		if dy > 0:
			set_motion("D")
		elif dy < 0:
			set_motion("U")
		elif dx > 0:
			set_motion("R")
		elif dx < 0:
			set_motion("L")
		else:
			set_motion()

func half_body_damage(point: Vector2i, cl, current_time: int) -> void:
	try_damage(cl.grid_damage_blood[point])

func contact_damage() -> void:
	var me = Game.current_level.me
	if me.x == x and me.y == y:
		me.try_damage(contact, "C")

func _apply_item_effect(_data: Dictionary) -> void:
	pass

func die() -> void:
	super.die()
	gene_gifts()
	if drops_key:
		_drop_key()

func _drop_key() -> void:
	var cl = Game.current_level
	var item_data = ItemData.load_item("iron_key")
	if item_data.is_empty():
		return
	ItemInstance.new(x, y, cl.item_instances, item_data)


const SNOW_PREFIXES := ["YongDong", "FengBao", "JiZhou", "ShouWang", "NuFeng", "ShowWang"]
const FOREST_PREFIXES := ["SenLin", "MiZhiDi", "Journey"]
const FIRE_PREFIXES := ["HeiLong", "FireBall", "Fire"]


func gene_gifts() -> void:
	_drop_gold()
	_drop_material()
	_drop_rare()
	_drop_configured_gifts()


# Gold: base economy, amount scales with monster blood.
func _drop_gold() -> void:
	var count := clampi(int(blood) / 1500, 1, 3)
	var item_data = ItemData.load_item("gold_coin")
	if item_data.is_empty():
		return
	for _i in range(count):
		_drop_item_scatter(item_data)


# Material: themed alchemy ingredient, 50% chance.
func _drop_material() -> void:
	if randi() % 100 >= 50:
		return
	var mid := _material_for_npc()
	if mid == "":
		return
	var item_data = ItemData.load_item(mid)
	if item_data.is_empty():
		return
	_drop_item_scatter(item_data)


# Rare: occasional power-up, 5% chance.
func _drop_rare() -> void:
	if randi() % 100 >= 5:
		return
	var pool := ["bomb_up", "power_up", "speed_up"]
	var item_data = ItemData.load_item(pool[randi() % pool.size()])
	if item_data.is_empty():
		return
	_drop_item_scatter(item_data)


# Configurable gifts from the npc json (name/possibility). Original QQT item ids
# that don't exist in this project are skipped gracefully.
func _drop_configured_gifts() -> void:
	if gifts == null or gifts.is_empty():
		return
	for gift in gifts:
		var id := str(gift.get("name", gift.get("id", "")))
		if id == "":
			continue
		var possibility := float(gift.get("possibility", gift.get("weight", 1.0)))
		if possibility < 1.0 and randf() >= possibility:
			continue
		if possibility > 1.0:
			# legacy weight form (0..100)
			if randi() % 100 >= int(possibility):
				continue
		var item_data = ItemData.load_item(id)
		if item_data.is_empty():
			continue
		_drop_item_scatter(item_data)


func _material_for_npc() -> String:
	for p in SNOW_PREFIXES:
		if npc_file_name.begins_with(p):
			return "ice_crystal"
	for p in FOREST_PREFIXES:
		if npc_file_name.begins_with(p):
			return "red_herb"
	for p in FIRE_PREFIXES:
		if npc_file_name.begins_with(p):
			return "fire_flower"
	return "blue_herb"


func _drop_item_scatter(item_data: Dictionary) -> void:
	var cl = Game.current_level
	for attempt in range(9):
		var dx := attempt % 3 - 1
		var dy := attempt / 3 - 1
		var px := x + dx
		var py := y + dy
		if px < 0 or py < 0 or px >= cl.map_x or py >= cl.map_y:
			continue
		if cl.block[0][px][py] > 0 or cl.obstacle_instances.has(Vector2i(px, py)):
			continue
		if cl.item_instances.has(Vector2i(px, py)):
			continue
		ItemInstance.new(px, py, cl.item_instances, item_data)
		return
	ItemInstance.new(x, y, cl.item_instances, item_data)

func try_using_skills() -> void:
	if not resentful and not mocking or friendly:
		return
	npc_skill_time = Time.get_ticks_msec()
	for i in skill_names.size():
		use_skill(i)

func use_skill(idx: int) -> void:
	var current_time = Time.get_ticks_msec()
	if current_time < int(skill_init_times[idx]) or int(skill_remains[idx]) == 0:
		return
	# TODO: full NPC skill dispatch (game/skill/*.py) -- hundreds of skills.
	skill_remains[idx] = int(skill_remains[idx]) - 1
	skill_init_times[idx] = current_time + int(skill_intervals[idx])

func set_bomb() -> void:
	if state != NORMAL:
		return
	var cl = Game.current_level
	var p = Vector2i(x, y)
	if cl.get_bomb_instance(p.x, p.y).size() > 0:
		return
	BombInstance.new(p.x, p.y, cl.bomb_instances, bomb_skin, 3, 1000, self)

func set_restoration(to_x: int, to_y: int) -> void:
	x = to_x
	y = to_y

func draw(ci: CanvasItem) -> void:
	super.draw(ci)
	if G.DISPLAY_NPC_NAME_CARD:
		# TODO: draw name card (needs a Font + bg texture)
		pass

func draw_blood_bar(_ci: CanvasItem) -> void:
	pass
