class_name AdventureLevelProgressRepository
extends RefCounted

const DEFAULT_PATH := "user://adventure_level_progress.json"
const LEVEL_CATALOG := preload("res://src/level/level_catalog.gd")
const WORLD_CAMPAIGN_CATALOG := preload("res://src/level/world_campaign_catalog.gd")

var progress_path: String
var catalog
var campaign

func _init(path: String = DEFAULT_PATH, level_catalog = null, campaign_catalog = null) -> void:
	progress_path = path
	catalog = level_catalog if level_catalog != null else LEVEL_CATALOG.new()
	campaign = campaign_catalog if campaign_catalog != null else WORLD_CAMPAIGN_CATALOG.new(WORLD_CAMPAIGN_CATALOG.DEFAULT_PATH, catalog)

func completed_level_ids() -> Array[String]:
	var completed: Array[String] = _state()["completed"]
	return completed.duplicate()


func visible_level_ids() -> Array[String]:
	var result: Array[String] = []
	var state: Dictionary = _state()
	var completed: Array = state["completed"]
	var selections: Dictionary = state["selected_by_stage"]
	for stage_data in campaign.stages():
		var stage_id := str(stage_data.get("id", ""))
		var selected_level_id := str(selections.get(stage_id, ""))
		if not selected_level_id.is_empty():
			result.append(selected_level_id)
			if not completed.has(selected_level_id):
				break
			continue
		for raw_level_id in stage_data.get("level_ids", []):
			result.append(str(raw_level_id))
		break
	return result


func active_stage_id() -> String:
	var state: Dictionary = _state()
	var completed: Array = state["completed"]
	var selections: Dictionary = state["selected_by_stage"]
	for stage_data in campaign.stages():
		var stage_id := str(stage_data.get("id", ""))
		var selected_level_id := str(selections.get(stage_id, ""))
		if selected_level_id.is_empty() or not completed.has(selected_level_id):
			return stage_id
	return ""


func selected_level_for_stage(stage_id: String) -> String:
	return str((_state()["selected_by_stage"] as Dictionary).get(stage_id, ""))

func is_unlocked(level_id: String) -> bool:
	return campaign.contains_level(level_id) and visible_level_ids().has(level_id)


func select_level(level_id: String) -> bool:
	if not is_unlocked(level_id):
		return false
	var stage_data: Dictionary = campaign.stage_for_level(level_id)
	var stage_id := str(stage_data.get("id", ""))
	if stage_id.is_empty():
		return false
	var state: Dictionary = _state()
	var selections: Dictionary = state["selected_by_stage"]
	var existing := str(selections.get(stage_id, ""))
	if not existing.is_empty():
		return existing == level_id
	if active_stage_id() != stage_id:
		return false
	selections[stage_id] = level_id
	state["selected_by_stage"] = selections
	return _write_json(state)

func complete_level(level_id: String) -> bool:
	if not campaign.contains_level(level_id):
		return false
	var state: Dictionary = _state()
	var stage_id: String = campaign.stage_id_for_level(level_id)
	var selections: Dictionary = state["selected_by_stage"]
	var selected_level_id := str(selections.get(stage_id, ""))
	if selected_level_id.is_empty():
		if active_stage_id() != stage_id:
			return false
		selections[stage_id] = level_id
	elif selected_level_id != level_id:
		return false
	var completed: Array = state["completed"]
	if not completed.has(level_id):
		completed.append(level_id)
	state["version"] = 2
	state["completed"] = completed
	state["selected_by_stage"] = selections
	return _write_json(state)


func _state() -> Dictionary:
	var raw: Variant = _read_json()
	var raw_state: Dictionary = raw if raw is Dictionary else {}
	var completed: Array[String] = []
	for raw_id in raw_state.get("completed", []):
		var level_id := str(raw_id)
		if catalog.contains(level_id) and not completed.has(level_id):
			completed.append(level_id)
	var selections: Dictionary = {}
	var raw_selections: Variant = raw_state.get("selected_by_stage", {})
	if raw_selections is Dictionary:
		for raw_stage_id in (raw_selections as Dictionary):
			var stage_id := str(raw_stage_id)
			var level_id := str((raw_selections as Dictionary)[raw_stage_id])
			var stage_data: Dictionary = campaign.stage(stage_id)
			if (stage_data.get("level_ids", []) as Array).has(level_id):
				selections[stage_id] = level_id
	# Version 1 saves only had completed IDs. Derive the chosen branch for those stages.
	for completed_id in completed:
		var stage_id: String = campaign.stage_id_for_level(completed_id)
		if not stage_id.is_empty() and not selections.has(stage_id):
			selections[stage_id] = completed_id
	return {
		"version": 2,
		"completed": completed,
		"selected_by_stage": selections,
	}

func _read_json() -> Variant:
	if not FileAccess.file_exists(progress_path):
		return null
	var file := FileAccess.open(progress_path, FileAccess.READ)
	if file == null:
		return null
	var data: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return data

func _write_json(data: Dictionary) -> bool:
	var file := FileAccess.open(progress_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true
