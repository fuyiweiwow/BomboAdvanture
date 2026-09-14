# res://src/tests/city_selftest.gd
# Headless verification of the city (district) system: data loading, the
# incremental district/building model, and scene construction.
extends Node

const CityData = preload("res://src/city/city_data.gd")


func _ready() -> void:
	var failures := 0
	failures += _verify_data()
	failures += _verify_scene()
	print("FAILURES=", failures)
	get_tree().quit(failures)


func _verify_data() -> int:
	var d = CityData.load_district("living_district")
	if d.is_empty():
		print("FAIL: living_district not loaded")
		return 1
	if str(d.get("name", "")) == "":
		print("FAIL: district name missing")
		return 1
	var buildings: Array = d.get("buildings", [])
	if buildings.is_empty():
		print("FAIL: no buildings")
		return 1
	var has_home := false
	for b in buildings:
		if str(b.get("action", "")) == "home":
			has_home = true
	if not has_home:
		print("FAIL: no home building")
		return 1
	var districts = CityData.list_districts()
	if not districts.has("living_district"):
		print("FAIL: list_districts missing living_district")
		return 1
	print("OK: city data (%d districts, %d buildings)" % [districts.size(), buildings.size()])
	return 0


func _verify_scene() -> int:
	var scene = load("res://src/city/city_scene.gd").new()
	scene._build()
	var buttons := 0
	for c in scene.get_children():
		if c is Button:
			buttons += 1
	if buttons < 2:
		print("FAIL: city scene missing buttons (got %d)" % buttons)
		return 1
	print("OK: city scene built (%d buttons)" % buttons)
	return 0
