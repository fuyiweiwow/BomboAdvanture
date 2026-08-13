class_name AdventureWorldCampaignCatalog
extends RefCounted

const DEFAULT_PATH := "res://assets/config/hiloan_campaign.json"
const LEVEL_CATALOG := preload("res://src/level/level_catalog.gd")

var config_path: String
var level_catalog
var _config: Dictionary = {}
var _regions_by_id: Dictionary = {}
var _stages: Array[Dictionary] = []
var _stage_by_id: Dictionary = {}
var _stage_id_by_level: Dictionary = {}


func _init(path: String = DEFAULT_PATH, catalog = null) -> void:
	config_path = path
	level_catalog = catalog if catalog != null else LEVEL_CATALOG.new()
	reload()


func reload() -> bool:
	_config = {}
	_regions_by_id.clear()
	_stages.clear()
	_stage_by_id.clear()
	_stage_id_by_level.clear()
	var loaded: Variant = _read_json(config_path)
	if not loaded is Dictionary:
		push_error("World campaign config is not a JSON object: %s" % config_path)
		return false
	_config = (loaded as Dictionary).duplicate(true)
	for raw_region in _config.get("regions", []):
		if not raw_region is Dictionary:
			continue
		var region: Dictionary = (raw_region as Dictionary).duplicate(true)
		var region_id := str(region.get("id", ""))
		if region_id.is_empty():
			continue
		_regions_by_id[region_id] = region
	for raw_stage in _config.get("stages", []):
		if not raw_stage is Dictionary:
			continue
		var stage: Dictionary = (raw_stage as Dictionary).duplicate(true)
		var stage_id := str(stage.get("id", ""))
		var region_id := str(stage.get("region", ""))
		if stage_id.is_empty() or not _regions_by_id.has(region_id):
			continue
		var valid_levels: Array[String] = []
		for raw_level_id in stage.get("level_ids", []):
			var level_id := str(raw_level_id)
			if level_catalog.contains(level_id) and not _stage_id_by_level.has(level_id):
				valid_levels.append(level_id)
				_stage_id_by_level[level_id] = stage_id
		if valid_levels.is_empty():
			continue
		stage["level_ids"] = valid_levels
		stage["index"] = _stages.size()
		_stages.append(stage)
		_stage_by_id[stage_id] = stage
	return not _stages.is_empty()


func stages() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for stage in _stages:
		result.append(stage.duplicate(true))
	return result


func stage(stage_id: String) -> Dictionary:
	var value: Dictionary = _stage_by_id.get(stage_id, {})
	return value.duplicate(true)


func region(region_id: String) -> Dictionary:
	var value: Dictionary = _regions_by_id.get(region_id, {})
	return value.duplicate(true)


func stage_id_for_level(level_id: String) -> String:
	return str(_stage_id_by_level.get(level_id, ""))


func stage_for_level(level_id: String) -> Dictionary:
	return stage(stage_id_for_level(level_id))


func contains_level(level_id: String) -> bool:
	return _stage_id_by_level.has(level_id)


func placement() -> Dictionary:
	var value = _config.get("placement", {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func campaign_seed() -> int:
	return int(_config.get("seed", 0))


func campaign_profile(level_id: String) -> Dictionary:
	var stage_data := stage_for_level(level_id)
	if stage_data.is_empty():
		return {}
	var region_data := region(str(stage_data.get("region", "")))
	var level_ids: Array = stage_data.get("level_ids", [])
	var candidate_index := level_ids.find(level_id)
	var result := {
		"campaign_stage_id": str(stage_data.get("id", "")),
		"campaign_stage_index": int(stage_data.get("index", 0)),
		"campaign_stage_name": str(stage_data.get("name", "")),
		"campaign_candidate_index": candidate_index,
		"campaign_candidate_count": level_ids.size(),
		"campaign_seed": campaign_seed(),
		"campaign_placement": placement(),
		"campaign_region_id": str(region_data.get("id", "")),
		"campaign_region_bounds": region_data.get("bounds", []).duplicate(),
		"campaign_region_biomes": region_data.get("biomes", []).duplicate(),
		"region_name": str(region_data.get("name", "")),
		"region_subtitle": str(region_data.get("description", "")),
		"travel_mode": str(region_data.get("travel_mode", "walk")),
		"marker_label": str(candidate_index + 1),
	}
	return result


func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if _stages.is_empty():
		errors.append("No valid campaign stages were loaded.")
	var configured_levels: Dictionary = {}
	for raw_stage in _config.get("stages", []):
		if not raw_stage is Dictionary:
			continue
		var stage_data := raw_stage as Dictionary
		var stage_id := str(stage_data.get("id", ""))
		if not _regions_by_id.has(str(stage_data.get("region", ""))):
			errors.append("Stage %s references an unknown region." % stage_id)
		for raw_level_id in stage_data.get("level_ids", []):
			var level_id := str(raw_level_id)
			if not level_catalog.contains(level_id):
				errors.append("Stage %s references missing level %s." % [stage_id, level_id])
			elif configured_levels.has(level_id):
				errors.append("Level %s is assigned to more than one stage." % level_id)
			configured_levels[level_id] = true
	return errors


func _read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var data: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return data
