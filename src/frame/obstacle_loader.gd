# res://src/frame/obstacle_loader.gd
# Port of game/frame/obstacle.py
class_name ObstacleLoader
extends RefCounted

static var _obstacles = {}

# Returns a Dictionary describing one obstacle kind.
static func get_obstacle(type: String, name: String) -> Dictionary:
	if not _obstacles.has(type):
		_obstacles[type] = {}
	if _obstacles[type].has(name):
		return _obstacles[type][name]
	var j = Utils.load_json(G.FRAME_ROOT + "obstacle/" + type + "/" + name + ".json")
	if j == null:
		return {}
	var width = int(j.get("WIDTH", 1))
	var height = int(j.get("HEIGHT", 1))
	var o = {}
	o["TYPE"] = j.get("TYPE", type)
	o["NAME"] = j.get("NAME", name)
	o["WIDTH"] = width
	o["HEIGHT"] = height
	o["BLOCK"] = j.get("BLOCK", [[[0]], [[0]]])
	var bf = []
	for orient in range(2):
		var layer = []
		for gx in range(width):
			var col = []
			for gy in range(height):
				col.append(0)
			layer.append(col)
		bf.append(layer)
	o["BLOCK_FLAME"] = j.get("BLOCK_FLAME", bf)
	o["BREAKABLE"] = int(j.get("BREAKABLE", 0))
	o["CAN_HIDE"] = int(j.get("CAN_HIDE", 0))
	if j.has("SLIDE"):
		o["SLIDE"] = j["SLIDE"]
	o["TRIGGER"] = int(j.get("TRIGGER", 0))
	o["BACKGROUND"] = int(j.get("BACKGROUND", 0))
	o["CAN_PUSH"] = int(j.get("CAN_PUSH", 0))
	o["PUSH_TIME"] = int(j.get("PUSH_TIME", 0))
	o["CONTACT"] = int(j.get("CONTACT", 0))
	o["INTERVAL"] = int(j.get("INTERVAL", 200))
	o["STAND"] = _frames(j, "STAND", o["TYPE"])
	o["PUSH"] = _frames(j, "PUSH", o["TYPE"])
	o["DIE"] = _frames(j, "DIE", o["TYPE"])
	_obstacles[type][name] = o
	return o

static func _frames(j: Dictionary, state: String, type) -> Array:
	if not j.has(state):
		return []
	var frames: Dictionary = j[state]
	var imgs: Array = frames.get("IMG", [])
	var cxs: Array = frames.get("CX", [])
	var cys: Array = frames.get("CY", [])
	var out: Array = []
	for i in imgs.size():
		var tex = Utils.load_texture(G.RES_IMG_ROOT + "mapElem/" + str(type) + "/" + str(imgs[i]))
		var cx = cxs[i] if i < cxs.size() else 0
		var cy = cys[i] if i < cys.size() else 0
		out.append(Frame.new(tex, cx, cy))
	return out
