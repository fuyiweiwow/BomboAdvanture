# res://src/main/world.gd  (translated world layer)
extends Node2D

func _draw() -> void:
	_dbg("WORLD_DRAW")
	if Game != null and Game.current_level != null and Game.current_level.has_method("draw_world"):
		Game.current_level.draw_world(self)

func _dbg(s: String) -> void:
	var path = "res://dbg.txt"
	var prev = ""
	if FileAccess.file_exists(path):
		var rf = FileAccess.open(path, FileAccess.READ)
		if rf != null:
			prev = rf.get_as_text()
			rf.close()
	var wf = FileAccess.open(path, FileAccess.WRITE)
	if wf != null:
		wf.store_string(prev + s + "\n")
		wf.close()
