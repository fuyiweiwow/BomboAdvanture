@tool
extends Node2D

# Test preview for hybrid body+face system.
# Preview test characters with different face decorations.

var _character: Dictionary = {}
var _orient: String = "D"
var _moving: bool = false
var _frame_idx: int = 0
var _timer: int = 0

@onready var _face_label: Label = $FaceLabel if has_node("FaceLabel") else null

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_load_character("body0", "happy")
	
	# Face toggle with keyboard
	print("=== Test Preview Controls ===")
	print("  1-5: Switch face (happy/angry/shy/closed_eyes/blank)")
	print("  WASD: Change orientation")
	print("  Space: Toggle walk/stand")


func _load_character(body_name: String, face_name: String) -> void:
	_character = TestCharacterLoader.get_character(body_name, face_name)
	if _face_label:
		_face_label.text = "Face: " + face_name
	queue_redraw()
	print("  Loaded: body=%s face=%s" % [body_name, face_name])


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1: _load_character("body0", "happy")
			KEY_2: _load_character("body0", "angry")
			KEY_3: _load_character("body0", "shy")
			KEY_4: _load_character("body0", "closed_eyes")
			KEY_5: _load_character("body0", "blank")
			KEY_W: _set_orient("U"); _moving = true
			KEY_S: _set_orient("D"); _moving = true
			KEY_A: _set_orient("L"); _moving = true
			KEY_D: _set_orient("R"); _moving = true
			KEY_SPACE: _moving = !_moving; queue_redraw()


func _set_orient(orient: String) -> void:
	if _character.has("STAND_" + orient):
		_orient = orient
		_frame_idx = 0
		queue_redraw()


func _process(_delta: float) -> void:
	if _character.is_empty():
		return
	
	var now = Time.get_ticks_msec()
	var interval = 80 if _moving else 200
	if now - _timer > interval:
		_timer = now
		_frame_idx += 1
		queue_redraw()


func _draw() -> void:
	if _character.is_empty():
		return
	
	var key = _orient if _moving else "STAND_" + _orient
	if not _character.has(key):
		return
	
	var cx = _character[key].get("Cx", 0)
	var cy = _character[key].get("Cy", 0)
	
	# Draw in order: Body first, then Face overlay
	for component in ["Body", "Face"]:
		if not _character[key].has(component):
			continue
		var frames: Array = _character[key][component]
		if frames.is_empty():
			continue
		var idx = _frame_idx % frames.size()
		var fr: Frame = frames[idx]
		fr.draw(self, cx, cy)
