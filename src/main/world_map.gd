class_name AdventureWorldMap
extends Control

const LEVEL_CATALOG := preload("res://src/level/level_catalog.gd")
const LEVEL_PROGRESS_REPOSITORY := preload("res://src/level/level_progress_repository.gd")
const LEVEL_SESSION := preload("res://src/level/level_session.gd")

const NODE_SIZE := 54.0
const REGION_SPACING := 160.0
const LEVEL_SPACING := 82.0
const MAP_MARGIN := Vector2(96.0, 86.0)

class MapCanvas:
	extends Control

	var profiles: Array[Dictionary] = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		var bounds = Rect2(Vector2.ZERO, size)
		draw_rect(bounds, Color(0.035, 0.105, 0.155))
		_draw_island(bounds)
		_draw_route()
		_draw_landmarks()

	func _draw_island(bounds: Rect2) -> void:
		var inset = Rect2(bounds.position + Vector2(42, 36), bounds.size - Vector2(84, 72))
		if inset.size.x <= 0 or inset.size.y <= 0:
			return
		var island = PackedVector2Array([
			_point(inset, Vector2(0.02, 0.76)),
			_point(inset, Vector2(0.06, 0.34)),
			_point(inset, Vector2(0.20, 0.16)),
			_point(inset, Vector2(0.44, 0.25)),
			_point(inset, Vector2(0.58, 0.09)),
			_point(inset, Vector2(0.94, 0.12)),
			_point(inset, Vector2(0.99, 0.43)),
			_point(inset, Vector2(0.87, 0.80)),
			_point(inset, Vector2(0.58, 0.93)),
			_point(inset, Vector2(0.29, 0.84)),
		])
		draw_colored_polygon(island, Color(0.15, 0.31, 0.22))
		draw_polyline(island + PackedVector2Array([island[0]]), Color(0.50, 0.70, 0.42), 5.0, true)
		draw_polyline(island + PackedVector2Array([island[0]]), Color(0.09, 0.17, 0.10, 0.58), 2.0, true)

	func _draw_route() -> void:
		var path = PackedVector2Array()
		for profile in profiles:
			path.append(profile.get("world_point", Vector2.ZERO))
		if path.size() > 1:
			draw_polyline(path, Color(0.95, 0.74, 0.28, 0.88), 7.0, true)
			draw_polyline(path, Color(0.36, 0.20, 0.07, 0.60), 2.0, true)

	func _draw_landmarks() -> void:
		for marker in [Vector2(0.14, 0.42), Vector2(0.23, 0.34), Vector2(0.72, 0.29), Vector2(0.78, 0.37)]:
			var p = Vector2(marker.x * size.x, marker.y * size.y)
			draw_circle(p, 13.0, Color(0.08, 0.25, 0.14))
			draw_circle(p + Vector2(0, -7), 7.0, Color(0.18, 0.42, 0.20))
		for marker in [Vector2(0.44, 0.74), Vector2(0.51, 0.77), Vector2(0.84, 0.50)]:
			var p = Vector2(marker.x * size.x, marker.y * size.y)
			draw_circle(p, 16.0, Color(0.62, 0.16, 0.05))
			draw_circle(p, 8.0, Color(1.0, 0.48, 0.08))
		for marker in [Vector2(0.12, 0.66), Vector2(0.37, 0.55), Vector2(0.88, 0.23)]:
			draw_circle(Vector2(marker.x * size.x, marker.y * size.y), 10.0, Color(0.82, 0.92, 1.0, 0.72))

	func _point(rect: Rect2, normalized: Vector2) -> Vector2:
		return rect.position + Vector2(normalized.x * rect.size.x, normalized.y * rect.size.y)

var catalog
var progress_repository
var level_buttons: Dictionary = {}
var detail_label: Label
var map_canvas: MapCanvas
var scroll: ScrollContainer
var _selected_profile: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	catalog = LEVEL_CATALOG.new()
	progress_repository = LEVEL_PROGRESS_REPOSITORY.new()
	_build()

func _build() -> void:
	var root = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	root.add_child(_build_header())

	scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	root.add_child(scroll)

	var profiles = _profiles_with_world_points()
	map_canvas = MapCanvas.new()
	map_canvas.name = "WorldMapCanvas"
	map_canvas.custom_minimum_size = _canvas_size()
	map_canvas.size = map_canvas.custom_minimum_size
	map_canvas.profiles = profiles
	scroll.add_child(map_canvas)

	for profile in profiles:
		_add_level_node(profile)

	root.add_child(_build_detail_band())

	if not profiles.is_empty():
		_show_profile(profiles[0])
	call_deferred("_center_initial_view")

func _build_header() -> Control:
	var header = HBoxContainer.new()
	header.custom_minimum_size.y = 70
	header.add_theme_constant_override("separation", 12)

	var back_button = Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(104, 42)
	back_button.add_theme_font_size_override("font_size", 18)
	back_button.pressed.connect(_return_to_title)
	header.add_child(back_button)

	var title = Label.new()
	title.text = "LEVEL MAP"
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.34))
	header.add_child(title)

	var right_pad = Control.new()
	right_pad.custom_minimum_size.x = 104
	header.add_child(right_pad)
	return header

func _build_detail_band() -> Control:
	var panel = PanelContainer.new()
	panel.custom_minimum_size.y = 110

	var label = Label.new()
	label.custom_minimum_size.y = 88
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color(0.90, 0.94, 0.96))
	panel.add_child(label)
	detail_label = label
	return panel

func _canvas_size() -> Vector2:
	var sets = catalog.map_sets()
	var set_count = max(1, sets.size())
	var max_set_size = 1
	for set_profile in sets:
		max_set_size = max(max_set_size, (set_profile.get("maps", []) as Array).size())
	return Vector2(
		max(1120.0, MAP_MARGIN.x * 2.0 + REGION_SPACING * float(max(1, set_count - 1)) + NODE_SIZE),
		max(620.0, MAP_MARGIN.y * 2.0 + LEVEL_SPACING * float(max(1, max_set_size - 1)) + NODE_SIZE)
	)

func _profiles_with_world_points() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var canvas_size = _canvas_size()
	for raw_profile in catalog.levels():
		var profile = raw_profile.duplicate(true)
		profile["world_point"] = _world_point(profile, canvas_size)
		result.append(profile)
	return result

func _world_point(profile: Dictionary, canvas_size: Vector2) -> Vector2:
	var set_index = int(profile.get("set_index", 0))
	var local_index = int(profile.get("local_index", 0))
	var set_size = max(1, int(profile.get("set_size", 1)))
	var start_y = (canvas_size.y - LEVEL_SPACING * float(max(0, set_size - 1))) * 0.5
	var wave = sin(float(set_index) * 1.37) * 24.0
	return Vector2(MAP_MARGIN.x + REGION_SPACING * float(set_index), start_y + LEVEL_SPACING * float(local_index) + wave)

func _add_level_node(profile: Dictionary) -> void:
	var level_id = str(profile.get("id", ""))
	var unlocked = progress_repository.is_unlocked(level_id)
	var completed = progress_repository.completed_level_ids().has(level_id)
	var point = profile.get("world_point", Vector2.ZERO)
	var button = Button.new()
	button.name = "Level_%s" % level_id
	button.text = str(profile.get("local_number", profile.get("number", "?"))) if unlocked else "LOCK"
	button.position = point - Vector2(NODE_SIZE * 0.5, NODE_SIZE * 0.5)
	button.size = Vector2(NODE_SIZE, NODE_SIZE)
	button.add_theme_font_size_override("font_size", 21 if unlocked else 10)
	button.tooltip_text = _tooltip(profile, unlocked)
	button.disabled = not unlocked
	button.add_theme_stylebox_override("normal", _level_style(Color(0.16, 0.52, 0.32) if completed else Color(0.14, 0.34, 0.52)))
	button.add_theme_stylebox_override("hover", _level_style(Color(0.94, 0.62, 0.16)))
	button.add_theme_stylebox_override("pressed", _level_style(Color(0.95, 0.76, 0.22)))
	button.add_theme_stylebox_override("disabled", _level_style(Color(0.16, 0.18, 0.20)))
	button.mouse_entered.connect(func(): _show_profile(profile))
	button.focus_entered.connect(func(): _show_profile(profile))
	if unlocked:
		button.pressed.connect(func(): _enter_level(level_id))
	map_canvas.add_child(button)
	level_buttons[level_id] = button

func _center_initial_view() -> void:
	if scroll == null or map_canvas == null:
		return
	var selected_point = _selected_profile.get("world_point", Vector2.ZERO)
	scroll.scroll_horizontal = max(0, int(selected_point.x - scroll.size.x * 0.5))
	scroll.scroll_vertical = max(0, int(selected_point.y - scroll.size.y * 0.5))

func _tooltip(profile: Dictionary, unlocked: bool) -> String:
	if not unlocked:
		return "Complete the previous level to unlock"
	return "%s\n%s" % [str(profile.get("name", "")), str(profile.get("description", ""))]

func _show_profile(profile: Dictionary) -> void:
	_selected_profile = profile
	if detail_label == null:
		return
	var level_id = str(profile.get("id", ""))
	var completed = progress_repository.completed_level_ids().has(level_id)
	var state = "COMPLETED" if completed else ("READY" if progress_repository.is_unlocked(level_id) else "LOCKED")
	detail_label.text = "%s  %s-%s  |  %s\n%s  |  Start %s  Finish %s" % [
		state,
		str(profile.get("region_name", "")),
		str(profile.get("local_number", "")),
		str(profile.get("name", "")),
		str(profile.get("description", "")),
		str(profile.get("begin", Vector2i.ZERO)),
		str(profile.get("finish", Vector2i.ZERO)),
	]

func _enter_level(level_id: String) -> void:
	if not progress_repository.is_unlocked(level_id):
		return
	if not LEVEL_SESSION.select_level(level_id):
		return
	var select = load("res://src/player_editor/character_select.gd").new()
	if select is Control:
		(select as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(select)
	queue_free()

func _return_to_title() -> void:
	LEVEL_SESSION.clear()
	var ts = Control.new()
	ts.set_script(preload("res://src/main/title_screen.gd"))
	ts.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(ts)
	queue_free()

func _level_style(color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.86, 0.91, 0.82)
	style.set_border_width_all(3)
	style.set_corner_radius_all(int(NODE_SIZE * 0.5))
	return style
