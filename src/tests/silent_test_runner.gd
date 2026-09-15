# res://src/tests/silent_test_runner.gd
# Shared headless test runner. Feature tests are plain callables, so they can
# execute without creating a window, player input, or gameplay scene.
extends SceneTree

var _results: Array[Dictionary] = []

func _initialize() -> void:
	_discover_and_run()
	var failed := 0
	for result in _results:
		if not result["passed"]:
			failed += 1
	print(JSON.stringify({"passed": failed == 0, "tests": _results}, "\t"))
	quit(0 if failed == 0 else 1)

func _discover_and_run() -> void:
	var dir := DirAccess.open("res://src/tests/silent")
	if dir == null:
		_results.append({"name": "discovery", "passed": false, "failures": ["silent test directory missing"]})
		return
	dir.list_dir_begin()
	var filename := dir.get_next()
	var paths: Array[String] = []
	while filename != "":
		if not dir.current_is_dir() and filename.ends_with("_test.gd"):
			paths.append("res://src/tests/silent/" + filename)
		filename = dir.get_next()
	dir.list_dir_end()
	paths.sort()
	for path in paths:
		var script = load(path)
		var test = script.new() if script != null else null
		if test == null or not test.has_method("run"):
			_results.append({"name": path, "passed": false, "failures": ["test must expose run()"]})
			continue
		var failures = test.run()
		var failure_list: Array = failures if failures is Array else ["run() must return Array"]
		_results.append({"name": path.get_file().trim_suffix(".gd"), "passed": failure_list.is_empty(), "failures": failure_list})
