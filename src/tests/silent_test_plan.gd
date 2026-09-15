class_name SilentTestPlan
extends RefCounted

## Returns suites matching at least one case-insensitive name fragment.
## Keeping this policy outside the runner makes selection deterministic and testable.
static func filter_paths(paths: Array[String], modules: Array[String]) -> Array[String]:
	if modules.is_empty():
		return paths.duplicate()

	var normalized_modules: Array[String] = []
	for module in modules:
		var normalized := module.strip_edges().to_lower()
		if not normalized.is_empty() and not normalized_modules.has(normalized):
			normalized_modules.append(normalized)

	var selected: Array[String] = []
	for path in paths:
		var suite_name := path.get_file().trim_suffix("_test.gd").to_lower()
		for module in normalized_modules:
			if suite_name.contains(module):
				selected.append(path)
				break
	return selected
