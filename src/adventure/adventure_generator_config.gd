# Converts a visual recipe plus mission overrides into the single normalized
# parameter shape consumed by WorldMapGenerator.
class_name AdventureGeneratorConfig
extends RefCounted


static func build(recipe: Dictionary, overrides: Dictionary = {}) -> Dictionary:
	var raw_pool = overrides.get("monster_pool", recipe.get("monsters", []))
	var monster_pool: Array = raw_pool.duplicate(true) if raw_pool is Array else []
	return {
		"count": clampi(int(overrides.get("count", 6)), 1, 20),
		"seed": int(overrides.get("seed", 0)),
		"width": clampi(int(overrides.get("width", recipe.get("width", 21))), 11, 60),
		"height": clampi(int(overrides.get("height", recipe.get("height", 15))), 11, 40),
		"floor": str(overrides.get("floor", recipe.get("floor", "elem220"))),
		"wall": str(overrides.get("wall", recipe.get("wall", "elem212"))),
		"breakable": overrides.get("breakable", recipe.get("breakable", ["elem225", "elem226", "elem227"])),
		"monster_pool": monster_pool,
		"density": clampf(float(overrides.get("density", recipe.get("density", 0.25))), 0.0, 1.0),
		"name": str(overrides.get("name", recipe.get("name", "procedural"))),
	}
