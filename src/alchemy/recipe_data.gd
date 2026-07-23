class_name RecipeData
extends RefCounted

const RECIPE_DIR = "res://assets/alchemy/recipe/"

static func list_recipes() -> Array:
	var dir = DirAccess.open(RECIPE_DIR)
	if dir == null:
		return []
	var result = []
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			var j = Utils.load_json(RECIPE_DIR + fname)
			if j != null and j.has("id"):
				j["_path"] = RECIPE_DIR + fname
				result.append(j)
		fname = dir.get_next()
	dir.list_dir_end()
	result.sort_custom(func(a, b): return str(a.get("id", "")) < str(b.get("id", "")))
	return result

static func load_recipe(recipe_id: String) -> Dictionary:
	var path = RECIPE_DIR + recipe_id + ".json"
	if FileAccess.file_exists(path):
		var j = Utils.load_json(path)
		if j != null:
			j["_path"] = path
			return j
	return {}

static func recipe_exists(recipe_id: String) -> bool:
	return FileAccess.file_exists(RECIPE_DIR + recipe_id + ".json")

static func save_recipe(data: Dictionary) -> bool:
	if not data.has("id") or str(data["id"]).strip_edges() == "":
		return false
	var path = RECIPE_DIR + str(data["id"]) + ".json"
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	var clean = data.duplicate()
	clean.erase("_path")
	f.store_string(JSON.new().stringify(clean, "\t"))
	f.close()
	return true

static func delete_recipe(recipe_id: String) -> bool:
	var path = RECIPE_DIR + recipe_id + ".json"
	if not FileAccess.file_exists(path):
		return false
	var dir = DirAccess.open(RECIPE_DIR)
	if dir == null:
		return false
	dir.remove(recipe_id + ".json")
	return true

static func new_template() -> Dictionary:
	var gen = preload("res://src/alchemy/recipe_generator.gd")
	var temp = gen.generate_recipe("common", ["_template"])
	return temp
