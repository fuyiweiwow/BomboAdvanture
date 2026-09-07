# res://src/tests/gen_map.gd
# Command-line random-map generator for testing map generation.
# Build a map by selecting elements via CLI args, output JSON + optional preview PNG.
#
#   godot --headless --path . res://src/tests/gen_map.tscn -- --list
#   godot --headless --path . res://src/tests/gen_map.tscn -- \
#       --width 25 --height 15 --seed 42 --density 0.3 \
#       --floor elem220 --wall elem212 --breakable elem225,elem226,elem227 \
#       --monsters FireBall0:3,NuFengMons1:5 \
#       --outdir C:/tmp/maps --preview
extends Node

const MAP_GENERATOR = preload("res://src/game/level/map_generator.gd")

const COLOR_FLOOR := Color(0.43, 0.47, 0.36)
const COLOR_WALL := Color(0.16, 0.17, 0.20)
const COLOR_BREAKABLE := Color(0.70, 0.58, 0.36)
const COLOR_BEGIN := Color(0.90, 0.22, 0.22)
const COLOR_NPC := Color(0.22, 0.50, 0.90)

var _cell := 12
var _outdir := ""


func _ready() -> void:
	var p := _parse_args()
	if p.has("list"):
		_list()
	else:
		_generate(p)
	get_tree().quit(0)


func _parse_args() -> Dictionary:
	var args := OS.get_cmdline_user_args()
	var p := {"width": 21, "height": 15, "seed": 0, "density": 0.25}
	var i := 0
	while i < args.size():
		var a = args[i]
		var val := ""
		if i + 1 < args.size() and not str(args[i + 1]).begins_with("--"):
			val = args[i + 1]
			i += 1
		match a:
			"--width": p["width"] = int(val)
			"--height": p["height"] = int(val)
			"--seed": p["seed"] = int(val)
			"--density": p["density"] = float(val)
			"--floor": p["floor"] = val
			"--wall": p["wall"] = val
			"--breakable": p["breakable"] = val
			"--monsters": p["monsters"] = val
			"--outdir": p["outdir"] = val
			"--preview": p["preview"] = true
			"--list": p["list"] = true
		i += 1
	return p


func _generate(p: Dictionary) -> void:
	var width := clampi(int(p.get("width", 21)), 5, 100)
	var height := clampi(int(p.get("height", 15)), 5, 100)
	var density := clampf(float(p.get("density", 0.25)), 0.0, 0.9)

	var seed_val := int(p.get("seed", 0))
	if seed_val == 0:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		seed_val = rng.randi_range(1, 999999999)

	var floor_name := str(p.get("floor", "elem220"))
	var wall_name := str(p.get("wall", "elem212"))
	var breakables := _parse_list(str(p.get("breakable", "")), "mix")
	if breakables.is_empty() or breakables[0] == "mix":
		breakables = ["elem225", "elem226", "elem227"]
	var monster_pool := _parse_monsters(str(p.get("monsters", "")))

	var params := {
		"width": width, "height": height,
		"seed": seed_val,
		"breakable_density": density,
		"floor_texture_pool": [floor_name],
		"obstacle_pool": [wall_name],
		"interactive_pool": breakables,
		"monster_pool": monster_pool,
		"begin": [1, 1],
	}
	var map_json = MAP_GENERATOR.generate(params)

	_outdir = str(p.get("outdir", ""))
	if _outdir == "":
		_outdir = ProjectSettings.globalize_path("user://gen_map_output")
	_outdir = _outdir.trim_suffix("/").trim_suffix("\\")
	DirAccess.make_dir_recursive_absolute(_outdir)

	var json_path := "%s/map_%d.json" % [_outdir, seed_val]
	_write_json(json_path, map_json)

	var stats := _stats(map_json)
	print("GENERATED seed=%d size=%dx%d floor=%s wall=%s breakables=%s" % [seed_val, width, height, floor_name, wall_name, ",".join(breakables)])
	print("  walls=%d breakables=%d monsters=%d begin=(%d,%d)" % [stats["walls"], stats["breakables"], stats["monsters"], 1, 1])
	print("  json=%s" % json_path)

	if p.has("preview"):
		var png_path := _render_preview(map_json, seed_val)
		if png_path != "":
			print("  preview=%s" % png_path)


func _render_preview(map_json: Dictionary, seed_val: int) -> String:
	var hero = Hero.new(_pick_hero(), Vector2i(1, 1), C.CHARACTER_RED)
	Game.me = hero
	var level = Level.new("GenTest", "gen_preview", hero, 500, map_json)
	Game.current_level = level
	level.load_district_and_enemies()

	var img := Image.create(level.map_x * _cell, level.map_y * _cell, false, Image.FORMAT_RGBA8)
	img.fill(COLOR_FLOOR)
	for key in level.obstacle_instances:
		var oi = level.obstacle_instances[key]
		var c = COLOR_BREAKABLE if bool(oi.obstacle.get("BREAKABLE", false)) else COLOR_WALL
		img.fill_rect(Rect2i(int(key.x) * _cell, int(key.y) * _cell, _cell, _cell), c)
	for n in level.npcs:
		img.fill_rect(Rect2i(int(n.x) * _cell, int(n.y) * _cell, _cell, _cell), COLOR_NPC)
	img.fill_rect(Rect2i(int(level.me.x) * _cell, int(level.me.y) * _cell, _cell, _cell), COLOR_BEGIN)

	var png_path := "%s/map_%d.png" % [_outdir, seed_val]
	img.save_png(png_path)
	return png_path


func _stats(map_json: Dictionary) -> Dictionary:
	var walls := 0
	var breakables := 0
	for entry in map_json.get("obstacle", []):
		var is_breakable := str(entry.get("name", "")) != str(map_json.get("basic", {}).get("_wall", "elem212"))
		for _pt in entry.get("points", []):
			if is_breakable:
				breakables += 1
			else:
				walls += 1
	var monsters := 0
	for d in map_json.get("districts", []):
		monsters += int(d.get("npcs", []).size())
	return {"walls": walls, "breakables": breakables, "monsters": monsters}


func _list() -> void:
	print("=== FLOORS (img/mapElem/exploration, plain tiles) ===")
	for f in _discover_floors():
		print("  ", f)
	print("=== WALLS (frame/obstacle/exploration, non-breakable) ===")
	print("  ", ", ".join(_discover_obstacles()["walls"]))
	print("=== BREAKABLES (frame/obstacle/exploration, breakable) ===")
	print("  ", ", ".join(_discover_obstacles()["breakables"]))
	print("=== MONSTERS (assets/npc/*.json filenames) ===")
	var mons := _discover_monsters()
	for i in range(0, mons.size(), 6):
		print("  ", ", ".join(mons.slice(i, mini(i + 6, mons.size()))))


func _discover_floors() -> Array:
	var result: Array = []
	var dir = DirAccess.open(G.RES_IMG_ROOT + "mapElem/exploration/")
	if dir == null:
		return ["elem220"]
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with(".png") and not fname.ends_with(".import"):
			var base = fname.trim_suffix(".png")
			if not base.contains("_stand") and not base.contains("_die") and not base.contains("_trigger") and not result.has(base):
				result.append(base)
		fname = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result


func _discover_obstacles() -> Dictionary:
	var walls: Array = []
	var breakables: Array = []
	var dir = DirAccess.open(G.FRAME_ROOT + "obstacle/exploration/")
	if dir == null:
		return {"walls": ["elem212"], "breakables": ["elem225", "elem226", "elem227"]}
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			var name = fname.trim_suffix(".json")
			var j = Utils.load_json(G.FRAME_ROOT + "obstacle/exploration/" + fname)
			if j != null:
				if bool(j.get("BREAKABLE", false)):
					breakables.append(name)
				else:
					walls.append(name)
		fname = dir.get_next()
	dir.list_dir_end()
	walls.sort()
	breakables.sort()
	return {"walls": walls, "breakables": breakables}


func _discover_monsters() -> Array:
	var result: Array = []
	var dir = DirAccess.open(G.GAME_ROOT + "npc/")
	if dir == null:
		return result
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			result.append(fname.trim_suffix(".json"))
		fname = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result


func _parse_list(value: String, default: String) -> Array:
	var result: Array = []
	for part in value.split(","):
		var s = part.strip_edges()
		if s != "":
			result.append(s)
	if result.is_empty() and default != "":
		result.append(default)
	return result


func _parse_monsters(value: String) -> Array:
	var result: Array = []
	if value == "":
		return result
	for part in value.split(","):
		var p2 = part.split(":")
		var nm = p2[0].strip_edges()
		var mx := 3
		if p2.size() > 1:
			mx = int(p2[1].strip_edges())
		if nm != "":
			result.append({"name": nm, "max": maxi(0, mx)})
	return result


func _pick_hero() -> String:
	var cfg = Game.cfg_json
	var name = str(cfg.get("your_hero", "Maria"))
	if FileAccess.file_exists(G.GAME_ROOT + "hero/" + name + ".json"):
		return name
	return "Maria"


func _write_json(path: String, data: Dictionary) -> void:
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("cannot write " + path)
		return
	f.store_string(JSON.new().stringify(data, "\t"))
	f.close()
