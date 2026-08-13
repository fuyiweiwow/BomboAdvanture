class_name AdventureCampaignMapCanvas
extends Node2D

signal level_focused(profile: Dictionary)
signal level_activated(level_id: String)

const DESIGN_GRID_COLUMNS := 48
const DESIGN_GRID_ROWS := 30
const GRID_COLUMNS := 120
const GRID_ROWS := 75
const TILE_WIDTH := 35.0
const TILE_HEIGHT := 17.5
const MAP_ORIGIN := Vector2(1900.0, 180.0)
const CAMERA_HOME := Vector2(2300.0, 980.0)
const CAMERA_MIN_ZOOM := 0.34
const CAMERA_MAX_ZOOM := 2.70
const CAMERA_HOME_ZOOM := 0.38

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

const RIVER_PATHS := [
	[Vector2(29, 4), Vector2(28, 8), Vector2(30, 11), Vector2(29, 15), Vector2(31, 18), Vector2(30, 23), Vector2(31, 26)],
	[Vector2(39, 4), Vector2(38, 8), Vector2(36, 12), Vector2(37, 16), Vector2(39, 18), Vector2(39, 20), Vector2(41, 22)],
	[Vector2(17, 9), Vector2(19, 12), Vector2(23, 14), Vector2(29, 15)],
]

const CANAL_PATHS := [
	[Vector2(32, 7), Vector2(32, 16)],
	[Vector2(21, 16), Vector2(42, 16)],
]

const ROAD_PATHS := [
	{"points": [Vector2(11, 15), Vector2(17, 14), Vector2(20, 15), Vector2(21, 17), Vector2(27, 17), Vector2(30, 17), Vector2(32, 16)], "future": false},
	{"points": [Vector2(32, 16), Vector2(33, 15), Vector2(36, 15), Vector2(39, 12), Vector2(42, 10)], "future": true},
	{"points": [Vector2(32, 16), Vector2(35, 19), Vector2(39, 20), Vector2(41, 20)], "future": true},
	{"points": [Vector2(24, 23), Vector2(27, 20), Vector2(30, 18), Vector2(32, 16)], "future": false},
]

const LAKE_BASINS := [
	{"center": Vector2(17.0, 9.2), "radius": Vector2(1.8, 1.05)},
	{"center": Vector2(13.4, 18.8), "radius": Vector2(1.45, 0.82)},
	{"center": Vector2(27.0, 21.4), "radius": Vector2(1.25, 0.72)},
]

var _profiles: Array[Dictionary] = []
var _marker_by_id: Dictionary = {}
var _campaign_marker_cells: Dictionary = {}
var _selected_level_id := ""
var _camera: Camera2D
var _dragging := false
var _last_pointer := Vector2.ZERO
var _elapsed := 0.0

@export var show_campaign_overlay := false
@export var show_campaign_routes := false


func configure(profiles: Array[Dictionary]) -> void:
	_profiles.clear()
	for profile in profiles:
		_profiles.append(profile.duplicate(true))
	_assign_campaign_positions()
	if is_inside_tree():
		_build_level_markers()
	queue_redraw()


func focus_level(level_id: String) -> void:
	if not _marker_by_id.has(level_id):
		return
	_selected_level_id = level_id
	var marker := _marker_by_id[level_id] as Button
	if _camera != null and marker != null:
		var profile := marker.get_meta("profile", {}) as Dictionary
		_camera.position = _profile_to_world(profile)
	_refresh_markers()
	if show_campaign_routes:
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
		_camera.position.x = clampf(_camera.position.x, 180.0, 3900.0)
		_camera.position.y = clampf(_camera.position.y, 220.0, 2160.0)
		_last_pointer = motion.position
		get_viewport().set_input_as_handled()


func _set_zoom(value: float) -> void:
	var next_zoom := clampf(value, CAMERA_MIN_ZOOM, CAMERA_MAX_ZOOM)
	_camera.zoom = Vector2.ONE * next_zoom


func _draw() -> void:
	_draw_ocean()
	_draw_land_shadow()
	_draw_terrain_tiles()
	_draw_lakes_and_wetlands()
	_draw_waterways()
	_draw_landmark_foundations()
	_draw_ground_roads()
	_draw_bridges()
	_draw_terrain_details()
	_draw_world_routes()
	_draw_landmarks()
	_draw_region_labels()


func _draw_ocean() -> void:
	draw_rect(Rect2(-5000.0, -3000.0, 12000.0, 8000.0), OCEAN_DEEP)
	for band in range(7):
		var band_color := OCEAN.lightened(0.035 * float(band))
		band_color.a = 0.10 - float(band) * 0.009
		draw_rect(Rect2(-5000.0, 40.0 + float(band) * 170.0, 12000.0, 180.0), band_color)
	for row in range(28):
		var y := 28.0 + float(row) * 54.0
		var offset := float(row % 2) * 42.0
		for column in range(46):
			var x := -90.0 + offset + float(column) * 94.0
			var wave := 14.0 + _hash_noise(column + 17, row + 9) * 12.0
			var alpha := 0.07 + _hash_noise(column, row) * 0.08
			draw_arc(Vector2(x, y), wave, 0.25, 2.82, 10, Color(0.63, 0.86, 0.86, alpha), 1.4, true)
			if (column + row) % 5 == 0:
				draw_line(Vector2(x - wave * 0.45, y + 5), Vector2(x + wave * 0.65, y + 5), Color(0.18, 0.48, 0.55, 0.16), 1.0)
	for current_index in range(11):
		var current_center := Vector2(430.0 + float(current_index) * 365.0, 330.0 + float(current_index % 4) * 390.0)
		var current_width := 105.0 + _hash_noise(current_index + 7, 31) * 75.0
		draw_arc(current_center, current_width, 3.38, 5.78, 30, Color(0.48, 0.78, 0.79, 0.10), 4.0, true)
		draw_arc(current_center + Vector2(18, 9), current_width * 0.72, 3.38, 5.78, 24, Color(0.67, 0.90, 0.87, 0.08), 1.5, true)


func _draw_land_shadow() -> void:
	for row in range(GRID_ROWS):
		for column in range(GRID_COLUMNS):
			if not _is_world_tile(column, row):
				continue
			var center := _grid_to_world(Vector2(column, row)) + Vector2(9.0, 14.0)
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
			_draw_coast_detail(center - Vector2(0.0, elevation), column, row)


func _draw_terrain_details() -> void:
	for diagonal in range(GRID_COLUMNS + GRID_ROWS - 1):
		for row in range(GRID_ROWS):
			var column := diagonal - row
			if column < 0 or column >= GRID_COLUMNS or not _is_world_tile(column, row):
				continue
			if _is_campaign_clearing(Vector2i(column, row)):
				continue
			var biome := _biome_at(column, row)
			var elevation := _elevation_at(column, row, biome)
			var center := _grid_to_world(Vector2(column, row)) - Vector2(0.0, elevation)
			_draw_tile_detail(center, column, row, biome)


func _is_world_tile(column: int, row: int) -> bool:
	if _is_floating_island(column, row) or _is_southern_island(column, row) or _is_nether_land(column, row):
		return true
	var design := _grid_to_design(Vector2(column, row))
	var x := (design.x - 27.0) / 20.5
	var y := (design.y - 14.0) / 12.4
	var edge_noise := (_fractal_noise(design.x * 0.52, design.y * 0.52) - 0.5) * 0.56
	var shape := 1.0 - x * x - y * y + edge_noise
	shape += sin(design.x * 0.72) * 0.07 + cos(design.y * 0.91) * 0.06
	if design.x < 13 and design.y < 8:
		shape -= 0.38
	if design.x < 12 and design.y > 20:
		shape -= 0.34
	if design.x > 42 and design.y > 21:
		shape -= 0.30
	return shape > 0.05


func _is_floating_island(column: int, row: int) -> bool:
	var design := _grid_to_design(Vector2(column, row))
	return (
		_in_ellipse(design.x, design.y, 5, 8, 3, 2)
		or _in_ellipse(design.x, design.y, 3, 12, 2, 2)
		or _in_ellipse(design.x, design.y, 8, 13, 2, 2)
		or _in_ellipse(design.x, design.y, 7, 5, 1, 1)
	)


func _is_southern_island(column: int, row: int) -> bool:
	var design := _grid_to_design(Vector2(column, row))
	return (
		_in_ellipse(design.x, design.y, 35, 27, 3, 1)
		or _in_ellipse(design.x, design.y, 41, 26, 3, 2)
		or _in_ellipse(design.x, design.y, 45, 23, 2, 1)
		or _in_ellipse(design.x, design.y, 29, 28, 2, 1)
	)


func _is_nether_land(column: int, row: int) -> bool:
	var design := _grid_to_design(Vector2(column, row))
	# An irregular polar peninsula anchors the Nether source to the ice cap.
	var x := (design.x - 39.0) / 3.35
	var y := (design.y - 2.0) / 2.25
	var edge_noise := (_fractal_noise(design.x * 0.96 + 11.0, design.y * 0.96 + 5.0) - 0.5) * 0.42
	var polar_mass := 1.0 - x * x - y * y + edge_noise > 0.08
	var ice_neck := _in_ellipse(design.x, design.y, 37.2, 3.6, 2.1, 1.15)
	return polar_mass or ice_neck


func _in_ellipse(column: float, row: float, center_x: float, center_y: float, radius_x: float, radius_y: float) -> bool:
	var x := (column - center_x) / maxf(1.0, radius_x)
	var y := (row - center_y) / maxf(1.0, radius_y)
	return x * x + y * y <= 1.0


func _biome_at(column: int, row: int) -> String:
	var design := _grid_to_design(Vector2(column, row))
	if _is_floating_island(column, row):
		return "floating"
	if _is_southern_island(column, row):
		return "coast"
	if design.y <= 3 and design.x >= 32:
		return "nether"
	if design.y <= 5:
		return "snow"
	if design.y <= 8:
		return "tundra" if _fractal_noise(design.x * 0.42, design.y * 0.42) > 0.34 else "snow"
	if design.y >= 22 and design.x < 34:
		return "desert"
	if design.x >= 37 and design.y <= 15:
		return "rock" if design.y < 10 else "industry"
	if design.x >= 39 and design.y <= 21:
		return "industry"
	if design.x >= 27 and design.x <= 36 and design.y >= 12 and design.y <= 20:
		return "urban" if _fractal_noise(design.x * 0.62, design.y * 0.62) > 0.42 else "plains"
	if design.x <= 22 and design.y >= 9 and design.y <= 20:
		return "forest" if _fractal_noise(design.x * 0.52, design.y * 0.52) > 0.38 else "plains"
	if (design.x >= 24 and design.x <= 35 and design.y <= 10) or (design.x >= 34 and design.y <= 13):
		return "rock"
	if _fractal_noise(design.x * 0.49, design.y * 0.49) > 0.67:
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
	var design := _grid_to_design(Vector2(column, row))
	var relief := _fractal_noise(design.x * 0.40, design.y * 0.40)
	var north_east_rise := (1.0 - float(row) / float(GRID_ROWS)) * 3.4 + float(column) / float(GRID_COLUMNS) * 2.6
	var base_elevation: float
	if biome == "floating":
		return 23.0 + relief * 13.0
	if biome == "rock":
		base_elevation = 10.0 + relief * 9.0 + north_east_rise
	elif biome in ["snow", "nether"]:
		base_elevation = 6.0 + relief * 7.0 + north_east_rise
	elif biome == "desert":
		base_elevation = 3.0 + relief * 4.0
	else:
		base_elevation = 3.0 + relief * 4.0 + north_east_rise * 0.35
	return _river_valley_elevation(_grid_to_design(Vector2(column, row)), base_elevation)


func _river_valley_elevation(design: Vector2, base_elevation: float) -> float:
	var river_heights := [Vector2(15.0, 4.0), Vector2(16.0, 4.0), Vector2(12.0, 9.2)]
	var result := base_elevation
	var channel_floor := INF
	for path_index in range(RIVER_PATHS.size()):
		var nearest := _distance_and_progress_on_path(design, RIVER_PATHS[path_index])
		var distance := nearest.x
		if distance > 1.45:
			continue
		var heights: Vector2 = river_heights[path_index]
		var valley_height := lerpf(heights.x, heights.y, nearest.y)
		if distance <= 0.82:
			channel_floor = minf(channel_floor, valley_height)
		else:
			var blend := smoothstep(0.82, 1.45, distance)
			result = minf(result, lerpf(valley_height, base_elevation, blend))
	return channel_floor if channel_floor < INF else result


func _distance_and_progress_on_path(point: Vector2, path: Array) -> Vector2:
	var total_length := 0.0
	for index in range(path.size() - 1):
		total_length += (path[index + 1] as Vector2).distance_to(path[index] as Vector2)
	var nearest_distance := INF
	var nearest_progress := 0.0
	var traversed := 0.0
	for index in range(path.size() - 1):
		var from := path[index] as Vector2
		var to := path[index + 1] as Vector2
		var segment := to - from
		var segment_length := segment.length()
		var t := 0.0 if segment_length <= 0.0001 else clampf((point - from).dot(segment) / segment.length_squared(), 0.0, 1.0)
		var distance := point.distance_to(from + segment * t)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_progress = (traversed + segment_length * t) / maxf(total_length, 0.0001)
		traversed += segment_length
	return Vector2(nearest_distance, nearest_progress)


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
	var tint := (_fractal_noise(center.x * 0.0075, center.y * 0.0075) - 0.5) * 0.055
	var surface := color.lightened(tint)
	draw_colored_polygon(diamond, surface)
	draw_colored_polygon(PackedVector2Array([diamond[0], diamond[1], diamond[2]]), Color(0.90, 0.94, 0.78, 0.012))


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
		var biome := _biome_at(column, row)
		var shore_color := Color("#c8b987") if biome in ["plains", "coast", "desert"] else Color("#89978b")
		if _is_floating_island(column, row):
			shore_color = Color("#485b50")
		draw_line(diamond[from_index] + Vector2(0, 1), diamond[to_index] + Vector2(0, 1), shore_color, 2.2, true)
		draw_line(diamond[from_index] + Vector2(0, 4), diamond[to_index] + Vector2(0, 4), Color(0.65, 0.91, 0.86, 0.43), 1.3, true)
		draw_line(diamond[from_index] + Vector2(0, 8), diamond[to_index] + Vector2(0, 8), Color(0.38, 0.73, 0.74, 0.17), 2.0, true)
		if _is_floating_island(column, row) and _hash_noise(column * 5 + index, row * 7) > 0.66:
			var waterfall_start := diamond[from_index].lerp(diamond[to_index], 0.52) + Vector2(0, 4)
			draw_line(waterfall_start, waterfall_start + Vector2(0, 28), Color(0.53, 0.92, 0.90, 0.58), 2.2, true)
			draw_line(waterfall_start + Vector2(3, 1), waterfall_start + Vector2(3, 23), Color(0.83, 1.0, 0.96, 0.30), 1.0, true)


func _draw_lakes_and_wetlands() -> void:
	var water_heights := [7.0, 4.5, 3.5]
	var directions: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	for row in range(GRID_ROWS):
		for column in range(GRID_COLUMNS):
			var basin_index := _lake_basin_index(column, row)
			if basin_index < 0 or not _is_world_tile(column, row):
				continue
			var center := _grid_to_world(Vector2(column, row)) - Vector2(0, water_heights[basin_index])
			var diamond := _tile_diamond(center, 0.0)
			draw_colored_polygon(diamond, Color("#377b7d").lightened(float(basin_index) * 0.025))
			if (column + row) % 3 == 0:
				draw_line(center + Vector2(-8, -1), center + Vector2(7, -4), Color(0.70, 0.91, 0.84, 0.33), 1.0, true)
			for edge_index in range(directions.size()):
				var neighbor := Vector2i(column, row) + directions[edge_index]
				if neighbor.x >= 0 and neighbor.y >= 0 and neighbor.x < GRID_COLUMNS and neighbor.y < GRID_ROWS and _lake_basin_index(neighbor.x, neighbor.y) == basin_index:
					continue
				var edge_from := diamond[edge_index]
				var edge_to := diamond[(edge_index + 1) % 4]
				draw_line(edge_from, edge_to, Color("#75815d"), 3.2, true)
				draw_line(edge_from + Vector2(0, 2), edge_to + Vector2(0, 2), Color(0.68, 0.88, 0.78, 0.30), 1.0, true)
				if (column * 3 + row + edge_index) % 5 == 0:
					for reed_index in range(3):
						var reed_base := edge_from.lerp(edge_to, 0.25 + reed_index * 0.23)
						draw_line(reed_base, reed_base - Vector2(1, 5 + reed_index), Color("#576c42"), 1.0)


func _lake_basin_index(column: int, row: int) -> int:
	var design := _grid_to_design(Vector2(column, row))
	for index in range(LAKE_BASINS.size()):
		var basin: Dictionary = LAKE_BASINS[index]
		var center: Vector2 = basin["center"]
		var radius: Vector2 = basin["radius"]
		var normalized := (design - center) / radius
		var distortion := (_fractal_noise(design.x * 0.86 + index * 3.0, design.y * 0.86) - 0.5) * 0.22
		if normalized.length_squared() + distortion <= 1.0:
			return index
	return -1


func _is_lake_cell(column: int, row: int) -> bool:
	return _lake_basin_index(column, row) >= 0


func _scaled_polygon(points: PackedVector2Array, center: Vector2, scale_value: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(center + (point - center) * scale_value)
	return result


func _draw_tile_detail(center: Vector2, column: int, row: int, biome: String) -> void:
	var design := _grid_to_design(Vector2(column, row))
	var noise := _fractal_noise(design.x * 0.72 + 8.1, design.y * 0.72 + 3.9)
	var distribution := _hash_noise(column * 17 + row * 3, row * 19 + column)
	if _is_lake_cell(column, row):
		return
	if _near_infrastructure(Vector2(column, row), 0.64):
		if biome in ["forest", "rock", "snow", "tundra", "plains", "coast"]:
			_draw_verge_detail(center, column, row, biome)
		return
	match biome:
		"forest":
			if distribution < 0.40:
				return
			var tree_count := 2 + int(noise * 2.0)
			draw_ellipse_shadow(center + Vector2(2, 3), Vector2(14, 4), Color(0.06, 0.15, 0.07, 0.16))
			for index in range(tree_count):
				var offset := Vector2(
					(_hash_noise(column * 7 + index, row * 5 + 2) - 0.5) * 25.0,
					(_hash_noise(column * 3 + index, row * 11 + 4) - 0.5) * 9.0 - 3.0
				)
				_draw_tree(center + offset, _hash_noise(column + index * 13, row + index * 7))
		"rock":
			if noise > 0.52 and distribution > 0.28:
				_draw_mountain(center + Vector2(0.0, -3.0), noise, design.y < 8)
			elif noise > 0.27 and distribution > 0.48:
				_draw_rock_cluster(center, noise)
		"snow", "tundra":
			if distribution > 0.36 and (noise > 0.72 or (design.y < 5 and noise > 0.54)):
				_draw_mountain(center + Vector2(0, -2), 0.55 + noise * 0.40, true)
			elif noise > 0.54 and distribution > 0.42:
				_draw_pine(center + Vector2(-4.0, -3.0), Color("#345d55"), 0.85 + noise * 0.35)
			if noise > 0.63 and noise <= 0.72 and distribution > 0.72:
				_draw_pine(center + Vector2(8.0, 1.0), Color("#486f61"), 0.68)
		"desert":
			if distribution > 0.36:
				_draw_dunes(center, column, row, noise)
		"industry":
			if noise > 0.58 and distribution > 0.56:
				_draw_small_factory(center)
		"urban":
			if noise > 0.56 and distribution > 0.52:
				_draw_small_block(center, noise)
		"floating":
			if noise > 0.70 and distribution > 0.52:
				_draw_magic_crystal(center)
			elif noise > 0.48 and distribution > 0.45:
				_draw_tree(center + Vector2(2, -2), noise)
		"plains", "coast":
			if noise > 0.72 and distribution > 0.58:
				_draw_tree(center + Vector2(4, -2), noise)
			elif noise < 0.21 and design.y > 10 and distribution > 0.45:
				_draw_field(center, column, row)
			elif noise > 0.60 and distribution > 0.56:
				_draw_low_hill(center, noise)
			elif distribution > 0.62:
				_draw_grass_detail(center, column, row, noise)


func _draw_tree(center: Vector2, seed: float) -> void:
	var scale_value := 0.60 + seed * 0.34
	draw_ellipse_shadow(center + Vector2(4, 3), Vector2(8, 3) * scale_value, Color(0.04, 0.10, 0.06, 0.30))
	draw_rect(Rect2(center + Vector2(-1.4, -7.0) * scale_value, Vector2(2.8, 10.0) * scale_value), Color("#5c4933"))
	var dark := Color("#294e37")
	var mid := Color("#3e6c45")
	var light := Color("#5b824c")
	draw_circle(center + Vector2(-4.0, -9.0) * scale_value, 5.8 * scale_value, dark)
	draw_circle(center + Vector2(4.0, -10.0) * scale_value, 6.2 * scale_value, mid)
	draw_circle(center + Vector2(0.0, -15.0) * scale_value, 6.6 * scale_value, light)
	draw_circle(center + Vector2(-2.0, -17.0) * scale_value, 2.1 * scale_value, Color(0.58, 0.70, 0.40, 0.65))
	draw_arc(center + Vector2(0, -12) * scale_value, 7.5 * scale_value, 3.4, 5.8, 10, Color(0.73, 0.82, 0.52, 0.26), 1.0, true)


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
	var height := 18.0 + seed * 16.0
	var width := 19.0 + seed * 10.0
	draw_ellipse_shadow(center + Vector2(8, 8), Vector2(width, 6.5), Color(0.04, 0.07, 0.06, 0.36))
	var left_peak := center + Vector2(-width * 0.43, -height * 0.58)
	var right_peak := center + Vector2(width * 0.46, -height * 0.45)
	draw_colored_polygon(PackedVector2Array([center + Vector2(-width, 6), left_peak, center + Vector2(0, 6)]), Color("#626963"))
	draw_colored_polygon(PackedVector2Array([center + Vector2(-2, 6), right_peak, center + Vector2(width, 6)]), Color("#4d5551"))
	draw_colored_polygon(PackedVector2Array([center + Vector2(-width * 0.74, 6), center + Vector2(0, -height), center + Vector2(width * 0.72, 6)]), Color("#565e59"))
	draw_colored_polygon(PackedVector2Array([center + Vector2(-width * 0.74, 6), center + Vector2(0, -height), center + Vector2(-3, 3)]), Color("#858a7d"))
	draw_colored_polygon(PackedVector2Array([center + Vector2(-3, 3), center + Vector2(0, -height), center + Vector2(width * 0.72, 6)]), Color("#626963"))
	draw_line(center + Vector2(-2, -height + 8), center + Vector2(-10, 0), Color(0.82, 0.82, 0.70, 0.34), 1.1)
	draw_line(center + Vector2(3, -height + 12), center + Vector2(11, 3), Color(0.16, 0.20, 0.19, 0.45), 1.3)
	if snow_cap:
		draw_colored_polygon(PackedVector2Array([
			center + Vector2(-8, -height + 14), center + Vector2(0, -height), center + Vector2(9, -height + 16),
			center + Vector2(4, -height + 12), center + Vector2(0, -height + 18), center + Vector2(-4, -height + 12),
		]), Color("#eef1e9"))
	else:
		draw_colored_polygon(PackedVector2Array([
			center + Vector2(-5, -height + 12), center + Vector2(0, -height), center + Vector2(6, -height + 13), center + Vector2(1, -height + 9),
		]), Color("#9a9b87"))
	if seed > 0.52 and not snow_cap:
		_draw_pine(center + Vector2(-width * 0.52, 4), Color("#354f3b"), 0.52)
		_draw_pine(center + Vector2(width * 0.46, 5), Color("#405b42"), 0.45)


func _draw_low_hill(center: Vector2, seed: float) -> void:
	var width := 13.0 + seed * 6.0
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-width, 4), center + Vector2(-4, -5 - seed * 4),
		center + Vector2(width, 3), center + Vector2(3, 7),
	]), Color("#718752"))
	draw_line(center + Vector2(-width * 0.72, 1), center + Vector2(-3, -4 - seed * 3), Color(0.76, 0.82, 0.55, 0.26), 1.0, true)


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


func _draw_verge_detail(center: Vector2, column: int, row: int, biome: String) -> void:
	var side := -1.0 if (column + row) % 2 == 0 else 1.0
	if biome in ["forest", "plains", "coast"] and _hash_noise(column + 31, row + 57) > 0.58:
		_draw_grass_detail(center + Vector2(side * 8.0, 2), column, row, 0.5)
	elif biome in ["rock", "snow", "tundra"] and _hash_noise(column + 19, row + 11) > 0.76:
		_draw_rock_cluster(center + Vector2(side * 9.0, 2), 0.25)


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


func _draw_magic_crystal(center: Vector2, scale_value: float = 1.0) -> void:
	draw_circle(center + Vector2(0, -4) * scale_value, 8.0 * scale_value, Color(0.35, 0.75, 0.71, 0.07))
	draw_colored_polygon(PackedVector2Array([center + Vector2(-4, 0) * scale_value, center + Vector2(0, -16) * scale_value, center + Vector2(5, 0) * scale_value, center + Vector2(0, 5) * scale_value]), Color("#69aaa3"))
	draw_colored_polygon(PackedVector2Array([center + Vector2(-1, -2) * scale_value, center + Vector2(0, -14) * scale_value, center + Vector2(3, -1) * scale_value, center + Vector2(0, 2) * scale_value]), Color("#b2d8ca"))


func _draw_waterways() -> void:
	for path in RIVER_PATHS:
		_draw_tiled_infrastructure(path, "river")
		_draw_river_mouth(path)
	for path in CANAL_PATHS:
		_draw_tiled_infrastructure(path, "canal")


func _draw_river_mouth(path: Array) -> void:
	var cells := _rasterize_grid_path(path)
	var last_land_index := -1
	for index in range(cells.size()):
		var cell: Vector2i = cells[index]
		if _is_world_tile(cell.x, cell.y):
			last_land_index = index
			continue
		if last_land_index < 0:
			continue
		var land_cell: Vector2i = cells[last_land_index]
		var land_center := _grid_surface_to_world(Vector2(land_cell), 1.0)
		var sea_center := _grid_to_world(Vector2(cell))
		var direction := land_center.direction_to(sea_center)
		var side := direction.orthogonal()
		var outer := PackedVector2Array([
			land_center - side * 9.0, sea_center - side * 15.0,
			sea_center + side * 15.0, land_center + side * 9.0,
		])
		var water := PackedVector2Array([
			land_center - side * 6.0, sea_center - side * 12.0,
			sea_center + side * 12.0, land_center + side * 6.0,
		])
		draw_colored_polygon(outer, Color("#244f55"))
		draw_colored_polygon(water, Color("#2d6e75"))
		for flow_offset in [-0.52, 0.0, 0.52]:
			var flow_start := land_center + side * 5.0 * float(flow_offset)
			var flow_end := sea_center + side * 10.0 * float(flow_offset)
			draw_line(flow_start.lerp(flow_end, 0.28), flow_end, Color(0.50, 0.78, 0.77, 0.28), 0.9, true)
		draw_line(sea_center - side * 11.0, sea_center + side * 11.0, Color(0.65, 0.90, 0.86, 0.48), 1.5, true)
		var glint_center := land_center.lerp(sea_center, 0.62)
		draw_line(glint_center - side * 5.0, glint_center + side * 5.0, Color(0.55, 0.83, 0.80, 0.32), 1.0, true)
		return


func _draw_ground_roads() -> void:
	for road in ROAD_PATHS:
		_draw_tiled_infrastructure(road["points"], "rail" if bool(road["future"]) else "road")


func _draw_landmark_foundations() -> void:
	_draw_ground_pad(_design_surface_to_world(Vector2(18, 14), 0.6), Vector2(126, 57), Color("#78835e"), Color("#9b956e"))
	_draw_ground_pad(_design_surface_to_world(Vector2(32, 16), 0.7), Vector2(205, 92), Color("#667a72"), Color("#8a9a8f"))
	_draw_ground_pad(_design_surface_to_world(Vector2(40, 11), 0.6), Vector2(150, 68), Color("#6f7065"), Color("#918b77"))
	_draw_ground_pad(_design_surface_to_world(Vector2(42, 19), 0.6), Vector2(142, 62), Color("#6d7770"), Color("#9ba397"))
	_draw_ground_pad(_design_surface_to_world(Vector2(24, 24), 0.5), Vector2(58, 27), Color("#a78550"), Color("#cfb477"))


func _draw_ground_pad(center: Vector2, size: Vector2, fill: Color, rim: Color) -> void:
	var diamond := PackedVector2Array([
		center + Vector2(0, -size.y * 0.5), center + Vector2(size.x * 0.5, 0),
		center + Vector2(0, size.y * 0.5), center + Vector2(-size.x * 0.5, 0),
	])
	draw_colored_polygon(diamond, fill)
	draw_polyline(diamond + PackedVector2Array([diamond[0]]), rim, 1.4, true)
	var inset := _scaled_polygon(diamond, center, 0.86)
	draw_polyline(inset + PackedVector2Array([inset[0]]), Color(rim, 0.28), 0.8, true)


func _draw_tiled_infrastructure(grid_points: Array, kind: String) -> void:
	var cells := _continuous_land_cells(_rasterize_grid_path(grid_points))
	for index in range(cells.size()):
		var connections: Array[Vector2i] = []
		if index > 0:
			connections.append(cells[index - 1] - cells[index])
		if index < cells.size() - 1:
			connections.append(cells[index + 1] - cells[index])
		_draw_infrastructure_tile(cells[index], connections, kind, index)


func _continuous_land_cells(cells: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var entered_land := false
	for cell in cells:
		if _is_world_tile(cell.x, cell.y):
			entered_land = true
			result.append(cell)
		elif entered_land:
			break
	return result


func _rasterize_grid_path(grid_points: Array) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for segment_index in range(grid_points.size() - 1):
		var from_grid := _design_to_grid(grid_points[segment_index] as Vector2)
		var to_grid := _design_to_grid(grid_points[segment_index + 1] as Vector2)
		var from := Vector2i(roundi(from_grid.x), roundi(from_grid.y))
		var to := Vector2i(roundi(to_grid.x), roundi(to_grid.y))
		var delta := to - from
		var total_steps := absi(delta.x) + absi(delta.y)
		if cells.is_empty() or cells[-1] != from:
			cells.append(from)
		if total_steps == 0:
			continue
		var sign_x := signi(delta.x)
		var sign_y := signi(delta.y)
		for step in range(1, total_steps + 1):
			var x_steps := roundi(float(absi(delta.x) * step) / float(total_steps))
			var y_steps := step - x_steps
			var cell := from + Vector2i(sign_x * x_steps, sign_y * y_steps)
			if cells[-1] != cell:
				cells.append(cell)
	return cells


func _draw_infrastructure_tile(cell: Vector2i, connections: Array[Vector2i], kind: String, variant: int) -> void:
	if not _is_world_tile(cell.x, cell.y):
		return
	var lift := 1.0 if kind in ["river", "canal"] else 3.0
	var center := _grid_surface_to_world(Vector2(cell), lift)
	var diamond := _tile_diamond(center, 0.0)
	var shoulder_color := Color("#52614b")
	var surface_color := Color("#2d6e75")
	var shoulder_width := 18.0
	var surface_width := 12.0
	if kind == "canal":
		shoulder_color = Color("#68716b")
		surface_color = Color("#39777b")
		shoulder_width = 13.0
		surface_width = 9.0
	elif kind == "road":
		shoulder_color = Color("#756b55")
		surface_color = Color("#b5a174")
		shoulder_width = 11.0
		surface_width = 8.0
	elif kind == "rail":
		shoulder_color = Color("#59625f")
		surface_color = Color("#a8b0a8")
		shoulder_width = 10.0
		surface_width = 6.0
	var edge_centers := PackedVector2Array()
	for connection in connections:
		var edge := _tile_edge_center(diamond, connection)
		edge_centers.append(edge)
		_draw_isometric_arm(center, edge, shoulder_width, shoulder_color)
	_draw_iso_path_center(center, shoulder_width, shoulder_color)
	for edge in edge_centers:
		_draw_isometric_arm(center, edge, surface_width, surface_color)
	_draw_iso_path_center(center, surface_width, surface_color)
	_draw_infrastructure_texture(center, edge_centers, kind, variant)


func _tile_edge_center(diamond: PackedVector2Array, direction: Vector2i) -> Vector2:
	if direction == Vector2i(1, 0):
		return diamond[1].lerp(diamond[2], 0.5)
	if direction == Vector2i(-1, 0):
		return diamond[3].lerp(diamond[0], 0.5)
	if direction == Vector2i(0, 1):
		return diamond[2].lerp(diamond[3], 0.5)
	return diamond[0].lerp(diamond[1], 0.5)


func _draw_isometric_arm(center: Vector2, edge: Vector2, width: float, color: Color) -> void:
	var direction := center.direction_to(edge)
	var side := direction.orthogonal() * width * 0.5
	draw_colored_polygon(PackedVector2Array([center - side, edge - side, edge + side, center + side]), color)


func _draw_iso_path_center(center: Vector2, width: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, -width * 0.34), center + Vector2(width * 0.68, 0),
		center + Vector2(0, width * 0.34), center + Vector2(-width * 0.68, 0),
	]), color)


func _draw_infrastructure_texture(center: Vector2, edges: PackedVector2Array, kind: String, variant: int) -> void:
	for edge in edges:
		var direction := center.direction_to(edge)
		var side := direction.orthogonal()
		if kind == "river":
			if variant % 3 == 0:
				var glint := center.lerp(edge, 0.55)
				draw_line(glint - direction * 3.0, glint + direction * 3.0, Color(0.65, 0.90, 0.86, 0.38), 1.0, true)
		elif kind == "canal":
			draw_line(center + side * 2.0, edge + side * 2.0, Color(0.66, 0.91, 0.86, 0.26), 0.9, true)
		elif kind == "road":
			if variant % 2 == 0:
				var groove := center.lerp(edge, 0.65)
				draw_line(groove - side * 1.8, groove + side * 1.8, Color(0.43, 0.36, 0.24, 0.34), 0.8, true)
		else:
			for sleeper_step in [0.35, 0.68]:
				var sleeper: Vector2 = center.lerp(edge, float(sleeper_step))
				draw_line(sleeper - side * 3.5, sleeper + side * 3.5, Color("#d4d7cd"), 0.9, true)


func _grid_surface_to_world(grid: Vector2, lift: float = 0.0) -> Vector2:
	var column := clampi(roundi(grid.x), 0, GRID_COLUMNS - 1)
	var row := clampi(roundi(grid.y), 0, GRID_ROWS - 1)
	var biome := _biome_at(column, row)
	var elevation := _elevation_at(column, row, biome)
	return _grid_to_world(grid) - Vector2(0, elevation + lift)


func _near_infrastructure(point: Vector2, radius: float) -> bool:
	var design_point := _grid_to_design(point)
	var design_radius := radius * float(DESIGN_GRID_COLUMNS - 1) / float(GRID_COLUMNS - 1)
	for path in RIVER_PATHS:
		if _distance_to_grid_path(design_point, path) <= design_radius:
			return true
	for path in CANAL_PATHS:
		if _distance_to_grid_path(design_point, path) <= design_radius:
			return true
	for road in ROAD_PATHS:
		if _distance_to_grid_path(design_point, road["points"]) <= design_radius:
			return true
	return false


func _distance_to_grid_path(point: Vector2, path: Array) -> float:
	var nearest := INF
	for index in range(path.size() - 1):
		nearest = minf(nearest, _distance_to_segment(point, path[index] as Vector2, path[index + 1] as Vector2))
	return nearest


func _distance_to_segment(point: Vector2, from: Vector2, to: Vector2) -> float:
	var segment := to - from
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(from)
	var t := clampf((point - from).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(from + segment * t)


func _draw_bridges() -> void:
	_draw_bridge(Vector2(20.8, 16.0), Vector2(0.58, 0.82), false)
	_draw_bridge(Vector2(32.0, 16.0), Vector2(1.0, 0.48), true)
	_draw_bridge(Vector2(36.9, 14.5), Vector2(0.84, -0.54), true)
	_draw_bridge(Vector2(39.6, 20.1), Vector2(0.82, 0.58), true)
	_draw_bridge(Vector2(30.6, 17.2), Vector2(0.72, -0.70), false)


func _draw_bridge(grid: Vector2, direction: Vector2, future: bool) -> void:
	var center := _grid_surface_to_world(_design_to_grid(grid), 5.0)
	var normalized := direction.normalized()
	var side := normalized.orthogonal()
	var half_length := 13.0 if future else 11.0
	var half_width := 4.2 if future else 3.7
	var corners := PackedVector2Array([
		center - normalized * half_length - side * half_width,
		center + normalized * half_length - side * half_width,
		center + normalized * half_length + side * half_width,
		center - normalized * half_length + side * half_width,
	])
	draw_colored_polygon(corners, Color("#87938e") if future else Color("#a89570"))
	draw_line(center - normalized * half_length - side * half_width, center + normalized * half_length - side * half_width, Color("#d5d9ce") if future else Color("#d0bd8c"), 1.3, true)
	draw_line(center - normalized * half_length + side * half_width, center + normalized * half_length + side * half_width, Color("#d5d9ce") if future else Color("#d0bd8c"), 1.3, true)
	for support in [-0.55, 0.55]:
		var support_center: Vector2 = center + normalized * half_length * float(support)
		draw_line(support_center - side * half_width, support_center + side * half_width, Color(0.23, 0.27, 0.25, 0.55), 1.0, true)


func _draw_world_routes() -> void:
	if not show_campaign_overlay or not show_campaign_routes or _profiles.size() < 2:
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
	_draw_village(_design_surface_to_world(Vector2(13, 17)), Color("#8a5d45"))
	_draw_village(_design_surface_to_world(Vector2(22, 18)), Color("#7e6148"))
	_draw_village(_design_surface_to_world(Vector2(28, 21)), Color("#9b754b"))
	_draw_netherit_gate(_design_surface_to_world(Vector2(39, 2)))
	_draw_castle(_design_surface_to_world(Vector2(18, 14)))
	_draw_datt_metropolis(_design_surface_to_world(Vector2(32, 16)))
	_draw_heren_industrial_coast(_design_surface_to_world(Vector2(40, 11)))
	_draw_mining_complex(_design_surface_to_world(Vector2(35, 9)), 0.52)
	_draw_mining_complex(_design_surface_to_world(Vector2(38, 8)) + Vector2(28, 10), 0.46)
	_draw_modern_port(_design_surface_to_world(Vector2(42, 19)))
	_draw_desert_outpost(_design_surface_to_world(Vector2(24, 24)))
	_draw_psetia_archipelago()
	_draw_magic_sanctuary(_design_surface_to_world(Vector2(5, 8)), 0.54)
	_draw_magic_sanctuary(_design_surface_to_world(Vector2(3, 12)), 0.44)
	_draw_magic_observatory(_design_surface_to_world(Vector2(8, 13)), 0.58)
	_draw_ship(_design_to_world(Vector2(39, 29)), 0.62)
	_draw_ship(_design_to_world(Vector2(46, 20)), 0.55)
	_draw_airship(_design_to_world(Vector2(8, 8)) + Vector2(-4, -48), 0.82)
	_draw_airship(_design_to_world(Vector2(4, 13)) + Vector2(-18, -34), 0.62)


func _draw_iso_building(base: Vector2, footprint: Vector2, height: float, front: Color, side: Color, roof: Color, window_color: Color = Color.TRANSPARENT) -> void:
	var top := base - Vector2(0, height)
	var diamond := PackedVector2Array([
		top + Vector2(0, -footprint.y * 0.5),
		top + Vector2(footprint.x * 0.5, 0),
		top + Vector2(0, footprint.y * 0.5),
		top + Vector2(-footprint.x * 0.5, 0),
	])
	draw_ellipse_shadow(base + Vector2(height * 0.18, 4), Vector2(footprint.x * 0.56, footprint.y * 0.42), Color(0.02, 0.06, 0.06, 0.28))
	draw_colored_polygon(PackedVector2Array([
		diamond[1], diamond[2], diamond[2] + Vector2(0, height), diamond[1] + Vector2(0, height),
	]), side)
	draw_colored_polygon(PackedVector2Array([
		diamond[2], diamond[3], diamond[3] + Vector2(0, height), diamond[2] + Vector2(0, height),
	]), front)
	draw_colored_polygon(diamond, roof)
	if window_color.a <= 0.0 or height < 18.0:
		return
	var floor_count := maxi(1, int(height / 9.0))
	for floor_index in range(floor_count):
		var y := base.y - height + 7.0 + float(floor_index) * 8.0
		if y > base.y - 3.0:
			break
		draw_line(Vector2(base.x - footprint.x * 0.32, y + footprint.y * 0.15), Vector2(base.x - 2, y + footprint.y * 0.30), window_color, 1.4)
		draw_line(Vector2(base.x + 3, y + footprint.y * 0.28), Vector2(base.x + footprint.x * 0.30, y + footprint.y * 0.12), window_color.darkened(0.08), 1.4)


func _draw_datt_metropolis(center: Vector2) -> void:
	var district_offsets := [
		Vector2(-76, -18), Vector2(-57, 10), Vector2(-40, -27), Vector2(-24, 18),
		Vector2(28, -27), Vector2(43, 13), Vector2(61, -8), Vector2(75, 21),
		Vector2(-66, 35), Vector2(27, 39), Vector2(55, 43),
	]
	for index in range(district_offsets.size()):
		var offset: Vector2 = district_offsets[index]
		var height := 24.0 + float((index * 17) % 31)
		var footprint := Vector2(17.0 + float(index % 3) * 3.0, 10.0 + float(index % 2) * 2.0)
		var front := Color("#607d7c").lightened(float(index % 3) * 0.045)
		var side := Color("#405f62").lightened(float(index % 2) * 0.05)
		_draw_iso_building(center + offset, footprint, height, front, side, Color("#a6b9b2"), Color("#73ddd4"))
		if index % 3 == 0:
			draw_line(center + offset - Vector2(0, height + 5), center + offset - Vector2(0, height + 15), Color("#86e7db"), 1.5)
	_draw_transit_ring(center)
	_draw_future_hub(center)


func _draw_transit_ring(center: Vector2) -> void:
	draw_arc(center + Vector2(0, 4), 70.0, 0.16, PI - 0.10, 42, Color(0.05, 0.10, 0.11, 0.50), 7.0, true)
	draw_arc(center + Vector2(0, 4), 70.0, 0.16, PI - 0.10, 42, Color("#aab6ae"), 4.0, true)
	draw_arc(center + Vector2(0, 4), 70.0, 0.16, PI - 0.10, 42, Color("#6ed8ce"), 1.2, true)
	for angle_index in range(7):
		var angle := lerpf(0.25, PI - 0.18, float(angle_index) / 6.0)
		var point := center + Vector2(cos(angle), sin(angle)) * 70.0 + Vector2(0, 4)
		draw_circle(point, 2.8, Color("#d9e1d6"))


func _draw_heren_industrial_coast(center: Vector2) -> void:
	for row_index in range(2):
		for column_index in range(4):
			var offset := Vector2(float(column_index) * 26.0 - 41.0, float(row_index) * 25.0 - 9.0)
			_draw_iso_building(center + offset, Vector2(24, 12), 13.0 + float((column_index + row_index) % 2) * 5.0, Color("#625f56"), Color("#494d4a"), Color("#857862"))
	_draw_factory_district(center + Vector2(0, -8))
	for tank_index in range(3):
		var tank_center := center + Vector2(-48 + tank_index * 25, 38)
		draw_circle(tank_center - Vector2(0, 8), 8.0, Color("#a2a69e"))
		draw_rect(Rect2(tank_center + Vector2(-8, -8), Vector2(16, 10)), Color("#737872"))
		draw_arc(tank_center - Vector2(0, 8), 8.0, PI, TAU, 14, Color("#d2d4ca"), 1.3)


func _draw_mining_complex(center: Vector2, scale_value: float) -> void:
	# The mine mouth sits against a rock spoil bank instead of floating as an icon.
	draw_set_transform(center * (1.0 - scale_value), 0.0, Vector2.ONE * scale_value)
	draw_ellipse_shadow(center + Vector2(12, 8), Vector2(44, 13), Color(0.03, 0.05, 0.04, 0.34))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-35, 7), center + Vector2(-20, -23), center + Vector2(2, -31),
		center + Vector2(23, -18), center + Vector2(36, 8),
	]), Color("#555b55"))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-31, 6), center + Vector2(-18, -18), center + Vector2(0, -25), center + Vector2(-5, 7),
	]), Color("#74786e"))
	draw_arc(center + Vector2(2, 7), 13.0, PI, TAU, 18, Color("#272d2c"), 11.0, true)
	draw_rect(Rect2(center + Vector2(-11, 4), Vector2(26, 10)), Color("#292e2d"))
	# Timber portal, ore conveyor and processing shed are separate model pieces.
	var timber := Color("#7c6543")
	draw_line(center + Vector2(-14, 10), center + Vector2(-14, -7), timber, 4.0)
	draw_line(center + Vector2(16, 10), center + Vector2(16, -7), timber, 4.0)
	draw_line(center + Vector2(-16, -7), center + Vector2(18, -7), timber, 4.0)
	var conveyor_start := center + Vector2(17, 9)
	var conveyor_end := center + Vector2(66, 33)
	draw_line(conveyor_start, conveyor_end, Color("#4d5350"), 9.0, true)
	draw_line(conveyor_start, conveyor_end, Color("#a58b5e"), 4.0, true)
	for support_index in range(4):
		var support: Vector2 = conveyor_start.lerp(conveyor_end, 0.18 + float(support_index) * 0.21)
		draw_line(support, support + Vector2(0, 13), Color("#5b5140"), 2.0)
	_draw_iso_building(center + Vector2(70, 35), Vector2(31, 16), 21.0, Color("#675f50"), Color("#484e4b"), Color("#8c8066"))
	_draw_ore_cart(center + Vector2(38, 27))
	for pile_index in range(3):
		var pile_center := center + Vector2(46 + pile_index * 13, 51 + float(pile_index % 2) * 4.0)
		draw_colored_polygon(PackedVector2Array([
			pile_center + Vector2(-8, 3), pile_center + Vector2(0, -8 - pile_index * 2), pile_center + Vector2(9, 3),
		]), [Color("#776f62"), Color("#655f58"), Color("#8a7351")][pile_index])
	draw_set_transform(Vector2.ZERO)


func _draw_ore_cart(center: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-10, -5), center + Vector2(8, -5), center + Vector2(6, 4), center + Vector2(-7, 4),
	]), Color("#575d59"))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-8, -4), center + Vector2(6, -4), center + Vector2(3, 1), center + Vector2(-5, 1),
	]), Color("#8b7251"))
	draw_circle(center + Vector2(-5, 6), 2.8, Color("#303534"))
	draw_circle(center + Vector2(5, 6), 2.8, Color("#303534"))
	draw_line(center + Vector2(-14, 9), center + Vector2(15, 9), Color("#9ba098"), 1.5)


func _draw_netherit_gate(center: Vector2) -> void:
	draw_circle(center + Vector2(0, -18), 27.0, Color(0.46, 0.82, 0.86, 0.10))
	draw_circle(center + Vector2(0, -18), 19.0, Color("#7fb7ba"))
	draw_circle(center + Vector2(0, -18), 12.0, Color("#1f3544"))
	draw_arc(center + Vector2(0, -18), 15.0, 0, TAU, 28, Color("#c2e4df"), 2.0, true)
	draw_colored_polygon(PackedVector2Array([center + Vector2(-25, 5), center + Vector2(-13, -37), center + Vector2(-4, -21), center + Vector2(10, -42), center + Vector2(25, 5)]), Color(0.78, 0.88, 0.88, 0.76))
	draw_line(center + Vector2(-17, -9), center + Vector2(-8, -32), Color(0.94, 1.0, 0.98, 0.72), 1.5)


func _draw_castle(center: Vector2) -> void:
	draw_ellipse_shadow(center + Vector2(16, 16), Vector2(65, 19), Color(0.03, 0.06, 0.05, 0.36))
	# Raised bailey platform and four low wall sections share the map's 2:1 projection.
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, -31), center + Vector2(62, 0), center + Vector2(0, 31), center + Vector2(-62, 0),
	]), Color("#8f866f"))
	_draw_iso_building(center + Vector2(0, 23), Vector2(92, 18), 13.0, Color("#8e7d65"), Color("#6f6658"), Color("#b2a383"))
	_draw_iso_building(center + Vector2(0, -22), Vector2(92, 18), 13.0, Color("#8e7d65"), Color("#6f6658"), Color("#b2a383"))
	_draw_iso_building(center + Vector2(-45, 0), Vector2(20, 43), 13.0, Color("#8e7d65"), Color("#6f6658"), Color("#b2a383"))
	_draw_iso_building(center + Vector2(45, 0), Vector2(20, 43), 13.0, Color("#8e7d65"), Color("#6f6658"), Color("#b2a383"))
	for tower_offset in [Vector2(-47, -24), Vector2(47, -24), Vector2(-47, 24), Vector2(47, 24)]:
		_draw_castle_tower(center + tower_offset, 37.0)
	# The central keep, gatehouse and chapel read as separate model pieces.
	_draw_iso_building(center + Vector2(0, -3), Vector2(42, 23), 55.0, Color("#94816a"), Color("#6d6659"), Color("#b6a789"), Color("#efcf84"))
	_draw_iso_building(center + Vector2(0, 27), Vector2(27, 15), 30.0, Color("#927e67"), Color("#665f55"), Color("#a99a7d"))
	draw_arc(center + Vector2(0, 30), 8.0, PI, TAU, 14, Color("#3c3834"), 4.0)
	_draw_iso_building(center + Vector2(26, -4), Vector2(19, 12), 34.0, Color("#9c896f"), Color("#71685a"), Color("#3d5a56"), Color("#efd28b"))
	draw_line(center + Vector2(0, -60), center + Vector2(0, -78), Color("#554937"), 2.0)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, -78), center + Vector2(20, -72), center + Vector2(0, -65),
	]), Color("#c99a45"))


func _draw_castle_tower(center: Vector2, height: float) -> void:
	_draw_iso_building(center, Vector2(22, 13), height, Color("#8d7c67"), Color("#696257"), Color("#a99a7f"), Color("#efd18a"))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-14, -height - 5), center + Vector2(0, -height - 22), center + Vector2(14, -height - 5), center + Vector2(0, -height + 2),
	]), Color("#385550"))
	draw_circle(center + Vector2(-3, -height - 8), 2.0, Color(0.78, 0.91, 0.80, 0.42))


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
	# Cargo structures use the actual ocean cells south of the landward district.
	var harbor_center := _design_to_world(Vector2(42, 21))
	var shore_anchors := [
		_design_to_world(Vector2(41, 20)),
		_design_to_world(Vector2(41, 21)),
	]
	for pier_index in range(shore_anchors.size()):
		_draw_port_pier(shore_anchors[pier_index], pier_index)

	# Warehouses stay clear of the estuary corridor on the landward side.
	var warehouse_offsets := [Vector2(-78, -8), Vector2(1, -40), Vector2(31, -33)]
	for warehouse_index in range(warehouse_offsets.size()):
		var warehouse_base: Vector2 = center + warehouse_offsets[warehouse_index]
		_draw_iso_building(warehouse_base, Vector2(27, 14), 15.0, Color("#777065"), Color("#535c59"), Color("#aaa184"))
		for door_index in range(3):
			draw_line(warehouse_base + Vector2(-8 + door_index * 7, -7), warehouse_base + Vector2(-8 + door_index * 7, -2), Color("#384a49"), 2.0)
	var exchange_base := center + Vector2(53, -25)
	_draw_iso_building(exchange_base, Vector2(27, 15), 48.0, Color("#637e7b"), Color("#405e61"), Color("#b2c2b9"), Color("#7be0d4"))
	draw_arc(exchange_base - Vector2(0, 54), 9.0, 0.0, TAU, 20, Color("#79e0d4"), 2.5, true)
	draw_line(exchange_base - Vector2(0, 48), exchange_base - Vector2(0, 67), Color("#b9d8cf"), 2.0)

	# Rail terminal and elevated air terminal complete the water-land-air hub.
	var terminal_base := center + Vector2(76, 15)
	_draw_iso_building(terminal_base, Vector2(39, 17), 18.0, Color("#687b78"), Color("#485d60"), Color("#b1b59d"), Color("#7de0d5"))
	for rail_index in range(3):
		draw_line(center + Vector2(30, 30 + rail_index * 4), center + Vector2(103, 30 + rail_index * 4), Color("#aeb4aa"), 1.5, true)
	draw_arc(center + Vector2(83, -18), 18.0, PI, TAU, 24, Color("#85ddd3"), 3.0, true)
	draw_line(center + Vector2(65, -18), center + Vector2(101, -18), Color("#9fb3ad"), 3.0, true)
	_draw_airship(center + Vector2(83, -58), 0.70)
	_draw_fast_boat(harbor_center + Vector2(-30, 49), 0.72)


func _draw_port_pier(center: Vector2, variant: int) -> void:
	var length := 54.0 + float(variant) * 4.0
	var end := center + Vector2(length, 24.0)
	draw_line(center + Vector2(2, 6), end + Vector2(2, 6), Color(0.04, 0.11, 0.12, 0.58), 18.0, true)
	draw_line(center, end, Color("#8c856f"), 14.0, true)
	draw_line(center - Vector2(0, 3), end - Vector2(0, 3), Color("#c3b280"), 1.3, true)
	draw_line(center + Vector2(0, 3), end + Vector2(0, 3), Color("#5f645d"), 1.2, true)
	for support_step in [0.18, 0.48, 0.78]:
		var support: Vector2 = center.lerp(end, float(support_step))
		draw_line(support + Vector2(-4, 5), support + Vector2(-4, 15), Color("#454b48"), 2.4, true)
		draw_line(support + Vector2(4, 7), support + Vector2(4, 15), Color("#5b605a"), 2.0, true)
	for crane_index in range(2):
		var anchor := center.lerp(end, 0.34 + float(crane_index) * 0.38)
		_draw_cargo_crane(anchor, 0.74 + float(variant) * 0.05)
	for container_index in range(3):
		var stack := center.lerp(end, 0.18 + float(container_index) * 0.27) + Vector2(-5, 5)
		draw_rect(Rect2(stack + Vector2(-4, -5), Vector2(8, 5)), [Color("#a65f49"), Color("#4d7b78"), Color("#b7934d")][(container_index + variant) % 3])


func _draw_cargo_crane(center: Vector2, scale_value: float) -> void:
	var gold := Color("#d0ad5f")
	var left_foot := center + Vector2(-5, 1) * scale_value
	var right_foot := center + Vector2(7, 5) * scale_value
	var left_top := center + Vector2(-3, -28) * scale_value
	var right_top := center + Vector2(9, -24) * scale_value
	draw_line(left_foot + Vector2(-4, 1) * scale_value, left_foot + Vector2(4, 1) * scale_value, Color("#57594f"), 2.4 * scale_value, true)
	draw_line(right_foot + Vector2(-4, 1) * scale_value, right_foot + Vector2(4, 1) * scale_value, Color("#57594f"), 2.4 * scale_value, true)
	draw_line(left_foot, left_top, gold, 3.0 * scale_value, true)
	draw_line(right_foot, right_top, gold.darkened(0.08), 2.5 * scale_value, true)
	draw_line(left_top, right_top, gold, 2.8 * scale_value, true)
	draw_line(right_top, center + Vector2(26, -33) * scale_value, gold, 2.3 * scale_value, true)
	draw_line(center + Vector2(22, -31) * scale_value, center + Vector2(22, -16) * scale_value, Color("#7d6d52"), 1.1 * scale_value, true)


func _draw_fast_boat(center: Vector2, scale_value: float) -> void:
	draw_line(center + Vector2(-18, 8) * scale_value, center + Vector2(21, 8) * scale_value, Color(0.55, 0.88, 0.87, 0.42), 2.0)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-16, 0) * scale_value, center + Vector2(22, 0) * scale_value,
		center + Vector2(10, 8) * scale_value, center + Vector2(-10, 7) * scale_value,
	]), Color("#d9ddd5"))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-3, -7) * scale_value, center + Vector2(10, -7) * scale_value,
		center + Vector2(15, 0) * scale_value, center + Vector2(-8, 0) * scale_value,
	]), Color("#49777c"))


func _draw_desert_outpost(center: Vector2) -> void:
	draw_ellipse_shadow(center + Vector2(8, 9), Vector2(29, 8), Color(0.15, 0.09, 0.04, 0.28))
	draw_colored_polygon(PackedVector2Array([center + Vector2(-22, 4), center + Vector2(0, -16), center + Vector2(23, 4), center + Vector2(18, 17), center + Vector2(-18, 17)]), Color("#785638"))
	draw_colored_polygon(PackedVector2Array([center + Vector2(-18, 2), center + Vector2(0, -12), center + Vector2(19, 2), center + Vector2(0, 11)]), Color("#b58a54"))
	draw_line(center + Vector2(-4, -10), center + Vector2(-4, -40), Color("#5d432e"), 3.0)
	draw_colored_polygon(PackedVector2Array([center + Vector2(-4, -40), center + Vector2(17, -33), center + Vector2(-4, -26)]), Color("#d5b25f"))


func _draw_psetia_archipelago() -> void:
	_draw_psetia_settlement(_design_surface_to_world(Vector2(35, 27)), 0.48, true)
	_draw_psetia_settlement(_design_surface_to_world(Vector2(41, 26)), 0.54, true)
	_draw_psetia_settlement(_design_surface_to_world(Vector2(45, 23)), 0.44, false)
	_draw_psetia_settlement(_design_surface_to_world(Vector2(29, 28)), 0.40, false)


func _draw_psetia_settlement(center: Vector2, scale_value: float, has_temple: bool) -> void:
	var house_offsets := [Vector2(-24, 2), Vector2(2, -10), Vector2(25, 5), Vector2(-2, 18)]
	for index in range(house_offsets.size()):
		_draw_stilt_house(center + house_offsets[index] * scale_value, scale_value * (0.78 + float(index % 2) * 0.12))
	if has_temple:
		_draw_psetia_temple(center + Vector2(8, -5) * scale_value, scale_value)
	_draw_island_pier(center + Vector2(-8, 28) * scale_value, scale_value)


func _draw_stilt_house(center: Vector2, scale_value: float) -> void:
	var wall := Color("#aa936d")
	var dark_wall := Color("#766451")
	var roof := Color("#765748")
	for stilt_x in [-8.0, 7.0]:
		draw_line(center + Vector2(stilt_x, -1) * scale_value, center + Vector2(stilt_x, 12) * scale_value, Color("#594635"), 2.0 * scale_value)
	_draw_iso_building(center, Vector2(24, 13) * scale_value, 15.0 * scale_value, wall, dark_wall, Color("#9a7958"))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-17, -18) * scale_value,
		center + Vector2(0, -34) * scale_value,
		center + Vector2(19, -18) * scale_value,
		center + Vector2(0, -9) * scale_value,
	]), roof)
	draw_line(center + Vector2(-18, -17) * scale_value, center + Vector2(19, -17) * scale_value, Color("#b79664"), 1.5 * scale_value)


func _draw_psetia_temple(center: Vector2, scale_value: float) -> void:
	for tier in range(3):
		var tier_scale := scale_value * (1.0 - float(tier) * 0.20)
		var tier_center := center - Vector2(0, float(tier) * 14.0 * scale_value)
		_draw_iso_building(tier_center, Vector2(31, 16) * tier_scale, 12.0 * scale_value, Color("#a9926c"), Color("#746354"), Color("#b49a69"))
		draw_colored_polygon(PackedVector2Array([
			tier_center + Vector2(-20, -14) * tier_scale, tier_center + Vector2(0, -26) * tier_scale,
			tier_center + Vector2(21, -14) * tier_scale, tier_center + Vector2(0, -6) * tier_scale,
		]), Color("#765044").lightened(float(tier) * 0.05))
	draw_line(center + Vector2(0, -58) * scale_value, center + Vector2(0, -72) * scale_value, Color("#bba264"), 1.5 * scale_value)


func _draw_island_pier(center: Vector2, scale_value: float) -> void:
	var end := center + Vector2(30, 15) * scale_value
	draw_line(center, end, Color("#5f4935"), 7.0 * scale_value, true)
	draw_line(center, end, Color("#b18a55"), 4.0 * scale_value, true)
	for post_index in range(3):
		var post: Vector2 = center.lerp(end, 0.22 + float(post_index) * 0.28)
		draw_line(post, post + Vector2(0, 8) * scale_value, Color("#584434"), 1.7 * scale_value)


func _draw_magic_sanctuary(center: Vector2, scale_value: float) -> void:
	var cyan := Color("#76b8ae")
	var glow := Color(0.43, 0.75, 0.70, 0.13)
	var outer := PackedVector2Array([
		center + Vector2(0, -22) * scale_value, center + Vector2(42, 0) * scale_value,
		center + Vector2(0, 22) * scale_value, center + Vector2(-42, 0) * scale_value,
	])
	var inner := PackedVector2Array([
		center + Vector2(0, -13) * scale_value, center + Vector2(25, 0) * scale_value,
		center + Vector2(0, 13) * scale_value, center + Vector2(-25, 0) * scale_value,
	])
	draw_polyline(outer + PackedVector2Array([outer[0]]), glow, 7.0 * scale_value, true)
	draw_polyline(outer + PackedVector2Array([outer[0]]), cyan, 2.0 * scale_value, true)
	draw_polyline(inner + PackedVector2Array([inner[0]]), Color(0.70, 0.86, 0.79, 0.52), 1.2 * scale_value, true)
	for point in outer:
		_draw_magic_crystal(point - Vector2(0, 2) * scale_value, scale_value * 0.62)
	_draw_magic_portal(center - Vector2(0, 9) * scale_value, scale_value)


func _draw_magic_portal(center: Vector2, scale_value: float) -> void:
	draw_circle(center, 17.0 * scale_value, Color(0.35, 0.73, 0.69, 0.11))
	draw_arc(center, 14.0 * scale_value, 0, TAU, 28, Color("#82bdb4"), 3.0 * scale_value, true)
	draw_arc(center, 8.0 * scale_value, 0, TAU, 20, Color("#38545b"), 5.0 * scale_value, true)
	draw_line(center + Vector2(-18, 16) * scale_value, center + Vector2(-12, -14) * scale_value, Color("#66746f"), 3.0 * scale_value)
	draw_line(center + Vector2(18, 16) * scale_value, center + Vector2(12, -14) * scale_value, Color("#66746f"), 3.0 * scale_value)


func _draw_magic_observatory(center: Vector2, scale_value: float) -> void:
	draw_set_transform(center * (1.0 - scale_value), 0.0, Vector2.ONE * scale_value)
	_draw_iso_building(center, Vector2(34, 18), 37.0, Color("#677674"), Color("#455b5c"), Color("#9fae9d"), Color("#70b9af"))
	draw_circle(center - Vector2(0, 47), 13.0, Color("#3d5d68"))
	draw_arc(center - Vector2(0, 47), 13.0, 0, TAU, 24, Color("#78b9b0"), 2.5, true)
	for arm_index in range(4):
		var angle := float(arm_index) * PI * 0.5 + PI * 0.25
		draw_line(center - Vector2(0, 47), center - Vector2(0, 47) + Vector2(cos(angle), sin(angle)) * 20.0, Color("#c4d7c8"), 1.8)
	draw_set_transform(Vector2.ZERO)


func _draw_ship(center: Vector2, scale_value: float = 1.0) -> void:
	# Open-water wake establishes that the vessel is afloat, not sitting on an island tile.
	for wake_index in range(3):
		var wake_y := 14.0 + float(wake_index) * 5.0
		draw_arc(center + Vector2(-24, wake_y) * scale_value, (20.0 + wake_index * 7.0) * scale_value, 3.45, 5.92, 16, Color(0.63, 0.91, 0.88, 0.34 - wake_index * 0.07), 1.6 * scale_value, true)
	draw_colored_polygon(PackedVector2Array([center + Vector2(-27, -5) * scale_value, center + Vector2(24, -5) * scale_value, center + Vector2(14, 10) * scale_value, center + Vector2(-16, 11) * scale_value]), Color("#d9ddd5"))
	draw_colored_polygon(PackedVector2Array([center + Vector2(-16, 5) * scale_value, center + Vector2(14, 5) * scale_value, center + Vector2(24, -5) * scale_value, center + Vector2(-27, -5) * scale_value]), Color("#647f80"))
	draw_rect(Rect2(center + Vector2(-6, -18) * scale_value, Vector2(19, 13) * scale_value), Color("#e3e5dc"))
	draw_rect(Rect2(center + Vector2(-2, -15) * scale_value, Vector2(13, 5) * scale_value), Color("#3e737b"))
	draw_line(center + Vector2(5, -18) * scale_value, center + Vector2(5, -30) * scale_value, Color("#87928d"), 2.0 * scale_value)
	draw_colored_polygon(PackedVector2Array([center + Vector2(5, -30) * scale_value, center + Vector2(17, -25) * scale_value, center + Vector2(5, -21) * scale_value]), Color("#71c9c2"))


func _draw_village(center: Vector2, roof_color: Color) -> void:
	var offsets := [Vector2(-23, 0), Vector2(-7, -13), Vector2(15, -5), Vector2(-9, 13), Vector2(17, 15)]
	draw_line(center + Vector2(-32, 12), center + Vector2(29, -7), Color("#a18d68"), 5.5, true)
	draw_line(center + Vector2(-32, 10), center + Vector2(29, -9), Color(0.82, 0.73, 0.52, 0.42), 1.0, true)
	for index in range(offsets.size()):
		_draw_cottage(center + offsets[index], roof_color.lightened(float(index % 3) * 0.045), index)
	var well_center := center + Vector2(3, 11)
	draw_ellipse_shadow(well_center + Vector2(2, 2), Vector2(6, 2), Color(0.03, 0.06, 0.04, 0.26))
	draw_circle(well_center, 5.0, Color("#8d866f"))
	draw_circle(well_center, 2.8, Color("#315f61"))
	for fence_index in range(5):
		var post := center + Vector2(-31 + fence_index * 8, 22 - fence_index * 2)
		draw_line(post, post - Vector2(0, 5), Color("#765f3f"), 1.2)
		if fence_index > 0:
			var previous := center + Vector2(-31 + (fence_index - 1) * 8, 22 - (fence_index - 1) * 2) - Vector2(0, 3)
			draw_line(previous, post - Vector2(0, 3), Color("#94784e"), 1.0, true)


func _draw_cottage(base: Vector2, roof_color: Color, variant: int) -> void:
	var footprint := Vector2(16.0 + float(variant % 2) * 2.0, 8.0 + float((variant + 1) % 2))
	var height := 10.0 + float(variant % 3)
	_draw_iso_building(base, footprint, height, Color("#b6a47d"), Color("#81775f"), roof_color.darkened(0.04))
	var roof_center := base - Vector2(0, height)
	var half_width := footprint.x * 0.57
	var half_depth := footprint.y * 0.58
	var ridge := roof_center - Vector2(0, 7.0 + float(variant % 2))
	draw_colored_polygon(PackedVector2Array([
		roof_center + Vector2(-half_width, 0), ridge, roof_center + Vector2(0, half_depth),
	]), roof_color.lightened(0.08))
	draw_colored_polygon(PackedVector2Array([
		ridge, roof_center + Vector2(half_width, 0), roof_center + Vector2(0, half_depth),
	]), roof_color.darkened(0.10))
	draw_line(roof_center + Vector2(-half_width * 0.55, 0), ridge, Color(0.90, 0.79, 0.58, 0.30), 0.8, true)
	draw_rect(Rect2(base + Vector2(-2, -6), Vector2(4, 6)), Color("#5a4735"))
	if variant % 2 == 0:
		draw_rect(Rect2(base + Vector2(half_width * 0.35, -height + 2), Vector2(2.5, 4.0)), Color("#d7c978"))
	if variant % 3 == 0:
		draw_rect(Rect2(ridge + Vector2(3, -5), Vector2(2.5, 7)), Color("#6f6251"))


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
	_draw_map_label(font, "冥河极寒带", _design_to_world(Vector2(39, 1)) + Vector2(-54, -60), Color("#dcece7"))
	_draw_map_label(font, "洛安德自治区", _design_to_world(Vector2(17, 16)) + Vector2(-64, 35), Color("#f1deb1"))
	_draw_map_label(font, "达特核心区", _design_to_world(Vector2(31, 18)) + Vector2(-48, 52), Color("#b8eee5"))
	_draw_map_label(font, "赫伦工业海岸", _design_to_world(Vector2(40, 10)) + Vector2(20, -44), Color("#ead7ad"))
	_draw_map_label(font, "南部拓殖带", _design_to_world(Vector2(23, 25)) + Vector2(-46, 42), Color("#f1d08f"))
	_draw_map_label(font, "普赛提亚群岛", _design_to_world(Vector2(39, 27)) + Vector2(-42, 54), Color("#c5ece6"))
	_draw_map_label(font, "西部浮空岛", _design_to_world(Vector2(5, 9)) + Vector2(-62, -45), Color("#d8c8ea"))


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
		marker.text = str(profile.get("marker_label", profile.get("local_number", index + 1)))
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
	if show_campaign_routes:
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
	if profile.has("campaign_grid_position"):
		var grid: Vector2 = profile["campaign_grid_position"]
		var column := clampi(roundi(grid.x), 0, GRID_COLUMNS - 1)
		var row := clampi(roundi(grid.y), 0, GRID_ROWS - 1)
		var elevation := _elevation_at(column, row, _biome_at(column, row))
		return _grid_to_world(grid) - Vector2(0.0, elevation + 28.0)
	var normalized: Vector2 = profile.get("map_position", Vector2(0.5, 0.5))
	var design_column := lerpf(4.0, 45.0, normalized.x)
	var design_row := lerpf(1.0, 28.0, normalized.y)
	return _design_to_world(Vector2(design_column, design_row)) - Vector2(0.0, 28.0)


func campaign_marker_cells() -> Dictionary:
	return _campaign_marker_cells.duplicate(true)


func _assign_campaign_positions() -> void:
	_campaign_marker_cells.clear()
	var stage_profiles: Dictionary = {}
	for profile in _profiles:
		var stage_id := str(profile.get("campaign_stage_id", ""))
		if stage_id.is_empty():
			continue
		if not stage_profiles.has(stage_id):
			stage_profiles[stage_id] = []
		(stage_profiles[stage_id] as Array).append(profile)
	var ordered_stage_ids: Array[String] = []
	for stage_id in stage_profiles:
		ordered_stage_ids.append(str(stage_id))
	ordered_stage_ids.sort_custom(func(a: String, b: String) -> bool:
		return _stage_index(stage_profiles[a]) < _stage_index(stage_profiles[b])
	)
	var occupied: Array[Vector2] = []
	for stage_id in ordered_stage_ids:
		var profiles: Array = stage_profiles[stage_id]
		var representative: Dictionary = profiles[0]
		var candidate_count := int(representative.get("campaign_candidate_count", profiles.size()))
		var generated: Array[Vector2i] = _generate_stage_cells(representative, candidate_count, occupied)
		for cell in generated:
			occupied.append(Vector2(cell))
		for profile in profiles:
			var candidate_index := int((profile as Dictionary).get("campaign_candidate_index", 0))
			if candidate_index < 0 or candidate_index >= generated.size():
				continue
			var cell: Vector2i = generated[candidate_index]
			(profile as Dictionary)["campaign_grid_position"] = Vector2(cell)
			_campaign_marker_cells[str((profile as Dictionary).get("id", ""))] = cell


func _stage_index(profiles: Array) -> int:
	if profiles.is_empty():
		return 0
	return int((profiles[0] as Dictionary).get("campaign_stage_index", 0))


func _generate_stage_cells(profile: Dictionary, count: int, occupied: Array[Vector2]) -> Array[Vector2i]:
	var bounds: Array = profile.get("campaign_region_bounds", [])
	var allowed_biomes: Array = profile.get("campaign_region_biomes", [])
	var placement: Dictionary = profile.get("campaign_placement", {})
	var density_scale := float(GRID_COLUMNS - 1) / 79.0
	var minimum_spacing := float(placement.get("minimum_spacing", 2.4)) * density_scale
	var infrastructure_clearance := float(placement.get("infrastructure_clearance", 1.1)) * density_scale
	var landmark_clearance := float(placement.get("landmark_clearance", 2.2))
	var design_min := Vector2(float(bounds[0]), float(bounds[1])) if bounds.size() >= 4 else Vector2(4, 1)
	var design_max := Vector2(float(bounds[2]), float(bounds[3])) if bounds.size() >= 4 else Vector2(45, 28)
	var grid_min := Vector2i(_design_to_grid(design_min).ceil())
	var grid_max := Vector2i(_design_to_grid(design_max).floor())
	var available: Array[Vector2i] = []
	for row in range(grid_min.y, grid_max.y + 1):
		for column in range(grid_min.x, grid_max.x + 1):
			if column < 0 or row < 0 or column >= GRID_COLUMNS or row >= GRID_ROWS:
				continue
			if not _is_world_tile(column, row):
				continue
			if _is_lake_cell(column, row):
				continue
			if not allowed_biomes.is_empty() and not allowed_biomes.has(_biome_at(column, row)):
				continue
			var grid := Vector2(column, row)
			if _near_infrastructure(grid, infrastructure_clearance):
				continue
			if _near_landmark(grid, landmark_clearance):
				continue
			available.append(Vector2i(column, row))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(profile.get("campaign_seed", 0)) + int(profile.get("campaign_stage_index", 0)) * 104729
	for index in range(available.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var value := available[index]
		available[index] = available[swap_index]
		available[swap_index] = value
	var result: Array[Vector2i] = []
	for candidate in available:
		if not _far_enough_from_cells(Vector2(candidate), occupied, minimum_spacing):
			continue
		var selected_cells: Array[Vector2] = []
		for selected in result:
			selected_cells.append(Vector2(selected))
		if not _far_enough_from_cells(Vector2(candidate), selected_cells, minimum_spacing):
			continue
		result.append(candidate)
		if result.size() >= count:
			break
	if result.size() < count:
		for candidate in available:
			if result.has(candidate):
				continue
			result.append(candidate)
			if result.size() >= count:
				break
	return result


func _far_enough_from_cells(cell: Vector2, cells: Array[Vector2], distance: float) -> bool:
	for other in cells:
		if cell.distance_to(other) < distance:
			return false
	return true


func _near_landmark(grid: Vector2, radius: float) -> bool:
	var design := _grid_to_design(grid)
	var landmarks := [
		Vector2(13, 17), Vector2(22, 18), Vector2(28, 21), Vector2(39, 2),
		Vector2(18, 14), Vector2(32, 16), Vector2(40, 11), Vector2(35, 9),
		Vector2(38, 8), Vector2(42, 19), Vector2(24, 24), Vector2(5, 8),
		Vector2(3, 12), Vector2(8, 13), Vector2(35, 27), Vector2(41, 26),
		Vector2(45, 23), Vector2(29, 28), Vector2(39, 29), Vector2(46, 20),
	]
	for landmark in landmarks:
		if design.distance_to(landmark) < radius:
			return true
	return false


func _is_campaign_clearing(cell: Vector2i) -> bool:
	var clearing_radius := float(GRID_COLUMNS - 1) / 79.0
	for marker_cell in _campaign_marker_cells.values():
		if cell.distance_to(marker_cell as Vector2i) <= clearing_radius:
			return true
	return false


func _design_to_world(design: Vector2) -> Vector2:
	return _grid_to_world(_design_to_grid(design))


func _design_surface_to_world(design: Vector2, lift: float = 0.0) -> Vector2:
	return _grid_surface_to_world(_design_to_grid(design), lift)


func _design_to_grid(design: Vector2) -> Vector2:
	return Vector2(
		design.x * float(GRID_COLUMNS - 1) / float(DESIGN_GRID_COLUMNS - 1),
		design.y * float(GRID_ROWS - 1) / float(DESIGN_GRID_ROWS - 1)
	)


func _grid_to_design(grid: Vector2) -> Vector2:
	return Vector2(
		grid.x * float(DESIGN_GRID_COLUMNS - 1) / float(GRID_COLUMNS - 1),
		grid.y * float(DESIGN_GRID_ROWS - 1) / float(GRID_ROWS - 1)
	)


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
