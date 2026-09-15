# Persistent adventure rewards. A claim id is stored together with the updated
# totals so replaying or copying a completed run cannot grant rewards twice.
class_name AdventureProfileRepository
extends RefCounted

const JsonStore = preload("res://src/core/json_store.gd")

var _path: String
var _profile: Dictionary


func _init(path: String = "user://adventure_profile.json") -> void:
	_path = path
	_profile = _normalize_profile(JsonStore.read_dictionary(_path))


func claim(claim_id: String, rewards: Dictionary) -> bool:
	var normalized_id := claim_id.strip_edges()
	if normalized_id.is_empty() or normalized_id in _profile["claimed"]:
		return false

	var next_profile := _profile.duplicate(true)
	var normalized_rewards := _normalize_rewards(rewards)
	next_profile["gold"] += normalized_rewards["gold"]
	for item_id in normalized_rewards["items"]:
		var current := int(next_profile["items"].get(item_id, 0))
		next_profile["items"][item_id] = current + normalized_rewards["items"][item_id]
	next_profile["claimed"].append(normalized_id)

	# Publish the in-memory state only after the complete profile was written.
	if not JsonStore.write(_path, next_profile):
		return false
	_profile = next_profile
	return true


func snapshot() -> Dictionary:
	return _profile.duplicate(true)


func _normalize_profile(raw: Dictionary) -> Dictionary:
	var items: Dictionary = {}
	var raw_items = raw.get("items", {})
	if raw_items is Dictionary:
		for item_id in raw_items:
			var amount := int(raw_items[item_id])
			if not str(item_id).is_empty() and amount > 0:
				items[str(item_id)] = amount

	var claimed: Array[String] = []
	var raw_claimed = raw.get("claimed", [])
	if raw_claimed is Array:
		for claim_id in raw_claimed:
			var normalized_id := str(claim_id).strip_edges()
			if not normalized_id.is_empty() and normalized_id not in claimed:
				claimed.append(normalized_id)
	return {
		"version": 1,
		"gold": maxi(0, int(raw.get("gold", 0))),
		"items": items,
		"claimed": claimed,
	}


func _normalize_rewards(rewards: Dictionary) -> Dictionary:
	var normalized := _normalize_profile(rewards)
	return {"gold": normalized["gold"], "items": normalized["items"]}
