# res://src/core/utils.gd
# Shared helpers: grid math, JSON/file loading, texture loading.
class_name Utils
extends RefCounted

# (game/sprite/updatable.py : current_grid)
static func current_grid(x_pos: float, y_pos: float) -> Vector2i:
	var x = int(x_pos / G.GAME_SQUARE)
	var y = int(y_pos / G.GAME_SQUARE)
	return Vector2i(x, y)

# Load & parse a JSON file relative to the project (res://...).
static func load_json(path: String) -> Variant:
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Utils.load_json: cannot open %s" % path)
		return null
	var text = f.get_as_text()
	f.close()
	return JSON.parse_string(text)

# Load a PNG as a Texture2D (uses Godot's resource loader, works on export).
static func load_texture(path: String) -> Texture2D:
	var tex = load(path)
	if tex == null or not tex is Texture2D:
		push_error("Utils.load_texture: failed to load %s" % path)
		return null
	return tex

# Load a PNG as an Image for pixel manipulation.
static func load_image(path: String) -> Image:
	var tex = load_texture(path)
	if tex == null:
		return null
	return tex.get_image()
