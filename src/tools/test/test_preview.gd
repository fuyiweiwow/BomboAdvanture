@tool
extends SceneTree

# Test preview for new AI-generated sprites.
# Usage: godot --path <project> --script res://src/tools/test/test_preview.gd
# Renders test character to PNG for visual review.

var test_assets = {
	"body0": {
		"json": "res://assets/test/body/body0/body0.json",
		"atlas_json": "res://assets/test/body/body0/body0.atlas.json",
		"atlas_png": "res://assets/test/body/body0/body0.atlas.png",
	}
}

func _initialize() -> void:
	print("=== Test Preview ===")
	
	var frames = _load_component_frames("body0")
	if frames.is_empty():
		print("ERROR: No frames loaded")
		quit()
		return
	
	for orient in frames.keys():
		print("  %s: %d frame(s)" % [orient, frames[orient]["IMG"].size()])
	
	# Render stand front view to PNG
	var output_dir = "res://assets/test/output/"
	var dir = DirAccess.open("res://")
	if dir:
		dir.make_dir_recursive("assets/test/output")
	
	# Simple rendering for visual check
	var img = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.5, 0.5, 1))  # gray background
	
	for orient_key in ["STAND_D", "D"]:
		var frame_data = frames.get(orient_key, {})
		var imgs = frame_data.get("IMG", [])
		if imgs.is_empty():
			continue
		
		var cx_arr = frame_data.get("CX", [0])
		var cy_arr = frame_data.get("CY", [0])
		
		for i in range(imgs.size()):
			var fn = str(imgs[i])
			var cx = int(cx_arr[i]) if i < cx_arr.size() else 0
			var cy = int(cy_arr[i]) if i < cy_arr.size() else 0
			
			var atlas_json_path = "res://assets/test/body/body0/body0.atlas.json"
			var atlas_json = _load_json(atlas_json_path)
			if atlas_json and atlas_json["frames"].has(fn):
				var f = atlas_json["frames"][fn]["frame"]
				var src_img = _load_atlas_png("res://assets/test/body/body0/body0.atlas.png")
				if src_img:
					src_img = src_img.get_region(Rect2i(f["x"], f["y"], f["w"], f["h"]))
					var dx = 64 + cx
					var dy = 64 + cy
					img.blit_rect(src_img, Rect2i(0, 0, src_img.get_width(), src_img.get_height()), Vector2i(dx, dy))
	
	var out_path = output_dir + "test_render.png"
	var err = img.save_png(out_path)
	if err == OK:
		print("  Rendered: %s" % out_path)
	else:
		push_error("  Failed to save: err=%d" % err)
	
	print("=== Done ===")
	quit()


func _load_json(path: String):
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var txt = f.get_as_text()
	f.close()
	return JSON.parse_string(txt)


func _load_atlas_png(path: String) -> Image:
	var img = Image.new()
	var err = img.load(path)
	if err == OK:
		return img
	return null


func _load_component_frames(comp_name: String) -> Dictionary:
	var json_path = test_assets[comp_name]["json"]
	var j = _load_json(json_path)
	if j == null:
		return {}
	return j
