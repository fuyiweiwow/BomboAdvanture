class_name AdventureLevelCatalog
extends RefCounted

const MAP_CATALOG := preload("res://src/map/map_catalog.gd")

var maps

func _init(map_catalog = null) -> void:
	maps = map_catalog if map_catalog != null else MAP_CATALOG.new()

func levels() -> Array[Dictionary]:
	return maps.levels()

func map_sets() -> Array[Dictionary]:
	return maps.map_sets()

func profile(level_id: String) -> Dictionary:
	return maps.profile(level_id)

func contains(level_id: String) -> bool:
	return maps.contains(level_id)

func first_level_id() -> String:
	return maps.first_level_id()

func next_level_id(level_id: String) -> String:
	return maps.next_level_id(level_id)
