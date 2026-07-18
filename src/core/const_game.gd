# res://src/core/const_game.gd  (autoload: G)
extends Node

# --- geometry constants (game/const/game.py) ---
const QQT_SIZE = 20
const QQT_SCALE = 1.5
const SCALE = QQT_SCALE
const GAME_SQUARE = 40
const BLOCK_SIZE = GAME_SQUARE
const HALF_GAME_SQUARE = float(GAME_SQUARE) / 2.0
const MAIN_AREA_X = 20
const MAIN_AREA_Y = 13
const MAIN_AREA_X_POS = MAIN_AREA_X * GAME_SQUARE
const MAIN_AREA_Y_POS = MAIN_AREA_Y * GAME_SQUARE
const BOMB_EXPLODE_TIME = 3000
const R_SCROLL = 640
const U_SCROLL = 160
const L_SCROLL = 160
const D_SCROLL = 360
const PLAYER_TEXT_COLOR = Color(1.0, 16.0 / 255.0, 16.0 / 255.0)
const HALF_BODY_PIXEL = 10

# --- mutable global flags (mirror the module-level vars in game.py) ---
var DISPLAY_NPC_NAME_CARD = false
var DISPLAY_NPC_BLOOD = false
var DISPLAY_FRAME_RATE = false
var FIRST_FRAME_SHORTEN_RATE = 1.0
var LOW_CONFIG_MODE = false
var SOUND_VOLUME = 1.0

# --- asset roots (assets copied to res://assets for Godot import) ---
const ASSET_ROOT = "res://assets/"
const GAME_ROOT = "res://assets/"
const RES_IMG_ROOT = "res://assets/img/"
const FRAME_ROOT = "res://assets/frame/"
