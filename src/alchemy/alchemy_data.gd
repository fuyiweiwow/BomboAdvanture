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

static func calculate_params(ingredients: Array, solvents: Array, grinds: Dictionary, heat_level: float = 0.5) -> Dictionary:
	var total_element = {}
	var total_concentration = 0.0
	var total_weight = 0.0
	var weighted_granularity = 0.0
	var heat_match_sum = 0.0
	var heat_weight = 0.0

	# accumulate solvent amounts
	var solvent_totals = {}
	for se in solvents:
		var sid = se.get("id", "")
		var amt = se.get("amount", 1.0)
		solvent_totals[sid] = solvent_totals.get(sid, 0.0) + amt

	for entry in ingredients:
		var item_data = entry.get("data", {})
		var count = entry.get("count", 1)
		var alch = get_ingredient(item_data)
		var gr = grinds.get(item_data.get("id", ""), 0)
		var max_g = alch.get("max_grind", 0)
		var actual_gr = clampi(gr, 0, max_g)

		var elem = alch.get("element", {})
		var conc = alch.get("concentration", 0.3)

		# heat affinity match (0.0 = perfect, higher = worse)
		var ha = alch.get("heat_affinity", {})
		var heat_penalty = 0.0
		if not ha.is_empty():
			var hmin = ha.get("min", 0.0)
			var hmax = ha.get("max", 1.0)
			if heat_level < hmin:
				heat_penalty = hmin - heat_level
			elif heat_level > hmax:
				heat_penalty = heat_level - hmax
		var heat_factor = maxf(0.0, 1.0 - heat_penalty * 2.0)

		for i in range(count):
			var g_factor = 1.0 + actual_gr * 0.15
			var e_factor = conc * g_factor * heat_factor

			# combined solvent dilution from all solvents
			var dilution = 1.0
			for sid in solvent_totals:
				var sd = get_solvent(sid)
				var d = sd.get("concentration_dilution", 0.5)
				var amt = solvent_totals[sid]
				dilution *= (1.0 - (1.0 - d) * minf(amt, 1.0))

			for ek in elem:
				total_element[ek] = total_element.get(ek, 0.0) + elem[ek] * e_factor * dilution

			total_concentration += e_factor
			total_weight += e_factor
			weighted_granularity += actual_gr * e_factor
			heat_match_sum += heat_factor * e_factor
			heat_weight += e_factor

	# apply solvent element affinity
	for sid in solvent_totals:
		var sd = get_solvent(sid)
		var se = sd.get("element_affinity", {})
		var amt = solvent_totals[sid]
		for ek in se:
			total_element[ek] = total_element.get(ek, 0.0) + se[ek] * minf(amt, 1.0)

	var avg_granularity = 0.0
	if total_weight > 0:
		avg_granularity = weighted_granularity / total_weight

	var avg_heat_match = 1.0
	if heat_weight > 0:
		avg_heat_match = heat_match_sum / heat_weight

	var max_elem = 0.0
	for ek in total_element:
		if total_element[ek] > max_elem:
			max_elem = total_element[ek]

	if max_elem > 0:
		for ek in total_element:
			total_element[ek] /= max_elem

	# snapshot used solvents for recipe condition
	var solvent_snap = {}
	for sid in solvent_totals:
		solvent_snap[sid] = snapped(solvent_totals[sid], 0.1)

	return {
		"element": total_element,
		"granularity": avg_granularity,
		"concentration": total_concentration,
		"solvent": solvent_snap,
		"solvent_list": solvent_totals,
		"heat": heat_level,
		"heat_match": avg_heat_match
	}

static func match_recipe(params: Dictionary, recipe: Dictionary) -> bool:
	var cond = recipe.get("condition", {})
	if cond.is_empty():
		return false

	if cond.has("solvent"):
		var required = cond["solvent"]
		var p_solvents = params.get("solvent_list", {})
		if required is String:
			# old format: single solvent ID
			if not p_solvents.has(required):
				return false
		elif required is Dictionary:
			# dict format: { "water": { "min_amount": 0.3 }, ... }
			for sid in required:
				var req_amt = required[sid].get("min_amount", 0.1) if required[sid] is Dictionary else 0.1
				if p_solvents.get(sid, 0.0) < req_amt:
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

	if cond.has("heat"):
		var hc = cond["heat"]
		var ph = params.get("heat", 0.5)
		if hc.has("min") and ph < hc["min"]: return false
		if hc.has("max") and ph > hc["max"]: return false

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

static func brew(ingredients: Array, solvents: Array, grinds: Dictionary, owned_recipes: Array, brew_level: int, heat_level: float = 0.5) -> Dictionary:
	var params = calculate_params(ingredients, solvents, grinds, heat_level)

	var matched_recipe = null
	var matched_id = ""
	for r in owned_recipes:
		if match_recipe(params, r):
			matched_recipe = r
			matched_id = str(r.get("id", ""))
			break

	var discovered = false
	if matched_recipe == null and _params_look_valid(params):
		var new_recipe = RecipeGenerator.generate_from_params(params, owned_recipes)
		if not new_recipe.is_empty():
			matched_recipe = new_recipe
			matched_id = str(new_recipe.get("id", ""))
			discovered = true

	if matched_recipe == null:
		var heat_penalty = int((1.0 - params.get("heat_match", 1.0)) * 3)
		var fail_severity = clampi(1 + int(params["concentration"] / 2.0) + heat_penalty, 1, 3)
		return {
			"success": false,
			"params": params,
			"fail_severity": fail_severity
		}

	var max_rarity = 0
	for entry in ingredients:
		var item_data = entry.get("data", {})
		var rl = get_material_rarity(item_data)
		if rl > max_rarity:
			max_rarity = rl

	var hm = params.get("heat_match", 1.0)
	var fail_chance = maxf(0.0, 0.05 * max_rarity - 0.02 * brew_level + 0.3 * (1.0 - hm))
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


