# res://src/game/level/map_data_validator.gd
# Validation boundary for map JSON. Runtime systems can assume a normalized
# shape after this module succeeds, while editors may still preserve unknown
# fields for forward compatibility.
class_name MapDataValidator
extends RefCounted

static func normalize(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var data: Dictionary = (raw as Dictionary).duplicate(true)
	var basic: Dictionary = data.get("basic", {}) if data.get("basic", {}) is Dictionary else {}
	var width := maxi(1, int(basic.get("width", 1)))
	var height := maxi(1, int(basic.get("height", 1)))
	var begin := _pair(basic.get("begin", [1, 1]), Vector2i(1, 1))
	var scroll := _pair(basic.get("scroll", [0, 0]), Vector2i.ZERO)
	var finish := _pair(basic.get("finish", [-1, -1]), Vector2i(-1, -1))
	begin.x = clampi(begin.x, 0, width - 1)
	begin.y = clampi(begin.y, 0, height - 1)
	basic["width"] = width
	basic["height"] = height
	basic["begin"] = [begin.x, begin.y]
	basic["scroll"] = [scroll.x, scroll.y]
	basic["finish"] = [finish.x, finish.y]
	data["basic"] = basic
	for key in ["floor", "floors", "obstacle", "obstacles", "districts"]:
		if not data.has(key) or not data[key] is Array:
			data[key] = []
	return data


static func is_valid(raw: Variant) -> bool:
	if not raw is Dictionary:
		return false
	var basic = (raw as Dictionary).get("basic", null)
	if not basic is Dictionary:
		return false
	return int(basic.get("width", 0)) > 0 and int(basic.get("height", 0)) > 0


static func _pair(value: Variant, fallback: Vector2i) -> Vector2i:
	if value is Array:
		var pair: Array = value
		return Vector2i(int(pair[0]) if pair.size() > 0 else fallback.x, int(pair[1]) if pair.size() > 1 else fallback.y)
	return fallback
