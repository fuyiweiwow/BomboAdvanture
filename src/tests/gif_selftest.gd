# res://tests/gif_selftest.gd
# Silent self-test: simulate a random-map run headlessly (no window, no GPU),
# composite each frame as a pixel board via CPU (Image.fill_rect), save PNG frames,
# and write a JSON report. Run:
#   godot --headless --path . res://tests/gif_selftest.tscn -- --seed 123 --steps 140 --outdir <abs>
extends Node

const MAP_GENERATOR = preload("res://src/game/level/map_generator.gd")

const COLOR_FLOOR := Color(0.43, 0.47, 0.36)
const COLOR_WALL := Color(0.16, 0.17, 0.20)
const COLOR_BREAKABLE := Color(0.70, 0.58, 0.36)
const COLOR_ITEM := Color(0.93, 0.85, 0.30)
const COLOR_BOMB := Color(0.10, 0.10, 0.10)
const COLOR_FLAME := Color(0.98, 0.55, 0.12)
const COLOR_NPC := Color(0.22, 0.50, 0.90)
const COLOR_HERO := Color(0.90, 0.22, 0.22)

var _outdir: String = ""
var _cell: int = 12

func _ready() -> void:
	var p = _parse_args()
	_run(p)
	get_tree().quit(0)


func _parse_args() -> Dictionary:
	var args := OS.get_cmdline_user_args()
	var p := {
		"seed": 0,
		"steps": 140,
		"cell": 12,
		"outdir": "",
	}
	var i := 0
	while i < args.size():
		var a = args[i]
		var val = ""
		if i + 1 < args.size() and not str(args[i + 1]).begins_with("--"):
			val = args[i + 1]
			i += 1
		match a:
			"--seed": p["seed"] = int(val)
			"--steps": p["steps"] = int(val)
			"--cell": p["cell"] = int(val)
			"--outdir": p["outdir"] = val
		i += 1
	return p


func _run(p: Dictionary) -> void:
	_cell = clampi(int(p["cell"]), 4, 40)
	var steps := clampi(int(p["steps"]), 10, 1000)
	var seed_val := int(p["seed"])

	var hero_name := _pick_hero()
	var monster_pool := _pick_monsters()

	var gen_params := {
		"width": 21, "height": 15,
		"seed": seed_val,
		"breakable_density": 0.30,
		"floor_texture_pool": ["elem220"],
		"obstacle_pool": ["elem212"],
		"interactive_pool": ["elem225", "elem226", "elem227"],
		"monster_pool": monster_pool,
		"begin": [1, 1],
	}
	var map_json = MAP_GENERATOR.generate(gen_params)

	var hero = Hero.new(hero_name, Vector2i(1, 1), C.CHARACTER_RED)
	hero.bomb = 99
	hero.remain_bombs = 99
	hero.defense = 100000
	hero.base_defense = 100000
	Game.me = hero
	var level = Level.new("Selftest", "selftest_generated", hero, 500, map_json)
	Game.current_level = level
	level.load_district_and_enemies()

	var outdir := str(p["outdir"])
	if outdir == "":
		outdir = ProjectSettings.globalize_path("user://selftest_output")
	_outdir = outdir.trim_suffix("/").trim_suffix("\\")
	var frames_dir := _outdir + "/frames"
	_make_dir(frames_dir)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val if seed_val != 0 else 12345
	var dirs := ["R", "U", "L", "D"]
	var cur_dir := "R"
	var last_pos := Vector2i(-1, -1)
	var stall := 0
	var snapshots: Array = []

	var breakables: Array = []
	for key in level.obstacle_instances:
		if bool(level.obstacle_instances[key].obstacle.get("BREAKABLE", false)):
			breakables.append(Vector2i(int(key.x), int(key.y)))

	for t in range(steps):
		if stall > 8:
			cur_dir = dirs[rng.randi_range(0, 3)]
			stall = 0
		hero.set_motion(cur_dir)
		if t % 25 == 10:
			hero.set_bomb()
		if breakables.size() > 0 and t % 40 == 20:
			_place_demo_bomb(level, hero, breakables[rng.randi_range(0, breakables.size() - 1)])

		_reset_obstacle_flags(level)
		level.update()

		var pos := Vector2i(hero.x, hero.y)
		if pos == last_pos:
			stall += 1
		else:
			stall = 0
			last_pos = pos

		var img := _render_frame(level)
		img.save_png("%s/frame_%04d.png" % [frames_dir, t])

		snapshots.append({
			"t": t,
			"hero": [hero.x, hero.y],
			"npcs": _npc_snapshot(level),
			"bombs": level.bomb_instances.size(),
			"flames": level.flame_instances.size(),
			"items": level.item_instances.size(),
			"breakables": _count_breakables(level),
		})
		if t % 20 == 0:
			print("PROG t=%d breakables=%d obs=%d npcs=%d" % [t, _count_breakables(level), level.obstacle_instances.size(), level.npcs.size()])
		OS.delay_msec(40)

	var summary := {
		"seed": seed_val,
		"width": level.map_x,
		"height": level.map_y,
		"steps": steps,
		"hero": hero_name,
		"monsters_requested": monster_pool,
		"monsters_spawned": level.npcs.size(),
		"hero_final": [hero.x, hero.y],
		"hero_hp": [hero.remain_blood, hero.blood],
	}
	_write_json(_outdir + "/report.json", {"summary": summary, "frames": snapshots})
	print("SELFTEST DONE seed=%d steps=%d monsters=%d frames=%d outdir=%s" % [seed_val, steps, level.npcs.size(), steps, _outdir])


func _pick_hero() -> String:
	var cfg = Game.cfg_json
	var name = str(cfg.get("your_hero", "Maria"))
	if FileAccess.file_exists(G.GAME_ROOT + "hero/" + name + ".json"):
		return name
	return "Maria"


func _reset_obstacle_flags(level) -> void:
	for key in level.obstacle_instances:
		var oi = level.obstacle_instances[key]
		oi.has_updated = false
		oi.has_drawn = false


func _place_demo_bomb(level, hero, cell: Vector2i) -> void:
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var p := cell + d
		if p.x < 0 or p.y < 0 or p.x >= level.map_x or p.y >= level.map_y:
			continue
		if level.obstacle_instances.has(p):
			continue
		if level.get_bomb_instance(p.x, p.y).size() > 0:
			continue
		BombInstance.new(p.x, p.y, level.bomb_instances, hero.bomb_skin, hero.power, hero.damage, hero)
		print("DEMO bomb at (%d,%d) targeting breakable (%d,%d) power=%d" % [p.x, p.y, cell.x, cell.y, hero.power])
		return


func _pick_monsters() -> Array:
	# choose monsters with empty skill lists to keep the short sim stable
	var dir = DirAccess.open(G.GAME_ROOT + "npc/")
	var result: Array = []
	if dir == null:
		return result
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			var j = Utils.load_json(G.GAME_ROOT + "npc/" + fname)
			if j != null and (not j.has("skills") or j["skills"].is_empty()):
				result.append({"name": fname.trim_suffix(".json"), "max": 3})
				if result.size() >= 3:
					break
		fname = dir.get_next()
	dir.list_dir_end()
	return result


func _render_frame(level) -> Image:
	var w = level.map_x
	var h = level.map_y
	var img := Image.create(w * _cell, h * _cell, false, Image.FORMAT_RGBA8)
	img.fill(COLOR_FLOOR)

	for key in level.obstacle_instances:
		var oi = level.obstacle_instances[key]
		var c = COLOR_BREAKABLE if bool(oi.obstacle.get("BREAKABLE", false)) else COLOR_WALL
		_fill(img, int(key.x), int(key.y), c)

	for key in level.item_instances:
		_fill(img, int(key.x), int(key.y), COLOR_ITEM)
	for b in level.bomb_instances:
		_fill(img, int(b.x), int(b.y), COLOR_BOMB)
	for f in level.flame_instances:
		_fill(img, int(f.x), int(f.y), COLOR_FLAME)
	for n in level.npcs:
		_fill(img, int(n.x), int(n.y), COLOR_NPC)
	if level.me != null:
		_fill(img, int(level.me.x), int(level.me.y), COLOR_HERO)
	return img


func _fill(img: Image, x: int, y: int, c: Color) -> void:
	img.fill_rect(Rect2i(x * _cell, y * _cell, _cell, _cell), c)


func _count_breakables(level) -> int:
	var n := 0
	for key in level.obstacle_instances:
		var oi = level.obstacle_instances[key]
		if bool(oi.obstacle.get("BREAKABLE", false)):
			n += 1
	return n


func _npc_snapshot(level) -> Array:
	var out: Array = []
	for n in level.npcs:
		out.append([int(n.x), int(n.y), int(n.remain_blood)])
	return out


func _write_json(path: String, data: Dictionary) -> void:
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("cannot write " + path)
		return
	f.store_string(JSON.new().stringify(data, "  "))
	f.close()


func _make_dir(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path)
