# res://src/frame/item_loader.gd
# Port of game/frame/item.py
class_name ItemLoader
extends RefCounted

static var _items = {}

# Returns { "INTERVAL":int, "STAND":Array[Frame], "DIE":Array[Frame] }
static func get_item(name: String) -> Dictionary:
	if _items.has(name):
		return _items[name]
	var j = Utils.load_json(G.FRAME_ROOT + "item/" + name + ".json")
	if j == null:
		return {}
	var a = {}
	a["INTERVAL"] = j.get("INTERVAL", 200)
	_append(a, j, "STAND")
	_append(a, j, "DIE")
	_items[name] = a
	return a

static func _append(a: Dictionary, j: Dictionary, state: String) -> void:
	if not j.has(state):
		return
	a[state] = []
	var frames: Dictionary = j[state]
	var imgs: Array = frames.get("IMG", [])
	var cxs: Array = frames.get("CX", [])
	var cys: Array = frames.get("CY", [])
	for i in imgs.size():
		var tex = Utils.load_texture(G.RES_IMG_ROOT + "item/" + str(imgs[i]))
		var cx = cxs[i] if i < cxs.size() else 0
		var cy = cys[i] if i < cys.size() else 0
		a[state].append(Frame.new(tex, cx, cy))
