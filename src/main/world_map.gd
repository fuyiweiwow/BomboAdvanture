class_name AdventureWorldMap
extends Control

const LEVEL_CATALOG := preload("res://src/level/level_catalog.gd")
const LEVEL_PROGRESS_REPOSITORY := preload("res://src/level/level_progress_repository.gd")
const LEVEL_SESSION := preload("res://src/level/level_session.gd")
const WORLD_MAP_3D := preload("res://src/main/world_map_3d.tscn")

var catalog
var progress_repository
var map_view: SubViewportContainer
var map_viewport: SubViewport
var world_map_3d: AdventureWorldMap3D
var detail_title: Label
var detail_description: Label
var detail_state: Label
var enter_button: Button
var _selected_profile: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	catalog = LEVEL_CATALOG.new()
	progress_repository = LEVEL_PROGRESS_REPOSITORY.new()
	_build()


func _build() -> void:
	var background := ColorRect.new()
	background.color = Color("#102f36")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(background)

	map_view = SubViewportContainer.new()
	map_view.name = "WorldMap3DContainer"
	map_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_view.offset_top = 64.0
	map_view.offset_bottom = -126.0
	map_view.stretch = true
	map_view.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(map_view)

	map_viewport = SubViewport.new()
	map_viewport.name = "WorldMap3DViewport"
	map_viewport.size = Vector2i(1280, 720)
	map_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	map_viewport.handle_input_locally = true
	map_viewport.physics_object_picking = true
	map_view.add_child(map_viewport)

	var profiles := _visible_profiles()
	world_map_3d = WORLD_MAP_3D.instantiate() as AdventureWorldMap3D
	world_map_3d.configure(profiles)
	world_map_3d.level_focused.connect(_show_profile)
	world_map_3d.level_activated.connect(_enter_level)
	map_viewport.add_child(world_map_3d)

	add_child(_build_header())
	add_child(_build_detail_band())

	if not profiles.is_empty():
		_show_profile(_first_available_profile(profiles))


func _build_header() -> Control:
	var panel := PanelContainer.new()
	panel.name = "Header"
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.custom_minimum_size.y = 64.0
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.065, 0.076, 0.97)))

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	header.add_theme_constant_override("margin_left", 10)
	header.add_theme_constant_override("margin_right", 10)
	panel.add_child(header)

	var back_button := Button.new()
	back_button.text = "返回"
	back_button.custom_minimum_size = Vector2(92, 42)
	back_button.add_theme_font_size_override("font_size", 17)
	back_button.pressed.connect(_return_to_title)
	header.add_child(back_button)

	var title := Label.new()
	title.text = "希洛安大陆"
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("#f3d36c"))
	header.add_child(title)

	var reset_button := Button.new()
	reset_button.text = "重置视角"
	reset_button.tooltip_text = "恢复地图初始视角"
	reset_button.custom_minimum_size = Vector2(108, 42)
	reset_button.add_theme_font_size_override("font_size", 16)
	reset_button.pressed.connect(func(): world_map_3d.reset_camera())
	header.add_child(reset_button)
	return panel


func _build_detail_band() -> Control:
	var panel := PanelContainer.new()
	panel.name = "LevelDetail"
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.custom_minimum_size.y = 126.0
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.030, 0.055, 0.066, 0.98)))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)

	detail_state = Label.new()
	detail_state.custom_minimum_size = Vector2(106, 86)
	detail_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	detail_state.add_theme_font_size_override("font_size", 16)
	detail_state.add_theme_color_override("font_color", Color("#6ed3c5"))
	row.add_child(detail_state)

	var text_column := VBoxContainer.new()
	text_column.size_flags_horizontal = SIZE_EXPAND_FILL
	text_column.add_theme_constant_override("separation", 4)
	row.add_child(text_column)

	detail_title = Label.new()
	detail_title.add_theme_font_size_override("font_size", 22)
	detail_title.add_theme_color_override("font_color", Color("#fff0c4"))
	text_column.add_child(detail_title)

	detail_description = Label.new()
	detail_description.size_flags_vertical = SIZE_EXPAND_FILL
	detail_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_description.add_theme_font_size_override("font_size", 15)
	detail_description.add_theme_color_override("font_color", Color("#d9e4e3"))
	text_column.add_child(detail_description)

	enter_button = Button.new()
	enter_button.text = "进入关卡"
	enter_button.custom_minimum_size = Vector2(132, 52)
	enter_button.size_flags_vertical = SIZE_SHRINK_CENTER
	enter_button.add_theme_font_size_override("font_size", 18)
	enter_button.pressed.connect(_enter_selected_level)
	row.add_child(enter_button)
	return panel


func _visible_profiles() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var completed_ids: Array[String] = progress_repository.completed_level_ids()
	for raw_profile in catalog.levels():
		var level_id := str(raw_profile.get("id", ""))
		var unlocked: bool = progress_repository.is_unlocked(level_id)
		var completed: bool = completed_ids.has(level_id)
		if not unlocked and not completed:
			continue
		var profile: Dictionary = raw_profile.duplicate(true)
		profile["unlocked"] = unlocked
		profile["completed"] = completed
		result.append(profile)
	return result


func _first_available_profile(profiles: Array[Dictionary]) -> Dictionary:
	for profile in profiles:
		if bool(profile.get("unlocked", false)) and not bool(profile.get("completed", false)):
			return profile
	for profile in profiles:
		if bool(profile.get("unlocked", false)):
			return profile
	return profiles[0]


func _show_profile(profile: Dictionary) -> void:
	_selected_profile = profile.duplicate(true)
	var level_id := str(profile.get("id", ""))
	var completed := bool(profile.get("completed", false))
	var unlocked: bool = progress_repository.is_unlocked(level_id)
	var travel_mode := str(profile.get("travel_mode", "walk"))
	var travel_label: String = str({"walk": "步行", "boat": "乘船", "airship": "浮空交通"}.get(travel_mode, "步行"))
	detail_state.text = "已完成" if completed else ("可进入" if unlocked else "未解锁")
	detail_state.add_theme_color_override("font_color", Color("#6ed3c5") if completed else Color("#f1c85a"))
	detail_title.text = "第%s章-%s  %s" % [str(int(profile.get("set_index", 0)) + 1), str(profile.get("local_number", "")), str(profile.get("name", level_id))]
	detail_description.text = "%s · 前往方式：%s\n%s" % [str(profile.get("region_name", "")), travel_label, str(profile.get("description", ""))]
	enter_button.disabled = not unlocked
	world_map_3d.focus_level(level_id)


func _enter_selected_level() -> void:
	_enter_level(str(_selected_profile.get("id", "")))


func _enter_level(level_id: String) -> void:
	if level_id.is_empty() or not progress_repository.is_unlocked(level_id):
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
	var title_screen := Control.new()
	title_screen.set_script(preload("res://src/main/title_screen.gd"))
	title_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(title_screen)
	queue_free()


func _panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("#315158")
	style.set_border_width_all(1)
	style.set_corner_radius_all(0)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style
