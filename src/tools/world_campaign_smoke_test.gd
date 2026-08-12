extends SceneTree

const LEVEL_CATALOG := preload("res://src/level/level_catalog.gd")
const CAMPAIGN_CATALOG := preload("res://src/level/world_campaign_catalog.gd")
const PROGRESS_REPOSITORY := preload("res://src/level/level_progress_repository.gd")
const RING_WORLD_MAP := preload("res://src/main/ring_world_map.gd")

var _failures: Array[String] = []


func _init() -> void:
	var save_path := "/tmp/bombo_world_campaign_smoke.json"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	var levels = LEVEL_CATALOG.new()
	var campaign = CAMPAIGN_CATALOG.new(CAMPAIGN_CATALOG.DEFAULT_PATH, levels)
	var progress = PROGRESS_REPOSITORY.new(save_path, levels, campaign)

	_expect(campaign.validation_errors().is_empty(), "campaign JSON must reference valid, unique levels")
	_expect(progress.visible_level_ids() == ["yx_map"], "the Nether start must be the only initial candidate")
	_expect(progress.select_level("yx_map"), "the initial candidate must be selectable")
	_expect(progress.visible_level_ids() == ["yx_map"], "selection must retain only the chosen point")
	_expect(progress.complete_level("yx_map"), "the selected level must be completable")
	_expect(progress.visible_level_ids() == ["yx_map", "YongDong1", "YongDong2"], "completion must reveal the next candidate group")
	_expect(progress.select_level("YongDong2"), "any candidate in the active group must be selectable")
	_expect(progress.visible_level_ids() == ["yx_map", "YongDong2"], "unchosen sibling points must disappear")
	_expect(not progress.select_level("YongDong1"), "a discarded sibling must stay locked")

	var profiles: Array[Dictionary] = []
	for stage_data in campaign.stages():
		for raw_level_id in stage_data.get("level_ids", []):
			var level_id := str(raw_level_id)
			var profile: Dictionary = levels.profile(level_id)
			profile.merge(campaign.campaign_profile(level_id), true)
			profiles.append(profile)
	var map = RING_WORLD_MAP.new()
	map.configure(profiles)
	var marker_cells: Dictionary = map.campaign_marker_cells()
	_expect(marker_cells.size() == profiles.size(), "every configured candidate must receive a map cell")
	var unique_cells: Dictionary = {}
	for level_id in marker_cells:
		var cell: Vector2i = marker_cells[level_id]
		_expect(not unique_cells.has(cell), "candidate cells must not overlap: %s" % level_id)
		unique_cells[cell] = true
		_expect(map._is_world_tile(cell.x, cell.y), "candidate must be on world terrain: %s" % level_id)
		var profile: Dictionary = levels.profile(str(level_id))
		profile.merge(campaign.campaign_profile(str(level_id)), true)
		var allowed_biomes: Array = profile.get("campaign_region_biomes", [])
		_expect(allowed_biomes.has(map._biome_at(cell.x, cell.y)), "candidate must match its configured biome: %s" % level_id)
		var clearance := float((profile.get("campaign_placement", {}) as Dictionary).get("infrastructure_clearance", 1.1))
		_expect(not map._near_infrastructure(Vector2(cell), clearance), "candidate must avoid infrastructure: %s" % level_id)
	map.free()

	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	if _failures.is_empty():
		print("WORLD_CAMPAIGN_SMOKE_OK profiles=%d stages=%d" % [profiles.size(), campaign.stages().size()])
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
