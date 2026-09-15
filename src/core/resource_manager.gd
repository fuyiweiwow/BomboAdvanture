extends Node

var _custom_dir: String = ""

func set_custom_dir(dir: String) -> void:
	_custom_dir = dir

func get_texture(original_path: String) -> Texture2D:
	var path = _resolve(original_path)
	# ResourceLoader.exists() may still see a stale .import entry after an
	# asset was removed from a partial checkout. Check the source path first so
	# optional UI art cleanly falls back to native drawing instead of logging a
	# noisy load error on every headless run.
	if path.begins_with("res://") and not FileAccess.file_exists(path):
		return null
	if ResourceLoader.exists(path):
		var texture = load(path)
		return texture if texture is Texture2D else null
	return null

func get_json(original_path: String) -> Variant:
	var path = _resolve(original_path)
	var f = FileAccess.open(path, FileAccess.READ)
	if f != null:
		return JSON.parse_string(f.get_as_text())
	return null

func get_file_path(original_path: String) -> String:
	return _resolve(original_path)

func _resolve(original_path: String) -> String:
	if _custom_dir == "":
		return original_path
	if original_path.begins_with("res://assets/"):
		var relative = original_path.trim_prefix("res://assets/")
		var custom_path = _custom_dir.path_join(relative)
		if FileAccess.file_exists(custom_path):
			return custom_path
	return original_path
