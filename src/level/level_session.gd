class_name AdventureLevelSession
extends RefCounted

const LEVEL_CATALOG := preload("res://src/level/level_catalog.gd")

static var _selected_level_id: String = ""

static func select_level(level_id: String) -> bool:
	var catalog = LEVEL_CATALOG.new()
	if not catalog.contains(level_id):
		return false
	_selected_level_id = level_id
	return true

static func clear() -> void:
	_selected_level_id = ""

static func has_selected_level() -> bool:
	return _selected_level_id != ""

static func selected_level_id() -> String:
	return _selected_level_id

static func current_profile() -> Dictionary:
	if not has_selected_level():
		return {}
	return LEVEL_CATALOG.new().profile(_selected_level_id)
