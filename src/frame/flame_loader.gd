# res://src/frame/flame_loader.gd
# Port of game/frame/flame.py -- loads the bomb-flame frame sequences.
class_name FlameLoader
extends RefCounted

const ORIENTATIONS = ["FLAME_C", "FLAME_R", "FLAME_U", "FLAME_L", "FLAME_D"]
const FLAME_JSON_FILE = "flame.json"
static var _flames = {}
static var flame_seq: Array = []

static func _ensure_seq() -> void:
	if flame_seq.is_empty():
		var j = Utils.load_json(G.FRAME_ROOT + "flame/" + FLAME_JSON_FILE)
		if j != null and j.has("FLAME_SEQ"):
			flame_seq = j["FLAME_SEQ"]

# Returns Array[Frame] for the given orientation.
static func get_flame(orientation: String) -> Array:
	_ensure_seq()
	if not _flames.has(orientation):
		_flames[orientation] = []
		var j = Utils.load_json(G.FRAME_ROOT + "flame/" + FLAME_JSON_FILE)
		if j == null or not j.has(orientation):
			return []
		var root: Dictionary = j[orientation]
		var imgs: Array = root.get("IMG", [])
		var cxs: Array = root.get("CX", [])
		var cys: Array = root.get("CY", [])
		for i in imgs.size():
			var tex = Utils.load_texture(G.RES_IMG_ROOT + "flame/" + str(imgs[i]))
			var cx = cxs[i] if i < cxs.size() else 0
			var cy = cys[i] if i < cys.size() else 0
			_flames[orientation].append(Frame.new(tex, cx, cy))
	return _flames[orientation]
