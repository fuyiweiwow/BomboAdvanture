class_name AlchemyData
extends RefCounted

const SOLVENT_DIR = "res://assets/alchemy/solvent/"
const RecipeGenerator = preload("res://src/alchemy/recipe_generator.gd")

static var _solvent_cache: Dictionary = {}

static func get_solvent(id: String) -> Dictionary:
	if _solvent_cache.has(id):
		return _solvent_cache[id]
	var j = Utils.load_json(SOLVENT_DIR + id + ".json")
	if j != null:
		_solvent_cache[id] = j
	return j if j != null else {}

static func get_ingredient(item_data: Dictionary) -> Dictionary:
	return item_data.get("alchemy", {})

static func is_grindable(item_data: Dictionary) -> bool:
	var a = get_ingredient(item_data)
	return a.get("grindable", false) and a.get("max_grind", 0) > 0

static func get_material_rarity(item_data: Dictionary) -> int:
	var a = get_ingredient(item_data)
	return a.get("rarity_level", 1)

static func list_solvents() -> Array:
	var dir = DirAccess.open(SOLVENT_DIR)
	if dir == null:
		return ["water"]
	var result: Array = []
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			result.append(fname.trim_suffix(".json"))
		fname = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result

static func calculate_params(ingredients: Array, solvent_id: String, grinds: Dictionary) -> Dictionary:
	var total_element = {}
	var total_concentration = 0.0
	var total_weight = 0.0
	var weighted_granularity = 0.0

	var solvent = get_solvent(solvent_id)
	var s_dilution = solvent.get("concentration_dilution", 0.5)
	var s_element = solvent.get("element_affinity", {})

	for entry in ingredients:
		var item_data = entry.get("data", {})
		var count = entry.get("count", 1)
		var alch = get_ingredient(item_data)
		var gr = grinds.get(item_data.get("id", ""), 0)
		var max_g = alch.get("max_grind", 0)
		var actual_gr = clampi(gr, 0, max_g)

		var elem = alch.get("element", {})
		var conc = alch.get("concentration", 0.3)

		for i in range(count):
			var g_factor = 1.0 + actual_gr * 0.15
			var e_factor = conc * g_factor

			for ek in elem:
				total_element[ek] = total_element.get(ek, 0.0) + elem[ek] * e_factor * s_dilution

			total_concentration += e_factor
			total_weight += e_factor
			weighted_granularity += actual_gr * e_factor

	for ek in s_element:
		total_element[ek] = total_element.get(ek, 0.0) + s_element[ek] * s_dilution

	var avg_granularity = 0.0
	if total_weight > 0:
		avg_granularity = weighted_granularity / total_weight

	var max_elem = 0.0
	for ek in total_element:
		if total_element[ek] > max_elem:
			max_elem = total_element[ek]

	if max_elem > 0:
		for ek in total_element:
			total_element[ek] /= max_elem

	return {
		"element": total_element,
		"granularity": avg_granularity,
		"concentration": total_concentration,
		"solvent": solvent_id
	}

static func match_recipe(params: Dictionary, recipe: Dictionary) -> bool:
	var cond = recipe.get("condition", {})
	if cond.is_empty():
		return false

	if cond.has("solvent") and str(cond["solvent"]) != params["solvent"]:
		return false

	if cond.has("granularity"):
		var g = cond["granularity"]
		var pg = params["granularity"]
		if g.has("min") and pg < g["min"]: return false
		if g.has("max") and pg > g["max"]: return false

	if cond.has("concentration"):
		var c = cond["concentration"]
		var pc = params["concentration"]
		if c.has("min") and pc < c["min"]: return false
		if c.has("max") and pc > c["max"]: return false

	if cond.has("element"):
		var ce = cond["element"]
		var pe = params.get("element", {})
		for ek in ce:
			var ev = ce[ek]
			var pv = pe.get(ek, 0.0)
			if ev.has("min") and pv < ev["min"]: return false
			if ev.has("max") and pv > ev["max"]: return false

	return true

static func _params_look_valid(params: Dictionary) -> bool:
	if params["concentration"] < 0.3 or params["concentration"] > 8.0:
		return false
	if params["granularity"] < 0:
		return false
	for ek in params.get("element", {}):
		if params["element"][ek] >= 0.25:
			return true
	return false

static func brew(ingredients: Array, solvent_id: String, grinds: Dictionary, owned_recipes: Array, brew_level: int) -> Dictionary:
	var params = calculate_params(ingredients, solvent_id, grinds)

	var matched_recipe = null
	var matched_id = ""
	for r in owned_recipes:
		if match_recipe(params, r):
			matched_recipe = r
			matched_id = str(r.get("id", ""))
			break

	var discovered = false
	if matched_recipe == null and _params_look_valid(params):
		var new_recipe = RecipeGenerator.generate_from_params(params, solvent_id, owned_recipes)
		if not new_recipe.is_empty():
			matched_recipe = new_recipe
			matched_id = str(new_recipe.get("id", ""))
			discovered = true

	if matched_recipe == null:
		var fail_severity = 1 + int(params["concentration"] / 2.0)
		return {
			"success": false,
			"params": params,
			"fail_severity": clampi(fail_severity, 1, 3)
		}

	var max_rarity = 0
	for entry in ingredients:
		var item_data = entry.get("data", {})
		var rl = get_material_rarity(item_data)
		if rl > max_rarity:
			max_rarity = rl

	var fail_chance = maxf(0.0, 0.05 * max_rarity - 0.02 * brew_level)
	if randf() < fail_chance:
		return {
			"success": false,
			"params": params,
			"fail_severity": clampi(max_rarity, 1, 3),
			"near_match": matched_id
		}

	return {
		"success": true,
		"params": params,
		"recipe": matched_recipe,
		"output_id": str(matched_recipe.get("output_item_id", "")),
		"discovered": discovered
	}

static func estimate_rarity_score(recipe: Dictionary) -> int:
	var score = 0
	var cond = recipe.get("condition", {})
	var ce = cond.get("element", {})
	for ek in ce:
		var ev = ce[ek]
		if ev.has("min"):
			score += int(ev["min"] * 10)
	if cond.has("concentration"):
		var c = cond["concentration"]
		if c.has("max"):
			score += int(c["max"] * 5)
	return score

static func rarity_from_score(score: int) -> String:
	if score >= 45: return "legendary"
	if score >= 26: return "epic"
	if score >= 13: return "rare"
	if score >= 6: return "uncommon"
	return "common"
