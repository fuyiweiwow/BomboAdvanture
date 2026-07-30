class_name AdventureWorldMap
extends Control

const LEVEL_CATALOG := preload("res://src/level/level_catalog.gd")
const LEVEL_PROGRESS_REPOSITORY := preload("res://src/level/level_progress_repository.gd")
const LEVEL_SESSION := preload("res://src/level/level_session.gd")

const NODE_SIZE := 48.0
const MAP_MARGIN := Vector2.ZERO
const CANVAS_MIN_SIZE := Vector2(1536.0, 1024.0)

class MapCanvas:
	extends Control

	var profiles: Array[Dictionary] = []
	var regions: Array[Dictionary] = []
	var background_texture: Texture2D

	const BACKGROUND_PATH := "res://assets/concepts/hiloan_global_world_map_v4_3d_platformer_diorama.png"

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		background_texture = _load_background_texture()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		var bounds = Rect2(Vector2.ZERO, size)
		_draw_background(bounds)
		_draw_region_fields()
		_draw_routes()

	func _load_background_texture() -> Texture2D:
		var image = Image.new()
		var err = image.load(ProjectSettings.globalize_path(BACKGROUND_PATH))
		if err == OK:
			return ImageTexture.create_from_image(image)
		var imported = ResourceLoader.load(BACKGROUND_PATH)
		if imported is Texture2D:
			return imported
		push_warning("World map background missing: " + BACKGROUND_PATH)
		return null

	func _draw_background(bounds: Rect2) -> void:
		draw_rect(bounds, Color(0.020, 0.075, 0.115))
		if background_texture != null:
			draw_texture_rect(background_texture, bounds, false)
		draw_rect(bounds, Color(0.02, 0.05, 0.07, 0.10))
		draw_line(Vector2(0.0, 0.0), Vector2(size.x, 0.0), Color(0.62, 0.86, 1.0, 0.25), 2.0, true)
		draw_line(Vector2(0.0, size.y), Vector2(size.x, size.y), Color(0.01, 0.02, 0.03, 0.34), 10.0, true)

	func _draw_region_fields() -> void:
		for region in regions:
			var center: Vector2 = region.get("world_point", Vector2.ZERO)
			var color: Color = region.get("color", Color(0.45, 0.55, 0.48))
			draw_circle(center, 86.0, Color(color.r, color.g, color.b, 0.12))
			draw_arc(center, 88.0, -0.35, TAU - 0.35, 64, Color(color.r, color.g, color.b, 0.55), 3.0, true)
			draw_arc(center, 96.0, 0.25, TAU + 0.25, 64, Color(0.75, 0.94, 1.0, 0.22), 2.0, true)

	func _draw_routes() -> void:
		if profiles.size() <= 1:
			return
		for i in range(profiles.size() - 1):
			var from_profile = profiles[i]
			var to_profile = profiles[i + 1]
			var from_point: Vector2 = from_profile.get("world_point", Vector2.ZERO)
			var to_point: Vector2 = to_profile.get("world_point", Vector2.ZERO)
			var unlocked = bool(from_profile.get("unlocked", false)) and bool(to_profile.get("unlocked", false))
			_draw_route_segment(from_point, to_point, unlocked, i)

	func _draw_route_segment(from_point: Vector2, to_point: Vector2, unlocked: bool, index: int) -> void:
		var delta = to_point - from_point
		var distance = delta.length()
		if distance <= 1.0:
			return
		var normal = Vector2(-delta.y, delta.x).normalized()
		var bend = min(distance * 0.16, 64.0) * (1.0 if index % 2 == 0 else -1.0)
		var control = from_point.lerp(to_point, 0.5) + normal * bend
		var points = PackedVector2Array()
		for step in range(18):
			var t = float(step) / 17.0
			points.append(from_point.lerp(control, t).lerp(control.lerp(to_point, t), t))
		var main_color = Color(0.42, 0.86, 1.0, 0.90) if unlocked else Color(0.34, 0.42, 0.48, 0.72)
		var bead_color = Color(1.0, 0.78, 0.22, 0.95) if unlocked else Color(0.28, 0.32, 0.36, 0.82)
		draw_polyline(points, Color(0.02, 0.04, 0.06, 0.70), 14.0, true)
		draw_polyline(points, Color(main_color.r, main_color.g, main_color.b, 0.28), 10.0, true)
		draw_polyline(points, main_color, 4.0, true)
		draw_circle(_quadratic_point(from_point, control, to_point, 0.5), 5.0, bead_color)

	func _quadratic_point(from_point: Vector2, control: Vector2, to_point: Vector2, t: float) -> Vector2:
		return from_point.lerp(control, t).lerp(control.lerp(to_point, t), t)

	func _point(normalized: Vector2) -> Vector2:
		return Vector2(normalized.x * size.x, normalized.y * size.y)

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
	map_canvas.regions = _regions_with_world_points()
	scroll.add_child(map_canvas)

	for region in map_canvas.regions:
		_add_region_label(region)
	for profile in profiles:
		_add_level_node(profile)

	root.add_child(_build_detail_band())

	if not profiles.is_empty():
		var focus_profile = _first_available_profile(profiles)
		_show_profile(focus_profile)
	call_deferred("_center_initial_view")

func _build_header() -> Control:
	var panel = PanelContainer.new()
	panel.custom_minimum_size.y = 72
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.050, 0.080, 0.095)))

	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	panel.add_child(header)

	var back_button = Button.new()
	back_button.text = "返回"
	back_button.custom_minimum_size = Vector2(104, 44)
	back_button.add_theme_font_size_override("font_size", 18)
	back_button.pressed.connect(_return_to_title)
	header.add_child(back_button)

	var title = Label.new()
	title.text = "希洛安大陆"
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.98, 0.82, 0.32))
	header.add_child(title)

	var count_label = Label.new()
	count_label.text = "%d 段记忆" % catalog.levels().size()
	count_label.custom_minimum_size.x = 132
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_label.add_theme_font_size_override("font_size", 16)
	count_label.add_theme_color_override("font_color", Color(0.72, 0.84, 0.86))
	header.add_child(count_label)
	return panel

func _build_detail_band() -> Control:
	var panel = PanelContainer.new()
	panel.custom_minimum_size.y = 124
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.040, 0.065, 0.078)))

	var label = Label.new()
	label.custom_minimum_size.y = 96
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color(0.90, 0.94, 0.96))
	panel.add_child(label)
	detail_label = label
	return panel

func _canvas_size() -> Vector2:
	return CANVAS_MIN_SIZE

func _profiles_with_world_points() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var canvas_size = _canvas_size()
	for raw_profile in catalog.levels():
		var profile = raw_profile.duplicate(true)
		profile["world_point"] = _world_point(profile.get("map_position", Vector2.ZERO), canvas_size)
		var level_id = str(profile.get("id", ""))
		profile["unlocked"] = progress_repository.is_unlocked(level_id)
		profile["completed"] = progress_repository.completed_level_ids().has(level_id)
		result.append(profile)
	return result

func _regions_with_world_points() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var canvas_size = _canvas_size()
	for raw_region in catalog.map_sets():
		var region = raw_region.duplicate(true)
		region["world_point"] = _world_point(region.get("position", Vector2.ZERO), canvas_size)
		result.append(region)
	return result

func _world_point(normalized: Variant, canvas_size: Vector2) -> Vector2:
	var value = normalized if normalized is Vector2 else Vector2.ZERO
	return Vector2(MAP_MARGIN.x + value.x * (canvas_size.x - MAP_MARGIN.x * 2.0), MAP_MARGIN.y + value.y * (canvas_size.y - MAP_MARGIN.y * 2.0))

func _add_region_label(region: Dictionary) -> void:
	var label = Label.new()
	label.name = "Region_%s" % str(region.get("id", ""))
	label.text = "第%d章  %s" % [int(region.get("chapter", 0)), str(region.get("name", ""))]
	label.position = region.get("world_point", Vector2.ZERO) + Vector2(-92.0, 72.0)
	label.size = Vector2(184.0, 28.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.94, 0.90, 0.72))
	label.add_theme_color_override("font_outline_color", Color(0.03, 0.05, 0.07, 0.95))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_canvas.add_child(label)

func _add_level_node(profile: Dictionary) -> void:
	var level_id = str(profile.get("id", ""))
	var unlocked = bool(profile.get("unlocked", false))
	var completed = bool(profile.get("completed", false))
	var point = profile.get("world_point", Vector2.ZERO)
	var button = Button.new()
	button.name = "Level_%s" % level_id
	button.text = str(profile.get("local_number", profile.get("number", "?"))) if unlocked else "?"
	button.position = point - Vector2(NODE_SIZE * 0.5, NODE_SIZE * 0.5)
	button.size = Vector2(NODE_SIZE, NODE_SIZE)
	button.add_theme_font_size_override("font_size", 21 if unlocked else 17)
	button.tooltip_text = _tooltip(profile, unlocked)
	button.disabled = not unlocked
	button.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.06, 0.95))
	button.add_theme_constant_override("outline_size", 3)
	button.add_theme_stylebox_override("normal", _level_style(Color(0.20, 0.74, 0.54, 0.92) if completed else Color(0.12, 0.45, 0.86, 0.92)))
	button.add_theme_stylebox_override("hover", _level_style(Color(1.0, 0.72, 0.20, 0.96)))
	button.add_theme_stylebox_override("pressed", _level_style(Color(1.0, 0.84, 0.30, 0.98)))
	button.add_theme_stylebox_override("disabled", _level_style(Color(0.12, 0.14, 0.16, 0.78)))
	button.mouse_entered.connect(func(): _show_profile(profile))
	button.focus_entered.connect(func(): _show_profile(profile))
	if unlocked:
		button.pressed.connect(func(): _enter_level(level_id))
	map_canvas.add_child(button)
	level_buttons[level_id] = button

func _first_available_profile(profiles: Array[Dictionary]) -> Dictionary:
	for profile in profiles:
		if bool(profile.get("unlocked", false)) and not bool(profile.get("completed", false)):
			return profile
	for profile in profiles:
		if bool(profile.get("unlocked", false)):
			return profile
	return profiles[0]

func _center_initial_view() -> void:
	if scroll == null or map_canvas == null:
		return
	var selected_point = _selected_profile.get("world_point", Vector2.ZERO)
	scroll.scroll_horizontal = max(0, int(selected_point.x - scroll.size.x * 0.5))
	scroll.scroll_vertical = max(0, int(selected_point.y - scroll.size.y * 0.5))

func _tooltip(profile: Dictionary, unlocked: bool) -> String:
	if not unlocked:
		return "完成前一段记忆后解锁"
	return "%s\n%s" % [str(profile.get("name", "")), str(profile.get("description", ""))]

func _show_profile(profile: Dictionary) -> void:
	_selected_profile = profile
	if detail_label == null:
		return
	var level_id = str(profile.get("id", ""))
	var completed = progress_repository.completed_level_ids().has(level_id)
	var state = "已完成" if completed else ("可进入" if progress_repository.is_unlocked(level_id) else "未解锁")
	detail_label.text = "%s  第%s章-%s  |  %s\n%s  |  起点 %s  终点 %s" % [
		state,
		str(profile.get("set_index", 0) + 1),
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
	style.border_color = Color(0.92, 0.98, 1.0, 0.96)
	style.set_border_width_all(3)
	style.set_corner_radius_all(int(NODE_SIZE * 0.5))
	style.shadow_color = Color(0.00, 0.05, 0.08, 0.42)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)
	return style

func _panel_style(color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.18, 0.27, 0.28)
	style.set_border_width_all(1)
	style.set_corner_radius_all(0)
	return style
