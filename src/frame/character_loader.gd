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
static func get_character(character_name: String, color: Color, decorations: Dictionary, is_ghost = false) -> Dictionary:
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
		var tex = Utils.load_texture(G.RES_IMG_ROOT + type_folder + "/" + str(imgs[i]))
		if tex == null:
			continue
		var masked = CHARACTER_COMPONENTS_MASKED.has(component)
		if masked and not is_ghost:
			var img = Utils.load_image(G.RES_IMG_ROOT + type_folder + "/" + str(imgs[i]))
			if img != null:
				var tinted = Utils.color_overlay(img, color)
				if tinted != null:
					tex = ImageTexture.create_from_image(tinted)
		elif is_ghost:
			var img = Utils.load_image(G.RES_IMG_ROOT + type_folder + "/" + str(imgs[i]))
			if img != null:
				img.set_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, img.get_data())
				# half alpha ghost
				for py in img.get_height():
					for px in img.get_width():
						var p = img.get_pixel(px, py)
						img.set_pixel(px, py, Color(p.r, p.g, p.b, p.a * 0.5))
				tex = ImageTexture.create_from_image(img)
		var cx = cxs[i] if i < cxs.size() else 0
		var cy = cys[i] if i < cys.size() else 0
		frames.append(Frame.new(tex, cx, cy))
	return frames
