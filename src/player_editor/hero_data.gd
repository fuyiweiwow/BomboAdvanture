class_name HeroData
extends RefCounted

const HERO_DIR = "res://assets/hero/"
const CUSTOM_DIR = "res://assets/hero_custom/"
const CUSTOM_TEX_DIR = "res://assets/custom_textures/"
const CUSTOM_TEX_COMPONENTS = ["body", "foot", "leg", "cloth", "face", "hair", "eye", "ear", "mouth", "cap", "npack", "cladorn", "fpack", "thadorn", "fhadorn"]
const HILOAN_CREATOR_OPTIONS = {
	"body_type": ["lean", "standard"],
	"skin_tone": ["fair", "warm", "tan", "deep"],
	"face_shape": ["oval", "angular", "soft"],
	"ears_style": ["natural", "slightly_pointed"],
	"eyes_style": ["soft", "narrow", "tired"],
	"eye_color": ["brown", "blue", "green", "amber"],
	"eyebrow_style": ["none", "eyebrow_natural", "eyebrow_arched", "eyebrow_full"],
	"eyebrow_color": ["black", "brown", "silver", "auburn"],
	"nose_style": ["straight", "soft", "broad"],
	"mouth_style": ["neutral", "gentle", "firm"],
	"lip_color": ["natural", "rose", "muted"],
	"hair_style": ["none", "short_hair", "close_crop", "side_swept"],
	"hair_color": ["black", "brown", "silver", "auburn"],
	"glasses_style": ["none", "round", "rectangular"],
	"glasses_color": ["brass", "silver", "black"],
	"clothes_style": ["none", "travel_suit", "field_suit", "formal_suit"],
	"clothes_color": ["navy", "forest", "burgundy", "charcoal"],
	"shoes_style": ["none", "travel_shoes", "low_shoes", "travel_boots"],
	"shoes_color": ["dark_brown", "black", "tan"],
	"accessory_style": ["none", "pendant", "scarf", "belt_vial"],
	"accessory_color": ["brass", "silver", "black"],
}
const HILOAN_CREATOR_LABELS = {
	"lean": "Lean",
	"standard": "Standard",
	"fair": "Fair",
	"warm": "Warm",
	"tan": "Tan",
	"deep": "Deep",
	"oval": "Oval",
	"angular": "Angular",
	"natural": "Natural",
	"slightly_pointed": "Slightly Pointed",
	"soft": "Soft",
	"narrow": "Narrow",
	"tired": "Tired",
	"brown": "Brown",
	"blue": "Blue",
	"green": "Green",
	"amber": "Amber",
	"eyebrow_natural": "Natural Brow",
	"eyebrow_arched": "Arched Brow",
	"eyebrow_full": "Full Brow",
	"straight": "Straight",
	"broad": "Broad",
	"neutral": "Neutral",
	"gentle": "Gentle",
	"firm": "Firm",
	"rose": "Rose",
	"muted": "Muted",
	"short_hair": "Short Hair",
	"close_crop": "Close Crop",
	"side_swept": "Side Swept",
	"black": "Black",
	"silver": "Silver",
	"auburn": "Auburn",
	"none": "None",
	"rectangular": "Rectangular",
	"brass": "Brass",
	"travel_suit": "Coastal Gear",
	"field_suit": "Frostfield Gear",
	"formal_suit": "Academy Robe",
	"navy": "Navy",
	"forest": "Forest",
	"burgundy": "Burgundy",
	"charcoal": "Charcoal",
	"travel_shoes": "High Boots",
	"low_shoes": "Ankle Boots",
	"travel_boots": "Lace Boots",
	"dark_brown": "Dark Brown",
	"pendant": "Pendant",
	"scarf": "Scarf",
	"belt_vial": "Belt Vial",
}
const HILOAN_CREATOR_SWATCHES = {
	"fair": Color("#e7bea0"), "warm": Color("#cd9670"), "tan": Color("#a56c4c"), "deep": Color("#6f4634"),
	"black": Color("#272326"), "brown": Color("#643f29"), "auburn": Color("#843624"), "silver": Color("#b1aea8"),
	"blue": Color("#3e7ea8"), "green": Color("#488160"), "amber": Color("#ae762a"),
	"natural": Color("#7e4941"), "rose": Color("#a04d54"), "muted": Color("#684748"),
	"brass": Color("#b27e30"), "navy": Color("#223e5b"), "forest": Color("#294c3d"),
	"burgundy": Color("#5b2a33"), "charcoal": Color("#303338"), "dark_brown": Color("#442d20"),
}

static func list_heroes() -> Array:
	var all: Dictionary = {}
	var dir = DirAccess.open(HERO_DIR)
	if dir:
		dir.list_dir_begin()
		var fname = dir.get_next()
		while fname != "":
			if fname.ends_with(".json"):
				var name = fname.trim_suffix(".json")
				all[name] = HERO_DIR + fname
			fname = dir.get_next()
		dir.list_dir_end()

	dir = DirAccess.open(CUSTOM_DIR)
	if dir:
		dir.list_dir_begin()
		var fname = dir.get_next()
		while fname != "":
			if fname.ends_with(".json"):
				var name = fname.trim_suffix(".json")
				all[name] = CUSTOM_DIR + fname
			fname = dir.get_next()
		dir.list_dir_end()

	var result: Array = []
	for name in all.keys():
		var path = all[name]
		var j = Utils.load_json(path)
		if j != null and j.has("name"):
			j["_src"] = "custom" if path.begins_with(CUSTOM_DIR) else "origin"
			j["_path"] = path
			result.append(j)
	result.sort_custom(func(a, b): return a["name"] < b["name"])
	return result

static func load_hero(hero_name: String) -> Dictionary:
	var custom_path = CUSTOM_DIR + hero_name + ".json"
	if FileAccess.file_exists(custom_path):
		var j = Utils.load_json(custom_path)
		if j != null:
			j["_src"] = "custom"
			j["_path"] = custom_path
			return j
	var origin_path = HERO_DIR + hero_name + ".json"
	var j = Utils.load_json(origin_path)
	if j != null:
		j["_src"] = "origin"
		j["_path"] = origin_path
	return j

static func hero_exists(hero_name: String) -> bool:
	return FileAccess.file_exists(HERO_DIR + hero_name + ".json") or FileAccess.file_exists(CUSTOM_DIR + hero_name + ".json")

static func is_custom(hero_name: String) -> bool:
	return FileAccess.file_exists(CUSTOM_DIR + hero_name + ".json")

static func save_hero(data: Dictionary) -> bool:
	if not data.has("name"):
		return false
	var hero_name = str(data["name"])
	var dir = DirAccess.open("res://assets")
	if dir == null:
		return false
	if not DirAccess.dir_exists_absolute(CUSTOM_DIR):
		dir.make_dir("hero_custom")

	var path = CUSTOM_DIR + hero_name + ".json"
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	var clean = data.duplicate()
	clean.erase("_src")
	clean.erase("_path")
	if clean.get("creator_mode", false):
		clean["creator_version"] = 8
		clean["creator"] = normalize_creator_data(clean.get("creator", {}))
	f.store_string(JSON.new().stringify(clean, "\t"))
	f.close()
	return true

static func restore_defaults(hero_name: String) -> bool:
	var path = CUSTOM_DIR + hero_name + ".json"
	if not FileAccess.file_exists(path):
		return false
	var dir = DirAccess.open(CUSTOM_DIR)
	if dir == null:
		return false
	dir.remove(hero_name + ".json")
	return true

static func list_decorations(category: String) -> Array:
	var dir_path = G.FRAME_ROOT + category + "/"
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return []
	var result: Array = []
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			result.append(fname.trim_suffix(".json"))
		fname = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result

static func list_bomb_skins() -> Array:
	var dir = DirAccess.open(G.FRAME_ROOT + "bomb/")
	if dir == null:
		return []
	var result: Array = []
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			result.append(fname.trim_suffix(".json"))
		fname = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result

static func get_custom_tex_dir(hero_name: String) -> String:
	return CUSTOM_TEX_DIR + hero_name + "/"

static func ensure_custom_tex_dir(hero_name: String) -> bool:
	var dir = DirAccess.open(CUSTOM_TEX_DIR)
	if dir == null:
		dir = DirAccess.open("res://assets/")
		if dir == null:
			return false
		dir.make_dir("custom_textures")
	var sub = get_custom_tex_dir(hero_name)
	if not DirAccess.dir_exists_absolute(sub):
		dir = DirAccess.open(CUSTOM_TEX_DIR)
		if dir == null:
			return false
		dir.make_dir(hero_name)
	return DirAccess.dir_exists_absolute(sub)

static func import_texture(hero_name: String, component: String, source_path: String) -> Dictionary:
	if not component in CUSTOM_TEX_COMPONENTS:
		return {"ok": false, "error": "Unknown component: " + component}
	if not ResourceLoader.exists(source_path):
		return {"ok": false, "error": "Source file not found: " + source_path}
	if not ensure_custom_tex_dir(hero_name):
		return {"ok": false, "error": "Cannot create texture directory"}
	var ext = source_path.get_extension()
	var dest = get_custom_tex_dir(hero_name) + component + "." + ext
	var src = FileAccess.open(source_path, FileAccess.READ)
	if src == null:
		return {"ok": false, "error": "Cannot read source file"}
	var data = src.get_buffer(src.get_length())
	src.close()
	var dst = FileAccess.open(dest, FileAccess.WRITE)
	if dst == null:
		return {"ok": false, "error": "Cannot write destination"}
	dst.store_buffer(data)
	dst.close()
	return {"ok": true, "path": dest}

static func delete_texture(hero_name: String, component: String) -> bool:
	if not component in CUSTOM_TEX_COMPONENTS:
		return false
	var dir = DirAccess.open(get_custom_tex_dir(hero_name))
	if dir == null:
		return false
	var files = dir.get_files()
	for f in files:
		var base = f.get_basename()
		if base == component:
			dir.remove(f)
			return true
	return false

static func get_texture_path(hero_name: String, component: String) -> String:
	var dir = DirAccess.open(get_custom_tex_dir(hero_name))
	if dir == null:
		return ""
	var files = dir.get_files()
	for f in files:
		var base = f.get_basename()
		if base == component:
			return get_custom_tex_dir(hero_name) + f
	return ""

static func has_custom_texture(hero_name: String, component: String) -> bool:
	var p = get_texture_path(hero_name, component)
	return p != "" and ResourceLoader.exists(p)

static func create_hiloan_creator_hero(hero_name: String = "NewHiloanHero") -> Dictionary:
	return {
		"name": hero_name,
		"character": "CharacterBlank",
		"icon_img": "",
		"use_custom_textures": false,
		"creator_mode": true,
		"creator_version": 8,
		"creator": default_creator_data(),
		"decorations": {
			"disable_foot_and_leg": false, "bomb_skin": "bomb1",
			"cap": null, "hair": null, "eye": null, "ear": null, "mouth": null,
			"cladorn": null, "fpack": null, "npack": null, "thadorn": null, "footprint": null,
			"head_effect": null, "body_effect": null
		},
		"blood": 4500, "speed": 5.83333, "bomb": 7, "restore": 700,
		"power": 3, "damage": 3500, "defense": 0, "skills": []
	}

static func list_creator_options(category: String) -> Array:
	return HILOAN_CREATOR_OPTIONS.get(category, []).duplicate()

static func get_creator_label(id: String) -> String:
	return str(HILOAN_CREATOR_LABELS.get(id, id))

static func get_creator_swatch(id: String) -> Color:
	return HILOAN_CREATOR_SWATCHES.get(id, Color.WHITE)

static func default_creator_data() -> Dictionary:
	return {
		"body_type": "standard",
		"skin_tone": "warm",
		"face_shape": "oval",
		"ears_style": "natural",
		"eyes_style": "soft",
		"eye_color": "brown",
		"eyebrow_style": "eyebrow_natural",
		"eyebrow_color": "black",
		"nose_style": "straight",
		"mouth_style": "neutral",
		"lip_color": "natural",
		"hair_style": "none",
		"hair_color": "black",
		"glasses_style": "none",
		"glasses_color": "brass",
		"clothes_style": "none",
		"clothes_color": "navy",
		"shoes_style": "none",
		"shoes_color": "dark_brown",
		"accessory_style": "none",
		"accessory_color": "brass",
	}

static func normalize_creator_data(value: Variant) -> Dictionary:
	var result = default_creator_data()
	if value is Dictionary:
		for key in result.keys():
			if value.has(key):
				result[key] = value[key]
		result["body_type"] = {
			"slim": "lean",
			"slender": "lean",
			"sturdy": "standard",
			"average": "standard",
		}.get(str(value.get("body", result["body_type"])), {
			"slender": "lean",
			"average": "standard",
		}.get(str(result["body_type"]), result["body_type"]))
		result["skin_tone"] = {
			"warm_light": "warm",
			"cool_pale": "fair",
		}.get(str(value.get("skin", result["skin_tone"])), result["skin_tone"])
		result["face_shape"] = {
			"long": "oval",
			"square": "angular",
			"round": "soft",
		}.get(str(value.get("face_shape", result["face_shape"])), result["face_shape"])
		result["ears_style"] = {
			"round": "natural",
			"pointed": "slightly_pointed",
		}.get(str(result["ears_style"]), result["ears_style"])
		result["eyes_style"] = {
			"weary": "tired",
			"pale": "tired",
		}.get(str(value.get("eyes", result["eyes_style"])), result["eyes_style"])
		result["nose_style"] = {
			"strong": "broad",
			"narrow": "straight",
		}.get(str(value.get("nose", result["nose_style"])), result["nose_style"])
		result["mouth_style"] = {
			"tired": "firm",
		}.get(str(value.get("mouth", result["mouth_style"])), result["mouth_style"])
		result["hair_style"] = {
			"academy_messy": "short_hair",
			"miner_braids": "close_crop",
			"coastal_scarf": "side_swept",
			"miner_braid_cap": "close_crop",
			"loande_ceremonial": "side_swept",
		}.get(str(value.get("hair", result["hair_style"])), result["hair_style"])
		result["clothes_style"] = {
			"dart_academy": "formal_suit",
			"ilsa_miner": "field_suit",
			"loande_mantle": "travel_suit",
			"pusaitia_coastal": "travel_suit",
		}.get(str(value.get("clothes", result["clothes_style"])), result["clothes_style"])
		result["shoes_style"] = {
			"academy_boots": "low_shoes",
			"miner_boots": "travel_boots",
			"loande_wrapped": "travel_shoes",
			"coastal_sandals": "travel_shoes",
		}.get(str(value.get("shoes", result["shoes_style"])), result["shoes_style"])
		var old_accessory = str(value.get("accessory", result["accessory_style"]))
		result["accessory_style"] = {
			"heraldic_pendant": "pendant",
			"biome_vial": "belt_vial",
			"dark_scarf": "scarf",
			"round_glasses": "none",
			"miner_goggles": "none",
			"royal_circlet": "none",
			"worker_tag": "pendant",
		}.get(old_accessory, old_accessory if old_accessory in HILOAN_CREATOR_OPTIONS["accessory_style"] else result["accessory_style"])
	for key in HILOAN_CREATOR_OPTIONS:
		if str(result.get(key, "")) not in HILOAN_CREATOR_OPTIONS[key]:
			result[key] = default_creator_data()[key]
	return result

static func build_custom_textures_dict(hero_name: String, offsets: Dictionary) -> Dictionary:
	var result = {}
	for comp in CUSTOM_TEX_COMPONENTS:
		var p = get_texture_path(hero_name, comp)
		if p != "" and ResourceLoader.exists(p):
			result[comp] = {
				"path": p,
				"cx": offsets.get(comp, {}).get("cx", 0),
				"cy": offsets.get(comp, {}).get("cy", 0),
			}
	return result
