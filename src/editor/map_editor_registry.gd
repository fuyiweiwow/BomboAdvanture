class_name MapEditorRegistry
extends RefCounted

const MAP_ROOT := "res://assets/map/"
const IMG_ROOT := "res://assets/img/"
const FRAME_ROOT := "res://assets/frame/"

const LAYER_FLOOR := 0
const LAYER_OBSTACLE := 1

func layer_defs() -> Array[Dictionary]:
	return [
		{
			"id": LAYER_FLOOR,
			"name": "Floor",
			"palette_key": "floor",
			"map_keys": ["floors", "floor"],
		},
		{
			"id": LAYER_OBSTACLE,
			"name": "Obstacle",
			"palette_key": "obstacle",
			"map_keys": ["obstacles", "obstacle"],
		},
	]

func build_palette() -> Dictionary:
	var floors: Dictionary = {}
	var obstacles: Dictionary = {}
	var da = DirAccess.open(MAP_ROOT)
	if da == null:
		return {"floor": floors, "obstacle": obstacles}
	da.list_dir_begin()
	var fn = da.get_next()
	while fn != "":
		if not da.current_is_dir() and fn.ends_with(".json"):
			_collect_from_map(MAP_ROOT + fn, floors, obstacles)
		fn = da.get_next()
	da.list_dir_end()
	return {
		"floor": _sort_palette(floors),
		"obstacle": _sort_palette(obstacles),
	}

func layer_name(layer_id: int) -> String:
	for layer in layer_defs():
		if int(layer["id"]) == layer_id:
			return str(layer["name"])
	return "Layer"

func floor_texture_path(type: String, name: String) -> String:
	return IMG_ROOT + "mapElem/" + type + "/" + name + ".png"

func obstacle_json_path(type: String, name: String) -> String:
	return FRAME_ROOT + "obstacle/" + type + "/" + name + ".json"

func obstacle_texture_path(type: String, name: String) -> String:
	var json = _load_json(obstacle_json_path(type, name))
	if json == null or typeof(json) != TYPE_DICTIONARY:
		return ""
	var img_type = str(json.get("TYPE", type))
	var stand = json.get("STAND", {})
	if typeof(stand) != TYPE_DICTIONARY:
		return ""
	var imgs = stand.get("IMG", [])
	if typeof(imgs) != TYPE_ARRAY or imgs.is_empty():
		return ""
	return IMG_ROOT + "mapElem/" + img_type + "/" + str(imgs[0])

func obstacle_size(type: String, name: String) -> Vector2i:
	var json = _load_json(obstacle_json_path(type, name))
	if json == null or typeof(json) != TYPE_DICTIONARY:
		return Vector2i.ONE
	return Vector2i(max(1, int(json.get("WIDTH", 1))), max(1, int(json.get("HEIGHT", 1))))

func _collect_from_map(path: String, floors: Dictionary, obstacles: Dictionary) -> void:
	var json = _load_json(path)
	if json == null or typeof(json) != TYPE_DICTIONARY:
		return
	for entry in _entries_for_keys(json, ["floors", "floor"]):
		var type = str(entry.get("type", ""))
		var name = str(entry.get("name", ""))
		if _is_valid_floor(type, name):
			_add_palette_item(floors, type, name)
	for entry in _entries_for_keys(json, ["obstacles", "obstacle"]):
		var type = str(entry.get("type", ""))
		var name = str(entry.get("name", ""))
		if _is_valid_obstacle(type, name):
			_add_palette_item(obstacles, type, name)

func _entries_for_keys(json: Dictionary, keys: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in keys:
		var entries = json.get(key, [])
		if typeof(entries) != TYPE_ARRAY:
			continue
		for entry in entries:
			if typeof(entry) == TYPE_DICTIONARY:
				result.append(entry)
	return result

func _is_valid_floor(type: String, name: String) -> bool:
	if type == "" or name == "":
		return false
	return _asset_exists(floor_texture_path(type, name))

func _is_valid_obstacle(type: String, name: String) -> bool:
	if type == "" or name == "" or name.ends_with("-floor"):
		return false
	var json = _load_json(obstacle_json_path(type, name))
	if json == null or typeof(json) != TYPE_DICTIONARY:
		return false
	var texture_path = obstacle_texture_path(type, name)
	return texture_path != "" and _asset_exists(texture_path)

func _add_palette_item(palette: Dictionary, type: String, name: String) -> void:
	if not palette.has(type):
		palette[type] = []
	if not palette[type].has(name):
		palette[type].append(name)

func _sort_palette(palette: Dictionary) -> Dictionary:
	var sorted: Dictionary = {}
	var types = palette.keys()
	types.sort()
	for type in types:
		var names: Array = palette[type]
		names.sort()
		sorted[type] = names
	return sorted

func _load_json(path: String) -> Variant:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	return data

func _asset_exists(path: String) -> bool:
	return ResourceLoader.exists(path) or FileAccess.file_exists(path)
