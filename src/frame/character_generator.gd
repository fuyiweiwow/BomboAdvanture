class_name CharacterGenerator
extends RefCounted

static func generate(character_name: String, color: Color, decorations: Dictionary,
		custom_textures: Dictionary = {}) -> Dictionary:
	return CharacterLoader.get_character(character_name, color, decorations, false, custom_textures)

static func generate_from_hero(hero: Dictionary, color: Color) -> Dictionary:
	var use_custom = hero.get("use_custom_textures", false)
	var hero_name: String = str(hero.get("name", ""))

	if use_custom and hero_name != "":
		var offsets = hero.get("custom_texture_offsets", {})
		var custom_textures: Dictionary = HeroData.build_custom_textures_dict(hero_name, offsets)
		return generate("", color, {}, custom_textures)

	var char_name: String = str(hero.get("character", ""))
	if char_name == "":
		return {}

	var decorations: Dictionary = _load_decorations(hero)
	return generate(char_name, color, decorations)

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
