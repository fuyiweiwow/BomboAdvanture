class_name CharacterGenerator
extends RefCounted

static func generate(character_name: String, color: Color, decorations: Dictionary,
		custom_textures: Dictionary = {}, component_colors: Dictionary = {},
		fill_body_defaults := true) -> Dictionary:
	return CharacterLoader.get_character(character_name, color, decorations, false, custom_textures, component_colors, fill_body_defaults)

static func generate_from_hero(hero: Dictionary, color: Color) -> Dictionary:
	var char_name: String = str(hero.get("character", ""))
	if char_name == "":
		return {}

	var decorations: Dictionary = _load_decorations(hero)
	var component_colors: Dictionary = _build_component_colors(hero, color)
	return generate(char_name, color, decorations, {}, component_colors)

static func _load_decorations(hero: Dictionary) -> Dictionary:
	var deco: Dictionary = {}
	var deco_data = hero.get("decorations", {})
	for component in LayerConfig.decoration_categories:
		var cat_lower: String = component.to_lower()
		var name = deco_data.get(cat_lower, null)
		if name == null:
			continue
		if cat_lower == "footprint":
			continue
		var path: String = G.FRAME_ROOT + cat_lower + "/" + str(name) + ".json"
		var j = Utils.load_json(path)
		if j != null:
			deco[component] = j
	return deco

static func _build_component_colors(hero: Dictionary, fallback: Color) -> Dictionary:
	var result: Dictionary = {}
	var colors_data = hero.get("colors", {})
	for comp_name in colors_data:
		var val = colors_data[comp_name]
		if val is Array:
			if val.size() >= 4:
				result[comp_name] = Color(val[0], val[1], val[2], val[3])
			else:
				result[comp_name] = Color(val[0], val[1], val[2])
		elif val is Color:
			result[comp_name] = val
	return result
