# res://src/game/sprite/flame_instance.gd
# Port of game/sprite/flame_instance.py
class_name FlameInstance
extends Updatable

const NORMAL = 0
const DEAD = -1

var flame: Array = []      # directional frame list (Array[Frame])
var seq: Array = []       # animation frame-index sequence
var state: int = NORMAL
var flame_timer: int = 0
var flame_frame_idx: int = 0
var cx: int = 0
var cy: int = 0

func _init(nx: int, ny: int, flame_: Array, seq_: int):
	super._init(nx, ny)
	flame = flame_
	get_seq(seq_)
	state = NORMAL
	flame_timer = 0
	flame_frame_idx = 0
	cx = 0
	cy = 0
	update()

func get_seq(seq_: int) -> void:
	seq = FlameLoader.flame_seq[int(seq_)]

func update() -> void:
	if state == DEAD:
		return
	var current_time = Time.get_ticks_msec()
	update_frame(current_time)
	if_hide()

func update_frame(current_time: int) -> void:
	if current_time - flame_timer > 20:
		blank_img()
		var lEN = seq.size()
		if flame_frame_idx >= lEN:
			switch_state(DEAD)
			return
		var fridx: int = int(seq[flame_frame_idx])
		var fr: Frame = flame[fridx]
		cx = fr.cx
		cy = fr.cy
		flame_timer = current_time
		flame_frame_idx += 1

func switch_state(new_state: int) -> void:
	state = new_state
	flame_frame_idx = 0

func draw(ci: CanvasItem) -> void:
	if state == DEAD:
		return
	if flame_frame_idx <= 0 or flame_frame_idx > seq.size():
		return
	var fridx: int = int(seq[flame_frame_idx - 1])
	var fr: Frame = flame[fridx]
	fr.draw(ci, x_pos, y_pos)
