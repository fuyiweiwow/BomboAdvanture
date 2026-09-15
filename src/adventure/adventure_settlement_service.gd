# Coordinates mission completion with the persistent claim repository. The
# session is marked settled only after durable storage succeeds, so failed disk
# writes remain retryable.
class_name AdventureSettlementService
extends RefCounted

const MissionService = preload("res://src/adventure/mission_service.gd")


static func complete(session: Dictionary, repository: RefCounted, bonus_rewards: Dictionary = {}) -> Dictionary:
	if not MissionService.is_complete(session):
		return {}
	var claim_id := str(session.get("claim_id", "")).strip_edges()
	var rewards_value = session.get("rewards", {})
	if claim_id.is_empty() or not rewards_value is Dictionary:
		return {}
	var rewards := _merge_rewards(rewards_value, bonus_rewards)
	if not repository.has_method("claim") or not repository.claim(claim_id, rewards):
		return {}
	session["status"] = "settled"
	return {
		"status": "claimed",
		"mission_id": str(session.get("mission_id", "")),
		"claim_id": claim_id,
		"gold": int(rewards.get("gold", 0)),
		"items": (rewards.get("items", {}) as Dictionary).duplicate(true),
	}


static func _merge_rewards(fixed_rewards: Dictionary, bonus_rewards: Dictionary) -> Dictionary:
	var items: Dictionary = {}
	for source in [fixed_rewards.get("items", {}), bonus_rewards.get("items", {})]:
		if not source is Dictionary:
			continue
		for item_id in source:
			var amount := maxi(0, int(source[item_id]))
			if not str(item_id).is_empty() and amount > 0:
				items[str(item_id)] = int(items.get(str(item_id), 0)) + amount
	return {
		"gold": maxi(0, int(fixed_rewards.get("gold", 0))) + maxi(0, int(bonus_rewards.get("gold", 0))),
		"items": items,
	}
