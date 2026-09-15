# Coordinates mission completion with the persistent claim repository. The
# session is marked settled only after durable storage succeeds, so failed disk
# writes remain retryable.
class_name AdventureSettlementService
extends RefCounted

const MissionService = preload("res://src/adventure/mission_service.gd")


static func complete(session: Dictionary, repository: RefCounted) -> Dictionary:
	if not MissionService.is_complete(session):
		return {}
	var claim_id := str(session.get("claim_id", "")).strip_edges()
	var rewards_value = session.get("rewards", {})
	if claim_id.is_empty() or not rewards_value is Dictionary:
		return {}
	var rewards: Dictionary = rewards_value
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
