# res://src/frame/frame.gd
# A single sprite frame: a texture plus its draw offset (cx, cy).
# (game/frame/frame.py : Frame)
class_name Frame
extends RefCounted

var texture: Texture2D
var cx: int
var cy: int

func _init(tex: Texture2D, cx_: int, cy_: int):
	texture = tex
	cx = cx_
	cy = cy_

# Draw this frame onto a CanvasItem at world (x, y) with optional alpha.
func draw(ci: CanvasItem, x: float, y: float, alpha = 1.0) -> void:
	if texture == null:
		return
	var w = float(texture.get_width())
	var h = float(texture.get_height())
	var dx = x + float(cx)
	var dy = y + float(cy)
	ci.draw_texture_rect(texture, Rect2(dx, dy, w, h), false, Color(1, 1, 1, alpha))
