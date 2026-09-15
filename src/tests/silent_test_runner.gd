# res://src/tests/silent_test_runner.gd
# Shared headless test runner. Feature tests are plain callables, so they can
# execute without creating a window, player input, or gameplay scene.
extends SceneTree

const MapDataValidator = preload("res://src/game/level/map_data_validator.gd")
const MapGenerator = preload("res://src/game/level/map_generator.gd")

func _init() -> void:
	# Avoid loading the gameplay autoload graph in a pure data test process.
	set_meta("silent_test", true)

var _results: Array[Dictionary] = []
var _current_failures: Array[String] = []

func _initialize() -> void:
	_run_suite("map_data", Callable(self, "_test_map_data"))
	_run_suite("map_generation", Callable(self, "_test_map_generation"))
	var failed := 0
	for result in _results:
		if not result["passed"]:
			failed += 1
	print(JSON.stringify({"passed": failed == 0, "tests": _results}, "\t"))
	quit(0 if failed == 0 else 1)

func _run_suite(name: String, test: Callable) -> void:
	_current_failures.clear()
	test.call()
	_results.append({"name": name, "passed": _current_failures.is_empty(), "failures": _current_failures.duplicate()})

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_current_failures.append(message)

func _test_map_data() -> void:
	_expect(not MapDataValidator.is_valid({}), "empty map accepted")
	var data := MapDataValidator.normalize({"basic": {"width": 5, "height": 4, "begin": [99]}})
	_expect(data["basic"]["begin"] == [4, 1], "begin was not normalized")
	_expect(data.get("districts", []) is Array, "districts default missing")

func _test_map_generation() -> void:
	var data := MapGenerator.generate({"width": 11, "height": 11, "seed": 12345, "begin": [1, 1], "breakable_density": 0.8})
	var begin: Array = data["basic"]["begin"]
	var blocked := false
	for entry in data.get("obstacle", []):
		for point in entry.get("points", []):
			blocked = blocked or (int(point["x"]) == begin[0] and int(point["y"]) == begin[1])
	_expect(not blocked, "generated begin cell is blocked")
