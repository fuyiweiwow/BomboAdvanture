# res://src/tests/world_selftest.gd
# Headless verification of the world-mode runtime:
#   - gates are placed on passages (clear/key = wall, hidden = breakable)
#   - clearing a zone's monsters opens its clear gates
#   - killing the key holder drops a key; touching a key gate with a key opens it
extends Node

const WorldMapGenerator = preload("res://src/game/level/world_map_generator.gd")


func _ready() -> void:
	var failures := 0
	failures += _verify_clear()
	failures += _verify_key()
	failures += _verify_game_flow()
	failures += _verify_drop()
	print("FAILURES=", failures)
	get_tree().quit(failures)


func _verify_game_flow() -> int:
	# go through the real game.gd path: _generate_procedural_map -> set_level
	var map_entry = {"generator_params": {
		"count": 5, "seed": 1, "width": 21, "height": 15,
		"floor": "elem220", "wall": "elem212",
		"monster_pool": ["SenLin11CaiQingQing"], "density": 0.25,
	}}
	var name = Game._generate_procedural_map(map_entry)
	if name != "procedural":
		print("FAIL: _generate_procedural_map did not return procedural")
		return 1
	Game.set_level("test", name, "Maria", "Red", false, Game._pending_map_data)
	var level = Game.current_level
	if level == null or not level.world_mode:
		print("FAIL: set_level did not create a world level")
		return 1
	if level.world_doors.is_empty():
		print("FAIL: world level has no doors")
		return 1
	print("OK: game flow -> procedural world with %d doors" % level.world_doors.size())
	return 0


func _verify_drop() -> int:
	var level = _make_level(99)
	if level.npcs.is_empty():
		print("FAIL: no monsters to kill")
		return 1
	var has_gold := false
	var has_material := false
	for i in range(mini(3, level.npcs.size())):
		var npc = level.npcs[i]
		npc.defense = 0
		npc.try_damage(999999)
		level.update()
		level.update()
	for key in level.item_instances:
		var item = level.item_instances[key]
		var id := str(item.item_data.get("id", ""))
		if id == "gold_coin":
			has_gold = true
		if id in ["red_herb", "blue_herb", "ice_crystal", "fire_flower", "slime_goo"]:
			has_material = true
	if not has_gold:
		print("FAIL: no gold dropped")
		return 1
	if not has_material:
		print("FAIL: no material dropped")
		return 1
	print("OK: gold + material dropped (items=%d)" % level.item_instances.size())
	return 0


func _make_level(seed: int):
	var world = WorldMapGenerator.generate({
		"count": 6, "seed": seed,
		"zone_width": 21, "zone_height": 15,
		"recipe": {"name": "森林", "floor": "elem220", "wall": "elem212", "breakable": ["elem225", "elem226", "elem227"], "monsters": [{"name": "SenLin11CaiQingQing", "max": 3}], "density": 0.25},
	})
	var hero = Hero.new("Maria", Vector2i(0, 0), C.CHARACTER_RED)
	hero.defense = 100000
	hero.base_defense = 100000
	Game.me = hero
	var level = Level.new("World", "world_test", hero, 500, world)
	Game.current_level = level
	return level


func _verify_clear() -> int:
	var level = _make_level(42)
	var fails := 0
	if not level.world_mode:
		print("FAIL: world_mode not set")
		return 1
	if level.world_doors.is_empty():
		print("FAIL: no doors placed")
		return 1
	# find a clear door
	var clear_door = null
	for d in level.world_doors:
		if d["gate"] == "clear":
			clear_door = d
			break
	if clear_door == null:
		print("INFO: no clear door in this seed; skip clear check")
		return 0
	# door obstacle must block
	var key := Vector2i(clear_door["x"], clear_door["y"])
	if not level.obstacle_instances.has(key):
		print("FAIL: clear door not placed as obstacle")
		fails += 1
	# kill all monsters in that zone
	var zone := str(clear_door["zone"])
	for n in level.npcs.duplicate():
		if str(level.npc_zone.get(n, "")) == zone:
			n.remain_blood = 0
	level.update()
	level.update()
	if not clear_door["opened"]:
		print("FAIL: clear door did not open after clearing zone")
		fails += 1
	else:
		print("OK: clear door opened after zone cleared")
	return fails


func _verify_key() -> int:
	var level = _make_level(7)
	var fails := 0
	if not level.world_mode:
		return 1
	# find a key door
	var key_door = null
	for d in level.world_doors:
		if d["gate"] == "key":
			key_door = d
			break
	if key_door == null:
		print("INFO: no key door in this seed; skip key check")
		return 0
	# find the key holder (drops_key npc)
	var holder = null
	for n in level.npcs:
		if n.drops_key:
			holder = n
			break
	if holder == null:
		print("FAIL: key door exists but no key holder")
		return 1
	# kill holder -> should drop a key item at its position
	var hx: int = holder.x
	var hy: int = holder.y
	holder.defense = 0
	holder.try_damage(999999)
	level.update()
	level.update()
	var key_item = level.item_instances.get(Vector2i(hx, hy), null)
	if key_item == null:
		print("FAIL: key holder did not drop key")
		return 1
	# hero picks up key
	key_item.player_get(level.me)
	if int(level.me.keys.get("iron_key", 0)) <= 0:
		print("FAIL: hero did not get key")
		return 1
	# move hero adjacent to key door
	level.me.set_xy(key_door["x"], key_door["y"] - 1)
	level.check_key_doors()
	if not key_door["opened"]:
		print("FAIL: key door did not open with key")
		fails += 1
	else:
		print("OK: key door opened with key")
	return fails
