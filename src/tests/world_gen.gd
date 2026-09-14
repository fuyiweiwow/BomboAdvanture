# res://src/tests/world_gen.gd
# Generate ONE continuous world map from a tree of themed zones and render
# a big stitched preview so the seamless zone layout + doorways can be reviewed.
#
#   godot --headless --path . res://src/tests/world_gen.tscn -- \
#       --count 5 --seed 123 --recipe forest --outdir C:/tmp/world
extends Node

const WorldMapGenerator = preload("res://src/game/level/world_map_generator.gd")

const COLOR_FLOOR := Color(0.43, 0.47, 0.36)
const COLOR_WALL := Color(0.15, 0.15, 0.18)
const COLOR_BREAKABLE := Color(0.85, 0.70, 0.40)
const COLOR_NPC := Color(0.22, 0.50, 0.90)
const COLOR_HERO := Color(0.90, 0.22, 0.22)
const COLOR_DOOR := Color(1.0, 0.35, 0.95)

var _cell := 12
var _outdir := ""
var _recipe: Dictionary = {}


func _ready() -> void:
	var p := _parse_args()
	_cell = clampi(int(p.get("cell", 12)), 4, 40)
	_outdir = str(p.get("outdir", ""))
	if _outdir == "":
		_outdir = ProjectSettings.globalize_path("user://world_output")
	_outdir = _outdir.trim_suffix("/").trim_suffix("\\")
	DirAccess.make_dir_recursive_absolute(_outdir)

	if p.has("recipe"):
		_recipe = Utils.load_json("res://src/tests/recipes/" + str(p["recipe"]) + ".json")
		if _recipe == null:
			_recipe = {}
			print("WARN recipe not found, using defaults")

	var world = WorldMapGenerator.generate(_params(p))
	_write_json("%s/world.json" % _outdir, world)

	print("WORLD size=%dx%d zones=%d" % [world["basic"]["width"], world["basic"]["height"], world["zones"].size()])
	for z in world["zones"]:
		print("  %s parent=%s children=%s at(%d,%d) %dx%d center=(%d,%d) theme=%s" % [
			z["id"], z["parent"], ",".join(z["children"]), z["ox"], z["oy"], z["w"], z["h"],
			z["cx"], z["cy"], z["theme_name"],
		])

	var img := _render_world(world)
	img.save_png("%s/world_full.png" % _outdir)
	print("FULL %s/world_full.png" % _outdir)
	get_tree().quit(0)


func _params(p: Dictionary) -> Dictionary:
	var recipe: Dictionary = _recipe
	if recipe.is_empty():
		recipe = {"name": "default", "floor": "elem220", "wall": "elem212", "breakable": ["elem225", "elem226", "elem227"], "monsters": []}
	return {
		"count": int(p.get("count", 5)),
		"zone_width": int(recipe.get("width", 21)),
		"zone_height": int(recipe.get("height", 15)),
		"seed": int(p.get("seed", 0)),
		"recipe": recipe,
	}


func _parse_args() -> Dictionary:
	var args := OS.get_cmdline_user_args()
	var p := {"count": 5, "seed": 0, "cell": 12}
	var i := 0
	while i < args.size():
		var a = args[i]
		var val := ""
		if i + 1 < args.size() and not str(args[i + 1]).begins_with("--"):
			val = args[i + 1]
			i += 1
		match a:
			"--count": p["count"] = int(val)
			"--seed": p["seed"] = int(val)
			"--cell": p["cell"] = int(val)
			"--outdir": p["outdir"] = val
			"--recipe": p["recipe"] = val
		i += 1
	return p


func _render_world(world: Dictionary) -> Image:
	var w: int = int(world["basic"]["width"])
	var h: int = int(world["basic"]["height"])
	var img := Image.create(w * _cell, h * _cell, false, Image.FORMAT_RGBA8)
	img.fill(COLOR_FLOOR)

	# per-zone floor points (themed)
	for f in world.get("floor", []):
		var fc := _floor_color(str(f.get("name", "")))
		for p in f.get("points", []):
			img.fill_rect(Rect2i(int(p["x"]) * _cell, int(p["y"]) * _cell, _cell, _cell), fc)

	# obstacles
	for o in world.get("obstacle", []):
		var nm := str(o.get("name", ""))
		var c := COLOR_BREAKABLE if _is_breakable(nm) else COLOR_WALL
		for p in o.get("points", []):
			img.fill_rect(Rect2i(int(p["x"]) * _cell, int(p["y"]) * _cell, _cell, _cell), c)

	# monsters
	for d in world.get("districts", []):
		for n in d.get("npcs", []):
			img.fill_rect(Rect2i(int(n["x"]) * _cell, int(n["y"]) * _cell, _cell, _cell), COLOR_NPC)

	# begin
	var b = world["basic"].get("begin", [1, 1])
	img.fill_rect(Rect2i(int(b[0]) * _cell, int(b[1]) * _cell, _cell, _cell), COLOR_HERO)

	# zone outline (thin) for review; centers marked
	for z in world["zones"]:
		var ox = int(z["ox"]) * _cell
		var oy = int(z["oy"]) * _cell
		var zw = int(z["w"]) * _cell
		var zh = int(z["h"]) * _cell
		img.fill_rect(Rect2i(ox, oy, zw, 1), Color(0.2, 0.2, 0.25))
		img.fill_rect(Rect2i(ox, oy + zh - 1, zw, 1), Color(0.2, 0.2, 0.25))
		img.fill_rect(Rect2i(ox, oy, 1, zh), Color(0.2, 0.2, 0.25))
		img.fill_rect(Rect2i(ox + zw - 1, oy, 1, zh), Color(0.2, 0.2, 0.25))
		# center marker
		img.fill_rect(Rect2i(int(z["cx"]) * _cell, int(z["cy"]) * _cell, _cell, _cell), Color(0.9, 0.5, 0.2))
	return img


func _is_breakable(name: String) -> bool:
	var recipe: Dictionary = _recipe
	if not recipe.is_empty():
		var brk = recipe.get("breakable", [])
		if brk is Array and brk.has(name):
			return true
	var known := ["elem225", "elem226", "elem227", "elem2", "elem3", "elem4", "elem6"]
	return known.has(name)


func _floor_color(name: String) -> Color:
	match name:
		"elem1": return Color(0.07, 0.42, 0.13)
		"elem17", "elem18", "elem19", "elem20", "elem21", "elem22": return Color(0.58, 0.45, 0.13)
		"elem29", "elem39": return Color(0.35, 0.60, 0.64)
		_: return COLOR_FLOOR


func _write_json(path: String, data: Dictionary) -> void:
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("cannot write " + path)
		return
	f.store_string(JSON.new().stringify(data, "\t"))
	f.close()
