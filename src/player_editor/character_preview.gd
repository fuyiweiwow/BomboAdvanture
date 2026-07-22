extends Node2D
class_name CharacterPreview

var _character: Dictionary = {}
var _orient: String = "D"
var _frame_idxs: Dictionary = {}
var _timer: int = 0
var _anim_interval: int = 200
var _moving: bool = false
var _tint_color: Color = Color.WHITE

var _bomb_active: bool = false
var _bomb_frames: Array = []
var _bomb_frame_idx: int = 0
var _bomb_timer: int = 0
var _bomb_interval: int = 300
var _bomb_phase: String = ""
var _bomb_start_time: int = 0
var _bomb_pos: Vector2 = Vector2.ZERO

var _flame_active: bool = false
var _flame_frames: Dictionary = {}
var _flame_seq: Array = []
var _flame_frame_idx: int = 0
var _flame_timer: int = 0

func _orient_key() -> String:
	return _orient if _moving else "STAND_" + _orient

func set_character(character: Dictionary, initial_orient: String = "D", tint_color: Color = Color.WHITE) -> void:
	_character = character
	_orient = initial_orient if (_character.has("STAND_" + initial_orient)) else "D"
	_moving = false
	_anim_interval = _character.get("INTERVAL", 200)
	_tint_color = tint_color
	_reset_frames()
	_cancel_bomb()
	queue_redraw()

func set_orientation(orient: String) -> void:
	if orient in ["U", "D", "L", "R"] and _character.has("STAND_" + orient):
		_orient = orient
		_reset_frames()
		queue_redraw()

func is_moving() -> bool:
	return _moving

func set_moving(moving: bool) -> void:
	if moving == _moving:
		return
	_moving = moving
	_anim_interval = _character.get("INTERVAL", 100) if moving else 200
	_reset_frames()
	queue_redraw()

func _reset_frames() -> void:
	_frame_idxs.clear()
	if _character.is_empty():
		return
	var key = _orient_key()
	if not _character.has(key):
		return
	for component in _character[key].keys():
		if component in ["Cx", "Cy", "NAME"]:
			continue
		_frame_idxs[component] = 0
	_timer = Time.get_ticks_msec()

func start_bomb(frames: Array, interval: int) -> void:
	_bomb_frames = frames
	_bomb_interval = interval
	_bomb_frame_idx = 0
	_bomb_timer = Time.get_ticks_msec()
	_bomb_start_time = _bomb_timer
	_bomb_phase = "planting"
	_bomb_active = true
	_bomb_pos = Vector2.ZERO
	queue_redraw()

func _cancel_bomb() -> void:
	_bomb_active = false
	_bomb_frames = []
	_bomb_phase = ""
	_flame_active = false
	_flame_frames = {}
	_flame_seq = []

func _start_explosion() -> void:
	_flame_frames = {}
	for orient in ["FLAME_C", "FLAME_R", "FLAME_U", "FLAME_L", "FLAME_D"]:
		var frames = FlameLoader.get_flame(orient)
		if not frames.is_empty():
			_flame_frames[orient] = frames
	_flame_seq = FlameLoader.flame_seq.duplicate()
	if _flame_seq.is_empty() or _flame_seq[0].is_empty():
		return
	_flame_frame_idx = 0
	_flame_timer = Time.get_ticks_msec()
	_flame_active = true

const FLAME_POSITIONS = [
	["FLAME_C", 0, 0],
	["FLAME_R", 1, 0], ["FLAME_R", 2, 0],
	["FLAME_L", -1, 0], ["FLAME_L", -2, 0],
	["FLAME_U", 0, -1], ["FLAME_U", 0, -2],
	["FLAME_D", 0, 1], ["FLAME_D", 0, 2],
]

func _draw_flames() -> void:
	if not _flame_active or _flame_seq.is_empty():
		return
	var seq = _flame_seq[0]
	if _flame_frame_idx >= seq.size():
		return
	var fridx = int(seq[_flame_frame_idx])
	for pos in FLAME_POSITIONS:
		var orient: String = pos[0]
		var dx: int = pos[1]
		var dy: int = pos[2]
		var frames: Array = _flame_frames.get(orient, [])
		if frames.is_empty() or fridx >= frames.size():
			continue
		var fr: Frame = frames[fridx]
		var ox = _bomb_pos.x + 20 + dx * 32
		var oy = _bomb_pos.y + 10 + dy * 32
		fr.draw(self, ox, oy)

func _process(_delta: float) -> void:
	var now = Time.get_ticks_msec()
	var redraw = false

	if not _character.is_empty():
		if now - _timer > _anim_interval:
			_timer = now
			var key = _orient_key()
			for component in _frame_idxs.keys():
				if _character.has(key) and _character[key].has(component):
					var frames = _character[key][component]
					if not frames.is_empty():
						_frame_idxs[component] = (_frame_idxs[component] + 1) % frames.size()
			redraw = true

	if _bomb_active:
		if _bomb_phase == "planting":
			if now - _bomb_timer > _bomb_interval:
				_bomb_frame_idx += 1
				_bomb_timer = now
				if _bomb_frame_idx >= _bomb_frames.size():
					_bomb_frame_idx = _bomb_frames.size() - 1
					_bomb_phase = "exploding"
					_bomb_start_time = now
					_start_explosion()
				redraw = true
		elif _bomb_phase == "exploding":
			if now - _bomb_start_time > 1500:
				_cancel_bomb()
			redraw = true

	if _flame_active:
		if now - _flame_timer > 20:
			_flame_frame_idx += 1
			_flame_timer = now
			if _flame_frame_idx >= _flame_seq[0].size():
				_flame_active = false
			redraw = true

	if redraw:
		queue_redraw()

func _draw() -> void:
	if not _character.is_empty():
		var key = _orient_key()
		if _character.has(key):
			var cx = _character[key].get("Cx", 0)
			var cy = _character[key].get("Cy", 0)
			var comp_colors: Dictionary = _character.get("COLORS", {})
			for component in LayerConfig.draw_order[_orient]:
				if not _character[key].has(component):
					continue
				var frames: Array = _character[key][component]
				if frames.is_empty():
					continue
				var idx = _frame_idxs.get(component, 0)
				if idx >= frames.size():
					idx = 0
				var fr: Frame = frames[idx]
				fr.draw(self, cx, cy, comp_colors.get(component, _tint_color))

	if _bomb_active and _bomb_frames.size() > 0:
		var idx = clampi(_bomb_frame_idx, 0, _bomb_frames.size() - 1)
		if _bomb_phase == "planting":
			var fr: Frame = _bomb_frames[idx]
			fr.draw(self, _bomb_pos.x, _bomb_pos.y)

	_draw_flames()