class_name AdventureRingWorldMap
extends Node2D

signal level_focused(profile: Dictionary)
signal level_activated(level_id: String)

const GRID_COLUMNS := 48
const GRID_ROWS := 30
const TILE_WIDTH := 44.0
const TILE_HEIGHT := 22.0
const MAP_ORIGIN := Vector2(1020.0, 126.0)
const CAMERA_HOME := Vector2(1020.0, 530.0)
const CAMERA_MIN_ZOOM := 0.52
const CAMERA_MAX_ZOOM := 1.12
const CAMERA_HOME_ZOOM := 0.66

const OCEAN := Color("#315d68")
const OCEAN_DEEP := Color("#244b58")
const PLAINS := Color("#81965f")
const FOREST := Color("#4f7652")
const TUNDRA := Color("#93a89d")
const SNOW := Color("#c9d6d0")
const ROCK := Color("#73776b")
const DESERT := Color("#bd9457")
const COAST := Color("#8ca978")
const INDUSTRY := Color("#7d7766")
const URBAN := Color("#71817c")

var _profiles: Array[Dictionary] = []
var _marker_by_id: Dictionary = {}
var _selected_level_id := ""
var _camera: Camera2D
var _dragging := false
var _last_pointer := Vector2.ZERO
var _elapsed := 0.0


func configure(profiles: Array[Dictionary]) -> void:
	_profiles.clear()
	for profile in profiles:
		_profiles.append(profile.duplicate(true))
	if is_inside_tree():
		_build_level_markers()
	queue_redraw()


func focus_level(level_id: String) -> void:
	if not _marker_by_id.has(level_id):
		return
	_selected_level_id = level_id
	_refresh_markers()


func reset_camera() -> void:
	if _camera == null:
		return
	_camera.position = CAMERA_HOME
	_camera.zoom = Vector2.ONE * CAMERA_HOME_ZOOM


func _ready() -> void:
	_camera = Camera2D.new()
	_camera.name = "MapCamera"
	_camera.position = CAMERA_HOME
	_camera.zoom = Vector2.ONE * CAMERA_HOME_ZOOM
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 8.0
	_camera.enabled = true
	add_child(_camera)
	_build_level_markers()
	set_process(true)
	set_process_unhandled_input(true)


func _process(delta: float) -> void:
	_elapsed += delta
	for level_id in _marker_by_id:
		var marker := _marker_by_id[level_id] as Button
		if marker == null:
			continue
		var base_y := float(marker.get_meta("base_y", marker.position.y))
		var phase := float(marker.get_meta("phase", 0.0))
		marker.position.y = base_y + sin(_elapsed * 2.2 + phase) * 2.2


func _unhandled_input(event: InputEvent) -> void:
	if _camera == null:
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_WHEEL_UP and mouse.pressed:
			_set_zoom(_camera.zoom.x + 0.07)
			get_viewport().set_input_as_handled()
		elif mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse.pressed:
			_set_zoom(_camera.zoom.x - 0.07)
			get_viewport().set_input_as_handled()
		elif mouse.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			_dragging = mouse.pressed
			_last_pointer = mouse.position
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		_camera.position -= motion.relative / _camera.zoom.x
		_camera.position.x = clampf(_camera.position.x, 540.0, 1490.0)
		_camera.position.y = clampf(_camera.position.y, 300.0, 800.0)
		_last_pointer = motion.position
		get_viewport().set_input_as_handled()


func _set_zoom(value: float) -> void:
	var next_zoom := clampf(value, CAMERA_MIN_ZOOM, CAMERA_MAX_ZOOM)
	_camera.zoom = Vector2.ONE * next_zoom


func _draw() -> void:
	_draw_ocean()
	_draw_terrain_tiles()
	_draw_waterways()
	_draw_world_routes()
	_draw_landmarks()
	_draw_region_labels()


func _draw_ocean() -> void:
	draw_rect(Rect2(-300.0, -200.0, 2700.0, 1600.0), OCEAN_DEEP)
	for row in range(18):
		var y := 50.0 + float(row) * 64.0
		var offset := float(row % 2) * 38.0
		for column in range(24):
			var x := -80.0 + offset + float(column) * 104.0
			var alpha := 0.10 + _hash_noise(column, row) * 0.08
			draw_arc(Vector2(x, y), 18.0, 0.15, 2.75, 10, Color(0.55, 0.78, 0.78, alpha), 2.0)


func _draw_terrain_tiles() -> void:
	for diagonal in range(GRID_COLUMNS + GRID_ROWS - 1):
		for row in range(GRID_ROWS):
			var column := diagonal - row
			if column < 0 or column >= GRID_COLUMNS:
				continue
			if not _is_world_tile(column, row):
				continue
			var center := _grid_to_world(Vector2(column, row))
			var biome := _biome_at(column, row)
			var color := _biome_color(biome)
			var elevation := _elevation_at(column, row, biome)
			_draw_tile(center, color, elevation)
			_draw_tile_detail(center - Vector2(0.0, elevation), column, row, biome)


func _is_world_tile(column: int, row: int) -> bool:
	if _is_floating_island(column, row) or _is_southern_island(column, row):
		return true
	var x := (float(column) - 27.0) / 20.5
	var y := (float(row) - 14.0) / 12.4
	var edge_noise := (_hash_noise(column, row) - 0.5) * 0.46
	var shape := 1.0 - x * x - y * y + edge_noise
	shape += sin(float(column) * 0.72) * 0.07 + cos(float(row) * 0.91) * 0.06
	if column < 13 and row < 8:
		shape -= 0.38
	if column < 12 and row > 20:
		shape -= 0.34
	if column > 42 and row > 21:
		shape -= 0.30
	return shape > 0.05


func _is_floating_island(column: int, row: int) -> bool:
	return (
		_in_ellipse(column, row, 5, 8, 3, 2)
		or _in_ellipse(column, row, 3, 12, 2, 2)
		or _in_ellipse(column, row, 8, 13, 2, 2)
		or _in_ellipse(column, row, 7, 5, 1, 1)
	)


func _is_southern_island(column: int, row: int) -> bool:
	return (
		_in_ellipse(column, row, 35, 27, 3, 1)
		or _in_ellipse(column, row, 41, 26, 3, 2)
		or _in_ellipse(column, row, 45, 23, 2, 1)
		or _in_ellipse(column, row, 29, 28, 2, 1)
	)


func _in_ellipse(column: int, row: int, center_x: int, center_y: int, radius_x: int, radius_y: int) -> bool:
	var x := float(column - center_x) / float(maxi(1, radius_x))
	var y := float(row - center_y) / float(maxi(1, radius_y))
	return x * x + y * y <= 1.0


func _biome_at(column: int, row: int) -> String:
	if _is_floating_island(column, row):
		return "floating"
	if _is_southern_island(column, row):
		return "coast"
	if row <= 3 and column >= 32:
		return "nether"
	if row <= 5:
		return "snow"
	if row <= 8:
		return "tundra" if _hash_noise(column, row) > 0.28 else "snow"
	if row >= 22 and column < 34:
		return "desert"
	if column >= 37 and row <= 15:
		return "rock" if row < 10 else "industry"
	if column >= 39 and row <= 21:
		return "industry"
	if column >= 27 and column <= 36 and row >= 12 and row <= 20:
		return "urban" if _hash_noise(column, row) > 0.36 else "plains"
	if column <= 22 and row >= 9 and row <= 20:
		return "forest" if _hash_noise(column, row) > 0.30 else "plains"
	if (column >= 24 and column <= 35 and row <= 10) or (column >= 34 and row <= 13):
		return "rock"
	if _hash_noise(column, row) > 0.80:
		return "forest"
	return "plains"


func _biome_color(biome: String) -> Color:
	return {
		"plains": PLAINS,
		"forest": FOREST,
		"tundra": TUNDRA,
		"snow": SNOW,
		"nether": Color("#aabfc2"),
		"rock": ROCK,
		"desert": DESERT,
		"coast": COAST,
		"floating": Color("#6f956c"),
		"industry": INDUSTRY,
		"urban": URBAN,
	}.get(biome, PLAINS)


func _elevation_at(column: int, row: int, biome: String) -> float:
	if biome == "floating":
		return 13.0 + _hash_noise(column, row) * 8.0
	if biome == "rock":
		return 8.0 + _hash_noise(column, row) * 5.0
	if biome in ["snow", "nether"]:
		return 5.0
	return 3.0 + _hash_noise(column, row) * 2.0


func _draw_tile(center: Vector2, color: Color, elevation: float) -> void:
	var half_w := TILE_WIDTH * 0.5
	var half_h := TILE_HEIGHT * 0.5
	var top := center - Vector2(0.0, elevation)
	var diamond := PackedVector2Array([
		top + Vector2(0.0, -half_h),
		top + Vector2(half_w, 0.0),
		top + Vector2(0.0, half_h),
		top + Vector2(-half_w, 0.0),
	])
	var side_right := PackedVector2Array([
		diamond[1], diamond[2], diamond[2] + Vector2(0.0, elevation), diamond[1] + Vector2(0.0, elevation),
	])
	var side_left := PackedVector2Array([
		diamond[2], diamond[3], diamond[3] + Vector2(0.0, elevation), diamond[2] + Vector2(0.0, elevation),
	])
	draw_colored_polygon(side_right, color.darkened(0.30))
	draw_colored_polygon(side_left, color.darkened(0.20))
	draw_colored_polygon(diamond, color.lightened((_hash_noise(int(center.x), int(center.y)) - 0.5) * 0.10))
	draw_polyline(diamond + PackedVector2Array([diamond[0]]), color.darkened(0.18), 1.0, true)


func _draw_tile_detail(center: Vector2, column: int, row: int, biome: String) -> void:
	var noise := _hash_noise(column + 81, row + 39)
	match biome:
		"forest":
			if noise > 0.30:
				_draw_tree(center + Vector2((noise - 0.5) * 16.0, -4.0), noise)
		"rock":
			if noise > 0.20:
				_draw_mountain(center + Vector2(0.0, -4.0), noise, row < 8)
		"snow", "tundra":
			if noise > 0.73:
				_draw_pine(center + Vector2(0.0, -3.0), Color("#41665f"))
		"desert":
			if noise > 0.80:
				draw_line(center + Vector2(-7, 2), center + Vector2(7, -1), Color("#8f663d"), 2.0)
		"industry":
			if noise > 0.58:
				_draw_small_factory(center)
		"urban":
			if noise > 0.64:
				_draw_small_block(center, noise)
		"floating":
			if noise > 0.56:
				_draw_magic_crystal(center)


func _draw_tree(center: Vector2, seed: float) -> void:
	draw_rect(Rect2(center + Vector2(-1.5, -5.0), Vector2(3.0, 10.0)), Color("#594b35"))
	draw_circle(center + Vector2(-3.0, -7.0), 5.5, Color("#315a42"))
	draw_circle(center + Vector2(3.0, -8.0), 6.0, Color("#3f704a"))
	draw_circle(center + Vector2(0.0, -12.0), 6.0 + seed * 2.0, Color("#527f4c"))


func _draw_pine(center: Vector2, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([center + Vector2(-7, 1), center + Vector2(0, -17), center + Vector2(7, 1)]), color)
	draw_colored_polygon(PackedVector2Array([center + Vector2(-5, -5), center + Vector2(0, -20), center + Vector2(5, -5)]), color.lightened(0.08))


func _draw_mountain(center: Vector2, seed: float, snow_cap: bool) -> void:
	var height := 18.0 + seed * 10.0
	draw_colored_polygon(PackedVector2Array([center + Vector2(-13, 5), center + Vector2(0, -height), center + Vector2(14, 5)]), Color("#555d55"))
	draw_colored_polygon(PackedVector2Array([center, center + Vector2(0, -height), center + Vector2(14, 5)]), Color("#7f8374"))
	if snow_cap:
		draw_colored_polygon(PackedVector2Array([center + Vector2(-4, -height + 8), center + Vector2(0, -height), center + Vector2(5, -height + 9), center + Vector2(1, -height + 7)]), Color("#e3e8de"))


func _draw_small_factory(center: Vector2) -> void:
	draw_rect(Rect2(center + Vector2(-8, -8), Vector2(16, 12)), Color("#5c594e"))
	draw_rect(Rect2(center + Vector2(3, -17), Vector2(4, 11)), Color("#454b49"))
	draw_circle(center + Vector2(5, -20), 3.0, Color(0.72, 0.76, 0.70, 0.38))


func _draw_small_block(center: Vector2, seed: float) -> void:
	var height := 10.0 + seed * 8.0
	draw_rect(Rect2(center + Vector2(-6, -height), Vector2(12, height + 3)), Color("#526a6b"))
	draw_line(center + Vector2(-2, -height + 3), center + Vector2(-2, -2), Color("#70c4bd"), 2.0)


func _draw_magic_crystal(center: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([center + Vector2(-4, 0), center + Vector2(0, -14), center + Vector2(5, 0), center + Vector2(0, 5)]), Color("#69c6c2"))


func _draw_waterways() -> void:
	_draw_river([Vector2(29, 4), Vector2(28, 8), Vector2(30, 11), Vector2(29, 15), Vector2(31, 18), Vector2(30, 23), Vector2(32, 27)])
	_draw_river([Vector2(39, 4), Vector2(38, 8), Vector2(36, 12), Vector2(37, 16), Vector2(41, 19)])
	_draw_river([Vector2(17, 9), Vector2(19, 12), Vector2(23, 14), Vector2(29, 15)])
	var hub := _grid_to_world(Vector2(32, 16))
	_draw_canal(_grid_to_world(Vector2(32, 7)), hub)
	_draw_canal(_grid_to_world(Vector2(21, 16)), _grid_to_world(Vector2(42, 16)))


func _draw_river(grid_points: Array[Vector2]) -> void:
	var points := PackedVector2Array()
	for point in grid_points:
		points.append(_grid_to_world(point) - Vector2(0.0, 5.0))
	draw_polyline(points, Color("#214d5b"), 10.0, true)
	draw_polyline(points, Color("#65a9b0"), 6.0, true)


func _draw_canal(from: Vector2, to: Vector2) -> void:
	draw_line(from, to, Color("#294f58"), 8.0, true)
	draw_line(from, to, Color("#78bac0"), 4.0, true)


func _draw_world_routes() -> void:
	if _profiles.size() < 2:
		return
	for index in range(_profiles.size() - 1):
		var from_profile := _profiles[index]
		var to_profile := _profiles[index + 1]
		var from := _profile_to_world(from_profile)
		var to := _profile_to_world(to_profile)
		var mode := str(to_profile.get("travel_mode", "walk"))
		var color := Color("#d4c38b")
		if mode == "boat":
			color = Color("#79c7cf")
		elif mode == "airship":
			color = Color("#c2a7d4")
		draw_line(from, to, Color(0.08, 0.11, 0.11, 0.72), 8.0, true)
		draw_line(from, to, color, 3.0, true)
		_draw_direction_chevrons(from, to, color)


func _draw_direction_chevrons(from: Vector2, to: Vector2, color: Color) -> void:
	var distance := from.distance_to(to)
	if distance < 36.0:
		return
	var direction := from.direction_to(to)
	var side := direction.orthogonal()
	var count := maxi(1, int(distance / 54.0))
	for step in range(1, count + 1):
		var center := from.lerp(to, float(step) / float(count + 1))
		var triangle := PackedVector2Array([
			center + direction * 7.0,
			center - direction * 5.0 + side * 5.0,
			center - direction * 5.0 - side * 5.0,
		])
		draw_colored_polygon(triangle, color)


func _draw_landmarks() -> void:
	_draw_netherit_gate(_grid_to_world(Vector2(39, 2)))
	_draw_castle(_grid_to_world(Vector2(18, 14)))
	_draw_future_hub(_grid_to_world(Vector2(32, 16)))
	_draw_factory_district(_grid_to_world(Vector2(40, 11)))
	_draw_modern_port(_grid_to_world(Vector2(42, 19)))
	_draw_desert_outpost(_grid_to_world(Vector2(24, 24)))
	_draw_ship(_grid_to_world(Vector2(40, 26)) + Vector2(18, 24))


func _draw_netherit_gate(center: Vector2) -> void:
	draw_circle(center + Vector2(0, -14), 18.0, Color("#6fa7ae"))
	draw_circle(center + Vector2(0, -14), 11.0, Color("#233b49"))
	draw_colored_polygon(PackedVector2Array([center + Vector2(-20, 3), center + Vector2(-10, -27), center + Vector2(0, -13), center + Vector2(10, -31), center + Vector2(21, 3)]), Color(0.76, 0.87, 0.87, 0.72))


func _draw_castle(center: Vector2) -> void:
	for offset in [-18.0, 0.0, 18.0]:
		draw_rect(Rect2(center + Vector2(offset - 6, -34), Vector2(12, 32)), Color("#7b6b58"))
		draw_colored_polygon(PackedVector2Array([center + Vector2(offset - 9, -34), center + Vector2(offset, -45), center + Vector2(offset + 9, -34)]), Color("#445b59"))
	draw_rect(Rect2(center + Vector2(-25, -16), Vector2(50, 18)), Color("#9a8568"))


func _draw_future_hub(center: Vector2) -> void:
	draw_circle(center, 28.0, Color("#344f56"))
	draw_arc(center, 23.0, 0.0, TAU, 32, Color("#69c8c6"), 4.0)
	for offset in [-18.0, 0.0, 18.0]:
		var height := 42.0 + (18.0 if offset == 0.0 else 0.0)
		draw_colored_polygon(PackedVector2Array([center + Vector2(offset - 5, -5), center + Vector2(offset - 3, -height), center + Vector2(offset + 3, -height - 8), center + Vector2(offset + 6, -5)]), Color("#93b9b4"))
		draw_line(center + Vector2(offset, -height + 2), center + Vector2(offset, -10), Color("#72d7ce"), 2.0)


func _draw_factory_district(center: Vector2) -> void:
	for index in range(4):
		var x := float(index) * 15.0 - 23.0
		draw_rect(Rect2(center + Vector2(x - 6, -18), Vector2(13, 20)), Color("#665e4d"))
		draw_rect(Rect2(center + Vector2(x + 2, -38 - float(index % 2) * 8.0), Vector2(5, 22 + float(index % 2) * 8.0)), Color("#444a47"))


func _draw_modern_port(center: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([center + Vector2(-34, 0), center + Vector2(0, -18), center + Vector2(35, 0), center + Vector2(0, 18)]), Color("#3f696b"))
	for offset in [-18.0, 0.0, 18.0]:
		draw_line(center + Vector2(offset, -5), center + Vector2(offset + 12, 22), Color("#d1bd78"), 3.0)
	draw_arc(center + Vector2(-5, -23), 11.0, 0.0, TAU, 20, Color("#72cbc6"), 3.0)


func _draw_desert_outpost(center: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([center + Vector2(-22, 4), center + Vector2(0, -16), center + Vector2(23, 4), center + Vector2(18, 17), center + Vector2(-18, 17)]), Color("#785638"))
	draw_line(center + Vector2(-4, -10), center + Vector2(-4, -40), Color("#5d432e"), 3.0)
	draw_colored_polygon(PackedVector2Array([center + Vector2(-4, -40), center + Vector2(17, -33), center + Vector2(-4, -26)]), Color("#d5b25f"))


func _draw_ship(center: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([center + Vector2(-20, -4), center + Vector2(18, -4), center + Vector2(11, 8), center + Vector2(-12, 9)]), Color("#d4d7cb"))
	draw_rect(Rect2(center + Vector2(-5, -14), Vector2(15, 10)), Color("#4f8588"))
	draw_line(center + Vector2(-22, 13), center + Vector2(20, 13), Color(0.55, 0.82, 0.82, 0.55), 2.0)


func _draw_region_labels() -> void:
	var font := ThemeDB.fallback_font
	_draw_map_label(font, "冥河极寒带", _grid_to_world(Vector2(39, 1)) + Vector2(-54, -60), Color("#dcece7"))
	_draw_map_label(font, "洛安德自治区", _grid_to_world(Vector2(17, 16)) + Vector2(-64, 35), Color("#f1deb1"))
	_draw_map_label(font, "达特核心区", _grid_to_world(Vector2(31, 18)) + Vector2(-48, 52), Color("#b8eee5"))
	_draw_map_label(font, "赫伦工业海岸", _grid_to_world(Vector2(40, 10)) + Vector2(20, -44), Color("#ead7ad"))
	_draw_map_label(font, "南部拓殖带", _grid_to_world(Vector2(23, 25)) + Vector2(-46, 42), Color("#f1d08f"))
	_draw_map_label(font, "普赛提亚群岛", _grid_to_world(Vector2(39, 27)) + Vector2(-42, 54), Color("#c5ece6"))
	_draw_map_label(font, "西部浮空岛", _grid_to_world(Vector2(5, 9)) + Vector2(-62, -45), Color("#d8c8ea"))


func _draw_map_label(font: Font, text: String, position: Vector2, color: Color) -> void:
	draw_string(font, position + Vector2(2, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color(0.06, 0.09, 0.10, 0.88))
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, color)


func _build_level_markers() -> void:
	for marker in _marker_by_id.values():
		if is_instance_valid(marker):
			(marker as Node).queue_free()
	_marker_by_id.clear()
	for index in range(_profiles.size()):
		var profile := _profiles[index]
		var level_id := str(profile.get("id", ""))
		if level_id.is_empty():
			continue
		var marker := Button.new()
		marker.name = "Level_%s" % level_id
		marker.text = str(profile.get("local_number", index + 1))
		marker.position = _profile_to_world(profile) - Vector2(20.0, 20.0)
		marker.custom_minimum_size = Vector2(40.0, 40.0)
		marker.size = Vector2(40.0, 40.0)
		marker.pivot_offset = Vector2(20.0, 20.0)
		marker.tooltip_text = "%s · %s" % [str(profile.get("region_name", "")), str(profile.get("name", level_id))]
		marker.add_theme_font_size_override("font_size", 16)
		marker.set_meta("profile", profile)
		marker.set_meta("base_y", marker.position.y)
		marker.set_meta("phase", float(index) * 0.73)
		marker.pressed.connect(_on_marker_pressed.bind(level_id))
		marker.mouse_entered.connect(_on_marker_hovered.bind(level_id))
		marker.gui_input.connect(_on_marker_input.bind(level_id))
		add_child(marker)
		_marker_by_id[level_id] = marker
	_refresh_markers()


func _on_marker_pressed(level_id: String) -> void:
	_selected_level_id = level_id
	_refresh_markers()
	var marker := _marker_by_id.get(level_id) as Button
	if marker != null:
		level_focused.emit((marker.get_meta("profile", {}) as Dictionary).duplicate(true))


func _on_marker_hovered(level_id: String) -> void:
	var marker := _marker_by_id.get(level_id) as Button
	if marker != null:
		level_focused.emit((marker.get_meta("profile", {}) as Dictionary).duplicate(true))


func _on_marker_input(event: InputEvent, level_id: String) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.double_click:
			var marker := _marker_by_id.get(level_id) as Button
			if marker != null:
				var profile := marker.get_meta("profile", {}) as Dictionary
				if bool(profile.get("unlocked", false)):
					level_activated.emit(level_id)


func _refresh_markers() -> void:
	for level_id in _marker_by_id:
		var marker := _marker_by_id[level_id] as Button
		if marker == null:
			continue
		var profile := marker.get_meta("profile", {}) as Dictionary
		var selected: bool = str(level_id) == _selected_level_id
		var completed := bool(profile.get("completed", false))
		var base_color := Color("#6bb6a8") if completed else Color("#e0b850")
		if selected:
			base_color = Color("#fff0a8")
		marker.add_theme_color_override("font_color", Color("#172423"))
		marker.add_theme_color_override("font_hover_color", Color("#172423"))
		marker.add_theme_stylebox_override("normal", _marker_style(base_color, selected))
		marker.add_theme_stylebox_override("hover", _marker_style(base_color.lightened(0.12), true))
		marker.add_theme_stylebox_override("pressed", _marker_style(base_color.darkened(0.08), true))
		var marker_scale := 1.16 if selected else (0.78 if completed else 1.0)
		marker.scale = Vector2.ONE * marker_scale
		marker.z_index = 30 if selected else 25


func _marker_style(color: Color, emphasized: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("#f8e6ad") if emphasized else Color("#263c3c")
	style.set_border_width_all(3 if emphasized else 2)
	style.set_corner_radius_all(3)
	style.shadow_color = Color(0.04, 0.08, 0.08, 0.65)
	style.shadow_size = 5
	return style


func _profile_to_world(profile: Dictionary) -> Vector2:
	var normalized: Vector2 = profile.get("map_position", Vector2(0.5, 0.5))
	var column := lerpf(4.0, 45.0, normalized.x)
	var row := lerpf(1.0, 28.0, normalized.y)
	return _grid_to_world(Vector2(column, row)) - Vector2(0.0, 28.0)


func _grid_to_world(grid: Vector2) -> Vector2:
	return MAP_ORIGIN + Vector2((grid.x - grid.y) * TILE_WIDTH * 0.5, (grid.x + grid.y) * TILE_HEIGHT * 0.5)


func _hash_noise(x: int, y: int) -> float:
	return fposmod(sin(float(x) * 12.9898 + float(y) * 78.233) * 43758.5453, 1.0)
