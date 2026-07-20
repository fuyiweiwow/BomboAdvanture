class_name HeroData
extends RefCounted

const HERO_DIR = "res://assets/hero/"
const CUSTOM_DIR = "res://assets/hero_custom/"
const CUSTOM_TEX_DIR = "res://assets/custom_textures/"
const CUSTOM_TEX_COMPONENTS = ["body", "foot", "leg", "cloth", "face", "hair", "eye", "ear", "mouth", "cap", "npack", "cladorn", "fpack", "thadorn", "fhadorn"]

static func list_heroes() -> Array:
	var all: Dictionary = {}
	var dir = DirAccess.open(HERO_DIR)
	if dir:
		dir.list_dir_begin()
		var fname = dir.get_next()
		while fname != "":
			if fname.ends_with(".json"):
				var name = fname.trim_suffix(".json")
				all[name] = HERO_DIR + fname
			fname = dir.get_next()
		dir.list_dir_end()

	dir = DirAccess.open(CUSTOM_DIR)
	if dir:
		dir.list_dir_begin()
		var fname = dir.get_next()
		while fname != "":
			if fname.ends_with(".json"):
				var name = fname.trim_suffix(".json")
				all[name] = CUSTOM_DIR + fname
			fname = dir.get_next()
		dir.list_dir_end()

	var result: Array = []
	for name in all.keys():
		var path = all[name]
		var j = Utils.load_json(path)
		if j != null and j.has("name"):
			j["_src"] = "custom" if path.begins_with(CUSTOM_DIR) else "origin"
			j["_path"] = path
			result.append(j)
	result.sort_custom(func(a, b): return a["name"] < b["name"])
	return result

static func load_hero(hero_name: String) -> Dictionary:
	var custom_path = CUSTOM_DIR + hero_name + ".json"
	if FileAccess.file_exists(custom_path):
		var j = Utils.load_json(custom_path)
		if j != null:
			j["_src"] = "custom"
			j["_path"] = custom_path
			return j
	var origin_path = HERO_DIR + hero_name + ".json"
	var j = Utils.load_json(origin_path)
	if j != null:
		j["_src"] = "origin"
		j["_path"] = origin_path
	return j

static func hero_exists(hero_name: String) -> bool:
	return FileAccess.file_exists(HERO_DIR + hero_name + ".json") or FileAccess.file_exists(CUSTOM_DIR + hero_name + ".json")

static func is_custom(hero_name: String) -> bool:
	return FileAccess.file_exists(CUSTOM_DIR + hero_name + ".json")

static func save_hero(data: Dictionary) -> bool:
	if not data.has("name"):
		return false
	var hero_name = str(data["name"])
	var dir = DirAccess.open("res://assets")
	if dir == null:
		return false
	if not DirAccess.dir_exists_absolute(CUSTOM_DIR):
		dir.make_dir("hero_custom")

	var path = CUSTOM_DIR + hero_name + ".json"
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	var clean = data.duplicate()
	clean.erase("_src")
	clean.erase("_path")
	f.store_string(JSON.new().stringify(clean, "\t"))
	f.close()
	return true

static func restore_defaults(hero_name: String) -> bool:
	var path = CUSTOM_DIR + hero_name + ".json"
	if not FileAccess.file_exists(path):
		return false
	var dir = DirAccess.open(CUSTOM_DIR)
	if dir == null:
		return false
	dir.remove(hero_name + ".json")
	return true

static func list_decorations(category: String) -> Array:
	var dir_path = G.FRAME_ROOT + category + "/"
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return []
	var result: Array = []
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			result.append(fname.trim_suffix(".json"))
		fname = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result

static func list_bomb_skins() -> Array:
	var dir = DirAccess.open(G.FRAME_ROOT + "bomb/")
	if dir == null:
		return []
	var result: Array = []
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			result.append(fname.trim_suffix(".json"))
		fname = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result

static func get_custom_tex_dir(hero_name: String) -> String:
	return CUSTOM_TEX_DIR + hero_name + "/"

static func ensure_custom_tex_dir(hero_name: String) -> bool:
	var dir = DirAccess.open(CUSTOM_TEX_DIR)
	if dir == null:
		dir = DirAccess.open("res://assets/")
		if dir == null:
			return false
		dir.make_dir("custom_textures")
	var sub = get_custom_tex_dir(hero_name)
	if not DirAccess.dir_exists_absolute(sub):
		dir = DirAccess.open(CUSTOM_TEX_DIR)
		if dir == null:
			return false
		dir.make_dir(hero_name)
	return DirAccess.dir_exists_absolute(sub)

static func import_texture(hero_name: String, component: String, source_path: String) -> Dictionary:
	if not component in CUSTOM_TEX_COMPONENTS:
		return {"ok": false, "error": "Unknown component: " + component}
	if not ResourceLoader.exists(source_path):
		return {"ok": false, "error": "Source file not found: " + source_path}
	if not ensure_custom_tex_dir(hero_name):
		return {"ok": false, "error": "Cannot create texture directory"}
	var ext = source_path.get_extension()
	var dest = get_custom_tex_dir(hero_name) + component + "." + ext
	var src = FileAccess.open(source_path, FileAccess.READ)
	if src == null:
		return {"ok": false, "error": "Cannot read source file"}
	var data = src.get_buffer(src.get_length())
	src.close()
	var dst = FileAccess.open(dest, FileAccess.WRITE)
	if dst == null:
		return {"ok": false, "error": "Cannot write destination"}
	dst.store_buffer(data)
	dst.close()
	return {"ok": true, "path": dest}

static func delete_texture(hero_name: String, component: String) -> bool:
	if not component in CUSTOM_TEX_COMPONENTS:
		return false
	var dir = DirAccess.open(get_custom_tex_dir(hero_name))
	if dir == null:
		return false
	var files = dir.get_files()
	for f in files:
		var base = f.get_basename()
		if base == component:
			dir.remove(f)
			return true
	return false

static func get_texture_path(hero_name: String, component: String) -> String:
	var dir = DirAccess.open(get_custom_tex_dir(hero_name))
	if dir == null:
		return ""
	var files = dir.get_files()
	for f in files:
		var base = f.get_basename()
		if base == component:
			return get_custom_tex_dir(hero_name) + f
	return ""

static func has_custom_texture(hero_name: String, component: String) -> bool:
	var p = get_texture_path(hero_name, component)
	return p != "" and ResourceLoader.exists(p)

static func build_custom_textures_dict(hero_name: String, offsets: Dictionary) -> Dictionary:
	var result = {}
	for comp in CUSTOM_TEX_COMPONENTS:
		var p = get_texture_path(hero_name, comp)
		if p != "" and ResourceLoader.exists(p):
			result[comp] = {
				"path": p,
				"cx": offsets.get(comp, {}).get("cx", 0),
				"cy": offsets.get(comp, {}).get("cy", 0),
			}
	return result
