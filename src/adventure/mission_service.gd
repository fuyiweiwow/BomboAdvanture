# Pure mission lifecycle service. Keeping this independent from scenes allows
# city, level runtime and silent simulations to share exactly the same rules.
class_name MissionService
extends RefCounted

static func accept(definition: Dictionary) -> Dictionary:
	if not _is_valid_definition(definition):
		return {}
	var objective: Dictionary = definition["objective"]
	var rewards: Dictionary = definition.get("rewards", {})
	return {
		"mission_id": str(definition["id"]),
		"status": "active",
		"objective_type": str(objective.get("type", "defeat")),
		"target": int(objective["target"]),
		"progress": 0,
		"rewards": _normalize_rewards(rewards),
	}


static func add_progress(session: Dictionary, amount: int = 1) -> bool:
	if session.get("status", "") != "active" or amount <= 0:
		return false
	var target := int(session.get("target", 0))
	session["progress"] = mini(target, int(session.get("progress", 0)) + amount)
	return true


static func is_complete(session: Dictionary) -> bool:
	return session.get("status", "") == "active" and int(session.get("progress", 0)) >= int(session.get("target", 1))


static func settle(session: Dictionary) -> Dictionary:
	if not is_complete(session):
		return {}
	session["status"] = "settled"
	return (session.get("rewards", {}) as Dictionary).duplicate(true)


static func _is_valid_definition(definition: Dictionary) -> bool:
	if str(definition.get("id", "")).strip_edges() == "":
		return false
	var objective = definition.get("objective", null)
	return objective is Dictionary and int(objective.get("target", 0)) > 0


static func _normalize_rewards(rewards: Dictionary) -> Dictionary:
	var items: Dictionary = {}
	var raw_items = rewards.get("items", {})
	if raw_items is Dictionary:
		for item_id in raw_items:
			var amount := int(raw_items[item_id])
			if str(item_id) != "" and amount > 0:
				items[str(item_id)] = amount
	return {"gold": maxi(0, int(rewards.get("gold", 0))), "items": items}
