# res://src/core/json_store.gd
# Small, side-effect-free JSON repository used by data-oriented modules.
# Keeping file access here makes loaders consistent and keeps UI/game code
# focused on domain behaviour rather than parsing and error handling.
class_name JsonStore
extends RefCounted

static func read(path: String, fallback: Variant = null) -> Variant:
	if path.strip_edges() == "" or not FileAccess.file_exists(path):
		return fallback
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return fallback
	var value = JSON.parse_string(file.get_as_text())
	file.close()
	return fallback if value == null else value


static func read_dictionary(path: String) -> Dictionary:
	var value := read(path, {})
	return value if value is Dictionary else {}


static func write(path: String, value: Variant) -> bool:
	if path.strip_edges() == "":
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value, "\t"))
	file.close()
	return true


static func list_json_ids(directory: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(directory)
	if dir == null:
		return result
	dir.list_dir_begin()
	var filename := dir.get_next()
	while filename != "":
		if not dir.current_is_dir() and filename.ends_with(".json"):
			result.append(filename.trim_suffix(".json"))
		filename = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result
