class_name AdventureRingWorldMap
extends Node2D

signal level_focused(profile: Dictionary)
signal level_activated(level_id: String)

const GRID_COLUMNS := 48
const GRID_ROWS := 30
const TILE_WIDTH := 44.0
const TILE_HEIGHT := 22.0
const MAP_ORIGIN := Vector2(1020.0, 126.0)
const CAMERA_HOME := Vector2(1200.0, 530.0)
const CAMERA_MIN_ZOOM := 0.48
const CAMERA_MAX_ZOOM := 1.80
const CAMERA_HOME_ZOOM := 0.90

const OCEAN := Color("#326f78")
const OCEAN_DEEP := Color("#173f4d")
const PLAINS := Color("#80975c")
const FOREST := Color("#426b45")
const TUNDRA := Color("#91a896")
const SNOW := Color("#d7ded7")
const ROCK := Color("#696f68")
const DESERT := Color("#bd9659")
const COAST := Color("#91aa6c")
const INDUSTRY := Color("#777269")
const URBAN := Color("#6f827d")

var _profiles: Array[Dictionary] = []
var _marker_by_id: Dictionary = {}
var _selected_level_id := ""
var _camera: Camera2D
var _dragging := false
var _last_pointer := Vector2.ZERO
var _elapsed := 0.0

@export var show_campaign_overlay := false


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
	queue_redraw()


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
	_draw_land_shadow()
	_draw_terrain_tiles()
	_draw_waterways()
	_draw_ground_roads()
	_draw_world_routes()
	_draw_landmarks()
	_draw_region_labels()


func _draw_ocean() -> void:
	draw_rect(Rect2(-300.0, -200.0, 2700.0, 1600.0), OCEAN_DEEP)
	for band in range(5):
		var band_color := OCEAN.lightened(0.04 * float(band))
		band_color.a = 0.12 - float(band) * 0.014
		draw_rect(Rect2(-300.0, 120.0 + float(band) * 180.0, 2700.0, 180.0), band_color)
	for row in range(22):
		var y := 28.0 + float(row) * 54.0
		var offset := float(row % 2) * 42.0
		for column in range(27):
			var x := -90.0 + offset + float(column) * 94.0
			var wave := 14.0 + _hash_noise(column + 17, row + 9) * 12.0
			var alpha := 0.07 + _hash_noise(column, row) * 0.08
			draw_arc(Vector2(x, y), wave, 0.25, 2.82, 10, Color(0.63, 0.86, 0.86, alpha), 1.4, true)
			if (column + row) % 5 == 0:
				draw_line(Vector2(x - wave * 0.45, y + 5), Vector2(x + wave * 0.65, y + 5), Color(0.18, 0.48, 0.55, 0.16), 1.0)


func _draw_land_shadow() -> void:
	for row in range(GRID_ROWS):
		for column in range(GRID_COLUMNS):
			if not _is_world_tile(column, row):
				continue
			var center := _grid_to_world(Vector2(column, row)) + Vector2(14.0, 22.0)
			var diamond := _tile_diamond(center, 0.0)
			draw_colored_polygon(diamond, Color(0.02, 0.09, 0.11, 0.16))


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
			_draw_coast_detail(center - Vector2(0.0, elevation), column, row)


func _is_world_tile(column: int, row: int) -> bool:
	if _is_floating_island(column, row) or _is_southern_island(column, row):
		return true
	var x := (float(column) - 27.0) / 20.5
	var y := (float(row) - 14.0) / 12.4
	var edge_noise := (_fractal_noise(float(column) * 0.31, float(row) * 0.31) - 0.5) * 0.56
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
		return "tundra" if _fractal_noise(float(column) * 0.25, float(row) * 0.25) > 0.34 else "snow"
	if row >= 22 and column < 34:
		return "desert"
	if column >= 37 and row <= 15:
		return "rock" if row < 10 else "industry"
	if column >= 39 and row <= 21:
		return "industry"
	if column >= 27 and column <= 36 and row >= 12 and row <= 20:
		return "urban" if _fractal_noise(float(column) * 0.37, float(row) * 0.37) > 0.42 else "plains"
	if column <= 22 and row >= 9 and row <= 20:
		return "forest" if _fractal_noise(float(column) * 0.31, float(row) * 0.31) > 0.38 else "plains"
	if (column >= 24 and column <= 35 and row <= 10) or (column >= 34 and row <= 13):
		return "rock"
	if _fractal_noise(float(column) * 0.29, float(row) * 0.29) > 0.67:
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
	var relief := _fractal_noise(float(column) * 0.24, float(row) * 0.24)
	var north_east_rise := (1.0 - float(row) / float(GRID_ROWS)) * 3.4 + float(column) / float(GRID_COLUMNS) * 2.6
	if biome == "floating":
		return 23.0 + relief * 13.0
	if biome == "rock":
		return 10.0 + relief * 9.0 + north_east_rise
	if biome in ["snow", "nether"]:
		return 6.0 + relief * 7.0 + north_east_rise
	if biome == "desert":
		return 3.0 + relief * 4.0
	return 3.0 + relief * 4.0 + north_east_rise * 0.35


func _draw_tile(center: Vector2, color: Color, elevation: float) -> void:
	var diamond := _tile_diamond(center, elevation)
	var side_right := PackedVector2Array([
		diamond[1], diamond[2], diamond[2] + Vector2(0.0, elevation), diamond[1] + Vector2(0.0, elevation),
	])
	var side_left := PackedVector2Array([
		diamond[2], diamond[3], diamond[3] + Vector2(0.0, elevation), diamond[2] + Vector2(0.0, elevation),
	])
	draw_colored_polygon(side_right, color.darkened(0.34))
	draw_colored_polygon(side_left, color.darkened(0.22))
	var tint := (_fractal_noise(center.x * 0.035, center.y * 0.035) - 0.5) * 0.13
	draw_colored_polygon(diamond, color.lightened(tint))


func _tile_diamond(center: Vector2, elevation: float) -> PackedVector2Array:
	var top := center - Vector2(0.0, elevation)
	return PackedVector2Array([
		top + Vector2(0.0, -TILE_HEIGHT * 0.5),
		top + Vector2(TILE_WIDTH * 0.5, 0.0),
		top + Vector2(0.0, TILE_HEIGHT * 0.5),
		top + Vector2(-TILE_WIDTH * 0.5, 0.0),
	])


func _draw_coast_detail(center: Vector2, column: int, row: int) -> void:
	var directions: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	var diamond := _tile_diamond(center, 0.0)
	for index in range(directions.size()):
		var neighbor: Vector2i = Vector2i(column, row) + directions[index]
		if neighbor.x >= 0 and neighbor.y >= 0 and neighbor.x < GRID_COLUMNS and neighbor.y < GRID_ROWS and _is_world_tile(neighbor.x, neighbor.y):
			continue
		var from_index := index
		var to_index := (index + 1) % 4
		draw_line(diamond[from_index] + Vector2(0, 3), diamond[to_index] + Vector2(0, 3), Color(0.65, 0.91, 0.86, 0.42), 2.0, true)
		draw_line(diamond[from_index] + Vector2(0, 7), diamond[to_index] + Vector2(0, 7), Color(0.38, 0.73, 0.74, 0.18), 3.0, true)
		if _is_floating_island(column, row) and _hash_noise(column * 5 + index, row * 7) > 0.66:
			var waterfall_start := diamond[from_index].lerp(diamond[to_index], 0.52) + Vector2(0, 4)
			draw_line(waterfall_start, waterfall_start + Vector2(0, 28), Color(0.53, 0.92, 0.90, 0.58), 2.2, true)
			draw_line(waterfall_start + Vector2(3, 1), waterfall_start + Vector2(3, 23), Color(0.83, 1.0, 0.96, 0.30), 1.0, true)


func _draw_tile_detail(center: Vector2, column: int, row: int, biome: String) -> void:
	var noise := _fractal_noise(float(column) * 0.43 + 8.1, float(row) * 0.43 + 3.9)
	match biome:
		"forest":
			var tree_count := 2 + int(noise * 3.0)
			for index in range(tree_count):
				var offset := Vector2(
					(_hash_noise(column * 7 + index, row * 5 + 2) - 0.5) * 25.0,
					(_hash_noise(column * 3 + index, row * 11 + 4) - 0.5) * 9.0 - 3.0
				)
				_draw_tree(center + offset, _hash_noise(column + index * 13, row + index * 7))
		"rock":
			if noise > 0.22:
				_draw_mountain(center + Vector2(0.0, -3.0), noise, row < 8)
			elif noise > 0.08:
				_draw_rock_cluster(center, noise)
		"snow", "tundra":
			if noise > 0.72 or (row < 5 and noise > 0.51):
				_draw_mountain(center + Vector2(0, -2), 0.55 + noise * 0.40, true)
			elif noise > 0.50:
				_draw_pine(center + Vector2(-4.0, -3.0), Color("#345d55"), 0.85 + noise * 0.35)
			if noise > 0.63 and noise <= 0.72:
				_draw_pine(center + Vector2(8.0, 1.0), Color("#486f61"), 0.68)
		"desert":
			_draw_dunes(center, column, row, noise)
		"industry":
			if noise > 0.52:
				_draw_small_factory(center)
		"urban":
			if noise > 0.52:
				_draw_small_block(center, noise)
		"floating":
			if noise > 0.68:
				_draw_magic_crystal(center)
			elif noise > 0.42:
				_draw_tree(center + Vector2(2, -2), noise)
		"plains", "coast":
			if noise > 0.72:
				_draw_tree(center + Vector2(4, -2), noise)
			elif noise < 0.21 and row > 10:
				_draw_field(center, column, row)
			else:
				_draw_grass_detail(center, column, row, noise)


func _draw_tree(center: Vector2, seed: float) -> void:
	var scale_value := 0.72 + seed * 0.40
	draw_ellipse_shadow(center + Vector2(3, 2), Vector2(7, 3) * scale_value, Color(0.04, 0.10, 0.06, 0.28))
	draw_rect(Rect2(center + Vector2(-1.4, -7.0) * scale_value, Vector2(2.8, 10.0) * scale_value), Color("#5c4933"))
	var dark := Color("#294e37")
	var mid := Color("#3e6c45")
	var light := Color("#5b824c")
	draw_circle(center + Vector2(-4.0, -9.0) * scale_value, 5.8 * scale_value, dark)
	draw_circle(center + Vector2(4.0, -10.0) * scale_value, 6.2 * scale_value, mid)
	draw_circle(center + Vector2(0.0, -15.0) * scale_value, 6.6 * scale_value, light)
	draw_circle(center + Vector2(-2.0, -17.0) * scale_value, 2.1 * scale_value, Color(0.58, 0.70, 0.40, 0.65))


func _draw_pine(center: Vector2, color: Color, scale_value: float = 1.0) -> void:
	draw_ellipse_shadow(center + Vector2(4, 2), Vector2(6, 2.6) * scale_value, Color(0.03, 0.09, 0.07, 0.28))
	draw_rect(Rect2(center + Vector2(-1, -4) * scale_value, Vector2(2, 7) * scale_value), Color("#584a38"))
	for tier in range(3):
		var width := (8.0 - float(tier) * 1.6) * scale_value
		var y := (-2.0 - float(tier) * 6.0) * scale_value
		draw_colored_polygon(PackedVector2Array([
			center + Vector2(-width, y),
			center + Vector2(0, y - 13.0 * scale_value),
			center + Vector2(width, y),
		]), color.lightened(float(tier) * 0.045))


func _draw_mountain(center: Vector2, seed: float, snow_cap: bool) -> void:
	var height := 28.0 + seed * 25.0
	var width := 14.0 + seed * 7.0
	draw_ellipse_shadow(center + Vector2(7, 7), Vector2(width * 0.9, 5.5), Color(0.04, 0.07, 0.06, 0.34))
	draw_colored_polygon(PackedVector2Array([center + Vector2(-width, 6), center + Vector2(0, -height), center + Vector2(width, 6)]), Color("#4d5450"))
	draw_colored_polygon(PackedVector2Array([center + Vector2(-width, 6), center + Vector2(0, -height), center + Vector2(-2, 2)]), Color("#7b8075"))
	draw_colored_polygon(PackedVector2Array([center + Vector2(-2, 2), center + Vector2(0, -height), center + Vector2(width, 6)]), Color("#5c625d"))
	draw_line(center + Vector2(-2, -height + 8), center + Vector2(-9, -3), Color(0.78, 0.78, 0.68, 0.35), 1.2)
	draw_line(center + Vector2(2, -height + 13), center + Vector2(8, 1), Color(0.19, 0.22, 0.21, 0.42), 1.4)
	if snow_cap:
		draw_colored_polygon(PackedVector2Array([
			center + Vector2(-7, -height + 13), center + Vector2(0, -height), center + Vector2(8, -height + 15),
			center + Vector2(3, -height + 11), center + Vector2(0, -height + 16), center + Vector2(-3, -height + 11),
		]), Color("#eef1e9"))


func _draw_rock_cluster(center: Vector2, seed: float) -> void:
	for index in range(3):
		var offset := Vector2(float(index - 1) * 7.0, float(index % 2) * 3.0)
		var radius := 3.5 + _hash_noise(index, int(seed * 100.0)) * 3.0
		draw_colored_polygon(PackedVector2Array([
			center + offset + Vector2(-radius, 2), center + offset + Vector2(-2, -radius),
			center + offset + Vector2(radius, -2), center + offset + Vector2(radius * 0.7, 3),
		]), Color("#5f655d").lightened(float(index) * 0.07))


func _draw_dunes(center: Vector2, column: int, row: int, noise: float) -> void:
	var dune_color := Color(0.43, 0.29, 0.16, 0.32)
	draw_arc(center + Vector2(-4, 0), 9.0 + noise * 4.0, 3.35, 5.86, 10, dune_color, 1.4, true)
	if (column + row) % 5 == 0:
		draw_circle(center + Vector2(7, -2), 2.2, Color("#6c7540"))
		draw_line(center + Vector2(7, -2), center + Vector2(7, -9), Color("#5b5635"), 1.4)


func _draw_field(center: Vector2, column: int, row: int) -> void:
	var field_color := Color("#b3a65b") if (column + row) % 2 == 0 else Color("#78924d")
	for stripe in range(4):
		var y := float(stripe) * 2.2 - 3.0
		draw_line(center + Vector2(-10, y), center + Vector2(9, y - 1), field_color.darkened(float(stripe) * 0.035), 1.3)


func _draw_grass_detail(center: Vector2, column: int, row: int, noise: float) -> void:
	var grass_color := Color(0.25, 0.39, 0.20, 0.38)
	var x := (_hash_noise(column + 41, row + 19) - 0.5) * 18.0
	var y := (_hash_noise(column + 17, row + 73) - 0.5) * 6.0
	draw_line(center + Vector2(x, y + 2), center + Vector2(x - 1, y - 2 - noise * 2), grass_color, 1.0)
	draw_line(center + Vector2(x + 2, y + 2), center + Vector2(x + 4, y - 1), grass_color, 1.0)


func draw_ellipse_shadow(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(16):
		var angle := TAU * float(index) / 16.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)


func _draw_small_factory(center: Vector2) -> void:
	draw_ellipse_shadow(center + Vector2(4, 3), Vector2(10, 3), Color(0.04, 0.06, 0.06, 0.30))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-9, -7), center + Vector2(0, -12), center + Vector2(10, -7), center + Vector2(1, -2),
	]), Color("#716857"))
	draw_rect(Rect2(center + Vector2(-9, -7), Vector2(10, 9)), Color("#5b584f"))
	draw_rect(Rect2(center + Vector2(4, -21), Vector2(4, 16)), Color("#454b49"))
	draw_circle(center + Vector2(6, -24), 3.2, Color(0.78, 0.80, 0.75, 0.30))


func _draw_small_block(center: Vector2, seed: float) -> void:
	var height := 10.0 + seed * 8.0
	draw_ellipse_shadow(center + Vector2(4, 3), Vector2(8, 2.5), Color(0.03, 0.08, 0.09, 0.28))
	draw_rect(Rect2(center + Vector2(-6, -height), Vector2(12, height + 3)), Color("#526a6b"))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-6, -height), center + Vector2(0, -height - 4),
		center + Vector2(7, -height), center + Vector2(1, -height + 4),
	]), Color("#839894"))
	for floor_index in range(2):
		draw_line(center + Vector2(-2, -height + 4 + floor_index * 5), center + Vector2(-2, -height + 7 + floor_index * 5), Color("#76d0c8"), 1.6)
		draw_line(center + Vector2(3, -height + 4 + floor_index * 5), center + Vector2(3, -height + 7 + floor_index * 5), Color("#76d0c8"), 1.6)


func _draw_magic_crystal(center: Vector2) -> void:
	draw_circle(center + Vector2(0, -4), 8.0, Color(0.35, 0.88, 0.85, 0.09))
	draw_colored_polygon(PackedVector2Array([center + Vector2(-4, 0), center + Vector2(0, -16), center + Vector2(5, 0), center + Vector2(0, 5)]), Color("#69c6c2"))
	draw_colored_polygon(PackedVector2Array([center + Vector2(-1, -2), center + Vector2(0, -14), center + Vector2(3, -1), center + Vector2(0, 2)]), Color("#b6f0df"))


func _draw_waterways() -> void:
	_draw_river([Vector2(29, 4), Vector2(28, 8), Vector2(30, 11), Vector2(29, 15), Vector2(31, 18), Vector2(30, 23), Vector2(32, 27)])
	_draw_river([Vector2(39, 4), Vector2(38, 8), Vector2(36, 12), Vector2(37, 16), Vector2(41, 19)])
	_draw_river([Vector2(17, 9), Vector2(19, 12), Vector2(23, 14), Vector2(29, 15)])
	var hub := _grid_to_world(Vector2(32, 16))
	_draw_canal(_grid_to_world(Vector2(32, 7)), hub)
	_draw_canal(_grid_to_world(Vector2(21, 16)), _grid_to_world(Vector2(42, 16)))


func _draw_river(grid_points: Array[Vector2]) -> void:
	var anchors := PackedVector2Array()
	for point in grid_points:
		anchors.append(_grid_to_world(point) - Vector2(0.0, 5.0))
	var points := _smooth_path(anchors, 7)
	draw_polyline(points, Color(0.11, 0.23, 0.22, 0.48), 13.0, true)
	draw_polyline(points, Color("#275f69"), 9.0, true)
	draw_polyline(points, Color("#69adb0"), 5.2, true)
	draw_polyline(points, Color(0.70, 0.91, 0.86, 0.30), 1.2, true)


func _draw_canal(from: Vector2, to: Vector2) -> void:
	draw_line(from, to, Color(0.08, 0.17, 0.18, 0.48), 11.0, true)
	draw_line(from, to, Color("#2b6068"), 8.0, true)
	draw_line(from, to, Color("#7cc0c0"), 3.6, true)


func _draw_ground_roads() -> void:
	_draw_road([Vector2(11, 15), Vector2(17, 14), Vector2(23, 15), Vector2(29, 16), Vector2(32, 16)], false)
	_draw_road([Vector2(32, 16), Vector2(36, 15), Vector2(39, 12), Vector2(42, 10)], true)
	_draw_road([Vector2(32, 16), Vector2(35, 19), Vector2(39, 21), Vector2(42, 24)], true)
	_draw_road([Vector2(24, 23), Vector2(27, 20), Vector2(30, 18), Vector2(32, 16)], false)


func _draw_road(grid_points: Array[Vector2], future_rail: bool) -> void:
	var anchors := PackedVector2Array()
	for point in grid_points:
		anchors.append(_grid_to_world(point) - Vector2(0, 8))
	var points := _smooth_path(anchors, 6)
	if future_rail:
		draw_polyline(points, Color(0.08, 0.12, 0.12, 0.62), 7.0, true)
		draw_polyline(points, Color("#9ca7a0"), 4.2, true)
		draw_polyline(points, Color("#83d3c7"), 1.2, true)
		_draw_path_sleepers(points)
	else:
		draw_polyline(points, Color(0.15, 0.12, 0.08, 0.36), 7.0, true)
		draw_polyline(points, Color("#b9a477"), 4.0, true)
		draw_polyline(points, Color(0.88, 0.78, 0.56, 0.38), 1.0, true)


func _draw_path_sleepers(points: PackedVector2Array) -> void:
	for index in range(4, points.size() - 1, 5):
		var direction := points[index - 1].direction_to(points[index + 1])
		var side := direction.orthogonal() * 4.0
		draw_line(points[index] - side, points[index] + side, Color("#d5d7c7"), 1.0, true)


func _smooth_path(anchors: PackedVector2Array, subdivisions: int) -> PackedVector2Array:
	if anchors.size() < 3:
		return anchors
	var result := PackedVector2Array()
	for index in range(anchors.size() - 1):
		var p0 := anchors[maxi(0, index - 1)]
		var p1 := anchors[index]
		var p2 := anchors[index + 1]
		var p3 := anchors[mini(anchors.size() - 1, index + 2)]
		for step in range(subdivisions):
			var t := float(step) / float(subdivisions)
			var t2 := t * t
			var t3 := t2 * t
			result.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	result.append(anchors[anchors.size() - 1])
	return result


func _draw_world_routes() -> void:
	if not show_campaign_overlay or _profiles.size() < 2:
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
	_draw_village(_grid_to_world(Vector2(13, 17)), Color("#8a5d45"))
	_draw_village(_grid_to_world(Vector2(22, 18)), Color("#7e6148"))
	_draw_village(_grid_to_world(Vector2(28, 21)), Color("#9b754b"))
	_draw_netherit_gate(_grid_to_world(Vector2(39, 2)))
	_draw_castle(_grid_to_world(Vector2(18, 14)))
	_draw_future_hub(_grid_to_world(Vector2(32, 16)))
	_draw_factory_district(_grid_to_world(Vector2(40, 11)))
	_draw_modern_port(_grid_to_world(Vector2(42, 19)))
	_draw_desert_outpost(_grid_to_world(Vector2(24, 24)))
	_draw_ship(_grid_to_world(Vector2(40, 26)) + Vector2(18, 24))
	_draw_airship(_grid_to_world(Vector2(8, 8)) + Vector2(-4, -48), 0.82)
	_draw_airship(_grid_to_world(Vector2(4, 13)) + Vector2(-18, -34), 0.62)


func _draw_netherit_gate(center: Vector2) -> void:
	draw_circle(center + Vector2(0, -18), 27.0, Color(0.46, 0.82, 0.86, 0.10))
	draw_circle(center + Vector2(0, -18), 19.0, Color("#7fb7ba"))
	draw_circle(center + Vector2(0, -18), 12.0, Color("#1f3544"))
	draw_arc(center + Vector2(0, -18), 15.0, 0, TAU, 28, Color("#c2e4df"), 2.0, true)
	draw_colored_polygon(PackedVector2Array([center + Vector2(-25, 5), center + Vector2(-13, -37), center + Vector2(-4, -21), center + Vector2(10, -42), center + Vector2(25, 5)]), Color(0.78, 0.88, 0.88, 0.76))
	draw_line(center + Vector2(-17, -9), center + Vector2(-8, -32), Color(0.94, 1.0, 0.98, 0.72), 1.5)


func _draw_castle(center: Vector2) -> void:
	draw_ellipse_shadow(center + Vector2(10, 9), Vector2(39, 11), Color(0.04, 0.06, 0.05, 0.34))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-33, -2), center + Vector2(0, -18), center + Vector2(34, -2), center + Vector2(0, 16),
	]), Color("#8d846c"))
	for offset in [-18.0, 0.0, 18.0]:
		var tower_height := 42.0 + (10.0 if offset == 0.0 else 0.0)
		draw_rect(Rect2(center + Vector2(offset - 6, -tower_height), Vector2(12, tower_height - 1)), Color("#887862"))
		draw_rect(Rect2(center + Vector2(offset, -tower_height), Vector2(6, tower_height - 1)), Color("#6f6557"))
		draw_colored_polygon(PackedVector2Array([center + Vector2(offset - 10, -tower_height), center + Vector2(offset, -tower_height - 15), center + Vector2(offset + 10, -tower_height)]), Color("#375754"))
		draw_line(center + Vector2(offset - 2, -tower_height + 7), center + Vector2(offset - 2, -tower_height + 13), Color("#eed591"), 2.0)
	draw_rect(Rect2(center + Vector2(-27, -20), Vector2(54, 20)), Color("#a18d70"))
	for merlon in range(7):
		draw_rect(Rect2(center + Vector2(-26 + merlon * 8, -25), Vector2(5, 6)), Color("#aa987c"))
	draw_arc(center + Vector2(0, 0), 8.0, PI, TAU, 14, Color("#493f38"), 4.0)


func _draw_future_hub(center: Vector2) -> void:
	draw_ellipse_shadow(center + Vector2(12, 9), Vector2(44, 13), Color(0.02, 0.07, 0.08, 0.42))
	draw_circle(center, 35.0, Color("#294a50"))
	draw_arc(center, 30.0, 0.0, TAU, 40, Color("#7ad8ce"), 4.0, true)
	draw_arc(center, 22.0, 0.0, TAU, 32, Color(0.50, 0.92, 0.85, 0.40), 2.0, true)
	for offset in [-23.0, -11.0, 0.0, 12.0, 24.0]:
		var height := 35.0 + (31.0 if offset == 0.0 else (15.0 if absf(offset) < 20.0 else 0.0))
		var width := 4.0 if offset != 0.0 else 6.0
		draw_colored_polygon(PackedVector2Array([
			center + Vector2(offset - width, -5), center + Vector2(offset - width * 0.55, -height),
			center + Vector2(offset + width * 0.35, -height - 8), center + Vector2(offset + width, -5),
		]), Color("#9fbcb6").darkened(absf(offset) * 0.006))
		draw_line(center + Vector2(offset + 1, -height + 1), center + Vector2(offset + 1, -11), Color("#77e1d5"), 1.8)
	for angle_index in range(4):
		var angle := PI * 0.25 + float(angle_index) * PI * 0.5
		var from := center + Vector2(cos(angle), sin(angle)) * 33.0
		var to := center + Vector2(cos(angle), sin(angle)) * 49.0
		draw_line(from, to, Color("#a9bbb2"), 6.0, true)
		draw_line(from, to, Color("#7fe0d4"), 1.3, true)


func _draw_factory_district(center: Vector2) -> void:
	draw_ellipse_shadow(center + Vector2(12, 9), Vector2(47, 12), Color(0.03, 0.05, 0.05, 0.36))
	for index in range(5):
		var x := float(index) * 17.0 - 34.0
		var depth := float(index % 2) * 5.0
		draw_colored_polygon(PackedVector2Array([
			center + Vector2(x - 8, -15 + depth), center + Vector2(x, -20 + depth), center + Vector2(x + 9, -15 + depth), center + Vector2(x + 1, -10 + depth),
		]), Color("#80735c"))
		draw_rect(Rect2(center + Vector2(x - 8, -15 + depth), Vector2(17, 17)), Color("#625f56"))
		draw_rect(Rect2(center + Vector2(x + 3, -41 - float(index % 2) * 9.0), Vector2(5, 29 + float(index % 2) * 9.0)), Color("#3f4847"))
		draw_circle(center + Vector2(x + 6, -47 - float(index % 2) * 9.0), 5.0, Color(0.78, 0.79, 0.73, 0.18))
		draw_circle(center + Vector2(x + 9, -53 - float(index % 2) * 9.0), 7.0, Color(0.77, 0.80, 0.76, 0.10))
	for rail in range(3):
		draw_line(center + Vector2(-45, 7 + rail * 3), center + Vector2(44, 7 + rail * 3), Color("#a6aaa0"), 1.2)


func _draw_modern_port(center: Vector2) -> void:
	draw_ellipse_shadow(center + Vector2(12, 10), Vector2(48, 14), Color(0.02, 0.07, 0.09, 0.38))
	draw_colored_polygon(PackedVector2Array([center + Vector2(-42, 0), center + Vector2(0, -22), center + Vector2(43, 0), center + Vector2(0, 22)]), Color("#426f70"))
	draw_polyline(PackedVector2Array([center + Vector2(-39, 0), center + Vector2(0, -19), center + Vector2(39, 0)]), Color("#8bd2c8"), 2.0, true)
	for offset in [-25.0, -7.0, 11.0, 29.0]:
		draw_line(center + Vector2(offset, -5), center + Vector2(offset + 13, 27), Color("#d3bc77"), 3.2, true)
		draw_line(center + Vector2(offset + 13, 27), center + Vector2(offset + 22, 22), Color("#d3bc77"), 2.0, true)
		draw_line(center + Vector2(offset + 6, 10), center + Vector2(offset + 16, 7), Color("#d3bc77"), 1.5, true)
	draw_arc(center + Vector2(-8, -29), 14.0, 0.0, TAU, 24, Color("#7ce1d4"), 3.0, true)
	draw_circle(center + Vector2(-8, -29), 5.0, Color("#d8e0d7"))
	draw_rect(Rect2(center + Vector2(13, -33), Vector2(11, 30)), Color("#6b8883"))
	draw_line(center + Vector2(18, -29), center + Vector2(18, -8), Color("#8ee5d9"), 2.0)
	_draw_airship(center + Vector2(20, -66), 0.48)


func _draw_desert_outpost(center: Vector2) -> void:
	draw_ellipse_shadow(center + Vector2(8, 9), Vector2(29, 8), Color(0.15, 0.09, 0.04, 0.28))
	draw_colored_polygon(PackedVector2Array([center + Vector2(-22, 4), center + Vector2(0, -16), center + Vector2(23, 4), center + Vector2(18, 17), center + Vector2(-18, 17)]), Color("#785638"))
	draw_colored_polygon(PackedVector2Array([center + Vector2(-18, 2), center + Vector2(0, -12), center + Vector2(19, 2), center + Vector2(0, 11)]), Color("#b58a54"))
	draw_line(center + Vector2(-4, -10), center + Vector2(-4, -40), Color("#5d432e"), 3.0)
	draw_colored_polygon(PackedVector2Array([center + Vector2(-4, -40), center + Vector2(17, -33), center + Vector2(-4, -26)]), Color("#d5b25f"))


func _draw_ship(center: Vector2) -> void:
	draw_line(center + Vector2(-30, 14), center + Vector2(24, 14), Color(0.61, 0.89, 0.88, 0.35), 3.0)
	draw_colored_polygon(PackedVector2Array([center + Vector2(-27, -5), center + Vector2(24, -5), center + Vector2(14, 10), center + Vector2(-16, 11)]), Color("#d9ddd5"))
	draw_colored_polygon(PackedVector2Array([center + Vector2(-16, 5), center + Vector2(14, 5), center + Vector2(24, -5), center + Vector2(-27, -5)]), Color("#647f80"))
	draw_rect(Rect2(center + Vector2(-6, -18), Vector2(19, 13)), Color("#e3e5dc"))
	draw_rect(Rect2(center + Vector2(-2, -15), Vector2(13, 5)), Color("#3e737b"))
	draw_line(center + Vector2(5, -18), center + Vector2(5, -30), Color("#87928d"), 2.0)
	draw_colored_polygon(PackedVector2Array([center + Vector2(5, -30), center + Vector2(17, -25), center + Vector2(5, -21)]), Color("#71c9c2"))


func _draw_village(center: Vector2, roof_color: Color) -> void:
	for index in range(3):
		var offset := Vector2(float(index - 1) * 13.0, float(index % 2) * 7.0)
		draw_ellipse_shadow(center + offset + Vector2(3, 4), Vector2(8, 3), Color(0.05, 0.07, 0.04, 0.24))
		draw_rect(Rect2(center + offset + Vector2(-6, -9), Vector2(12, 11)), Color("#b8a77e"))
		draw_colored_polygon(PackedVector2Array([
			center + offset + Vector2(-8, -9), center + offset + Vector2(0, -17), center + offset + Vector2(8, -9),
		]), roof_color.lightened(float(index) * 0.05))


func _draw_airship(center: Vector2, scale_value: float) -> void:
	draw_ellipse_shadow(center + Vector2(9, 25) * scale_value, Vector2(20, 4) * scale_value, Color(0.03, 0.08, 0.09, 0.16))
	draw_ellipse_shadow(center, Vector2(20, 9) * scale_value, Color("#d8d7be"))
	draw_ellipse_shadow(center + Vector2(-4, -3) * scale_value, Vector2(12, 4) * scale_value, Color(0.98, 0.95, 0.78, 0.54))
	draw_line(center + Vector2(-8, 7) * scale_value, center + Vector2(-5, 15) * scale_value, Color("#6e6655"), 1.3)
	draw_line(center + Vector2(8, 7) * scale_value, center + Vector2(5, 15) * scale_value, Color("#6e6655"), 1.3)
	draw_rect(Rect2(center + Vector2(-7, 14) * scale_value, Vector2(14, 5) * scale_value), Color("#456d6d"))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(18, -2) * scale_value, center + Vector2(27, -8) * scale_value, center + Vector2(24, 2) * scale_value,
	]), Color("#b5b695"))


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
	if not show_campaign_overlay:
		return
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
	queue_redraw()
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
	style.bg_color = color.lightened(0.04)
	style.border_color = Color("#f8e6ad") if emphasized else Color("#263c3c")
	style.set_border_width_all(3 if emphasized else 2)
	style.set_corner_radius_all(20)
	style.shadow_color = Color(0.04, 0.08, 0.08, 0.65)
	style.shadow_size = 7 if emphasized else 5
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


func _value_noise(x: float, y: float) -> float:
	var x0 := floori(x)
	var y0 := floori(y)
	var tx := x - float(x0)
	var ty := y - float(y0)
	var sx := tx * tx * (3.0 - 2.0 * tx)
	var sy := ty * ty * (3.0 - 2.0 * ty)
	var top := lerpf(_hash_noise(x0, y0), _hash_noise(x0 + 1, y0), sx)
	var bottom := lerpf(_hash_noise(x0, y0 + 1), _hash_noise(x0 + 1, y0 + 1), sx)
	return lerpf(top, bottom, sy)


func _fractal_noise(x: float, y: float) -> float:
	var total := 0.0
	var weight := 1.0
	var weight_sum := 0.0
	var frequency := 1.0
	for octave in range(4):
		total += _value_noise(x * frequency + float(octave) * 13.7, y * frequency - float(octave) * 7.9) * weight
		weight_sum += weight
		weight *= 0.52
		frequency *= 2.03
	return total / weight_sum
