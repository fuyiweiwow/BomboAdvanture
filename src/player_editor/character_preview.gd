extends Node2D
class_name CharacterPreview

var _character: Dictionary = {}
var _orient: String = "D"
var _frame_idxs: Dictionary = {}
var _timer: int = 0

func set_character(character: Dictionary) -> void:
	_character = character
	_orient = "D"
	_reset_frames()
	queue_redraw()

func set_orientation(orient: String) -> void:
	if orient in ["U", "D", "L", "R"] and _character.has("STAND_" + orient):
		_orient = orient
		_reset_frames()
		queue_redraw()

func _reset_frames() -> void:
	_frame_idxs.clear()
	if _character.is_empty():
		return
	var key = "STAND_" + _orient
	if not _character.has(key):
		return
	for component in _character[key].keys():
		if component in ["Cx", "Cy", "NAME"]:
			continue
		_frame_idxs[component] = 0
	_timer = Time.get_ticks_msec()

func _process(_delta: float) -> void:
	if _character.is_empty():
		return
	var now = Time.get_ticks_msec()
	if now - _timer > 200:
		_timer = now
		for component in _frame_idxs.keys():
			var key = "STAND_" + _orient
			if _character.has(key) and _character[key].has(component):
				var frames = _character[key][component]
				if not frames.is_empty():
					_frame_idxs[component] = (_frame_idxs[component] + 1) % frames.size()
		queue_redraw()

func _draw() -> void:
	if _character.is_empty():
		return
	var key = "STAND_" + _orient
	if not _character.has(key):
		return

	var cx = _character[key].get("Cx", 0)
	var cy = _character[key].get("Cy", 0)

	for component in Player.CHARACTER_COMPONENTS[_orient]:
		if not _character[key].has(component):
			continue
		var frames: Array = _character[key][component]
		if frames.is_empty():
			continue
		var idx = _frame_idxs.get(component, 0)
		if idx >= frames.size():
			idx = 0
		var fr: Frame = frames[idx]
		fr.draw(self, cx, cy)
