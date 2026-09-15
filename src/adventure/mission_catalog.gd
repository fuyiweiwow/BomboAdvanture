class_name MissionCatalog
extends RefCounted

const JsonStore = preload("res://src/core/json_store.gd")
const MISSION_ROOT := "res://assets/mission/"

static func list_missions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for mission_id in JsonStore.list_json_ids(MISSION_ROOT):
		var mission := JsonStore.read_dictionary(MISSION_ROOT + mission_id + ".json")
		if not mission.is_empty():
			result.append(mission)
	return result

static func get_mission(mission_id: String) -> Dictionary:
	if mission_id not in JsonStore.list_json_ids(MISSION_ROOT):
		return {}
	return JsonStore.read_dictionary(MISSION_ROOT + mission_id + ".json")
