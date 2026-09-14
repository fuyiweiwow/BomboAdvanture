# res://src/tests/recipe_map.gd
# Read a themed map "recipe" (src/tests/recipes/*.json) and generate random maps.
# The recipe fixes the terrain elements (floor/wall/breakable/monsters); the seed
# is auto-randomized so each run produces a new map of the same theme.
#
#   godot --headless --path . res://src/tests/recipe_map.tscn -- --list
#   godot --headless --path . res://src/tests/recipe_map.tscn -- \
#       --recipe forest --count 3 --outdir C:/tmp/maps
extends Node

const MAP_GENERATOR = preload("res://src/game/level/map_generator.gd")
const RECIPE_ROOT = "res://src/tests/recipes/"

const COLOR_WALL := Color(0.15, 0.15, 0.18)
const COLOR_BREAKABLE := Color(0.85, 0.70, 0.40)
const COLOR_NPC := Color(0.22, 0.50, 0.90)
const COLOR_HERO := Color(0.90, 0.22, 0.22)

var _outdir := ""
var _cell := 12


func _ready() -> void:
	var p := _parse_args()
	_cell = clampi(int(p.get("cell", 12)), 4, 40)
	if p.has("list"):
		_list_recipes()
	elif p.has("recipe"):
		_run_recipe(str(p["recipe"]), int(p.get("count", 1)), int(p.get("seed", 0)), str(p.get("outdir", "")))
	else:
		print("usage: --recipe <name> [--count N] [--seed N] [--cell N] [--outdir PATH]  (or --list)")
	get_tree().quit(0)


func _parse_args() -> Dictionary:
	var args := OS.get_cmdline_user_args()
	var p := {"count": 1, "seed": 0, "cell": 12}
	var i := 0
	while i < args.size():
		var a = args[i]
		var val := ""
		if i + 1 < args.size() and not str(args[i + 1]).begins_with("--"):
			val = args[i + 1]
			i += 1
		match a:
			"--recipe": p["recipe"] = val
			"--count": p["count"] = int(val)
			"--seed": p["seed"] = int(val)
			"--cell": p["cell"] = int(val)
			"--outdir": p["outdir"] = val
			"--list": p["list"] = true
		i += 1
	return p


func _list_recipes() -> void:
	var dir = DirAccess.open(RECIPE_ROOT)
	if dir == null:
		print("no recipes in " + RECIPE_ROOT)
		return
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			var j = Utils.load_json(RECIPE_ROOT + fname)
			if j != null:
				print("%-10s %s" % [fname.trim_suffix(".json"), str(j.get("name", ""))])
				if j.has("note"):
					print("           %s" % str(j["note"]))
		fname = dir.get_next()
	dir.list_dir_end()


func _run_recipe(recipe_name: String, count: int, seed: int, outdir: String) -> void:
	var recipe = Utils.load_json(RECIPE_ROOT + recipe_name + ".json")
	if recipe == null:
		push_error("recipe not found: " + recipe_name)
		return

	_outdir = outdir
	if _outdir == "":
		_outdir = ProjectSettings.globalize_path("user://recipe_maps")
	_outdir = _outdir.trim_suffix("/").trim_suffix("\\")
	DirAccess.make_dir_recursive_absolute(_outdir)

	print("=== recipe: %s (%s) ===" % [recipe_name, str(recipe.get("name", ""))])
	print("    %s" % str(recipe.get("note", "")))

	count = maxi(1, count)
	for i in range(count):
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var seed_val := seed
		if seed_val == 0:
			seed_val = rng.randi_range(1, 999999999)

		var map_json = MAP_GENERATOR.generate(_params_from_recipe(recipe, seed_val))
		var json_path := "%s/%s_%d.json" % [_outdir, recipe_name, seed_val]
		_write_json(json_path, map_json)

		var hero = Hero.new(_pick_hero(), Vector2i(1, 1), C.CHARACTER_RED)
		Game.me = hero
		var level = Level.new("Recipe", recipe_name, hero, 500, map_json)
		Game.current_level = level
		level.load_district_and_enemies()

		var png_path := "%s/%s_%d.png" % [_outdir, recipe_name, seed_val]
		_render_preview(level).save_png(png_path)

		var s := _stats(map_json)
		print("  #%d seed=%d %dx%d  walls=%d breakables=%d monsters=%d" % [i + 1, seed_val, level.map_x, level.map_y, s["walls"], s["breakables"], s["monsters"]])
		print("        json=%s" % json_path)
		print("        png =%s" % png_path)


func _params_from_recipe(recipe: Dictionary, seed_val: int) -> Dictionary:
	var breakable = recipe.get("breakable", ["elem225", "elem226", "elem227"])
	if breakable == null or (breakable is Array and breakable.is_empty()):
		breakable = ["elem225", "elem226", "elem227"]
	return {
		"width": int(recipe.get("width", 21)),
		"height": int(recipe.get("height", 15)),
		"seed": seed_val,
		"breakable_density": float(recipe.get("density", 0.25)),
		"floor_type": str(recipe.get("floor_type", "exploration")),
		"obstacle_type": str(recipe.get("obstacle_type", "exploration")),
		"floor_texture_pool": [str(recipe.get("floor", "elem220"))],
		"obstacle_pool": [str(recipe.get("wall", "elem212"))],
		"interactive_pool": breakable,
		"monster_pool": recipe.get("monsters", []),
		"begin": [1, 1],
	}


func _render_preview(level) -> Image:
	var w = level.map_x
	var h = level.map_y
	var img: Image = level.floor_image.duplicate() as Image
	img.resize(w * _cell, h * _cell, Image.INTERPOLATE_NEAREST)

	var seen := {}
	for key in level.obstacle_instances:
		var oi = level.obstacle_instances[key]
		if seen.has(oi):
			continue
		seen[oi] = true
		var placed := false
		var frames: Array = oi.obstacle.get("STAND", [])
		if frames.size() > 0 and frames[0].texture != null:
			var tex_img: Image = frames[0].texture.get_image()
			if tex_img != null:
				var scaled: Image = tex_img.duplicate() as Image
				scaled.resize(_cell, _cell, Image.INTERPOLATE_NEAREST)
				img.blit_rect(scaled, Rect2i(0, 0, _cell, _cell), Vector2i(oi.x * _cell, oi.y * _cell))
				placed = true
		if not placed:
			var c = COLOR_BREAKABLE if bool(oi.obstacle.get("BREAKABLE", false)) else COLOR_WALL
			img.fill_rect(Rect2i(oi.x * _cell, oi.y * _cell, _cell, _cell), c)

	for n in level.npcs:
		img.fill_rect(Rect2i(n.x * _cell, n.y * _cell, _cell, _cell), COLOR_NPC)
	if level.me != null:
		img.fill_rect(Rect2i(level.me.x * _cell, level.me.y * _cell, _cell, _cell), COLOR_HERO)
	return img


func _stats(map_json: Dictionary) -> Dictionary:
	var walls := 0
	var breakables := 0
	for entry in map_json.get("obstacle", []):
		var nm := str(entry.get("name", ""))
		var is_break := nm != str(_current_wall_name(map_json))
		for _pt in entry.get("points", []):
			if is_break:
				breakables += 1
			else:
				walls += 1
	var monsters := 0
	for d in map_json.get("districts", []):
		monsters += int(d.get("npcs", []).size())
	return {"walls": walls, "breakables": breakables, "monsters": monsters}


func _current_wall_name(map_json: Dictionary) -> String:
	for entry in map_json.get("obstacle", []):
		return str(entry.get("name", ""))
	return ""


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
