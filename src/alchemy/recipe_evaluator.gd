class_name RecipeEvaluator
extends RefCounted

const DATA = preload("res://src/alchemy/alchemy_data.gd")

const ELEMENT_RANGES = {
	"fire":    { "max_single": 0.9, "materials": ["red_herb", "fire_flower"] },
	"water":   { "max_single": 0.7, "materials": ["blue_herb", "slime_goo", "ice_crystal"] },
	"ice":     { "max_single": 0.9, "materials": ["ice_crystal"] },
	"earth":   { "max_single": 0.7, "materials": ["red_herb", "slime_goo"] },
	"air":     { "max_single": 0.7, "materials": ["bat_wing"] },
	"dark":    { "max_single": 0.7, "materials": ["bat_wing"] },
	"poison":  { "max_single": 0.5, "materials": ["slime_goo"] },
	"light":   { "max_single": 0.4, "materials": [] }
}

const ITEM_LOADER = preload("res://src/item_editor/item_data.gd")

static func get_all_materials() -> Array:
	var all = ITEM_LOADER.list_items()
	var mats = []
	for item in all:
		var alch = item.get("alchemy", {})
		if not alch.is_empty():
			mats.append(item)
	return mats

static func evaluate(recipe: Dictionary) -> Dictionary:
	var cond = recipe.get("condition", {})
	var output = recipe.get("output_item", {})

	var scores = {}
	scores["material_feasibility"] = _eval_material_feasibility(cond)
	scores["concentration_feasibility"] = _eval_concentration(cond)
	scores["grind_feasibility"] = _eval_grind(cond)
	scores["effect_balance"] = _eval_effects(output, recipe.get("rarity", "common"))

	var total = 0.0
	var count = 0
	for k in scores:
		total += scores[k].get("score", 0)
		count += 1
	var avg = total / maxi(count, 1)

	var warnings = []
	var suggestions = []

	for k in scores:
		var s = scores[k]
		if s.get("score", 100) < 30:
			warnings.append(s.get("warning", k + " 可行性低"))
			if s.has("suggestion"):
				suggestions.append(s["suggestion"])

	var flags = []
	if avg < 50:
		flags.append("建议修改")
	if avg < 30:
		flags.append("逆天")
	if warnings.size() > 0:
		flags.append("有警告")

	var fix = _generate_fix(recipe, scores) if avg < 60 else {}

	return {
		"total_score": int(avg),
		"detail": scores,
		"warnings": warnings,
		"suggestions": suggestions,
		"flags": flags,
		"fix_suggestion": fix
	}

static func _eval_material_feasibility(cond: Dictionary) -> Dictionary:
	var ce = cond.get("element", {})
	if ce.is_empty():
		return { "score": 0, "warning": "未指定元素条件", "suggestion": "添加至少一个元素需求" }

	var total_ok = 0.0
	var total = ce.size()
	var hardest = ""
	var hardest_threshold = 0.0

	for ek in ce:
		var ev = ce[ek]
		var min_val = ev.get("min", 0) if ev is Dictionary else float(ev)
		var range_info = ELEMENT_RANGES.get(ek, { "max_single": 0.3, "materials": [] })
		var max_possible = range_info.get("max_single", 0.3)

		if min_val > hardest_threshold:
			hardest_threshold = min_val
			hardest = ek

		if min_val <= max_possible * 1.2:
			total_ok += 1.0
		else:
			total_ok += max_possible / maxf(min_val, 0.01) * 0.5

	var ratio = total_ok / maxf(total, 1)
	var score = int(ratio * 50)

	var result: Dictionary = { "score": clampi(score, 0, 50) }
	if score < 15:
		result["warning"] = "元素 " + hardest + " 需求 " + str(hardest_threshold) + " 超过材料上限"
		result["suggestion"] = "将 " + hardest + " 阈值降低至 " + str(ELEMENT_RANGES.get(hardest, {}).get("max_single", 0.3))
	elif score < 30:
		result["warning"] = "部分元素需求偏高"
		result["suggestion"] = "检查 " + hardest + " 阈值是否需要降低"

	return result

static func _eval_concentration(cond: Dictionary) -> Dictionary:
	var c = cond.get("concentration", {})
	if c.is_empty():
		return { "score": 20, "suggestion": "建议设置浓度区间" }

	var max_c = c.get("max", 3.0)
	var min_c = c.get("min", 0.0)

	var score = 20
	var warning = ""
	var suggestion = ""

	if max_c < 0.3:
		score = 5
		warning = "浓度上限过低（<0.3），可能无法达成"
		suggestion = "将浓度上限提高到 0.5 以上"
	elif max_c > 8.0:
		score = 10
		warning = "浓度上限过高（>8.0），可能需要极大量材料"
		suggestion = "将浓度上限降低到 5.0 以下"
	elif max_c > 5.0:
		score = 14

	if min_c > max_c:
		score = 0
		warning = "浓度下限大于上限"

	return { "score": score, "warning": warning, "suggestion": suggestion }

static func _eval_grind(cond: Dictionary) -> Dictionary:
	var g = cond.get("granularity", {})
	if g.is_empty():
		return { "score": 15 }

	var max_g = g.get("max", 0) if g is Dictionary else 0
	var min_g = g.get("min", 0) if g is Dictionary else 0

	if max_g > 6:
		return { "score": 5, "warning": "颗粒度需求 > 6，仅有极少数材料可达", "suggestion": "将最大颗粒度降低到 6 以下" }
	if min_g < 0:
		return { "score": 10, "warning": "颗粒度下限不能为负" }
	if max_g <= 1:
		return { "score": 10, "warning": "颗粒度要求过严格（<=1）" }
	return { "score": 15 }

static func _eval_effects(output: Dictionary, rarity: String) -> Dictionary:
	var effects = output.get("effects", {})
	if effects.is_empty():
		return { "score": 0, "warning": "药剂无效果", "suggestion": "添加至少一个效果" }

	var rarity_order = { "common": 1, "uncommon": 2, "rare": 3, "epic": 4, "legendary": 5 }
	var rlvl = rarity_order.get(rarity, 1)
	var score = 15

	var max_reasonable = rlvl * 3
	var op_flag = false
	var op_field = ""

	for ek in effects:
		var val = effects[ek]
		if val is int or val is float:
			var abs_val = absf(float(val))
			if abs_val > max_reasonable * 2:
				op_flag = true
				if op_field == "":
					op_field = ek
				score = maxi(0, score - 5)

	if op_flag:
		return { "score": score, "warning": "效果 " + op_field + " 数值偏高（逆天级）", "suggestion": "将 " + op_field + " 降低到 " + str(max_reasonable) + " 以下" }

	return { "score": 15 }

static func _generate_fix(recipe: Dictionary, scores: Dictionary) -> Dictionary:
	var fix = recipe.duplicate(true)
	var cond = fix.get("condition", {})
	var modified = false

	var mat_score = scores.get("material_feasibility", {})
	if mat_score.get("score", 50) < 30 and mat_score.has("suggestion"):
		modified = true

	var conc_score = scores.get("concentration_feasibility", {})
	if conc_score.get("score", 20) < 10 and conc_score.has("suggestion"):
		var sug = str(conc_score["suggestion"])
		if "降低" in sug:
			cond["concentration"]["max"] = 5.0
			modified = true

	var grind_score = scores.get("grind_feasibility", {})
	if grind_score.get("score", 15) < 10 and grind_score.has("warning"):
		if cond.has("granularity") and cond["granularity"] is Dictionary:
			if cond["granularity"].get("max", 0) > 6:
				cond["granularity"]["max"] = 6
				modified = true

	if modified:
		fix["condition"] = cond
		return fix
	return {}

static func auto_fix(recipe: Dictionary) -> Dictionary:
	var eval_result = evaluate(recipe)
	if eval_result.has("fix_suggestion") and not eval_result["fix_suggestion"].is_empty():
		return eval_result["fix_suggestion"]
	return recipe.duplicate(true)
