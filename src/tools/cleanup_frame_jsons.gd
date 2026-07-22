# Tool: Clean up frame JSONs that reference non-existent textures
extends SceneTree

var _all_textures: Dictionary = {}
var _deleted_count: int = 0
var _partial_count: int = 0

func _initialize() -> void:
	_index_all_textures()
	var root = "res://assets/frame/"
	var dir = DirAccess.open(root)
	if dir == null:
		print("ERROR: cannot open ", root)
		quit(1)
		return
	dir.list_dir_begin()
	var cat = dir.get_next()
	while cat != "":
		if dir.current_is_dir() and not cat.begins_with("."):
			_process_category(root + cat + "/", cat)
		cat = dir.get_next()
	dir.list_dir_end()
	print("\n--- Done ---")
	print("Deleted: %d JSONs (all refs missing)" % _deleted_count)
	print("Partial: %d JSONs (some refs missing, kept)" % _partial_count)
	quit(0)

func _index_all_textures() -> void:
	var root = "res://assets/img/"
	var dir = DirAccess.open(root)
	if dir == null:
		return
	dir.list_dir_begin()
	var cat = dir.get_next()
	while cat != "":
		if dir.current_is_dir() and not cat.begins_with("."):
			var sub = DirAccess.open(root + cat + "/")
			if sub:
				sub.list_dir_begin()
				var f = sub.get_next()
				while f != "":
					if f.ends_with(".png"):
						_all_textures[f] = true
					f = sub.get_next()
				sub.list_dir_end()
		cat = dir.get_next()
	dir.list_dir_end()
	print("Indexed %d textures" % _all_textures.size())

func _process_category(dir_path: String, category: String) -> void:
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return
	var files: Array = []
	dir.list_dir_begin()
	var f = dir.get_next()
	while f != "":
		if f.ends_with(".json") and f != "layer_config.json":
			files.append(f)
		f = dir.get_next()
	dir.list_dir_end()
	files.sort()

	for fname in files:
		var path = dir_path + fname
		var j = _load_json(path)
		if j == null:
			continue
		var missing = _check_missing(j)
		var total = _count_refs(j)
		if total == 0:
			continue
		if missing >= total:
			dir.remove(fname)
			var uid_path = dir_path + fname + ".uid"
			if FileAccess.file_exists(uid_path):
				dir.remove(fname + ".uid")
			print("DELETED %s (%s) - all %d refs missing" % [category + "/" + fname, _get_name(j), total])
			_deleted_count += 1
		elif missing > 0:
			_partial_count += 1
			if _partial_count <= 20:
				print("  PARTIAL %s (%s) - %d/%d refs missing" % [category + "/" + fname, _get_name(j), missing, total])

func _load_json(path: String) -> Variant:
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var text = f.get_as_text()
	f.close()
	return JSON.parse_string(text)

func _count_refs(j: Variant) -> int:
	if j == null or typeof(j) != TYPE_DICTIONARY:
		return 0
	var count = 0
	for key in j:
		if key in ["NAME", "Cx", "Cy", "CX", "CY"]:
			continue
		var v = j[key]
		if typeof(v) == TYPE_DICTIONARY:
			count += _count_refs(v)
		elif typeof(v) == TYPE_ARRAY:
			for item in v:
				if typeof(item) == TYPE_DICTIONARY:
					count += _count_refs(item)
				elif typeof(item) == TYPE_STRING:
					count += 1
	return count

func _check_missing(j: Variant) -> int:
	if j == null or typeof(j) != TYPE_DICTIONARY:
		return 0
	var missing = 0
	for key in j:
		if key in ["NAME", "Cx", "Cy", "CX", "CY"]:
			continue
		var v = j[key]
		if typeof(v) == TYPE_ARRAY:
			for item in v:
				if typeof(item) == TYPE_STRING:
					if not _all_textures.has(item):
						missing += 1
				elif typeof(item) == TYPE_DICTIONARY:
					missing += _check_missing(item)
		elif typeof(v) == TYPE_DICTIONARY:
			missing += _check_missing(v)
	return missing

func _get_name(j: Variant) -> String:
	if j is Dictionary and j.has("NAME"):
		return str(j["NAME"])
	return "?"
