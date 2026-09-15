# res://src/city/city_data.gd
# District (城区) data access. A district is defined entirely by a JSON under
# assets/city/, so adding a new district/building is pure data, no code change.
#
# District JSON schema:
#   {
#     "id": "living_district", "name": "生活区", "desc": "...",
#     "buildings": [ {"id", "name", "action", "desc"?} ],
#     "exits":     [ {"to", "label"} ],
#     "npcs":      [ {"id", "name", "dialogue"?} ]
#   }
class_name CityData
extends RefCounted

const CITY_DIR = "res://assets/city/"


static func load_district(id: String) -> Dictionary:
	var path = CITY_DIR + id + ".json"
	var j := JsonStore.read_dictionary(path)
	if j.is_empty():
		return {}
	j = j.duplicate(true)
	j["_id"] = id
	return j


static func district_exists(id: String) -> bool:
	return FileAccess.file_exists(CITY_DIR + id + ".json")


static func list_districts() -> Array:
	return JsonStore.list_json_ids(CITY_DIR)
