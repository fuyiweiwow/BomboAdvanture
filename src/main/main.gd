extends Node2D

func _ready() -> void:
	var f = FileAccess.open("res://dbg_ready.txt", FileAccess.WRITE)
	if f != null:
		f.store_string("READY_CALLED\n")
		f.close()
	queue_redraw()

func _draw() -> void:
	var f2 = FileAccess.open("res://dbg_draw.txt", FileAccess.WRITE)
	if f2 != null:
		f2.store_string("DRAW_CALLED\n")
		f2.close()
	draw_rect(Rect2(0, 0, 200, 200), Color(1, 0, 0), true)