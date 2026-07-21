@tool
extends SceneTree

# Generates placeholder colored-ellipse PNGs + frame JSONs for:
#   1. Eye sub-components (eye_eyeball, eye_iris, eye_pupil, eye_highlight)
#   2. Decoration PNGs referenced by existing frame JSONs but missing on disk
#
# Usage: godot --path <project> --script res://src/tools/generate_placeholders.gd
# Then:  godot --path <project> --script res://src/tools/sprite_sheet_packer.gd

const IMG_ROOT = "res://assets/img/"
const FRAME_ROOT = "res://assets/frame/"

static var EYE_PARTS = {
	"eye_eyeball":  {"color": Color(1, 1, 1), "w": 16, "h": 12},
	"eye_iris":     {"color": Color(0.15, 0.4, 0.8), "w": 8, "h": 8},
	"eye_pupil":    {"color": Color(0, 0, 0), "w": 4, "h": 4},
	"eye_highlight": {"color": Color(1, 1, 1), "w": 3, "h": 3},
}

var _generated_count = 0

func _initialize() -> void:
	print("=== Placeholder Generator ===")
	_generate_eye_sub_components()
	_generate_missing_deco_pngs()
	print("Done. %d placeholder files generated." % _generated_count)
	print("Now run: godot --path <project> --script res://src/tools/sprite_sheet_packer.gd")
	quit()


func _load_json(path: String):
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var txt = f.get_as_text()
	f.close()
	return JSON.parse_string(txt)


func _generate_eye_sub_components() -> void:
	var ref = _load_json(FRAME_ROOT + "eye/eye33.json")
	if ref == null:
		push_error("Cannot load assets/frame/eye/eye33.json")
		return

	for sub in EYE_PARTS:
		_generate_placeholder_set(sub, ref)


func _generate_placeholder_set(sub_folder: String, ref: Dictionary) -> void:
	var img_dir = IMG_ROOT + sub_folder + "/"
	var frame_dir = FRAME_ROOT + sub_folder + "/"

	var da = DirAccess.open("res://")
	if da:
		da.make_dir_recursive("assets/img/" + sub_folder)
		da.make_dir_recursive("assets/frame/" + sub_folder)

	var parts = EYE_PARTS[sub_folder]
	var frame_data = {"NAME": sub_folder}
	var orientations = ["STAND_R", "STAND_U", "STAND_L", "STAND_D"]

	for orient in orientations:
		if not ref.has(orient):
			continue
		var src = ref[orient]
		var imgs = []
		var cxs = []
		var cys = []

		for i in src["IMG"].size():
			var orig_fn = str(src["IMG"][i])
			var new_fn = orig_fn.replace("eye33", sub_folder)
			imgs.append(new_fn)

			var cx = src["CX"][i] if i < src["CX"].size() else 0
			var cy = src["CY"][i] if i < src["CY"].size() else 0
			cxs.append(cx)
			cys.append(cy)

			var png_path = img_dir + new_fn
			if not FileAccess.file_exists(png_path):
				_generate_ellipse_png(png_path, parts.w, parts.h, parts.color)
				_generated_count += 1

		frame_data[orient] = {"IMG": imgs, "CX": cxs, "CY": cys}

	for orient in ["R", "U", "L", "D"]:
		var stand_key = "STAND_" + orient
		if not frame_data.has(stand_key):
			continue
		var sd = frame_data[stand_key]
		var walk_imgs = []
		var walk_cxs = []
		var walk_cys = []
		for i in sd["IMG"].size():
			var fn = str(sd["IMG"][i])
			var new_fn = fn.replace("stand", "walk")
			walk_imgs.append(new_fn)
			var cx = sd["CX"][i]
			var cy = sd["CY"][i]
			walk_cxs.append(cx)
			walk_cys.append(cy)
			var png_path = img_dir + new_fn
			if not FileAccess.file_exists(png_path):
				_generate_ellipse_png(png_path, parts.w, parts.h, parts.color)
				_generated_count += 1
		frame_data[orient] = {"IMG": walk_imgs, "CX": walk_cxs, "CY": walk_cys}

	var json_path = frame_dir + sub_folder + ".json"
	var f = FileAccess.open(json_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(frame_data, "\t", false))
		f.close()
		print("  Frame JSON: %s" % json_path)


func _generate_missing_deco_pngs() -> void:
	var pairs = [
		["cap", "cap719"],
		["ear", "ear33"],
		["mouth", "mouth33"],
		["npack", "npack33"],
		["thadorn", "thadorn33"],
	]
	for pair in pairs:
		var cat = pair[0]
		var json_name = pair[1]
		var j = _load_json(FRAME_ROOT + cat + "/" + json_name + ".json")
		if j == null:
			continue
		var img_dir = IMG_ROOT + cat + "/"
		var collected = {}
		for orient in j:
			if not (orient is String):
				continue
			if j[orient] is Dictionary and j[orient].has("IMG"):
				for fn in j[orient]["IMG"]:
					collected[str(fn)] = true
		for fn in collected:
			var png_path = img_dir + fn
			if not FileAccess.file_exists(png_path):
				_generate_ellipse_png(png_path, 32, 32, Color(0.5, 0.3, 0.8, 0.6))
				_generated_count += 1


func _generate_ellipse_png(path: String, w: int, h: int, color: Color) -> void:
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx = w / 2.0
	var cy = h / 2.0
	var rx = w / 2.0 - 0.5
	var ry = h / 2.0 - 0.5
	for y in h:
		for x in w:
			var dx = (x - cx) / rx
			var dy = (y - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, color)
	var err = img.save_png(path)
	if err == OK:
		print("  PNG: %s" % path)
	else:
		push_error("  Failed: %s (err=%d)" % [path, err])
