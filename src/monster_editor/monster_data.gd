class_name MonsterData
extends RefCounted

const NPC_DIR = "res://assets/npc/"

static func list_monsters() -> Array:
	var dir = DirAccess.open(NPC_DIR)
	if dir == null:
		return []
	var result: Array = []
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			var j = Utils.load_json(NPC_DIR + fname)
			if j != null and j.has("name"):
				j["_path"] = NPC_DIR + fname
				result.append(j)
		fname = dir.get_next()
	dir.list_dir_end()
	result.sort_custom(func(a, b): return a["name"] < b["name"])
	return result

static func load_monster(monster_name: String) -> Dictionary:
	var path = NPC_DIR + monster_name + ".json"
	if FileAccess.file_exists(path):
		var j = Utils.load_json(path)
		if j != null:
			j["_path"] = path
			return j
	return {}

static func monster_exists(monster_name: String) -> bool:
	return FileAccess.file_exists(NPC_DIR + monster_name + ".json")

static func save_monster(data: Dictionary) -> bool:
	if not data.has("name"):
		return false
	var dir = DirAccess.open("res://assets")
	if dir == null:
		return false
	var path = NPC_DIR + str(data["name"]) + ".json"
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	var clean = data.duplicate()
	clean.erase("_path")
	f.store_string(JSON.new().stringify(clean, "\t"))
	f.close()
	return true

static func delete_monster(monster_name: String) -> bool:
	var path = NPC_DIR + monster_name + ".json"
	if not FileAccess.file_exists(path):
		return false
	var dir = DirAccess.open(NPC_DIR)
	if dir == null:
		return false
	dir.remove(monster_name + ".json")
	return true

static func list_character_frames() -> Array:
	var dir = DirAccess.open(G.FRAME_ROOT + "character/")
	if dir == null:
		return []
	var result: Array = []
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			var name = fname.trim_suffix(".json")
			result.append(name)
		fname = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result
