# Pure mission lifecycle service. Keeping this independent from scenes allows
# city, level runtime and silent simulations to share exactly the same rules.
class_name MissionService
extends RefCounted

const SUPPORTED_OBJECTIVES := ["defeat"]

static func accept(definition: Dictionary) -> Dictionary:
	if not _is_valid_definition(definition):
		return {}
	var objective: Dictionary = definition["objective"]
	var raw_rewards = definition.get("rewards", {})
	var rewards: Dictionary = raw_rewards if raw_rewards is Dictionary else {}
	return {
		"mission_id": str(definition["id"]),
		"claim_id": _new_claim_id(str(definition["id"])),
		"status": "active",
		"objective_type": str(objective.get("type", "defeat")),
		"target": int(objective["target"]),
		"progress": 0,
		"rewards": _normalize_rewards(rewards),
	}


static func _new_claim_id(mission_id: String) -> String:
	var timestamp_us := int(Time.get_unix_time_from_system() * 1000000.0)
	return "%s:%d:%d" % [mission_id, timestamp_us, randi()]


static func add_progress(session: Dictionary, amount: int = 1, event_type: String = "defeat") -> bool:
	var target := int(session.get("target", 0))
	if session.get("status", "") != "active" or amount <= 0 or target <= 0:
		return false
	if str(session.get("objective_type", "")) != event_type:
		return false
	session["progress"] = mini(target, int(session.get("progress", 0)) + amount)
	return true


static func is_complete(session: Dictionary) -> bool:
	var target := int(session.get("target", 0))
	return session.get("status", "") == "active" and target > 0 and int(session.get("progress", 0)) >= target


static func settle(session: Dictionary) -> Dictionary:
	if not is_complete(session):
		return {}
	session["status"] = "settled"
	return (session.get("rewards", {}) as Dictionary).duplicate(true)


static func _is_valid_definition(definition: Dictionary) -> bool:
	if str(definition.get("id", "")).strip_edges() == "":
		return false
	var objective = definition.get("objective", null)
	return objective is Dictionary and str(objective.get("type", "")) in SUPPORTED_OBJECTIVES and int(objective.get("target", 0)) > 0


static func _normalize_rewards(rewards: Dictionary) -> Dictionary:
	var items: Dictionary = {}
	var raw_items = rewards.get("items", {})
	if raw_items is Dictionary:
		for item_id in raw_items:
			var amount := int(raw_items[item_id])
			if str(item_id) != "" and amount > 0:
				items[str(item_id)] = amount
	return {"gold": maxi(0, int(rewards.get("gold", 0))), "items": items}
