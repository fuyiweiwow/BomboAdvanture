class_name AdventureMapCatalog
extends RefCounted

const MAP_ROOT := "res://assets/map/"
const MAP_SET_ROOT := "res://assets/map_set/"

const REGION_ORDER := [
	"YongDong",
	"SenLin",
	"MiZhiDi",
	"YeWai",
	"JiZhou",
	"NuFeng",
	"FengBao",
	"ShouWang",
	"HeiLong",
	"Youxian_mapTest",
]

const REGION_NAMES := {
	"YongDong": "Frozen Gate",
	"SenLin": "Forest Trail",
	"MiZhiDi": "Mystic Garden",
	"YeWai": "Wild Field",
	"JiZhou": "Polar Camp",
	"NuFeng": "Storm Ridge",
	"FengBao": "Blizzard Pass",
	"ShouWang": "Watchland",
	"HeiLong": "Black Dragon Keep",
	"Youxian_mapTest": "Test Grounds",
}

var _profiles: Array[Dictionary] = []
var _profiles_by_id: Dictionary = {}
var _sets: Array[Dictionary] = []

func _init() -> void:
	reload()

func reload() -> void:
	_profiles.clear()
	_profiles_by_id.clear()
	_sets.clear()
	var set_names = _discover_map_sets()
	var global_index = 0
	for set_name in set_names:
		var maps = _maps_for_set(set_name)
		if maps.is_empty():
			continue
		var set_index = _sets.size()
		var set_profile = {
			"id": set_name,
			"name": REGION_NAMES.get(set_name, _humanize_id(set_name)),
			"maps": maps.duplicate(),
			"index": set_index,
		}
		_sets.append(set_profile)
		for local_index in maps.size():
			var map_name = str(maps[local_index])
			var profile = _build_map_profile(map_name, set_name, set_index, set_names.size(), local_index, maps.size(), global_index)
			_profiles.append(profile)
			_profiles_by_id[profile["id"]] = profile
			global_index += 1

func levels() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for profile in _profiles:
		result.append(profile.duplicate(true))
	return result

func map_sets() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for set_profile in _sets:
		result.append(set_profile.duplicate(true))
	return result

func profile(level_id: String) -> Dictionary:
	var profile = _profiles_by_id.get(level_id, {})
	return profile.duplicate(true) if not profile.is_empty() else {}

func contains(level_id: String) -> bool:
	return _profiles_by_id.has(level_id)

func first_level_id() -> String:
	return str(_profiles[0]["id"]) if not _profiles.is_empty() else ""

func next_level_id(level_id: String) -> String:
	for i in range(_profiles.size() - 1):
		if str(_profiles[i]["id"]) == level_id:
			return str(_profiles[i + 1]["id"])
	return ""

func _discover_map_sets() -> Array[String]:
	var discovered: Array[String] = []
	var da = DirAccess.open(MAP_SET_ROOT)
	if da != null:
		da.list_dir_begin()
		var fn = da.get_next()
		while fn != "":
			if not da.current_is_dir() and fn.ends_with(".json"):
				discovered.append(fn.trim_suffix(".json"))
			fn = da.get_next()
		da.list_dir_end()
	var ordered: Array[String] = []
	for name in REGION_ORDER:
		if discovered.has(name):
			ordered.append(name)
	for name in discovered:
		if not ordered.has(name):
			ordered.append(name)
	return ordered

func _maps_for_set(set_name: String) -> Array[String]:
	var data = _load_json(MAP_SET_ROOT + set_name + ".json")
	var result: Array[String] = []
	if data is Dictionary:
		for raw_name in (data as Dictionary).get("maps", []):
			var map_name = str(raw_name)
			if FileAccess.file_exists(MAP_ROOT + map_name + ".json"):
				result.append(map_name)
	return result

func _build_map_profile(map_name: String, set_name: String, set_index: int, set_count: int, local_index: int, set_size: int, global_index: int) -> Dictionary:
	var map_data = _load_json(MAP_ROOT + map_name + ".json")
	var basic = (map_data as Dictionary).get("basic", {}) if map_data is Dictionary else {}
	var display_name = str(basic.get("name", map_name))
	return {
		"id": map_name,
		"map_name": map_name,
		"map_set": set_name,
		"set_index": set_index,
		"set_count": set_count,
		"number": global_index + 1,
		"local_index": local_index,
		"set_size": set_size,
		"local_number": local_index + 1,
		"name": display_name,
		"region_name": REGION_NAMES.get(set_name, _humanize_id(set_name)),
		"description": _describe_map(display_name, set_name, basic),
		"width": int(basic.get("width", 0)),
		"height": int(basic.get("height", 0)),
		"music": str(basic.get("music", "")),
		"begin": _array_to_vec2i(basic.get("begin", [0, 0])),
		"finish": _array_to_vec2i(basic.get("finish", [0, 0])),
		"map_position": _map_position(set_index, max(1, set_count), local_index, max(1, set_size)),
	}

func _describe_map(display_name: String, set_name: String, basic: Dictionary) -> String:
	var size = "%dx%d" % [int(basic.get("width", 0)), int(basic.get("height", 0))]
	return "%s in %s. Map size %s." % [display_name, REGION_NAMES.get(set_name, _humanize_id(set_name)), size]

func _map_position(set_index: int, set_count: int, local_index: int, set_size: int) -> Vector2:
	var x = 0.10 + 0.80 * (float(set_index) / float(max(1, set_count - 1)))
	var local_t = float(local_index) / float(max(1, set_size - 1))
	var wave = sin(float(set_index) * 1.37) * 0.09
	var y = 0.30 + 0.42 * local_t + wave
	return Vector2(clampf(x, 0.08, 0.92), clampf(y, 0.18, 0.78))

func _load_json(path: String) -> Variant:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	return data

func _array_to_vec2i(value: Variant) -> Vector2i:
	if value is Array:
		var arr: Array = value
		return Vector2i(int(arr[0]) if arr.size() > 0 else 0, int(arr[1]) if arr.size() > 1 else 0)
	return Vector2i.ZERO

func _humanize_id(value: String) -> String:
	var parts = value.replace("-", "_").split("_", false)
	for i in parts.size():
		parts[i] = str(parts[i]).capitalize()
	return " ".join(parts)
