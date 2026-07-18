# res://src/frame/floor_loader.gd
# Port of game/frame/floor.py -- a single floor tile texture.
class_name FloorLoader
extends RefCounted

static var _floors = {}

static func get_floor(type: String, name: String) -> Texture2D:
	if not _floors.has(type):
		_floors[type] = {}
	if _floors[type].has(name):
		return _floors[type][name]
	var tex = Utils.load_texture(G.RES_IMG_ROOT + "mapElem/" + type + "/" + name + ".png")
	if tex == null:
		tex = Utils.load_texture(G.RES_IMG_ROOT + "mapElem/" + type + "/" + name + ".png")  # retry (some are not .png)
	_floors[type][name] = tex
	return tex
