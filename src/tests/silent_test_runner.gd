# res://src/tests/silent_test_runner.gd
# Shared headless test runner. Feature tests are plain callables, so they can
# execute without creating a window, player input, or gameplay scene.
extends SceneTree

const SilentTestPlan = preload("res://src/tests/silent_test_plan.gd")
const SilentTestTools = preload("res://src/tests/silent_test_tools.gd")

var _results: Array[Dictionary] = []
var _suite_timeout_msec := 10000

func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	_suite_timeout_msec = _read_suite_timeout(arguments)
	await _discover_and_run(arguments)
	var failed := 0
	for result in _results:
		if not result["passed"]:
			failed += 1
	print(JSON.stringify({"passed": failed == 0, "tests": _results}, "\t"))
	quit(0 if failed == 0 else 1)

func _discover_and_run(arguments: PackedStringArray) -> void:
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
	if paths.is_empty():
		_results.append({"name": "discovery", "passed": false, "failures": ["no *_test.gd suites discovered"]})
		return
	var modules := _read_module_filters(arguments)
	paths = SilentTestPlan.filter_paths(paths, modules)
	if paths.is_empty():
		_results.append({"name": "selection", "passed": false, "failures": ["no suites matched modules: %s" % ", ".join(modules)]})
		return
	for path in paths:
		var script = load(path)
		if script == null or not script.can_instantiate():
			_results.append({"name": path, "passed": false, "failures": ["test script could not be loaded"]})
			continue
		var test = script.new()
		if not test.has_method("run"):
			_results.append({"name": path, "passed": false, "failures": ["test must expose run()"]})
			continue
		var execution: Dictionary = await SilentTestTools.run_with_timeout(test.run, _suite_timeout_msec)
		if execution["timed_out"]:
			_results.append({"name": path.get_file().trim_suffix(".gd"), "passed": false, "failures": ["suite timed out after %d ms" % _suite_timeout_msec]})
			continue
		var failures = execution["result"]
		var failure_list: Array = failures if failures is Array else ["run() must return Array"]
		_results.append({"name": path.get_file().trim_suffix(".gd"), "passed": failure_list.is_empty(), "failures": failure_list})

func _read_module_filters(arguments: PackedStringArray) -> Array[String]:
	var modules: Array[String] = []
	for argument in arguments:
		if argument.begins_with("--module="):
			modules.append(argument.trim_prefix("--module="))
	return modules

func _read_suite_timeout(arguments: PackedStringArray) -> int:
	for argument in arguments:
		if argument.begins_with("--suite-timeout-msec="):
			return maxi(int(argument.trim_prefix("--suite-timeout-msec=")), 1)
	return 10000
