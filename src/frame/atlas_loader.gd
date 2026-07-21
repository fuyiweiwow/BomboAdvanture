class_name AtlasLoader
extends RefCounted

# Runtime atlas texture loader.
#
# Caches atlas Texture2D + JSON per component type.
# Returns Texture2D (AtlasTexture for plain frames, ImageTexture for
# masked/ghost frames that need pixel manipulation).

const CHARACTER_COMPONENTS_MASKED := ["Body_m", "Cloth_m", "Hair_m", "Leg_m", "Npack_m", "Cap_m"]

static var _atlas_textures := {}  # atlas_name -> Texture2D
static var _atlas_images   := {}  # atlas_name -> Image
static var _atlas_jsons    := {}  # atlas_name -> Dictionary (parsed atlas.json)
static var _atlas_loaded   := {}  # atlas_name -> bool (loaded successfully or failed)


# Get a Texture2D for the given component frame from its atlas.
#
# Parameters:
#   atlas_name  – component type folder name, e.g. "body", "hair"
#   filename    – original PNG filename, e.g. "body1_stand_0_0.png"
#   component   – component key, e.g. "Body", "Body_m" (for masked check)
#   color       – player tint colour (only used for masked components)
#   is_ghost    – if true, halve the alpha
#
# Returns a Texture2D if the atlas + frame exist, null otherwise.
static func get_texture(atlas_name: String, filename: String,
		component: String, color: Color, is_ghost: bool) -> Texture2D:

	if not _ensure_atlas(atlas_name):
		return null

	var frames: Dictionary = _atlas_jsons[atlas_name].get("frames", {})
	if not frames.has(filename):
		return null

	var frame_data: Dictionary = frames[filename]["frame"]
	var fx := int(frame_data["x"])
	var fy := int(frame_data["y"])
	var fw := int(frame_data["w"])
	var fh := int(frame_data["h"])
	var masked := CHARACTER_COMPONENTS_MASKED.has(component)

	# Plain frame — return an AtlasTexture (lightweight, GPU-resident)
	if not masked and not is_ghost:
		var at := AtlasTexture.new()
		at.atlas = _atlas_textures[atlas_name]
		at.region = Rect2(fx, fy, fw, fh)
		at.filter_clip = true
		return at

	# Masked or ghost — need to manipulate pixels on CPU
	var region_img := _get_region(atlas_name, fx, fy, fw, fh)
	if region_img == null:
		return null

	var result_img: Image

	if is_ghost:
		# Halve the alpha channel
		result_img = region_img.duplicate()
		result_img.convert(Image.FORMAT_RGBA8)
		var data := result_img.get_data()
		for pi in range(0, data.size(), 4):
			data[pi + 3] = data[pi + 3] / 2
		result_img = Image.create_from_data(fw, fh, false, Image.FORMAT_RGBA8, data)
	elif masked:
		result_img = Utils.color_overlay(region_img, color)
	else:
		result_img = region_img

	return ImageTexture.create_from_image(result_img)


# Load and cache an atlas (PNG + JSON) for the given component type.
static func _ensure_atlas(atlas_name: String) -> bool:
	if _atlas_loaded.has(atlas_name):
		return _atlas_loaded[atlas_name]

	_atlas_loaded[atlas_name] = false

	var root := G.RES_IMG_ROOT
	var png_path := root + atlas_name + "/" + atlas_name + ".atlas.png"
	var json_path := root + atlas_name + "/" + atlas_name + ".atlas.json"

	# Load JSON metadata
	var atlas_json = Utils.load_json(json_path)
	if atlas_json == null:
		push_error("AtlasLoader: missing " + json_path)
		return false

	_atlas_jsons[atlas_name] = atlas_json

	# Load texture
	var tex := Utils.load_texture(png_path)
	if tex == null:
		push_error("AtlasLoader: missing " + png_path)
		return false

	_atlas_textures[atlas_name] = tex
	_atlas_loaded[atlas_name] = true
	return true


# Extract a rectangular region of the atlas as a standalone Image.
static func _get_region(atlas_name: String, x: int, y: int, w: int, h: int) -> Image:
	if not _atlas_images.has(atlas_name):
		var tex: Texture2D = _atlas_textures.get(atlas_name)
		if tex == null:
			return null
		var full: Image = tex.get_image()
		if full == null:
			return null
		_atlas_images[atlas_name] = full
	return _atlas_images[atlas_name].get_region(Rect2i(x, y, w, h))


# Clear all cached data (useful if assets are hot-reloaded).
static func clear_cache() -> void:
	_atlas_textures.clear()
	_atlas_images.clear()
	_atlas_jsons.clear()
	_atlas_loaded.clear()
