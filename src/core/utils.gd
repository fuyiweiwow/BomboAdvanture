# res://src/core/utils.gd
# Shared helpers: grid math, image tinting (port of algo/blender.py color_overlay),
# and JSON/file loading used across the port.
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

# (game/algo/blender.py : color_overlay)  -- tint a grayscale mask to `color`.
# Masked character components (_m) are grayscale and get overlay-blended to the
# player colour, keeping their original alpha.
static func color_overlay(src: Image, color: Color) -> Image:
	var work = src.duplicate()
	work.convert(Image.FORMAT_RGBA8)
	var cr = int(clampf(color.r, 0.0, 1.0) * 255.0)
	var cg = int(clampf(color.g, 0.0, 1.0) * 255.0)
	var cb = int(clampf(color.b, 0.0, 1.0) * 255.0)
	var data = work.get_data()
	for i in range(0, data.size(), 4):
		data[i] = _overlay_ch(data[i], cr)
		data[i + 1] = _overlay_ch(data[i + 1], cg)
		data[i + 2] = _overlay_ch(data[i + 2], cb)
	var out = Image.create_from_data(work.get_width(), work.get_height(), false, Image.FORMAT_RGBA8, data)
	return out

# overlay blend of one channel against colour channel c (0..255), alpha = 1.
static func _overlay_ch(t: int, c: int) -> int:
	if t <= 128:
		return int(t * (c + (128 - c)) / 128.0)
	return int(255 - (255 - t) * (255 - c) / 128.0)

# Load a PNG as a Texture2D (uses Godot's resource loader, works on export).
static func load_texture(path: String) -> Texture2D:
	var tex = load(path)
	if tex == null or not tex is Texture2D:
		push_error("Utils.load_texture: failed to load %s" % path)
		return null
	return tex

# Load a PNG as an Image for pixel manipulation (color overlay, etc.).
# Uses texture.get_image() which works on imported textures.
static func load_image(path: String) -> Image:
	var tex = load_texture(path)
	if tex == null:
		return null
	return tex.get_image()
