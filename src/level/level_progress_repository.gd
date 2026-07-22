class_name AdventureLevelProgressRepository
extends RefCounted

const DEFAULT_PATH := "user://adventure_level_progress.json"
const LEVEL_CATALOG := preload("res://src/level/level_catalog.gd")

var progress_path: String
var catalog

func _init(path: String = DEFAULT_PATH, level_catalog = null) -> void:
	progress_path = path
	catalog = level_catalog if level_catalog != null else LEVEL_CATALOG.new()

func completed_level_ids() -> Array[String]:
	var result: Array[String] = []
	var raw = _read_json()
	if not raw is Dictionary:
		return result
	for raw_id in (raw as Dictionary).get("completed", []):
		var level_id = str(raw_id)
		if catalog.contains(level_id) and not result.has(level_id):
			result.append(level_id)
	return result

func is_unlocked(level_id: String) -> bool:
	if not catalog.contains(level_id):
		return false
	if catalog.first_level_id() == level_id:
		return true
	var completed = completed_level_ids()
	if completed.has(level_id):
		return true
	for completed_id in completed:
		if catalog.next_level_id(completed_id) == level_id:
			return true
	return false

func complete_level(level_id: String) -> bool:
	if not catalog.contains(level_id):
		return false
	var completed = completed_level_ids()
	if not completed.has(level_id):
		completed.append(level_id)
	return _write_json({"version": 1, "completed": completed})

func _read_json() -> Variant:
	if not FileAccess.file_exists(progress_path):
		return null
	var file = FileAccess.open(progress_path, FileAccess.READ)
	if file == null:
		return null
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	return data

func _write_json(data: Dictionary) -> bool:
	var file = FileAccess.open(progress_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true
