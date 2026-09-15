# Headless regression checks for the shared data and map-generation boundaries.
extends Node

const MapDataValidator = preload("res://src/game/level/map_data_validator.gd")
const MapGenerator = preload("res://src/game/level/map_generator.gd")

func _ready() -> void:
	var failures := 0
	failures += _verify_validator()
	failures += _verify_begin_cell()
	print("FAILURES=", failures)
	get_tree().quit(failures)


func _verify_validator() -> int:
	if MapDataValidator.is_valid({"basic": {"width": 0, "height": 4}}):
		print("FAIL: validator accepted zero width")
		return 1
	var normalized := MapDataValidator.normalize({"basic": {"width": 5, "height": 4, "begin": [99]}})
	if normalized.is_empty() or normalized["basic"]["begin"] != [4, 1]:
		print("FAIL: validator did not normalize begin")
		return 1
	print("OK: map validator")
	return 0


func _verify_begin_cell() -> int:
	var map_data := MapGenerator.generate({"width": 11, "height": 11, "seed": 12345, "begin": [1, 1], "breakable_density": 0.8})
	var begin: Array = map_data["basic"]["begin"]
	for entry in map_data.get("obstacle", []):
		for point in entry.get("points", []):
			if int(point["x"]) == int(begin[0]) and int(point["y"]) == int(begin[1]):
				print("FAIL: begin cell is blocked")
				return 1
	print("OK: begin cell remains walkable")
	return 0
