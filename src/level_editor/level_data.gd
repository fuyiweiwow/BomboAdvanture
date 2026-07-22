class_name LevelData
extends RefCounted

const LEVEL_DIR = "res://assets/level/"
const MAP_SET_DIR = "res://assets/map_set/"

static func list_levels() -> Array:
	var all: Dictionary = {}
	var dir = DirAccess.open(LEVEL_DIR)
	if dir:
		dir.list_dir_begin()
		var fname = dir.get_next()
		while fname != "":
			if fname.ends_with(".json"):
				var name = fname.trim_suffix(".json")
				all[name] = {"_path": LEVEL_DIR + fname, "_src": "custom"}
			fname = dir.get_next()
		dir.list_dir_end()

	dir = DirAccess.open(MAP_SET_DIR)
	if dir:
		dir.list_dir_begin()
		var fname = dir.get_next()
		while fname != "":
			if fname.ends_with(".json") and not all.has(fname.trim_suffix(".json")):
				var name = fname.trim_suffix(".json")
				all[name] = {"_path": MAP_SET_DIR + fname, "_src": "compat"}
			fname = dir.get_next()
		dir.list_dir_end()

	var result: Array = []
	for name in all.keys():
		var info = all[name]
		var level = _load_as_level(name, info._path, info._src)
		if not level.is_empty():
			result.append(level)
	result.sort_custom(func(a, b): return a["name"] < b["name"])
	return result

static func _load_as_level(name: String, path: String, src: String) -> Dictionary:
	var j = Utils.load_json(path)
	if j == null:
		return {}
	if src == "compat":
		return _map_set_to_level(name, j, path)
	else:
		return _custom_to_level(name, j, path)

static func _map_set_to_level(name: String, j: Dictionary, path: String) -> Dictionary:
	var maps: Array = []
	for m in j.get("maps", []):
		maps.append({
			"type": "predefined",
			"play_mode": "adventure",
			"map_id": str(m)
		})
	return {
		"name": name,
		"display_name": name,
		"description": "",
		"_src": "compat",
		"_path": path,
		"maps": maps,
	}

static func _custom_to_level(name: String, j: Dictionary, path: String) -> Dictionary:
	var result = j.duplicate()
	result["name"] = name
	result["_src"] = "custom"
	result["_path"] = path
	if not result.has("display_name"):
		result["display_name"] = name
	if not result.has("description"):
		result["description"] = ""
	if not result.has("maps"):
		result["maps"] = []
	return result

static func load_level(name: String) -> Dictionary:
	var custom_path = LEVEL_DIR + name + ".json"
	if FileAccess.file_exists(custom_path):
		var j = Utils.load_json(custom_path)
		if j != null:
			return _custom_to_level(name, j, custom_path)
	var compat_path = MAP_SET_DIR + name + ".json"
	var j = Utils.load_json(compat_path)
	if j != null:
		return _map_set_to_level(name, j, compat_path)
	return {}

static func save_level(data: Dictionary) -> bool:
	if not data.has("name"):
		return false
	var name = str(data["name"])
	var dir = DirAccess.open("res://assets/")
	if dir == null:
		return false
	if not DirAccess.dir_exists_absolute(LEVEL_DIR):
		dir.make_dir("level")
	var path = LEVEL_DIR + name + ".json"
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	var clean = data.duplicate()
	clean.erase("_src")
	clean.erase("_path")
	f.store_string(JSON.new().stringify(clean, "\t"))
	f.close()
	return true

static func level_exists(name: String) -> bool:
	return FileAccess.file_exists(LEVEL_DIR + name + ".json")

static func is_compat(name: String) -> bool:
	return not FileAccess.file_exists(LEVEL_DIR + name + ".json") and FileAccess.file_exists(MAP_SET_DIR + name + ".json")

static func delete_level(name: String) -> bool:
	var path = LEVEL_DIR + name + ".json"
	if not FileAccess.file_exists(path):
		return false
	var dir = DirAccess.open(LEVEL_DIR)
	if dir == null:
		return false
	dir.remove(name + ".json")
	return true
