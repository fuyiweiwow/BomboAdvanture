@tool
extends RefCounted
class_name TestCharacterLoader

# Test character loader for the hybrid body+face system.
# Reads test assets from assets/test/ instead of the main system.
# Same interface as CharacterLoader so it works with CharacterPreview.

const TEST_FRAME_ROOT = "res://assets/test/"
const TEST_IMG_ROOT = "res://assets/test/"
const ORIENTS = ["STAND_R", "STAND_U", "STAND_L", "STAND_D", "R", "U", "L", "D", "LOSE"]

static func get_character(body_name: String, face_name: String = "") -> Dictionary:
	var result = {}
	result["NAME"] = body_name
	result["COLORS"] = {}
	
	# Load body frames
	var body_frames = _load_component(body_name, "body")
	if body_frames.is_empty():
		return {}
	
	# Load face decoration
	var face_frames = {}
	if face_name:
		face_frames = _load_component(face_name, "face")
	
	for orient in ORIENTS:
		result[orient] = {}
		result[orient]["Cx"] = 0
		result[orient]["Cy"] = 0
		
		# Add body (always)
		if body_frames.has(orient):
			result[orient]["Body"] = body_frames[orient]
		
		# Add face overlay
		if face_frames.has(orient):
			result[orient]["Face"] = face_frames[orient]
	
	return result


static func _load_component(name: String, category: String) -> Dictionary:
	# Try atlas-first loading (same as AtlasLoader)
	var img_dir = TEST_IMG_ROOT + category + "/" + name + "/img/"
	var frame_path = TEST_FRAME_ROOT + category + "/" + name + "/" + name + ".json"
	
	var dir = DirAccess.open(img_dir)
	if dir == null:
		return {}
	
	var j = _load_json(frame_path)
	if j == null:
		return {}
	
	var result = {}
	for orient in ORIENTS:
		if not j.has(orient):
			continue
		var comp_data = j[orient]
		var imgs = comp_data.get("IMG", [])
		var cxs = comp_data.get("CX", [])
		var cys = comp_data.get("CY", [])
		
		var frames = []
		for i in range(imgs.size()):
			var fn = str(imgs[i])
			var cx = cxs[i] if i < cxs.size() else 0
			var cy = cys[i] if i < cys.size() else 0
			
			var tex = _load_texture_from_atlas(name, category, fn)
			if tex == null:
				tex = _load_texture_direct(img_dir, fn)
			if tex != null:
				frames.append(Frame.new(tex, cx, cy))
		
		if not frames.is_empty():
			result[orient] = frames
	
	return result


static func _load_texture_from_atlas(name: String, category: String, filename: String) -> Texture2D:
	var atlas_json_path = TEST_FRAME_ROOT + category + "/" + name + "/" + name + ".atlas.json"
	var atlas_png_path = TEST_FRAME_ROOT + category + "/" + name + "/" + name + ".atlas.png"
	
	var atlas_json = _load_json(atlas_json_path)
	if atlas_json == null or not atlas_json.get("frames", {}).has(filename):
		return null
	
	var frame_data = atlas_json["frames"][filename]["frame"]
	var atlas_img = Image.new()
	if atlas_img.load(atlas_png_path) != OK:
		return null
	
	var tex = ImageTexture.create_from_image(atlas_img)
	var at = AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(frame_data["x"], frame_data["y"], frame_data["w"], frame_data["h"])
	at.filter_clip = true
	return at


static func _load_texture_direct(img_dir: String, filename: String) -> Texture2D:
	var path = img_dir + filename
	var img = Image.new()
	if img.load(path) != OK:
		return null
	return ImageTexture.create_from_image(img)


static func _load_json(path: String):
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var txt = f.get_as_text()
	f.close()
	return JSON.parse_string(txt)
