# res://src/frame/magic_loader.gd
# Port of game/frame/magic.py
class_name MagicLoader
extends RefCounted

static var _magics = {}

# Returns { "STAND":Array[Frame] }
static func get_magic(name: String) -> Dictionary:
	if _magics.has(name):
		return _magics[name]
	var j = Utils.load_json(G.FRAME_ROOT + "magic/" + name + ".json")
	if j == null:
		return {}
	var a = {}
	a["STAND"] = []
	var imgs: Array = j.get("IMG", [])
	var cxs: Array = j.get("CX", [])
	var cys: Array = j.get("CY", [])
	for i in imgs.size():
		var tex = Utils.load_texture(G.RES_IMG_ROOT + "magic/" + str(imgs[i]))
		var cx = cxs[i] if i < cxs.size() else 0
		var cy = cys[i] if i < cys.size() else 0
		a["STAND"].append(Frame.new(tex, cx, cy))
	_magics[name] = a
	return a
