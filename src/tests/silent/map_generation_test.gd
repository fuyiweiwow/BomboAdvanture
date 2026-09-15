extends RefCounted

const Generator = preload("res://src/game/level/map_generator.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	var data := Generator.generate({"width": 11, "height": 11, "seed": 12345, "begin": [1, 1], "breakable_density": 0.8})
	var begin: Array = data["basic"]["begin"]
	for entry in data.get("obstacle", []):
		for point in entry.get("points", []):
			if int(point["x"]) == begin[0] and int(point["y"]) == begin[1]:
				failures.append("generated begin cell is blocked")
				return failures
	return failures
