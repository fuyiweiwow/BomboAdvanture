extends Node2D

const Hero = preload("res://src/game/sprite/hero.gd")
const Level = preload("res://src/game/level/level.gd")
const LevelData = preload("res://src/level_editor/level_data.gd")
const LEVEL_SESSION = preload("res://src/level/level_session.gd")
const LEVEL_PROGRESS_REPOSITORY = preload("res://src/level/level_progress_repository.gd")
const WorldMapGenerator = preload("res://src/game/level/world_map_generator.gd")
const MissionService = preload("res://src/adventure/mission_service.gd")
const AdventureGeneratorConfig = preload("res://src/adventure/adventure_generator_config.gd")
const AdventureProfileRepository = preload("res://src/adventure/adventure_profile_repository.gd")
const AdventureSettlementService = preload("res://src/adventure/adventure_settlement_service.gd")

var cfg_json: Dictionary = {}
var your_name: String = ""
var map_set_json: Dictionary = {}
var map_set_at: int = -1
var music_volume: float = 1.0
var frame_rate: int = 90
var display_frame_rate: bool = false
var grid_damage_duration: int = 500
var dev_mode: bool = false
var selected_level_profile: Dictionary = {}

var me = null
var current_level = null
var game_complete: bool = false
var sandbox_mode: bool = false
var selected_hero: String = ""
var selected_color: String = ""
var selected_level: String = ""
var level_json: Dictionary = {}
var _pending_map_data: Dictionary = {}
var active_mission: Dictionary = {}
var last_mission_result: Dictionary = {}
var _adventure_profile_repository = AdventureProfileRepository.new()
var settlement_error: String = ""
var _settlement_retry_at_msec: int = 0

const SETTLEMENT_RETRY_DELAY_MSEC := 1000

var _ui_layer: CanvasLayer = null

var orientations: Dictionary = {}
var walking_stack: Array = []
var bomb_old: int = 0
var f6_old: bool = false
var f7_old: bool = false
var reset_old: bool = false
var skills_old: Array = [false, false, false, false, false, false, false]
var key2idx: Dictionary = {}
var cfg_space: int = 0
var cfg_f6: int = 0
var cfg_reset: int = 0

const K_RIGHT = KEY_RIGHT
const K_UP = KEY_UP
const K_LEFT = KEY_LEFT
const K_DOWN = KEY_DOWN
const K_SPACE = KEY_SPACE
const K_F6 = KEY_F6
const K_F7 = KEY_F7
const K_RESET = KEY_0

func _ready() -> void:
	init_game()
	preload_assets()
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 128
	var ui_node = Node2D.new()
	ui_node.set_script(preload("res://src/main/ui.gd"))
	_ui_layer.add_child(ui_node)
	add_child(_ui_layer)
	call_deferred("_show_title")

var _last_r_state: bool = false
var _last_t_state: bool = false

func _show_title() -> void:
	var ts = Control.new()
	ts.set_script(preload("res://src/main/title_screen.gd"))
	_add_screen(ts)

func _add_screen(screen: Node) -> void:
	if screen is Control:
		(screen as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().root.call_deferred("add_child", screen)

func _unhandled_input(event: InputEvent) -> void:
	if sandbox_mode:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if game_complete:
			if event.keycode == KEY_R:
				game_complete = false
				init_game()
				proceed_game(true)
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_T:
				game_complete = false
				_return_to_title()
				get_viewport().set_input_as_handled()
		elif current_level != null and me != null and me.state == 1:
			if event.keycode == KEY_R:
				init_game()
				proceed_game(true)
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_T:
				_return_to_title()
				get_viewport().set_input_as_handled()

func _return_to_title() -> void:
	current_level = null
	me = null
	map_set_at = -1
	dev_mode = false
	game_complete = false
	selected_hero = ""
	selected_color = ""
	selected_level = ""
	level_json = {}
	selected_level_profile = {}
	active_mission = {}
	LEVEL_SESSION.clear()
	position = Vector2(0, 0)
	_show_title()

func start_game(dev: bool) -> void:
	active_mission = {}
	dev_mode = dev
	map_set_at = -1
	_apply_level_session()
	proceed_game()

func _process(_delta: float) -> void:
	if current_level != null and not sandbox_mode:
		frame_step()
		if current_level != null:
			current_level.scroll_map()
			position = Vector2(1.0 - current_level.scroll_x_pos, 21.0 - current_level.scroll_y_pos)
	queue_redraw()
	if _ui_layer != null and _ui_layer.get_child_count() > 0:
		_ui_layer.get_child(0).queue_redraw()

func _draw() -> void:
	if current_level != null and not sandbox_mode and current_level.has_method("draw_world"):
		current_level.draw_world(self)

func init_game() -> void:
	cfg_json = RM.get_json(G.ASSET_ROOT + "config.json")
	if cfg_json == null:
		push_error("Game: cannot open " + G.ASSET_ROOT + "config.json")
		cfg_json = {}
		return
	map_set_at = -1
	game_complete = false
	G.DISPLAY_NPC_NAME_CARD = bool(cfg_json.get("display_npc_name_card", false))
	G.DISPLAY_NPC_BLOOD = bool(cfg_json.get("display_npc_blood", true))
	music_volume = float(cfg_json.get("music_volume", 1.0))
	frame_rate = int(cfg_json.get("frame_rate", 90))
	G.SOUND_VOLUME = float(cfg_json.get("sound_volume", 1.0))
	G.DISPLAY_FRAME_RATE = bool(cfg_json.get("display_frame_rate", false))
	G.FIRST_FRAME_SHORTEN_RATE = float(cfg_json.get("first_frame_shorten_rate", 1.0))
	G.LOW_CONFIG_MODE = bool(cfg_json.get("low_config_mode", false))
	grid_damage_duration = int(cfg_json.get("grid_damage_duration", 500))
	your_name = str(cfg_json.get("your_name", "玩家"))
	init_keys(cfg_json["keys"])
	var resource_dir: String = str(cfg_json.get("resource_dir", ""))
	if resource_dir != "":
		RM.set_custom_dir(resource_dir)
	var map_set: String = str(cfg_json.get("map_set", "YongDong"))
	map_set_json = RM.get_json(G.GAME_ROOT + "map_set/" + map_set + ".json")
	if map_set_json == null:
		map_set_json = {}
	selected_level_profile = {}
	active_mission = {}

func _apply_level_session() -> void:
	selected_level_profile = {}
	if not LEVEL_SESSION.has_selected_level():
		return
	var profile = LEVEL_SESSION.current_profile()
	var map_name = str(profile.get("map_name", ""))
	if map_name == "":
		return
	selected_level_profile = profile
	map_set_json = {"maps": [map_name]}

func init_keys(keys_root: Dictionary) -> void:
	orientations = {K_RIGHT: "R", K_UP: "U", K_LEFT: "L", K_DOWN: "D"}
	key2idx = {KEY_1: 0, KEY_2: 1, KEY_3: 2, KEY_4: 3, KEY_5: 4, KEY_6: 5, KEY_7: 6}
	cfg_space = K_SPACE
	cfg_f6 = K_F6
	cfg_reset = K_RESET

func preload_assets() -> void:
	pass

func proceed_game(is_reset = false) -> void:
	if not map_set_json.has("maps") or not map_set_json["maps"] is Array or map_set_json["maps"].is_empty():
		return _on_game_complete()
	map_set_at += 1
	if selected_level != "":
		if level_json.is_empty():
			level_json = LevelData.load_level(selected_level)
		if map_set_at >= level_json.get("maps", []).size():
			return _on_game_complete()
		var map_entry = level_json["maps"][map_set_at]
		var map_name: String
		var map_data: Dictionary = {}
		if map_entry.get("type") == "predefined":
			map_name = str(map_entry.get("map_id", ""))
		else:
			map_name = _generate_procedural_map(map_entry)
			map_data = _pending_map_data
		if map_name == "":
			return _on_game_complete()
		var hero_name: String = selected_hero if selected_hero != "" else str(cfg_json["your_hero"])
		var character_color: String = selected_color if selected_color != "" else str(cfg_json["your_character_color"])
		set_level(your_name, map_name, hero_name, character_color, is_reset, map_data)
	else:
		if map_set_at >= map_set_json["maps"].size():
			return _on_game_complete()
		var map_name: String = str(map_set_json["maps"][map_set_at])
		var hero_name: String = selected_hero if selected_hero != "" else str(cfg_json["your_hero"])
		var character_color: String = selected_color if selected_color != "" else str(cfg_json["your_character_color"])
		set_level(your_name, map_name, hero_name, character_color, is_reset)

func _generate_procedural_map(map_entry: Dictionary) -> String:
	# Generate a procedural world from the level entry's generator_params and
	# stash it in _pending_map_data (consumed by set_level). Returns a placeholder
	# name; the actual map comes from memory, not a file.
	var params = map_entry.get("generator_params", {})
	var recipe: Dictionary = {
		"floor": str(params.get("floor", "elem220")),
		"wall": str(params.get("wall", "elem212")),
		"breakable": params.get("breakable", ["elem225", "elem226", "elem227"]),
		"monsters": _monsters_from_params(params),
		"density": float(params.get("density", 0.25)),
		"name": str(params.get("name", "procedural")),
	}
	var world = WorldMapGenerator.generate({
		"count": clampi(int(params.get("count", 5)), 1, 20),
		"seed": int(params.get("seed", 0)),
		"zone_width": clampi(int(params.get("width", 21)), 11, 60),
		"zone_height": clampi(int(params.get("height", 15)), 11, 40),
		"recipe": recipe,
	})
	_pending_map_data = world
	return "procedural"


func _monsters_from_params(params: Dictionary) -> Array:
	var pool = params.get("monster_pool", [])
	var out: Array = []
	if pool is Array:
		for m in pool:
			if m is Dictionary:
				out.append((m as Dictionary).duplicate(true))
			else:
				out.append({"name": str(m), "max": 4})
	return out


# One-click entry: generate a fresh procedural world and jump straight in.
func start_procedural_world(recipe_name: String = "", overrides: Dictionary = {}, clear_mission: bool = true) -> void:
	if clear_mission:
		active_mission = {}
	var recipe: Dictionary = {}
	if recipe_name != "":
		recipe = RM.get_json("res://src/tests/recipes/" + recipe_name + ".json")
		if recipe == null:
			recipe = {}
	var params := AdventureGeneratorConfig.build(recipe, overrides)
	_generate_procedural_map({"generator_params": params})
	selected_level = ""
	selected_level_profile = {}
	map_set_json = {"maps": ["procedural"]}
	map_set_at = -1
	proceed_game()

func start_adventure_mission(definition: Dictionary, launch_world: bool = true) -> bool:
	var raw_generator = definition.get("generator", {})
	if not raw_generator is Dictionary:
		return false
	var session := MissionService.accept(definition)
	if session.is_empty():
		return false
	last_mission_result = {}
	settlement_error = ""
	_settlement_retry_at_msec = 0
	if me != null:
		session["run_start_balances"] = {
			"gold": int(me.gold),
			"items": (me.items as Dictionary).duplicate(true),
		}
	active_mission = session
	var generator: Dictionary = raw_generator
	if launch_world:
		start_procedural_world(str(generator.get("recipe", "forest")), generator, false)
	return true

func record_mission_progress(event_type: String, amount: int = 1) -> bool:
	return MissionService.add_progress(active_mission, amount, event_type)

func _complete_adventure_mission() -> bool:
	var now := Time.get_ticks_msec()
	if now < _settlement_retry_at_msec:
		return false
	var result := AdventureSettlementService.complete(
		active_mission,
		_adventure_profile_repository,
		_run_loot_rewards()
	)
	if result.is_empty():
		settlement_error = "reward_save_failed"
		_settlement_retry_at_msec = now + SETTLEMENT_RETRY_DELAY_MSEC
		return false
	settlement_error = ""
	_settlement_retry_at_msec = 0
	_apply_adventure_rewards(result)
	last_mission_result = result
	active_mission = {}
	_return_to_city()
	return true

func _run_loot_rewards() -> Dictionary:
	if me == null:
		return {}
	var baseline_value = active_mission.get("run_start_balances", {})
	var baseline: Dictionary = baseline_value if baseline_value is Dictionary else {}
	var baseline_items_value = baseline.get("items", {})
	var baseline_items: Dictionary = baseline_items_value if baseline_items_value is Dictionary else {}
	var item_deltas: Dictionary = {}
	for item_id in me.items:
		var delta := int(me.items[item_id]) - int(baseline_items.get(item_id, 0))
		if delta > 0:
			item_deltas[str(item_id)] = delta
	return {
		"gold": maxi(0, int(me.gold) - int(baseline.get("gold", 0))),
		"items": item_deltas,
	}

func _apply_adventure_rewards(result: Dictionary) -> void:
	if me == null:
		return
	hydrate_adventure_profile(me)

func hydrate_adventure_profile(hero) -> void:
	if hero == null:
		return
	var profile := _adventure_profile_repository.snapshot()
	hero.gold = int(profile.get("gold", 0))
	hero.items = (profile.get("items", {}) as Dictionary).duplicate(true)

func persist_adventure_profile(hero) -> bool:
	return hero != null and _adventure_profile_repository.save_balances(int(hero.gold), hero.items)

func persist_adventure_balances(gold: int, items: Dictionary) -> bool:
	return _adventure_profile_repository.save_balances(gold, items)

func _return_to_city() -> void:
	current_level = null
	game_complete = false
	position = Vector2.ZERO
	if not is_inside_tree():
		return
	var city = load("res://src/city/city_scene.gd").new()
	_add_screen(city)

func _on_game_complete() -> void:
	game_complete = true
	current_level = null
	me = null

func set_level(your_name_: String, map_name: String, hero_name: String, character_color: String, is_reset = false, map_data: Dictionary = {}) -> void:
	var character_colors = {
		"Red": C.CHARACTER_RED, "Blue": C.CHARACTER_BLUE, "Yellow": C.CHARACTER_YELLOW,
		"Green": C.CHARACTER_GREEN, "Orange": C.CHARACTER_ORANGE, "Pink": C.CHARACTER_PINK,
		"Purple": C.CHARACTER_PURPLE, "Black": C.CHARACTER_BLACK,
	}
	var color: Color = character_colors.get(character_color, C.CHARACTER_RED)
	var new_me = Hero.new(hero_name, Vector2i(0, 0), color)
	if me != null and not is_reset:
		new_me.skill_remains = me.skill_remains
	me = new_me
	if map_data.is_empty() and not _pending_map_data.is_empty():
		map_data = _pending_map_data
	_pending_map_data = {}
	current_level = Level.new(your_name_, map_name, me, grid_damage_duration, map_data)

func frame_step() -> void:
	if not active_mission.is_empty() and MissionService.is_complete(active_mission):
		if _complete_adventure_mission():
			return
	if current_level != null:
		if current_level.finish_flag:
			if not active_mission.is_empty():
				# A durable claim failure is retried on a later frame; keep the run.
				pass
			elif not selected_level_profile.is_empty():
				_complete_selected_level()
				_on_game_complete()
			else:
				proceed_game()
		else:
			current_level.update()
	key_pressed()

func _complete_selected_level() -> void:
	var level_id = str(selected_level_profile.get("id", ""))
	if level_id != "":
		var progress_repository = LEVEL_PROGRESS_REPOSITORY.new()
		progress_repository.complete_level(level_id)

func key_pressed() -> void:
	if me == null:
		return
	player_bomb()
	player_move()
	player_f6()
	player_f7()
	player_reset()
	player_skill()

func player_move() -> void:
	for kc in orientations.keys():
		if Input.is_key_pressed(kc):
			if not walking_stack.has(kc):
				walking_stack.push_front(kc)
		else:
			if walking_stack.has(kc):
				walking_stack.erase(kc)
	var first = 0
	if walking_stack.size() > 0:
		first = walking_stack[0]
	if first == 0:
		me.set_motion()
	else:
		me.set_motion(orientations[first])

func player_bomb() -> void:
	if Input.is_key_pressed(cfg_space):
		if bomb_old == 0:
			me.set_bomb()
		bomb_old += 1
	else:
		bomb_old = 0

func player_f6() -> void:
	if Input.is_key_pressed(cfg_f6):
		if f6_old:
			return
		G.DISPLAY_NPC_NAME_CARD = not G.DISPLAY_NPC_NAME_CARD
		f6_old = true
	else:
		f6_old = false

func player_f7() -> void:
	if Input.is_key_pressed(K_F7):
		if f7_old:
			return
		G.DISPLAY_NPC_BLOOD = not G.DISPLAY_NPC_BLOOD
		f7_old = true
	else:
		f7_old = false

func player_reset() -> void:
	if Input.is_key_pressed(cfg_reset):
		if reset_old:
			return
		init_game()
		proceed_game(true)
		reset_old = true
	else:
		reset_old = false

func player_skill() -> void:
	for kc in key2idx.keys():
		var idx: int = key2idx[kc]
		if Input.is_key_pressed(kc):
			if skills_old[idx]:
				continue
			if dev_mode:
				me.dev_use_skill(idx)
			else:
				me.use_skill(idx)
			skills_old[idx] = true
		else:
			skills_old[idx] = false
