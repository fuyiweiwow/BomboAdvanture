extends RefCounted

const Validator = preload("res://src/game/level/map_data_validator.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	if Validator.is_valid({}):
		failures.append("empty map accepted")
	var data := Validator.normalize({"basic": {"width": 5, "height": 4, "begin": [99]}})
	if data["basic"]["begin"] != [4, 1]:
		failures.append("begin was not normalized")
	if not data.get("districts", []) is Array:
		failures.append("districts default missing")
	return failures
