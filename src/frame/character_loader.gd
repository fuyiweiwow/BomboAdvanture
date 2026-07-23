# res://src/frame/character_loader.gd
# Port of game/frame/character.py -- builds the per-orientation, per-component
# frame lists that make up a character (body + decorations).
#
# Tinting is no longer baked into textures at load time. The player colour is
# applied at draw time as a modulate Color by the caller (CharacterPreview,
# Player.draw, etc.).  All components receive the player colour uniformly.
class_name CharacterLoader
extends RefCounted

const CHARACTER_ORIENTS = ["STAND_R", "STAND_U", "STAND_L", "STAND_D", "R", "U", "L", "D", "LOSE"]

# Draw order, tintable list, and decoration categories come from LayerConfig
# (loaded from assets/frame/layer_config.json, with hardcoded defaults).
# Legacy constants removed — use LayerConfig.draw_order etc.

static var _cache = {}

# Build (and cache) the character frame dictionary.
# Returns a Dictionary: { "NAME":String, "STAND_R":{...}, ... } where each
# orientation holds "Cx","Cy" and component-name -> Array[Frame].
# If custom_textures is non-empty, skip the frame JSON and build from
# imported PNG textures (each component = single static frame).
#
# `color` is kept for API compatibility but no longer used internally —
# tinting is handled at draw time by the caller via modulate Color.
# `component_colors` is an optional map of component_name -> Color for
# per-part tinting; stored under result["COLORS"].
static func get_character(character_name: String, color: Color, decorations: Dictionary, is_ghost = false, custom_textures: Dictionary = {}, component_colors: Dictionary = {}, fill_body_defaults := true) -> Dictionary:
	if not custom_textures.is_empty():
		var r = _build_custom_character(custom_textures)
		r["COLORS"] = component_colors
		return r

	if decorations.is_empty() and custom_textures.is_empty() and fill_body_defaults:
		if _cache.has(character_name):
			var r = _cache[character_name].duplicate()
			r["COLORS"] = component_colors
			return r

	var path = G.FRAME_ROOT + "character/" + character_name + ".json"
	var j = Utils.load_json(path)
	if j == null:
		push_error("CharacterLoader: missing %s" % path)
		return {}

	var result = load_color(j, decorations, fill_body_defaults)
	result["COLORS"] = component_colors

	if decorations.is_empty() and custom_textures.is_empty() and fill_body_defaults:
		_cache[character_name] = result

	return result

# Build a minimal character dictionary from custom imported textures.
# Each component is a single static frame reused across all orientations.
static func _build_custom_character(custom_textures: Dictionary) -> Dictionary:
	var result = {}
	result["NAME"] = "CustomCharacter"
	var comp_to_custom = {"Body": "body", "Foot": "foot", "Leg": "leg", "Cloth": "cloth", "Cladorn": "cladorn", "Face": "face", "Hair": "hair", "Eye": "eye", "Ear": "ear", "Mouth": "mouth", "Cap": "cap", "Fhadorn": "fhadorn", "Npack": "npack", "Fpack": "fpack", "Thadorn": "thadorn"}
	for orient in CHARACTER_ORIENTS:
		result[orient] = {}
		result[orient]["Cx"] = 0
		result[orient]["Cy"] = 0
		var orient_key = orient.replace("STAND_", "")
		var draw_order = LayerConfig.draw_order.get(orient_key, LayerConfig.draw_order["D"])
		for comp_key in draw_order:
			var custom_key = comp_to_custom.get(comp_key, "")
			if custom_key == "" or not custom_textures.has(custom_key):
				continue
			var ct = custom_textures[custom_key]
			var tex = Utils.load_texture(str(ct["path"]))
			if tex == null:
				continue
			result[orient][comp_key] = [Frame.new(tex, int(ct.get("cx", 0)), int(ct.get("cy", 0)))]
	return result

# (game/frame/character.py : load_color)
static func load_color(character_json: Dictionary, decorations: Dictionary, fill_body_defaults := true) -> Dictionary:
	var a_color = {}
	a_color["NAME"] = character_json.get("NAME", "")
	var draw_order := LayerConfig.draw_order
	var deco_cats := LayerConfig.decoration_categories
	for orient in CHARACTER_ORIENTS:
		if not character_json.has(orient):
			continue
		a_color[orient] = {}
		a_color[orient]["Cx"] = character_json[orient].get("Cx", 0)
		a_color[orient]["Cy"] = character_json[orient].get("Cy", 0)
		for component in draw_order["D"]:
			if not character_json[orient].has(component):
				continue
			a_color[orient][component] = load_component_frames(character_json[orient][component], component)
		if orient == "LOSE":
			continue
		for component in deco_cats:
			if decorations.has(component) and decorations[component] is Dictionary:
				if a_color[orient].has(component):
					a_color[orient].erase(component)
				if component == "Cladorn":
					if a_color[orient].has("Cloth"):
						a_color[orient].erase("Cloth")
				a_color[orient][component] = load_component_frames(decorations[component][orient], component)
		if decorations.has("Eye"):
			_expand_eye_sub_components(a_color, orient)
		if fill_body_defaults:
			_fill_body_defaults(a_color, orient)
	return a_color

# Fill in default body parts for any component still missing after
# character JSON + decorations.  This ensures all body parts render
# even for characters that lack the component in their original JSON.
static func _fill_body_defaults(a_color: Dictionary, orient: String) -> void:
	var defaults = {"Body": "body1", "Foot": "foot1"}
	for component in LayerConfig.decoration_categories:
		if a_color[orient].has(component) and not a_color[orient][component].is_empty():
			continue
		if not defaults.has(component):
			continue
		var cat_lower = component.to_lower()
		var default_name = defaults[component]
		var default_path = G.FRAME_ROOT + cat_lower + "/" + default_name + ".json"
		var default_j = Utils.load_json(default_path)
		if default_j == null or not default_j.has(orient):
			continue
		a_color[orient][component] = load_component_frames(default_j[orient], component)

# When "Eye" decoration is present, expand it into sub-components
# (Eye_Eyeball → Eye_Highlight) using their own frame JSONs.
static func _expand_eye_sub_components(a_color: Dictionary, orient: String) -> void:
	for sub_comp in LayerConfig.EYE_SUB_COMPONENTS:
		if a_color[orient].has(sub_comp):
			continue
		var sub_path = G.FRAME_ROOT + sub_comp.to_lower() + "/" + sub_comp.to_lower() + ".json"
		var sub_j = Utils.load_json(sub_path)
		if sub_j == null:
			continue
		if sub_j.has(orient):
			a_color[orient][sub_comp] = load_component_frames(sub_j[orient], sub_comp)
		elif sub_j.has("STAND_" + orient):
			var stand_key = "STAND_" + orient
			a_color[orient][sub_comp] = load_component_frames(sub_j[stand_key], sub_comp)

# Load one component's frames: each entry has IMG[]/CX[]/CY[].
static func load_component_frames(comp: Dictionary, component: String) -> Array:
	var frames: Array = []
	var imgs: Array = comp.get("IMG", [])
	var cxs: Array = comp.get("CX", [])
	var cys: Array = comp.get("CY", [])
	var type_folder = component.to_lower()
	for i in imgs.size():
		var filename := str(imgs[i])
		var tex: Texture2D = AtlasLoader.get_texture(type_folder, filename)
		if tex == null:
			tex = _load_fallback(type_folder, filename)
		if tex == null:
			continue
		var cx = cxs[i] if i < cxs.size() else 0
		var cy = cys[i] if i < cys.size() else 0
		frames.append(Frame.new(tex, cx, cy))
	return frames

# Fallback when an atlas is not available — load individual PNG directly.
static func _load_fallback(type_folder: String, filename: String) -> Texture2D:
	var path := G.RES_IMG_ROOT + type_folder + "/" + filename
	return Utils.load_texture(path)
