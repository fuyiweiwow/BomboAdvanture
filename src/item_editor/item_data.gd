class_name ItemData
extends RefCounted

const ITEM_DIR = "res://assets/item/"
static var _cached_frames: Array = []

static func list_frames() -> Array:
	if not _cached_frames.is_empty():
		return _cached_frames
	var dir = DirAccess.open(G.FRAME_ROOT + "item/")
	if dir == null:
		_cached_frames = ["item1", "item2", "item3"]
		return _cached_frames
	var result: Array = []
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			result.append(fname.trim_suffix(".json"))
		fname = dir.get_next()
	dir.list_dir_end()
	result.sort()
	_cached_frames = result
	return result

static func invalidate_frame_cache() -> void:
	_cached_frames.clear()

const TYPES = ["weapon", "armor", "potion", "material", "key"]
const RARITIES = ["common", "uncommon", "rare", "epic", "legendary"]
const TYPE_LABELS = {"weapon": "Weapon", "armor": "Armor", "potion": "Potion", "material": "Material", "key": "Key"}
const RARITY_LABELS = {"common": "Common", "uncommon": "Uncommon", "rare": "Rare", "epic": "Epic", "legendary": "Legendary"}

const EFFECT_FIELDS = {
	"weapon": ["attack", "speed", "crit_chance", "crit_dmg"],
	"armor": ["defense", "hp_bonus", "mp_bonus"],
	"potion": ["heal_hp", "heal_mp", "buff_id", "buff_duration"],
	"material": [],
	"key": [],
}

const EFFECT_DEFAULTS = {
	"attack": 0, "speed": 0, "crit_chance": 0, "crit_dmg": 0,
	"defense": 0, "hp_bonus": 0, "mp_bonus": 0,
	"heal_hp": 0, "heal_mp": 0, "buff_id": "", "buff_duration": 0,
}

static func list_items() -> Array:
	var dir = DirAccess.open(ITEM_DIR)
	if dir == null:
		return []
	var result: Array = []
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			var j = Utils.load_json(ITEM_DIR + fname)
			if j != null and j.has("id"):
				j["_path"] = ITEM_DIR + fname
				result.append(j)
		fname = dir.get_next()
	dir.list_dir_end()
	result.sort_custom(func(a, b): return str(a.get("id", "")) < str(b.get("id", "")))
	return result

static func load_item(item_id: String) -> Dictionary:
	var path = ITEM_DIR + item_id + ".json"
	if FileAccess.file_exists(path):
		var j = Utils.load_json(path)
		if j != null:
			j["_path"] = path
			return j
	return {}

static func item_exists(item_id: String) -> bool:
	return FileAccess.file_exists(ITEM_DIR + item_id + ".json")

static func save_item(data: Dictionary) -> bool:
	if not data.has("id") or str(data["id"]).strip_edges() == "":
		return false
	var path = ITEM_DIR + str(data["id"]) + ".json"
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	var clean = data.duplicate()
	clean.erase("_path")
	f.store_string(JSON.new().stringify(clean, "\t"))
	f.close()
	return true

static func delete_item(item_id: String) -> bool:
	var path = ITEM_DIR + item_id + ".json"
	if not FileAccess.file_exists(path):
		return false
	var dir = DirAccess.open(ITEM_DIR)
	if dir == null:
		return false
	dir.remove(item_id + ".json")
	return true

static func new_template() -> Dictionary:
	return {
		"id": "", "name": "", "chs_name": "", "type": "material", "rarity": "common",
		"description": "", "frame": "item1",
		"buy_price": 0, "sell_price": 0,
		"stackable": true, "max_stack": 99,
		"effects": {},
	}

static func type_label(t: String) -> String:
	return TYPE_LABELS.get(t, t)

static func rarity_label(r: String) -> String:
	return RARITY_LABELS.get(r, r)

static func rarity_color(r: String) -> Color:
	match r:
		"uncommon": return Color(0.3, 0.7, 0.3)
		"rare": return Color(0.3, 0.5, 0.9)
		"epic": return Color(0.7, 0.3, 0.8)
		"legendary": return Color(1.0, 0.6, 0.1)
		_: return Color(0.8, 0.8, 0.8)

static func effects_for_type(item_type: String) -> Array:
	return EFFECT_FIELDS.get(item_type, [])
