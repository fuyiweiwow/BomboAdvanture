# Pure rules for temporary Rogue upgrades. Persistent rewards are handled by
# MissionService settlement and never mixed into this run-scoped state.
class_name RogueItemRules
extends RefCounted

static func apply(current_stats: Dictionary, item: Dictionary) -> Dictionary:
	var result := current_stats.duplicate(true)
	if str(item.get("lifecycle", "run")) != "run":
		return result
	var effects = item.get("effects", {})
	if not effects is Dictionary:
		return result
	if effects.has("bomb"):
		var increase := maxi(0, int(effects["bomb"]))
		result["bomb"] = maxi(0, int(result.get("bomb", 0)) + increase)
		result["remain_bombs"] = mini(int(result["bomb"]), maxi(0, int(result.get("remain_bombs", 0)) + increase))
	if effects.has("power"):
		result["power"] = maxi(0, int(result.get("power", 0)) + int(effects["power"]))
	if effects.has("speed"):
		result["speed"] = maxf(0.1, float(result.get("speed", 1.0)) + float(effects["speed"]))
	return result
