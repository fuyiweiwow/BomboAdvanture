# res://src/frame/character_loader.gd
# Port of game/frame/character.py -- builds the per-orientation, per-component
# frame lists that make up a character (body + decorations, tinted to player colour).
class_name CharacterLoader
extends RefCounted

const CHARACTER_ORIENTS = ["STAND_R", "STAND_U", "STAND_L", "STAND_D", "R", "U", "L", "D", "LOSE"]
const CHARACTER_COMPONENTS = {
	"R": ["Body", "Body_m", "Foot", "Leg", "Leg_m", "Cloth", "Cloth_m", "Cladorn", "Face", "Hair", "Hair_m", "Eye", "Ear", "Mouth", "Cap", "Cap_m", "Fhadorn", "Npack", "Npack_m", "Fpack", "Thadorn"],
	"U": ["Body", "Body_m", "Foot", "Leg", "Leg_m", "Cloth", "Cloth_m", "Cladorn", "Face", "Eye", "Ear", "Mouth", "Hair", "Hair_m", "Cap", "Cap_m", "Fhadorn", "Npack", "Npack_m", "Fpack", "Thadorn"],
	"L": ["Thadorn", "Body", "Body_m", "Foot", "Leg", "Leg_m", "Cloth", "Cloth_m", "Cladorn", "Npack", "Npack_m", "Face", "Hair", "Hair_m", "Eye", "Ear", "Mouth", "Cap", "Cap_m", "Fhadorn", "Fpack"],
	"D": ["Fpack", "Npack", "Npack_m", "Body", "Body_m", "Foot", "Leg", "Leg_m", "Cloth", "Cloth_m", "Cladorn", "Face", "Hair", "Hair_m", "Eye", "Ear", "Mouth", "Cap", "Cap_m", "Fhadorn", "Thadorn"],
}
const CHARACTER_COMPONENTS_MASKED = ["Body_m", "Cloth_m", "Hair_m", "Leg_m", "Npack_m", "Cap_m"]
const DECORATION_CATEGORIES = ["Cap", "Hair", "Eye", "Ear", "Mouth", "Cladorn", "Fpack", "Npack", "Thadorn", "Footprint"]

static var _cache = {}

# Build (and cache) the character frame dictionary.
# Returns a Dictionary: { "NAME":String, "STAND_R":{...}, ... } where each
# orientation holds "Cx","Cy" and component-name -> Array[Frame].
# If custom_textures is non-empty, skip the frame JSON and build from
# imported PNG textures (each component = single static frame).
static func get_character(character_name: String, color: Color, decorations: Dictionary, is_ghost = false, custom_textures: Dictionary = {}) -> Dictionary:
	if not custom_textures.is_empty():
		return _build_custom_character(custom_textures, is_ghost)

	var key = character_name + ("_ghost" if is_ghost else "")
	if not _cache.has(key):
		_cache[key] = {}
	var color_key = color.to_html()
	if _cache[key].has(color_key):
		return _cache[key][color_key]

	var path = G.FRAME_ROOT + "character/" + character_name + ".json"
	var j = Utils.load_json(path)
	if j == null:
		push_error("CharacterLoader: missing %s" % path)
		return {}

	var result = load_color(j, color, decorations, is_ghost)
	_cache[key][color_key] = result
	return result

# Build a minimal character dictionary from custom imported textures.
# Each component is a single static frame reused across all orientations.
static func _build_custom_character(custom_textures: Dictionary, is_ghost: bool) -> Dictionary:
	var result = {}
	result["NAME"] = "CustomCharacter"
	var comp_to_custom = {"Body": "body", "Foot": "foot", "Leg": "leg", "Cloth": "cloth", "Cladorn": "cladorn", "Face": "face", "Hair": "hair", "Eye": "eye", "Ear": "ear", "Mouth": "mouth", "Cap": "cap", "Fhadorn": "fhadorn", "Npack": "npack", "Fpack": "fpack", "Thadorn": "thadorn"}
	for orient in CHARACTER_ORIENTS:
		result[orient] = {}
		result[orient]["Cx"] = 0
		result[orient]["Cy"] = 0
		var orient_key = orient.replace("STAND_", "")
		var draw_order = CHARACTER_COMPONENTS.get(orient_key, CHARACTER_COMPONENTS["D"])
		for comp_key in draw_order:
			var custom_key = comp_to_custom.get(comp_key, "")
			if custom_key == "" or not custom_textures.has(custom_key):
				continue
			var ct = custom_textures[custom_key]
			var tex = Utils.load_texture(str(ct["path"]))
			if tex == null:
				continue
			if is_ghost:
				var img = tex.get_image()
				if img != null:
					img.convert(Image.FORMAT_RGBA8)
					var data = img.get_data()
					for pi in range(0, data.size(), 4):
						data[pi + 3] = data[pi + 3] / 2
					tex = ImageTexture.create_from_image(Image.create_from_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, data))
			result[orient][comp_key] = [Frame.new(tex, int(ct.get("cx", 0)), int(ct.get("cy", 0)))]
	return result

# (game/frame/character.py : load_color)
static func load_color(character_json: Dictionary, color: Color, decorations: Dictionary, is_ghost: bool) -> Dictionary:
	var a_color = {}
	a_color["NAME"] = character_json.get("NAME", "")
	for orient in CHARACTER_ORIENTS:
		if not character_json.has(orient):
			continue
		a_color[orient] = {}
		a_color[orient]["Cx"] = character_json[orient].get("Cx", 0)
		a_color[orient]["Cy"] = character_json[orient].get("Cy", 0)
		for component in CHARACTER_COMPONENTS["D"]:
			if not character_json[orient].has(component):
				continue
			a_color[orient][component] = load_component_frames(character_json[orient][component], component, color, is_ghost)
		if orient == "LOSE":
			continue
		for component in DECORATION_CATEGORIES:
			if decorations.has(component) and decorations[component] is Dictionary:
				# drop the existing (and its _m) then load the decoration
				if a_color[orient].has(component):
					a_color[orient].erase(component)
				if a_color[orient].has(component + "_m"):
					a_color[orient].erase(component + "_m")
				if component == "Cladorn":
					if a_color[orient].has("Cloth"):
						a_color[orient].erase("Cloth")
					if a_color[orient].has("Cloth_m"):
						a_color[orient].erase("Cloth_m")
				a_color[orient][component] = load_component_frames(decorations[component][orient], component, color, is_ghost)
	return a_color

# Load one component's frames: each entry has IMG[]/CX[]/CY[].
static func load_component_frames(comp: Dictionary, component: String, color: Color, is_ghost: bool) -> Array:
	var frames: Array = []
	var imgs: Array = comp.get("IMG", [])
	var cxs: Array = comp.get("CX", [])
	var cys: Array = comp.get("CY", [])
	var type_folder = component.replace("_m", "").to_lower()
	for i in imgs.size():
		var filename := str(imgs[i])
		var tex: Texture2D = AtlasLoader.get_texture(type_folder, filename, component, color, is_ghost)
		if tex == null:
			tex = _load_fallback(type_folder, filename, component, color, is_ghost)
		if tex == null:
			continue
		var cx = cxs[i] if i < cxs.size() else 0
		var cy = cys[i] if i < cys.size() else 0
		frames.append(Frame.new(tex, cx, cy))
	return frames

# Fallback when an atlas is not available — load individual PNG and apply
# colour/ghost effects the old way.
static func _load_fallback(type_folder: String, filename: String, component: String, color: Color, is_ghost: bool) -> Texture2D:
	var path := G.RES_IMG_ROOT + type_folder + "/" + filename
	var tex := Utils.load_texture(path)
	if tex == null:
		return null
	var masked := CHARACTER_COMPONENTS_MASKED.has(component)
	if masked and not is_ghost:
		var img := Utils.load_image(path)
		if img != null:
			var tinted := Utils.color_overlay(img, color)
			if tinted != null:
				tex = ImageTexture.create_from_image(tinted)
	elif is_ghost:
		var img := Utils.load_image(path)
		if img != null:
			img.convert(Image.FORMAT_RGBA8)
			var data := img.get_data()
			for pi in range(0, data.size(), 4):
				data[pi + 3] = data[pi + 3] / 2
			tex = ImageTexture.create_from_image(Image.create_from_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, data))
	return tex
