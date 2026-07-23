class_name RecipeGenerator
extends RefCounted

const QUALITY_RANGES = {
	"common":     { "min_score": 1,  "max_score": 5 },
	"uncommon":   { "min_score": 6,  "max_score": 12 },
	"rare":       { "min_score": 13, "max_score": 25 },
	"epic":       { "min_score": 26, "max_score": 45 },
	"legendary":  { "min_score": 46, "max_score": 999 }
}

const ELEMENTS = ["fire", "water", "ice", "earth", "air", "dark", "poison", "light"]
const SOLVENTS = ["water", "oil", "venom"]
const RARITY_ORDER = ["common", "uncommon", "rare", "epic", "legendary"]

static func generate_recipe(quality: String, existing_ids: Array = []) -> Dictionary:
	var score_range = QUALITY_RANGES.get(quality, QUALITY_RANGES["common"])
	var target_score = score_range["min_score"] + randi() % maxi(1, score_range["max_score"] - score_range["min_score"] + 1)

	var recipe_id = _make_unique_id(existing_ids)
	var element_count = 1 + (randi() % min(3, 1 + RARITY_ORDER.find(quality)))
	var elements = {}
	var used_elems = []
	var pool = ELEMENTS.duplicate()
	pool.shuffle()

	for i in range(element_count):
		var ek = pool[i]
		var min_val = 0.1 + (RARITY_ORDER.find(quality) + 1) * 0.05 * (randf() * 0.5 + 0.75)
		min_val = clampf(min_val, 0.1, 0.9)
		elements[ek] = { "min": snapped(min_val, 0.05) }
		used_elems.append(ek)

	var solvent = SOLVENTS[randi() % SOLVENTS.size()] if quality == "common" else _pick_solvent_by_elements(used_elems)

	var granularity_max = clampi(2 + RARITY_ORDER.find(quality), 1, 8)
	var granularity = {
		"max": snapped(granularity_max * (randf() * 0.5 + 0.3), 0.5)
	}
	if quality == "legendary":
		granularity["min"] = snapped(randf() * 2, 0.5)

	var conc = 0.3 + (RARITY_ORDER.find(quality) + 1) * 0.3 * (randf() * 0.5 + 0.3)
	var concentration = {
		"min": snapped(conc * 0.5, 0.1),
		"max": snapped(conc, 0.1)
	}

	var heat_range = {
		"min": snapped(randf() * 0.5, 0.05),
		"max": snapped(0.5 + randf() * 0.5, 0.05)
	}

	var solvent_cond = {}
	solvent_cond[solvent] = { "min_amount": snapped(0.3 + randf() * 0.7, 0.1) }

	var condition = {
		"solvent": solvent_cond,
		"granularity": granularity,
		"concentration": concentration,
		"element": elements,
		"heat": heat_range
	}

	var effect_template = _generate_effects(quality, used_elems, target_score)

	var output_item = _build_output_item(recipe_id, effect_template, quality, condition)

	return {
		"id": recipe_id,
		"name": effect_template.get("name", "Unknown Potion"),
		"chs_name": effect_template.get("chs_name", "未知药剂"),
		"type": "recipe",
		"rarity": quality,
		"description": "炼金配方",
		"frame": "item2",
		"color": _quality_color(quality),
		"buy_price": 20 * (RARITY_ORDER.find(quality) + 1) * 5,
		"sell_price": 10 * (RARITY_ORDER.find(quality) + 1) * 3,
		"output_item_id": recipe_id + "_potion",
		"output_item": output_item,
		"condition": condition
	}

static func _make_unique_id(existing_ids: Array) -> String:
	var id = ""
	for _i in range(100):
		id = "recipe_" + str(randi() % 100000)
		if not existing_ids.has(id):
			break
	return id

static func _pick_solvent_by_elements(elements: Array) -> String:
	if elements.has("fire") or elements.has("earth"):
		return "oil" if randi() % 2 == 0 else "water"
	if elements.has("poison"):
		return "venom" if randi() % 2 == 0 else "water"
	if elements.has("ice") or elements.has("water"):
		return "water"
	return SOLVENTS[randi() % SOLVENTS.size()]

static func _generate_effects(quality: String, elements: Array, score: int) -> Dictionary:
	var base_value = 1 + (RARITY_ORDER.find(quality) + 1) * 2 + (score / 5)

	var effect_type = _pick_effect_by_elements(elements)
	var name_key = RARITY_ORDER.find(quality) + 1
	var chs_prefix = { 1: "初级", 2: "中级", 3: "高级", 4: "特级", 5: "传说级" }

	var chs_effect_name = {
		"heal": "治疗药剂", "power": "力量药剂", "speed": "迅捷药剂",
		"defense": "护甲药剂", "bomb_up": "爆破药剂", "max_hp": "生命药剂",
		"fire_resist": "火焰抗性药剂", "poison_resist": "毒抗药剂",
		"ice_resist": "冰霜抗性药剂", "regen": "再生药剂"
	}

	var cn_name = chs_effect_name.get(effect_type, "神秘药剂")
	var chs_name = chs_prefix.get(name_key, "高级") + cn_name
	var en_name = _capitalize(effect_type) + " Potion"

	var effects = {}
	match effect_type:
		"heal":
			effects["hp"] = base_value * 5
		"power":
			effects["power"] = base_value
			effects["duration"] = 30 + base_value * 3
		"speed":
			effects["speed"] = base_value * 0.1
			effects["duration"] = 20 + base_value * 2
		"defense":
			effects["defense"] = base_value
			effects["duration"] = 30 + base_value * 3
		"bomb_up":
			effects["bomb_up"] = base_value
			effects["duration"] = 20 + base_value * 2
		"max_hp":
			effects["max_hp"] = base_value * 3
			effects["duration"] = 60
		"regen":
			effects["periodic"] = { "hp": base_value, "interval": 3, "duration": 15 }
		"fire_resist":
			effects["element_resist"] = { "fire": 0.2 * name_key }
			effects["duration"] = 30 + base_value * 2
		"poison_resist":
			effects["element_resist"] = { "poison": 0.2 * name_key }
			effects["duration"] = 30 + base_value * 2
		"ice_resist":
			effects["element_resist"] = { "ice": 0.2 * name_key }
			effects["duration"] = 30 + base_value * 2

	return { "name": en_name, "chs_name": chs_name, "effect_type": effect_type, "effects": effects }

static func _pick_effect_by_elements(elements: Array) -> String:
	var candidates = {
		"fire":    ["power", "bomb_up", "fire_resist"],
		"water":   ["heal", "regen", "defense"],
		"ice":     ["ice_resist", "speed", "defense"],
		"earth":   ["defense", "max_hp", "heal"],
		"air":     ["speed", "power", "regen"],
		"dark":    ["poison_resist", "power", "bomb_up"],
		"poison":  ["poison_resist", "power", "regen"],
		"light":   ["heal", "speed", "max_hp"]
	}

	var pool = {}
	for ek in elements:
		var c = candidates.get(ek, ["heal"])
		for e in c:
			pool[e] = pool.get(e, 0) + 1

	var total = 0
	for k in pool:
		total += pool[k]
	if total == 0:
		return "heal"

	var r = randi() % total
	for k in pool:
		r -= pool[k]
		if r < 0:
			return k
	return "heal"

static func _build_output_item(recipe_id: String, effect_template: Dictionary, quality: String, condition: Dictionary) -> Dictionary:
	return {
		"id": recipe_id + "_potion",
		"name": effect_template.get("name", "Unknown Potion"),
		"chs_name": effect_template.get("chs_name", "未知药剂"),
		"type": "potion",
		"rarity": quality,
		"description": "通过炼金术制作的药剂",
		"frame": "item3",
		"color": _quality_color(quality),
		"effects": effect_template.get("effects", {}),
		"buy_price": 15 * (RARITY_ORDER.find(quality) + 1) * 4,
		"sell_price": 8 * (RARITY_ORDER.find(quality) + 1) * 3,
		"stackable": true,
		"max_stack": 10
	}

static func _quality_color(quality: String) -> Array:
	match quality:
		"common":    return [0.8, 0.8, 0.8]
		"uncommon":  return [0.3, 0.8, 0.3]
		"rare":      return [0.3, 0.5, 1.0]
		"epic":      return [0.8, 0.3, 1.0]
		"legendary": return [1.0, 0.6, 0.0]
	return [1.0, 1.0, 1.0]

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
	if cond.has("heat"):
		var h = cond["heat"]
		var range_width = h.get("max", 1.0) - h.get("min", 0.0)
		score += maxi(0, 5 - int(range_width * 10))
	return score

static func rarity_from_score(score: int) -> String:
	if score >= 45: return "legendary"
	if score >= 26: return "epic"
	if score >= 13: return "rare"
	if score >= 6: return "uncommon"
	return "common"

static func _capitalize(s: String) -> String:
	if s.is_empty(): return s
	return s[0].to_upper() + s.substr(1)

static func generate_from_params(params: Dictionary, existing_recipes: Array = []) -> Dictionary:
	var existing_ids = []
	for r in existing_recipes:
		if r.has("id"):
			existing_ids.append(r["id"])

	var recipe_id = _make_unique_id(existing_ids)

	var ce = params.get("element", {})
	var dominant_elements = []
	for ek in ce:
		if ce[ek] >= 0.25:
			dominant_elements.append(ek)
	if dominant_elements.is_empty():
		for ek in ce:
			dominant_elements.append(ek)
	if dominant_elements.is_empty():
		return {}

	var pg = params.get("granularity", 0)
	var pc = params.get("concentration", 0.5)

	var ph = params.get("heat", 0.5)
	var solv_cond = {}
	var ps = params.get("solvent_list", {})
	for sid in ps:
		solv_cond[sid] = { "min_amount": snapped(maxf(ps[sid] * 0.5, 0.1), 0.1) }
	if solv_cond.is_empty():
		solv_cond = { "water": { "min_amount": 0.1 } }

	var condition = {
		"solvent": solv_cond,
		"granularity": {
			"max": snapped(pg * 1.5 + 0.5, 0.5)
		},
		"concentration": {
			"min": snapped(pc * 0.4, 0.1),
			"max": snapped(pc * 1.5 + 0.5, 0.1)
		},
		"heat": {
			"min": snapped(maxf(ph - 0.3, 0.0), 0.05),
			"max": snapped(minf(ph + 0.3, 1.0), 0.05)
		},
		"element": {}
	}
	for ek in dominant_elements:
		var min_val = snapped(maxf(ce[ek] * 0.6, 0.15), 0.05)
		condition["element"][ek] = { "min": min_val }

	var raw_score = 0
	for ek in dominant_elements:
		raw_score += int(ce[ek] * 10)
	raw_score += int(pc * 3)

	var quality = rarity_from_score(raw_score)
	var effect_template = _generate_effects(quality, dominant_elements, raw_score)
	var output_item = _build_output_item(recipe_id, effect_template, quality, condition)

	return {
		"id": recipe_id,
		"name": effect_template.get("name", "Unknown Potion"),
		"chs_name": effect_template.get("chs_name", "未知药剂"),
		"type": "recipe",
		"rarity": quality,
		"description": "炼金配方",
		"frame": "item2",
		"color": _quality_color(quality),
		"buy_price": 20 * (RARITY_ORDER.find(quality) + 1) * 5,
		"sell_price": 10 * (RARITY_ORDER.find(quality) + 1) * 3,
		"output_item_id": recipe_id + "_potion",
		"output_item": output_item,
		"condition": condition
	}

static func generate_chest_loot(area_level: int) -> Dictionary:
	var quality = "uncommon"
	if area_level >= 5:
		quality = "rare" if randi() % 3 != 0 else "epic"
	elif area_level >= 3:
		quality = "uncommon" if randi() % 3 != 0 else "rare"
	return generate_recipe(quality)

static func generate_shop_stock(shop_level: int) -> Array:
	var stock = []
	var count = 3 + randi() % 3
	for i in range(count):
		var quality = "common"
		var roll = randi() % 100
		if roll < 10 and shop_level >= 3:
			quality = "rare"
		elif roll < 40 and shop_level >= 2:
			quality = "uncommon"
		stock.append(generate_recipe(quality))
	return stock
