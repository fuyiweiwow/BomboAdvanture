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
	var value: Variant = read(path, {})
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


# Writes beside the destination first, then replaces it. The backup makes the
# short replacement window recoverable if the process stops between renames.
static func write_atomic(path: String, value: Variant) -> bool:
	if path.strip_edges() == "":
		return false
	var suffix := "%d-%d" % [Time.get_ticks_usec(), randi()]
	var temp_path := path + ".tmp-" + suffix
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value, "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
		return false

	var target_absolute := ProjectSettings.globalize_path(path)
	var temp_absolute := ProjectSettings.globalize_path(temp_path)
	var backup_absolute := target_absolute + ".bak"
	var had_target := FileAccess.file_exists(path)
	if FileAccess.file_exists(backup_absolute):
		DirAccess.remove_absolute(backup_absolute)
	if had_target and DirAccess.rename_absolute(target_absolute, backup_absolute) != OK:
		DirAccess.remove_absolute(temp_absolute)
		return false
	if DirAccess.rename_absolute(temp_absolute, target_absolute) != OK:
		if had_target:
			DirAccess.rename_absolute(backup_absolute, target_absolute)
		DirAccess.remove_absolute(temp_absolute)
		return false
	if FileAccess.file_exists(backup_absolute):
		DirAccess.remove_absolute(backup_absolute)
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
