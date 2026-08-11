class_name AdventureMapCatalog
extends RefCounted

const MAP_ROOT := "res://assets/map/"
const MAP_SET_ROOT := "res://assets/map_set/"

const REGION_ORDER := [
	"Youxian_mapTest",
	"YongDong",
	"JiZhou",
	"SenLin",
	"YeWai",
	"MiZhiDi",
	"NuFeng",
	"FengBao",
	"ShouWang",
	"HeiLong",
]

const REGION_NAMES := {
	"Youxian_mapTest": "冥河畔",
	"YongDong": "伊尔萨寒原",
	"JiZhou": "寒星矿区",
	"SenLin": "洛安德旧林",
	"YeWai": "洛安德工业郊野",
	"MiZhiDi": "旧王庭密园",
	"NuFeng": "普赛提亚风港",
	"FengBao": "暴雪山口",
	"ShouWang": "达特守望线",
	"HeiLong": "皇家科学院",
}

const REGION_SUBTITLES := {
	"Youxian_mapTest": "亡者记忆汇入世界的河岸。",
	"YongDong": "蓝血石矿脉穿过雪线，普通人用危险换取下一代的机会。",
	"JiZhou": "矿井、纪念碑与被暴雪封住的旧铁路。",
	"SenLin": "祖先、土地和旧王权仍在林间回响。",
	"YeWai": "工厂、罢工与现代化进入洛安德后的裂痕。",
	"MiZhiDi": "王族残影与被掩埋的隐秘关系。",
	"NuFeng": "船契精神、自治议会与海上贸易共同塑造的港湾。",
	"FengBao": "联邦边境的风暴线，理想和组织在这里相互拉扯。",
	"ShouWang": "联合王国的核心外环，铁路、军队和媒体从这里进入达特。",
	"HeiLong": "比奥姆微观实验撕开现实，真相只留下碎片。",
}

const REGION_COLORS := {
	"Youxian_mapTest": Color(0.42, 0.62, 0.86),
	"YongDong": Color(0.60, 0.82, 0.95),
	"JiZhou": Color(0.55, 0.70, 0.86),
	"SenLin": Color(0.32, 0.55, 0.32),
	"YeWai": Color(0.62, 0.56, 0.42),
	"MiZhiDi": Color(0.45, 0.34, 0.58),
	"NuFeng": Color(0.20, 0.62, 0.66),
	"FengBao": Color(0.48, 0.64, 0.76),
	"ShouWang": Color(0.72, 0.60, 0.34),
	"HeiLong": Color(0.50, 0.34, 0.36),
}

const REGION_POSITIONS := {
	"Youxian_mapTest": Vector2(0.776, 0.062),
	"YongDong": Vector2(0.620, 0.185),
	"JiZhou": Vector2(0.805, 0.245),
	"SenLin": Vector2(0.339, 0.406),
	"YeWai": Vector2(0.446, 0.641),
	"MiZhiDi": Vector2(0.124, 0.189),
	"NuFeng": Vector2(0.823, 0.504),
	"FengBao": Vector2(0.704, 0.344),
	"ShouWang": Vector2(0.600, 0.487),
	"HeiLong": Vector2(0.629, 0.426),
}

const REGION_LEVEL_POSITIONS := {
	"Youxian_mapTest": [
		Vector2(0.776, 0.062),
	],
	"YongDong": [
		Vector2(0.58, 0.17),
		Vector2(0.66, 0.21),
	],
	"JiZhou": [
		Vector2(0.75, 0.19),
		Vector2(0.82, 0.23),
		Vector2(0.87, 0.29),
	],
	"SenLin": [
		Vector2(0.27, 0.38),
		Vector2(0.33, 0.35),
		Vector2(0.39, 0.40),
		Vector2(0.34, 0.47),
		Vector2(0.43, 0.46),
	],
	"YeWai": [
		Vector2(0.38, 0.61),
		Vector2(0.43, 0.65),
		Vector2(0.49, 0.63),
		Vector2(0.55, 0.66),
	],
	"MiZhiDi": [
		Vector2(0.08, 0.23),
		Vector2(0.12, 0.16),
		Vector2(0.17, 0.14),
		Vector2(0.22, 0.21),
	],
	"NuFeng": [
		Vector2(0.91, 0.505),
		Vector2(0.93, 0.55),
		Vector2(0.89, 0.60),
	],
	"FengBao": [
		Vector2(0.66, 0.35),
		Vector2(0.72, 0.31),
		Vector2(0.78, 0.36),
	],
	"ShouWang": [
		Vector2(0.52, 0.55),
		Vector2(0.60, 0.49),
		Vector2(0.66, 0.45),
	],
	"HeiLong": [
		Vector2(0.56, 0.43),
		Vector2(0.59, 0.38),
		Vector2(0.63, 0.40),
		Vector2(0.67, 0.44),
		Vector2(0.63, 0.49),
		Vector2(0.69, 0.51),
		Vector2(0.73, 0.46),
	],
}

const REGION_LEVEL_NAMES := {
	"Youxian_mapTest": ["冥河初醒"],
	"YongDong": ["蓝井入口", "雪线营地"],
	"JiZhou": ["矿工纪念碑", "旧铁路", "暴雪前夜"],
	"SenLin": ["祖灵林道", "旧骑士营", "洛安德学校", "林间哨塔", "复兴者营地"],
	"YeWai": ["工厂外环", "罢工街区", "货运站", "黑烟尽头"],
	"MiZhiDi": ["密园入口", "破碎王冠", "公主密信", "祖庭深处"],
	"NuFeng": ["风港码头", "船契议会", "蓝火仓库"],
	"FengBao": ["风暴边境", "新船契派", "委员会灯塔"],
	"ShouWang": ["王国铁路线", "守望关口", "达特城门"],
	"HeiLong": ["科学院外庭", "真理大厅", "比奥姆反应炉", "记忆实验室", "黑龙档案", "现实裂缝", "未完成论文"],
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
			"subtitle": REGION_SUBTITLES.get(set_name, ""),
			"maps": maps.duplicate(),
			"index": set_index,
			"position": REGION_POSITIONS.get(set_name, _fallback_region_position(set_index, set_names.size())),
			"color": REGION_COLORS.get(set_name, Color(0.45, 0.55, 0.48)),
			"chapter": set_index + 1,
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
	var display_name = _level_display_name(map_name, set_name, local_index)
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
		"asset_name": str(basic.get("name", map_name)),
		"region_name": REGION_NAMES.get(set_name, _humanize_id(set_name)),
		"region_subtitle": REGION_SUBTITLES.get(set_name, ""),
		"region_color": REGION_COLORS.get(set_name, Color(0.45, 0.55, 0.48)),
		"description": _describe_map(display_name, set_name, basic, local_index),
		"travel_mode": _travel_mode_for_level(set_name, local_index),
		"width": int(basic.get("width", 0)),
		"height": int(basic.get("height", 0)),
		"music": str(basic.get("music", "")),
		"begin": _array_to_vec2i(basic.get("begin", [0, 0])),
		"finish": _array_to_vec2i(basic.get("finish", [0, 0])),
		"map_position": _map_position(set_name, set_index, max(1, set_count), local_index, max(1, set_size)),
	}


func _travel_mode_for_level(set_name: String, local_index: int) -> String:
	if set_name == "MiZhiDi":
		return "airship"
	if set_name == "NuFeng":
		return "airship" if local_index == 0 else "boat"
	return "walk"

func _level_display_name(map_name: String, set_name: String, local_index: int) -> String:
	var names = REGION_LEVEL_NAMES.get(set_name, [])
	if names is Array and local_index < (names as Array).size():
		return str((names as Array)[local_index])
	return map_name

func _describe_map(display_name: String, set_name: String, basic: Dictionary, local_index: int) -> String:
	var size = "%dx%d" % [int(basic.get("width", 0)), int(basic.get("height", 0))]
	var subtitle = str(REGION_SUBTITLES.get(set_name, ""))
	return "第%d段记忆：%s。%s 地图规模 %s。" % [local_index + 1, display_name, subtitle, size]

func _map_position(set_name: String, set_index: int, set_count: int, local_index: int, set_size: int) -> Vector2:
	var explicit_positions: Array = REGION_LEVEL_POSITIONS.get(set_name, [])
	if local_index < explicit_positions.size():
		return explicit_positions[local_index]
	var base: Vector2 = REGION_POSITIONS.get(set_name, _fallback_region_position(set_index, set_count))
	if set_size <= 1:
		return base
	var local_t = float(local_index) / float(max(1, set_size - 1))
	var path_vector = Vector2(0.08, 0.04)
	var offset = path_vector * (local_t - 0.5)
	return Vector2(clampf(base.x + offset.x, 0.04, 0.96), clampf(base.y + offset.y, 0.10, 0.88))

func _fallback_region_position(set_index: int, set_count: int) -> Vector2:
	var x = 0.08 + 0.84 * (float(set_index) / float(max(1, set_count - 1)))
	var y = 0.36 + sin(float(set_index) * 1.31) * 0.18
	return Vector2(clampf(x, 0.06, 0.94), clampf(y, 0.18, 0.78))

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
