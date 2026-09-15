extends RefCounted

const SilentTestPlan = preload("res://src/tests/silent_test_plan.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	var suites: Array[String] = [
		"res://src/tests/silent/adventure_flow_test.gd",
		"res://src/tests/silent/game_adventure_integration_test.gd",
		"res://src/tests/silent/map_data_test.gd",
		"res://src/tests/silent/map_generation_test.gd",
	]

	var adventure_suites := SilentTestPlan.filter_paths(suites, ["adventure"])
	if adventure_suites.size() != 2:
		failures.append("module filter should select every suite whose name contains the module")

	var selected := SilentTestPlan.filter_paths(suites, ["map_data", "game_adventure"])
	if selected != [suites[1], suites[2]]:
		failures.append("multiple module filters should combine matches in discovery order")

	if SilentTestPlan.filter_paths(suites, []).size() != suites.size():
		failures.append("an empty module filter should run every discovered suite")

	if not SilentTestPlan.filter_paths(suites, ["missing"]).is_empty():
		failures.append("an unknown module filter should not silently run unrelated suites")

	return failures
