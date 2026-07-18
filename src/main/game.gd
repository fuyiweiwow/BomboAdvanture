# res://src/main/game.gd
# Autoload "Game" -- port of game/control.py (Control).
# Owns the config, the current Hero (`me`) and the current Level,
# drives the per-frame update, translates input into player actions,
# and renders the world (acts as both Main + World from the original design).
extends Node2D

const Hero = preload("res://src/game/sprite/hero.gd")
const Level = preload("res://src/game/level/level.gd")

var cfg_json: Dictionary = {}
var your_name: String = ""
var map_set_json: Dictionary = {}
var map_set_at: int = -1
var music_volume: float = 1.0
var frame_rate: int = 90
var display_frame_rate: bool = false
var grid_damage_duration: int = 500

var me = null
var current_level = null

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

# --- Godot keycodes (KEY_* are global constants) ---
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
	proceed_game()
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 128
	var ui_node = Node2D.new()
	ui_node.set_script(preload("res://src/main/ui.gd"))
	_ui_layer.add_child(ui_node)
	add_child(_ui_layer)

# Per-frame update + rendering driver (replaces Main._process + World._draw).
func _process(_delta: float) -> void:
	if current_level != null:
		frame_step()
		current_level.scroll_map()
		position = Vector2(1.0 - current_level.scroll_x_pos, 21.0 - current_level.scroll_y_pos)
		queue_redraw()
		if _ui_layer != null and _ui_layer.get_child_count() > 0:
			_ui_layer.get_child(0).queue_redraw()

func _draw() -> void:
	if current_level != null and current_level.has_method("draw_world"):
		current_level.draw_world(self)

func init_game() -> void:
	var f = FileAccess.open(G.ASSET_ROOT + "config.json", FileAccess.READ)
	if f == null:
		push_error("Game: cannot open " + G.ASSET_ROOT + "config.json")
		return
	cfg_json = JSON.parse_string(f.get_as_text())
	f.close()
	map_set_at = -1
	G.DISPLAY_NPC_NAME_CARD = bool(cfg_json.get("display_npc_name_card", false))
	G.DISPLAY_NPC_BLOOD = bool(cfg_json.get("display_npc_blood", false))
	music_volume = float(cfg_json.get("music_volume", 1.0))
	frame_rate = int(cfg_json.get("frame_rate", 90))
	G.SOUND_VOLUME = float(cfg_json.get("sound_volume", 1.0))
	G.DISPLAY_FRAME_RATE = bool(cfg_json.get("display_frame_rate", false))
	G.FIRST_FRAME_SHORTEN_RATE = float(cfg_json.get("first_frame_shorten_rate", 1.0))
	G.LOW_CONFIG_MODE = bool(cfg_json.get("low_config_mode", false))
	grid_damage_duration = int(cfg_json.get("grid_damage_duration", 500))
	your_name = str(cfg_json.get("your_name", "玩家"))
	init_keys(cfg_json["keys"])
	var map_set: String = str(cfg_json.get("map_set", "YongDong"))
	var ms_path = G.GAME_ROOT + "map_set/" + map_set + ".json"
	var mf = FileAccess.open(ms_path, FileAccess.READ)
	if mf != null:
		map_set_json = JSON.parse_string(mf.get_as_text())
		mf.close()

func init_keys(keys_root: Dictionary) -> void:
	orientations = {K_RIGHT: "R", K_UP: "U", K_LEFT: "L", K_DOWN: "D"}
	key2idx = {KEY_1: 0, KEY_2: 1, KEY_3: 2, KEY_4: 3, KEY_5: 4, KEY_6: 5, KEY_7: 6}
	cfg_space = K_SPACE
	cfg_f6 = K_F6
	cfg_reset = K_RESET

func preload_assets() -> void:
	pass

func proceed_game(is_reset = false) -> void:
	map_set_at += 1
	var map_name: String = str(map_set_json["maps"][map_set_at])
	var hero_name: String = str(cfg_json["your_hero"])
	var character_color: String = str(cfg_json["your_character_color"])
	set_level(your_name, map_name, hero_name, character_color, is_reset)

func set_level(your_name_: String, map_name: String, hero_name: String, character_color: String, is_reset = false) -> void:
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
	current_level = Level.new(your_name_, map_name, me, grid_damage_duration)

# Per-frame step driven by Main._process.
func frame_step() -> void:
	if current_level != null:
		if current_level.finish_flag:
			proceed_game()
		else:
			current_level.update()
	key_pressed()

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
			me.use_skill(idx)
			skills_old[idx] = true
		else:
			skills_old[idx] = false
