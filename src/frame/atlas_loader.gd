class_name AtlasLoader
extends RefCounted

# Runtime atlas texture loader.
#
# Caches atlas Texture2D + JSON per component type.
# Returns AtlasTexture for every frame — tint/ghost are handled
# at draw time via Frame.draw(modulate), not via CPU pixel ops.

static var _atlas_textures: Dictionary = {}  # atlas_name -> Texture2D
static var _atlas_jsons: Dictionary    = {}  # atlas_name -> Dictionary (parsed atlas.json)
static var _atlas_loaded: Dictionary   = {}  # atlas_name -> bool


# Get an AtlasTexture for the given frame from its atlas.
static func get_texture(atlas_name: String, filename: String) -> Texture2D:
	if not _ensure_atlas(atlas_name):
		return null

	var frames: Dictionary = _atlas_jsons[atlas_name].get("frames", {})
	if not frames.has(filename):
		return null

	var frame_data: Dictionary = frames[filename]["frame"]
	var at := AtlasTexture.new()
	at.atlas = _atlas_textures[atlas_name]
	at.region = Rect2(frame_data["x"], frame_data["y"], frame_data["w"], frame_data["h"])
	at.filter_clip = true
	return at


# Load and cache an atlas (PNG + JSON) for the given component type.
static func _ensure_atlas(atlas_name: String) -> bool:
	if _atlas_loaded.has(atlas_name):
		return _atlas_loaded[atlas_name]

	_atlas_loaded[atlas_name] = false

	var root := G.RES_IMG_ROOT
	var png_path := root + atlas_name + "/" + atlas_name + ".atlas.png"
	var json_path := root + atlas_name + "/" + atlas_name + ".atlas.json"

	var atlas_json = Utils.load_json(json_path)
	if atlas_json == null:
		push_error("AtlasLoader: missing " + json_path)
		return false

	_atlas_jsons[atlas_name] = atlas_json

	var tex := Utils.load_texture(png_path)
	if tex == null:
		push_error("AtlasLoader: missing " + png_path)
		return false

	_atlas_textures[atlas_name] = tex
	_atlas_loaded[atlas_name] = true
	return true


static func clear_cache() -> void:
	_atlas_textures.clear()
	_atlas_jsons.clear()
	_atlas_loaded.clear()
