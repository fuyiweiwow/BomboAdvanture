# res://src/tests/city_selftest.gd
# Headless verification of the city (district) system: data loading, the
# incremental district/building model, scene construction, and shop buy logic.
extends Node

const CityData = preload("res://src/city/city_data.gd")
const ItemData = preload("res://src/item_editor/item_data.gd")
const Hero = preload("res://src/game/sprite/hero.gd")


func _ready() -> void:
	var failures := 0
	failures += _verify_data()
	failures += _verify_districts()
	failures += _verify_shop()
	failures += _verify_scene()
	print("FAILURES=", failures)
	get_tree().quit(failures)


func _verify_data() -> int:
	var d = CityData.load_district("living_district")
	if d.is_empty():
		print("FAIL: living_district not loaded")
		return 1
	var districts = CityData.list_districts()
	if not districts.has("living_district"):
		print("FAIL: list_districts missing living_district")
		return 1
	print("OK: city data (%d districts)" % districts.size())
	return 0


func _verify_districts() -> int:
	var districts = CityData.list_districts()
	for id in ["living_district", "market_district", "royal_district"]:
		if not districts.has(id):
			print("FAIL: missing district ", id)
			return 1
	var living = CityData.load_district("living_district")
	if int(living.get("exits", []).size()) < 2:
		print("FAIL: living district should have 2 exits")
		return 1
	var market = CityData.load_district("market_district")
	var has_shop := false
	for b in market.get("buildings", []):
		if str(b.get("action", "")) == "shop":
			has_shop = true
	if not has_shop:
		print("FAIL: market district has no shop")
		return 1
	print("OK: 3 districts, exits and shop wired")
	return 0


func _verify_shop() -> int:
	var hero = Hero.new("Maria", Vector2i(0, 0), C.CHARACTER_RED)
	hero.gold = 1000
	Game.me = hero
	var item = ItemData.load_item("red_herb")
	if item.is_empty():
		print("FAIL: red_herb missing")
		return 1
	var price := int(item.get("buy_price", 0))
	hero.gold = int(hero.gold) - price
	hero._apply_item_effect(item)
	if int(hero.gold) != 1000 - price:
		print("FAIL: gold not deducted")
		return 1
	if int(hero.items.get("red_herb", 0)) != 1:
		print("FAIL: red_herb not added to items")
		return 1
	print("OK: shop buy (gold -%d, red_herb +1)" % price)
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
