# res://src/frame/bomb_loader.gd
# Port of game/frame/bomb.py
class_name BombLoader
extends RefCounted

static var _bombs = {}

# Returns { "INTERVAL":int, "STAND":Array[Frame] }
static func get_bomb(name: String) -> Dictionary:
	if _bombs.has(name):
		return _bombs[name]
	var j = Utils.load_json(G.FRAME_ROOT + "bomb/" + name + ".json")
	if j == null:
		return {}
	var a_bomb = {}
	a_bomb["INTERVAL"] = j.get("INTERVAL", 300)
	a_bomb["STAND"] = []
	var stand: Dictionary = j.get("STAND", {})
	var imgs: Array = stand.get("IMG", [])
	var cxs: Array = stand.get("CX", [])
	var cys: Array = stand.get("CY", [])
	for i in imgs.size():
		var path = G.RES_IMG_ROOT + "bomb/" + str(imgs[i])
		var tex = Utils.load_texture(path)
		var cx = cxs[i] if i < cxs.size() else 0
		var cy = cys[i] if i < cys.size() else 0
		a_bomb["STAND"].append(Frame.new(tex, cx, cy))
		if tex == null:
			push_warning("BombLoader: missing texture %s, falling back to bomb1" % path)
			var fallback = get_bomb("bomb1")
			_bombs[name] = fallback
			return fallback
	_bombs[name] = a_bomb
	return a_bomb
