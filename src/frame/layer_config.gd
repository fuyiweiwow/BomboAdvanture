class_name LayerConfig
extends RefCounted

static var draw_order: Dictionary = _default_draw_order()
static var decoration_categories: Array = _default_decoration_categories()

const EYE_SUB_COMPONENTS = ["Eye_Eyeball", "Eye_Iris", "Eye_Pupil", "Eye_Highlight"]

static func init_from_json(path: String = "res://assets/frame/layer_config.json") -> bool:
	var j = Utils.load_json(path)
	if j == null:
		return false
	if j.has("draw_order"):
		draw_order = j["draw_order"]
	if j.has("decoration_categories"):
		decoration_categories = j["decoration_categories"]
	return true

static func _default_draw_order() -> Dictionary:
	return {
		"R": ["Body", "Foot", "Leg", "Cloth", "Cladorn", "Face", "Hair", "Eye_Eyeball", "Eye_Iris", "Eye_Pupil", "Eye_Highlight", "Ear", "Mouth", "Cap", "Fhadorn", "Npack", "Fpack", "Thadorn"],
		"U": ["Body", "Foot", "Leg", "Cloth", "Cladorn", "Face", "Eye_Eyeball", "Eye_Iris", "Eye_Pupil", "Eye_Highlight", "Ear", "Mouth", "Hair", "Cap", "Fhadorn", "Npack", "Fpack", "Thadorn"],
		"L": ["Thadorn", "Body", "Foot", "Leg", "Cloth", "Cladorn", "Npack", "Face", "Hair", "Eye_Eyeball", "Eye_Iris", "Eye_Pupil", "Eye_Highlight", "Ear", "Mouth", "Cap", "Fhadorn", "Fpack"],
		"D": ["Fpack", "Npack", "Body", "Foot", "Leg", "Cloth", "Cladorn", "Face", "Hair", "Eye_Eyeball", "Eye_Iris", "Eye_Pupil", "Eye_Highlight", "Ear", "Mouth", "Cap", "Fhadorn", "Thadorn"],
	}

static func _default_decoration_categories() -> Array:
	return ["Cap", "Hair", "Eye", "Eye_Eyeball", "Eye_Iris", "Eye_Pupil", "Eye_Highlight", "Ear", "Mouth", "Cladorn", "Fpack", "Npack", "Thadorn", "Footprint"]
