@tool
class_name AdventureWorldMap3D
extends Node3D

signal level_focused(profile: Dictionary)
signal level_activated(level_id: String)

const COLS := 34
const ROWS := 23
const HEX_RADIUS := 430.0
const HEX_WIDTH := 744.78
const ROW_STEP := 645.0
const CAMERA_MIN_SIZE := 7200.0
const CAMERA_MAX_SIZE := 24500.0

const STYLIZED_ROOT := "res://assets/environment/quaternius_stylized/"
const VILLAGE_ROOT := "res://assets/environment/quaternius_medieval_village/"
const COMMERCIAL_ROOT := "res://assets/environment/kenney_city_commercial/"
const INDUSTRIAL_ROOT := "res://assets/environment/kenney_city_industrial/"
const SHIPS_ROOT := "res://assets/environment/quaternius_ships/"

const BIOME_COLORS := {
	"ocean": Color("#15556d"),
	"coast": Color("#29889d"),
	"grass": Color("#619b45"),
	"plains": Color("#9ba94e"),
	"forest": Color("#3f7837"),
	"desert": Color("#c99b42"),
	"tundra": Color("#71877e"),
	"snow": Color("#d3e1df"),
	"mountain": Color("#626d68"),
	"floating": Color("#62a66b"),
}

const CITY_SITES := [
	["洛安德王庭", Vector2(0.34, 0.41), "loand"],
	["达特未来城", Vector2(0.60, 0.49), "datt"],
	["赫伦工业海岸", Vector2(0.82, 0.31), "heren"],
	["普赛提亚枢纽港", Vector2(0.84, 0.52), "port"],
	["西方浮空王庭", Vector2(0.13, 0.19), "floating"],
]

const RIVER_PATHS := [
	[Vector2(0.34, 0.20), Vector2(0.36, 0.27), Vector2(0.33, 0.34), Vector2(0.38, 0.40), Vector2(0.43, 0.45), Vector2(0.48, 0.49), Vector2(0.53, 0.57), Vector2(0.51, 0.67), Vector2(0.56, 0.75)],
	[Vector2(0.69, 0.13), Vector2(0.67, 0.20), Vector2(0.71, 0.26), Vector2(0.69, 0.33), Vector2(0.74, 0.39), Vector2(0.79, 0.44), Vector2(0.87, 0.47)],
]

const DATT_CANALS := [
	[Vector2(0.60, 0.29), Vector2(0.60, 0.61)],
	[Vector2(0.46, 0.49), Vector2(0.77, 0.49)],
]

var _profiles: Array[Dictionary] = []
var _cells: Dictionary = {}
var _land_cells: Array[Dictionary] = []
var _marker_by_id: Dictionary = {}
var _asset_cache: Dictionary = {}
var _generated: Node3D
var _camera: Camera3D
var _camera_target := Vector3.ZERO
var _camera_size := 17200.0
var _camera_yaw := deg_to_rad(-8.0)
var _camera_pitch := deg_to_rad(53.0)
var _camera_distance := 22000.0
var _pan_dragging := false
var _pointer_down := Vector2.ZERO
var _selected_level_id := ""
var _hovered_level_id := ""
var _elapsed := 0.0


func configure(profiles: Array[Dictionary]) -> void:
	_profiles.clear()
	for profile in profiles:
		_profiles.append(profile.duplicate(true))
	if is_inside_tree():
		_rebuild_campaign_layer()


func focus_level(level_id: String) -> void:
	if not _marker_by_id.has(level_id):
		return
	_selected_level_id = level_id
	_refresh_markers()


func reset_camera() -> void:
	_camera_target = Vector3(0.0, 0.0, 450.0)
	_camera_size = 17200.0
	_update_camera()


func _ready() -> void:
	if Engine.is_editor_hint() and _profiles.is_empty():
		_profiles = _editor_preview_profiles()
	_build_world()
	set_process(true)
	set_process_input(not Engine.is_editor_hint())


func _process(delta: float) -> void:
	_elapsed += delta
	for raw_id in _marker_by_id:
		var marker := _marker_by_id[raw_id] as Area3D
		if not is_instance_valid(marker):
			continue
		var beacon := marker.get_node_or_null("Visual/Beacon") as Node3D
		if beacon != null:
			beacon.position.y = 185.0 + sin(_elapsed * 2.3 + float(marker.get_meta("phase", 0.0))) * 24.0
			beacon.rotation.y += delta * 0.8


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_WHEEL_UP and mouse.pressed:
			_camera_size = maxf(CAMERA_MIN_SIZE, _camera_size * 0.88)
			_update_camera()
			get_viewport().set_input_as_handled()
		elif mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse.pressed:
			_camera_size = minf(CAMERA_MAX_SIZE, _camera_size * 1.13)
			_update_camera()
			get_viewport().set_input_as_handled()
		elif mouse.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			_pan_dragging = mouse.pressed
			_pointer_down = mouse.position
	elif event is InputEventMouseMotion and _pan_dragging:
		var motion := event as InputEventMouseMotion
		var factor := _camera_size / 900.0
		_camera_target.x -= motion.relative.x * factor
		_camera_target.z -= motion.relative.y * factor
		_camera_target.x = clampf(_camera_target.x, -7600.0, 7600.0)
		_camera_target.z = clampf(_camera_target.z, -5100.0, 5100.0)
		_update_camera()
		get_viewport().set_input_as_handled()


func _build_world() -> void:
	var old := get_node_or_null("GeneratedWorld")
	if old != null:
		old.free()
	_generated = Node3D.new()
	_generated.name = "GeneratedWorld"
	add_child(_generated)
	_add_environment()
	_generate_cells()
	_build_tiles()
	_build_grid_lines()
	_add_geography_features()
	_add_waterways()
	_add_city_sites()
	_rebuild_campaign_layer()
	_update_camera()


func _add_environment() -> void:
	var environment_node := WorldEnvironment.new()
	environment_node.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#0b3548")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#c5ddd8")
	environment.ambient_light_energy = 0.48
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = false
	environment_node.environment = environment
	_generated.add_child(environment_node)

	var light := DirectionalLight3D.new()
	light.name = "Sun"
	light.light_color = Color("#fff0cf")
	light.light_energy = 0.92
	light.shadow_enabled = true
	light.rotation_degrees = Vector3(-52.0, -34.0, 0.0)
	_generated.add_child(light)

	_camera = Camera3D.new()
	_camera.name = "Camera3D"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.current = true
	_camera.near = 20.0
	_camera.far = 70000.0
	_generated.add_child(_camera)


func _generate_cells() -> void:
	_cells.clear()
	_land_cells.clear()
	for row in range(ROWS):
		for col in range(COLS):
			var normalized := Vector2(float(col) / float(COLS - 1), float(row) / float(ROWS - 1))
			var floating := _is_floating_land(normalized)
			var southern_island := _is_southern_island(normalized)
			var land := floating or _is_main_land(normalized, col, row) or southern_island
			var cell := {
				"col": col,
				"row": row,
				"normalized": normalized,
				"center": _hex_center(col, row),
				"land": land,
				"floating": floating,
				"southern_island": southern_island,
				"biome": "ocean",
				"elevation": 0,
				"height": 0.0,
				"base_y": 0.0,
			}
			_cells[_cell_key(col, row)] = cell
	for row in range(ROWS):
		for col in range(COLS):
			var key := _cell_key(col, row)
			var cell: Dictionary = _cells[key]
			if bool(cell["land"]):
				_classify_land_cell(cell)
				_land_cells.append(cell)
			elif _has_land_neighbor(col, row):
				cell["biome"] = "coast"
				_cells[key] = cell


func _is_main_land(p: Vector2, col: int, row: int) -> bool:
	if p.x < 0.205 or p.y > 0.765:
		return false
	var rough := sin(float(col) * 1.61 + float(row) * 0.73) * 0.045
	rough += sin(float(col) * 0.43 - float(row) * 1.29) * 0.025
	var ellipse := pow((p.x - 0.55) / 0.47, 2.0) + pow((p.y - 0.405) / 0.39, 2.0)
	if ellipse > 1.0 + rough:
		return false
	if p.x < 0.30 and p.y > 0.56 + rough:
		return false
	if p.x > 0.80 and p.y > 0.59 + rough:
		return false
	if p.x > 0.90 and p.y < 0.22 - rough:
		return false
	return true


func _is_southern_island(p: Vector2) -> bool:
	var centers := [Vector2(0.35, 0.82), Vector2(0.47, 0.87), Vector2(0.59, 0.82), Vector2(0.72, 0.88), Vector2(0.84, 0.81)]
	for i in range(centers.size()):
		var radius := 0.055 if i % 2 == 0 else 0.045
		if p.distance_to(centers[i]) < radius:
			return true
	return false


func _is_floating_land(p: Vector2) -> bool:
	var centers := [Vector2(0.085, 0.16), Vector2(0.145, 0.20), Vector2(0.095, 0.29), Vector2(0.16, 0.37), Vector2(0.09, 0.46)]
	for i in range(centers.size()):
		var radius := 0.063 if i == 1 else 0.048
		if p.distance_to(centers[i]) < radius:
			return true
	return false


func _classify_land_cell(cell: Dictionary) -> void:
	var p: Vector2 = cell["normalized"]
	var col := int(cell["col"])
	var row := int(cell["row"])
	var noise := sin(float(col) * 1.13 + float(row) * 2.07) * 0.5 + 0.5
	var biome := "grass"
	var elevation := 1
	var base_y := 0.0
	if bool(cell["floating"]):
		biome = "floating"
		elevation = 1
		base_y = 1120.0 + sin(float(col + row)) * 120.0
	elif bool(cell["southern_island"]):
		biome = "forest" if noise > 0.58 else ("grass" if noise > 0.22 else "plains")
		elevation = 1
	elif p.y < 0.12:
		biome = "snow"
		elevation = 2
	elif p.y < 0.22:
		biome = "snow" if noise > 0.42 else "tundra"
		elevation = 2
	elif _is_mountain_ridge(p, 0.030) and noise > 0.18:
		biome = "snow" if p.y < 0.23 else "mountain"
		elevation = 4
	elif _is_mountain_ridge(p, 0.088):
		biome = "tundra" if p.y < 0.25 else "plains"
		elevation = 2
	elif p.y > 0.61 and p.x < 0.74:
		biome = "desert"
		elevation = 1
	elif p.x < 0.49 and p.y > 0.27 and p.y < 0.59 and noise > 0.20:
		biome = "forest"
		elevation = 1 if noise < 0.72 else 2
	elif p.x > 0.77 and p.y > 0.29 and p.y < 0.58:
		biome = "plains"
	else:
		biome = "grass" if noise > 0.28 else "plains"
		elevation = 1
	cell["biome"] = biome
	cell["elevation"] = elevation
	cell["height"] = 72.0 + float(elevation) * 92.0
	cell["base_y"] = base_y
	_cells[_cell_key(col, row)] = cell


func _is_mountain_ridge(p: Vector2, width: float) -> bool:
	if p.x > 0.54 and p.x < 0.91 and p.y < 0.40:
		var north_curve := 0.245 + sin(p.x * 18.0) * 0.055
		if absf(p.y - north_curve) < width:
			return true
	if p.x > 0.27 and p.x < 0.54 and p.y > 0.24 and p.y < 0.48:
		var west_curve := 0.355 + sin(p.x * 21.0 + 0.8) * 0.045
		if absf(p.y - west_curve) < width * 0.72:
			return true
	if p.x > 0.39 and p.x < 0.76 and p.y > 0.52 and p.y < 0.69:
		var south_curve := 0.605 + sin(p.x * 16.0) * 0.035
		if absf(p.y - south_curve) < width * 0.62:
			return true
	return false


func _has_land_neighbor(col: int, row: int) -> bool:
	for neighbor in _neighbor_offsets(row):
		var candidate: Dictionary = _cells.get(_cell_key(col + neighbor.x, row + neighbor.y), {})
		if not candidate.is_empty() and bool(candidate.get("land", false)):
			return true
	return false


func _neighbor_offsets(row: int) -> Array[Vector2i]:
	if row % 2 == 0:
		return [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1)]
	return [Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]


func _build_tiles() -> void:
	var buckets: Dictionary = {}
	for key in BIOME_COLORS:
		buckets[key] = []
	for raw_cell in _cells.values():
		var cell: Dictionary = raw_cell
		(buckets[str(cell["biome"])] as Array).append(cell)
	for biome in buckets:
		var cells: Array = buckets[biome]
		if cells.is_empty():
			continue
		var tile_mesh := CylinderMesh.new()
		tile_mesh.top_radius = HEX_RADIUS * 0.965
		tile_mesh.bottom_radius = HEX_RADIUS * 0.965
		tile_mesh.height = 1.0
		tile_mesh.radial_segments = 6
		tile_mesh.rings = 1
		tile_mesh.material = _material(BIOME_COLORS[biome], 0.88, 0.0)
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = tile_mesh
		multimesh.instance_count = cells.size()
		for i in range(cells.size()):
			var cell: Dictionary = cells[i]
			var center: Vector3 = cell["center"]
			var height := 58.0 if biome in ["ocean", "coast"] else float(cell["height"])
			var base_y := -58.0 if biome in ["ocean", "coast"] else float(cell["base_y"])
			var transform := Transform3D(Basis().scaled(Vector3(1.0, height, 1.0)), Vector3(center.x, base_y + height * 0.5, center.z))
			multimesh.set_instance_transform(i, transform)
		var instance := MultiMeshInstance3D.new()
		instance.name = "%sTiles" % str(biome).capitalize()
		instance.multimesh = multimesh
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if biome not in ["ocean", "coast"] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_generated.add_child(instance)


func _build_grid_lines() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_LINES)
	for raw_cell in _cells.values():
		var cell: Dictionary = raw_cell
		var center: Vector3 = cell["center"]
		var top := _cell_top(cell) + 5.0
		var line_color := Color(0.04, 0.12, 0.14, 0.42) if bool(cell["land"]) else Color(0.18, 0.55, 0.63, 0.22)
		for side in range(6):
			var a := _hex_corner(center, side, top, HEX_RADIUS * 0.965)
			var b := _hex_corner(center, side + 1, top, HEX_RADIUS * 0.965)
			surface.set_color(line_color)
			surface.add_vertex(a)
			surface.set_color(line_color)
			surface.add_vertex(b)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "HexGrid"
	mesh_instance.mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_generated.add_child(mesh_instance)


func _add_geography_features() -> void:
	var features := Node3D.new()
	features.name = "GeographyFeatures"
	_generated.add_child(features)
	for cell in _land_cells:
		var biome := str(cell["biome"])
		var seed_value := int(cell["col"]) * 73856093 ^ int(cell["row"]) * 19349663
		if int(cell["elevation"]) >= 4:
			_add_mountain_cluster(features, cell, seed_value, biome == "snow")
		elif biome in ["forest", "floating"] and abs(seed_value) % 3 != 0:
			_add_tree_cluster(features, cell, seed_value)
		elif biome == "desert" and abs(seed_value) % 9 == 0:
			_add_desert_resource(features, cell, seed_value)
		elif biome in ["grass", "plains"] and abs(seed_value) % 13 == 0:
			_add_farm_tile(features, cell, seed_value)
		elif int(cell["elevation"]) == 2 and abs(seed_value) % 5 == 0:
			_add_mine_resource(features, cell, seed_value)
	_add_floating_island_undersides(features)


func _add_tree_cluster(parent: Node3D, cell: Dictionary, seed_value: int) -> void:
	var paths := [STYLIZED_ROOT + "normal_tree_1.glb", STYLIZED_ROOT + "normal_tree_2.glb", STYLIZED_ROOT + "birch_tree_2.glb"]
	if str(cell["biome"]) == "floating":
		paths = [STYLIZED_ROOT + "normal_tree_2.glb", STYLIZED_ROOT + "birch_tree_2.glb"]
	var offsets := [Vector2(-0.24, -0.12), Vector2(0.20, -0.05), Vector2(0.02, 0.23)]
	for i in range(3):
		var scale_value := 48.0 + float(abs(seed_value + i * 17) % 18)
		_add_scene_asset(parent, paths[abs(seed_value + i) % paths.size()], _feature_position(cell, offsets[i], 8.0), scale_value, float(seed_value + i * 31) * 0.13)


func _add_mountain_cluster(parent: Node3D, cell: Dictionary, seed_value: int, snow_cap: bool) -> void:
	var center: Vector3 = cell["center"]
	var top := _cell_top(cell)
	var offsets := [Vector2(-0.16, 0.10), Vector2(0.17, -0.11), Vector2(0.02, 0.18)]
	var peak_count: int = 2 + absi(seed_value) % 2
	for i in range(peak_count):
		var height := 420.0 + float(abs(seed_value + i * 101) % 190)
		var radius := 145.0 + float(abs(seed_value + i * 53) % 55)
		var peak := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 4.0
		cone.bottom_radius = radius
		cone.height = height
		cone.radial_segments = 7
		cone.material = _material(Color("#525d59"), 0.92, 0.0)
		peak.mesh = cone
		peak.position = Vector3(center.x + offsets[i].x * HEX_RADIUS, top + height * 0.5, center.z + offsets[i].y * HEX_RADIUS)
		peak.rotation.y = float(seed_value + i * 23) * 0.09
		parent.add_child(peak)
		if snow_cap:
			var cap := MeshInstance3D.new()
			var cap_mesh := CylinderMesh.new()
			cap_mesh.top_radius = 3.0
			cap_mesh.bottom_radius = radius * 0.49
			cap_mesh.height = height * 0.36
			cap_mesh.radial_segments = 7
			cap_mesh.material = _material(Color("#e8f2ef"), 0.9, 0.0)
			cap.mesh = cap_mesh
			cap.position = Vector3(peak.position.x, top + height * 0.82, peak.position.z)
			cap.rotation.y = peak.rotation.y
			parent.add_child(cap)
func _add_desert_resource(parent: Node3D, cell: Dictionary, seed_value: int) -> void:
	_add_mine_resource(parent, cell, seed_value, Color("#8d6950"))


func _add_farm_tile(parent: Node3D, cell: Dictionary, seed_value: int) -> void:
	var center: Vector3 = cell["center"]
	var top := _cell_top(cell) + 10.0
	var angle := float(seed_value % 4) * PI * 0.25
	for i in range(5):
		var strip := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(270.0, 12.0, 28.0)
		box.material = _material(Color("#d8bd54"), 0.94, 0.0)
		strip.mesh = box
		strip.position = Vector3(center.x, top, center.z + float(i - 2) * 56.0)
		strip.rotation.y = angle
		parent.add_child(strip)


func _add_mine_resource(parent: Node3D, cell: Dictionary, seed_value: int, color := Color("#4d5956")) -> void:
	var offsets := [Vector2(-0.16, 0.08), Vector2(0.13, 0.12), Vector2(0.02, -0.14)]
	for i in range(3):
		var rock := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 58.0 + float(abs(seed_value + i * 17) % 25)
		sphere.height = sphere.radius * 1.45
		sphere.radial_segments = 7
		sphere.rings = 4
		sphere.material = _material(color, 0.96, 0.0)
		rock.mesh = sphere
		rock.position = _feature_position(cell, offsets[i], sphere.height * 0.42)
		rock.scale = Vector3(1.0, 0.75 + float(i) * 0.08, 0.9)
		parent.add_child(rock)


func _add_floating_island_undersides(parent: Node3D) -> void:
	for cell in _land_cells:
		if not bool(cell["floating"]):
			continue
		var cone_instance := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = HEX_RADIUS * 0.69
		cone.bottom_radius = 18.0
		cone.height = 720.0
		cone.radial_segments = 6
		cone.material = _material(Color("#596a61"), 0.94, 0.0)
		cone_instance.mesh = cone
		var center: Vector3 = cell["center"]
		cone_instance.position = Vector3(center.x, float(cell["base_y"]) - 360.0, center.z)
		parent.add_child(cone_instance)


func _add_waterways() -> void:
	var waterways := Node3D.new()
	waterways.name = "RiversAndCanals"
	_generated.add_child(waterways)
	for path in RIVER_PATHS:
		_add_path_ribbon(waterways, path, 58.0, Color("#45b7cf"), 13.0)
	for path in DATT_CANALS:
		_add_path_ribbon(waterways, path, 82.0, Color("#62d3df"), 16.0)


func _add_city_sites() -> void:
	var cities := Node3D.new()
	cities.name = "RegionalCities"
	_generated.add_child(cities)
	for definition in CITY_SITES:
		var label := str(definition[0])
		var cell := _cell_from_normalized(definition[1])
		if cell.is_empty():
			continue
		match str(definition[2]):
			"loand":
				_add_loand_city(cities, cell)
			"datt":
				_add_datt_city(cities, cell)
			"heren":
				_add_heren_city(cities, cell)
			"port":
				_add_port_city(cities, cell)
			"floating":
				_add_floating_city(cities, cell)
		_add_city_label(cities, label, cell)
	_add_datt_satellites(cities)
	_add_heren_industrial_corridor(cities)
	_add_southern_fleet(cities)


func _add_loand_city(parent: Node3D, cell: Dictionary) -> void:
	var assets := ["bell_tower.glb", "house_2.glb", "house_3.glb", "blacksmith.glb", "inn.glb"]
	var offsets := [Vector2(0.0, 0.0), Vector2(-0.22, 0.15), Vector2(0.22, 0.12), Vector2(-0.18, -0.18), Vector2(0.20, -0.20)]
	for i in range(assets.size()):
		_add_scene_asset(parent, VILLAGE_ROOT + assets[i], _feature_position(cell, offsets[i], 10.0), 58.0 if i > 0 else 72.0, float(i) * 1.1)


func _add_datt_city(parent: Node3D, cell: Dictionary) -> void:
	var assets := ["building-skyscraper-b.glb", "building-skyscraper-d.glb", "building-j.glb", "building-l.glb", "building-c.glb"]
	var offsets := [Vector2(0.0, 0.0), Vector2(-0.20, 0.14), Vector2(0.21, 0.13), Vector2(-0.16, -0.18), Vector2(0.20, -0.18)]
	for i in range(assets.size()):
		_add_scene_asset(parent, COMMERCIAL_ROOT + assets[i], _feature_position(cell, offsets[i], 12.0), 52.0 if i < 2 else 44.0, float(i) * 0.75)
	_add_city_ring(parent, cell, Color("#6be2ed"))


func _add_datt_satellites(parent: Node3D) -> void:
	var sites := [
		[Vector2(0.55, 0.46), "building-h.glb", 40.0],
		[Vector2(0.64, 0.45), "building-skyscraper-e.glb", 46.0],
		[Vector2(0.65, 0.53), "building-n.glb", 42.0],
		[Vector2(0.57, 0.55), "building-f.glb", 40.0],
	]
	for site in sites:
		var cell := _cell_from_normalized(site[0])
		if not cell.is_empty():
			_add_scene_asset(parent, COMMERCIAL_ROOT + str(site[1]), _feature_position(cell, Vector2.ZERO, 10.0), float(site[2]), float(site[0].x) * 5.0)


func _add_heren_city(parent: Node3D, cell: Dictionary) -> void:
	var assets := ["building-q.glb", "building-r.glb", "building-t.glb", "chimney-large.glb", "detail-tank.glb"]
	var offsets := [Vector2(-0.18, 0.12), Vector2(0.15, 0.15), Vector2(0.0, -0.18), Vector2(0.25, -0.10), Vector2(-0.26, -0.12)]
	for i in range(assets.size()):
		_add_scene_asset(parent, INDUSTRIAL_ROOT + assets[i], _feature_position(cell, offsets[i], 10.0), 50.0 if i < 3 else 58.0, float(i) * 0.9)


func _add_heren_industrial_corridor(parent: Node3D) -> void:
	var sites := [
		[Vector2(0.85, 0.24), "building-l.glb", 45.0],
		[Vector2(0.87, 0.35), "building-g.glb", 48.0],
		[Vector2(0.84, 0.40), "building-b.glb", 46.0],
		[Vector2(0.90, 0.43), "chimney-large.glb", 64.0],
	]
	for site in sites:
		var cell := _cell_from_normalized(site[0])
		if not cell.is_empty():
			_add_scene_asset(parent, INDUSTRIAL_ROOT + str(site[1]), _feature_position(cell, Vector2.ZERO, 10.0), float(site[2]), float(site[0].y) * 7.0)


func _add_port_city(parent: Node3D, cell: Dictionary) -> void:
	_add_scene_asset(parent, COMMERCIAL_ROOT + "building-e.glb", _feature_position(cell, Vector2(-0.20, 0.0), 10.0), 46.0, 0.4)
	_add_scene_asset(parent, COMMERCIAL_ROOT + "building-skyscraper-a.glb", _feature_position(cell, Vector2(0.14, 0.02), 10.0), 52.0, -0.3)
	var water_cell := _nearest_water_cell(Vector2(0.89, 0.53))
	if not water_cell.is_empty():
		_add_scene_asset(parent, SHIPS_ROOT + "cruiseship.glb", _feature_position(water_cell, Vector2.ZERO, 18.0), 25.0, deg_to_rad(75.0))
	_add_city_ring(parent, cell, Color("#f2bf55"))


func _add_floating_city(parent: Node3D, cell: Dictionary) -> void:
	_add_scene_asset(parent, VILLAGE_ROOT + "bell_tower.glb", _feature_position(cell, Vector2.ZERO, 8.0), 70.0, 0.0)
	_add_scene_asset(parent, VILLAGE_ROOT + "house_4.glb", _feature_position(cell, Vector2(-0.22, 0.12), 8.0), 54.0, 0.7)
	_add_scene_asset(parent, VILLAGE_ROOT + "mill.glb", _feature_position(cell, Vector2(0.22, -0.10), 8.0), 52.0, -0.6)
	_add_city_ring(parent, cell, Color("#c49cff"))


func _add_southern_fleet(parent: Node3D) -> void:
	for p in [Vector2(0.41, 0.78), Vector2(0.63, 0.85), Vector2(0.77, 0.80)]:
		var water_cell := _nearest_water_cell(p)
		if water_cell.is_empty():
			continue
		_add_scene_asset(parent, SHIPS_ROOT + "cruiseship.glb", _feature_position(water_cell, Vector2.ZERO, 16.0), 20.0, p.x * 5.0)


func _add_city_ring(parent: Node3D, cell: Dictionary, color: Color) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 285.0
	torus.outer_radius = 302.0
	torus.rings = 48
	torus.ring_segments = 8
	torus.material = _emissive_material(color, 1.8)
	ring.mesh = torus
	ring.position = Vector3((cell["center"] as Vector3).x, _cell_top(cell) + 18.0, (cell["center"] as Vector3).z)
	parent.add_child(ring)


func _add_city_label(parent: Node3D, text: String, cell: Dictionary) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 38
	label.pixel_size = 2.45
	label.outline_size = 9
	label.modulate = Color("#fff3cf")
	label.outline_modulate = Color(0.02, 0.05, 0.06, 0.92)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = Vector3((cell["center"] as Vector3).x, _cell_top(cell) + 620.0, (cell["center"] as Vector3).z)
	parent.add_child(label)


func _rebuild_campaign_layer() -> void:
	if _generated == null:
		return
	var old := _generated.get_node_or_null("CampaignLayer")
	if old != null:
		old.free()
	_marker_by_id.clear()
	var campaign := Node3D.new()
	campaign.name = "CampaignLayer"
	_generated.add_child(campaign)
	for i in range(_profiles.size() - 1):
		_add_campaign_route(campaign, _profiles[i], _profiles[i + 1])
	for i in range(_profiles.size()):
		_add_level_marker(campaign, _profiles[i], i)
	_refresh_markers()


func _add_campaign_route(parent: Node3D, from_profile: Dictionary, to_profile: Dictionary) -> void:
	var from_cell := _cell_from_normalized(from_profile.get("map_position", Vector2(0.5, 0.5)))
	var to_cell := _cell_from_normalized(to_profile.get("map_position", Vector2(0.5, 0.5)))
	if from_cell.is_empty() or to_cell.is_empty():
		return
	var mode := str(to_profile.get("travel_mode", "walk"))
	var color := Color("#9b6a3a")
	if mode == "boat":
		color = Color("#68d0dc")
	elif mode == "airship":
		color = Color("#c79df2")
	var route := _find_hex_route(from_cell, to_cell, mode)
	if route.size() < 2:
		return
	var route_points: Array[Vector3] = []
	for cell in route:
		var point := _marker_world_position(cell)
		point.y += 240.0 if mode == "airship" else 32.0
		route_points.append(point)
	for i in range(route_points.size() - 1):
		if mode == "airship" and i % 2 == 1:
			continue
		_add_world_ribbon(parent, route_points[i], route_points[i + 1], 46.0, color)
	var arrow_index := clampi(roundi(float(route_points.size() - 2) * 0.64), 0, route_points.size() - 2)
	_add_route_arrow(parent, route_points[arrow_index].lerp(route_points[arrow_index + 1], 0.55), route_points[arrow_index + 1] - route_points[arrow_index], color)


func _add_level_marker(parent: Node3D, profile: Dictionary, marker_index: int) -> void:
	var level_id := str(profile.get("id", ""))
	if level_id.is_empty():
		return
	var cell := _cell_from_normalized(profile.get("map_position", Vector2(0.5, 0.5)))
	if cell.is_empty():
		return
	var marker := Area3D.new()
	marker.name = "Level_%s" % level_id
	marker.position = _marker_world_position(cell)
	marker.set_meta("profile", profile.duplicate(true))
	marker.set_meta("phase", float(marker_index) * 0.73)
	marker.input_ray_pickable = true
	parent.add_child(marker)

	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 205.0
	collision.shape = sphere
	collision.position.y = 145.0
	marker.add_child(collision)

	var visual := Node3D.new()
	visual.name = "Visual"
	marker.add_child(visual)
	var base := MeshInstance3D.new()
	base.name = "Base"
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 126.0
	base_mesh.bottom_radius = 148.0
	base_mesh.height = 34.0
	base_mesh.radial_segments = 6
	base_mesh.material = _material(Color("#e6b950"), 0.55, 0.18)
	base.mesh = base_mesh
	base.position.y = 24.0
	visual.add_child(base)

	var beacon := MeshInstance3D.new()
	beacon.name = "Beacon"
	var beacon_mesh := PrismMesh.new()
	beacon_mesh.size = Vector3(98.0, 150.0, 98.0)
	beacon_mesh.material = _emissive_material(Color("#ffe781"), 2.0)
	beacon.mesh = beacon_mesh
	beacon.position.y = 185.0
	visual.add_child(beacon)

	var label := Label3D.new()
	label.name = "Label"
	label.text = "%s  %s" % [str(profile.get("local_number", marker_index + 1)), str(profile.get("name", level_id))]
	label.font_size = 34
	label.pixel_size = 1.85
	label.outline_size = 8
	label.modulate = Color("#fff4d7")
	label.outline_modulate = Color(0.02, 0.04, 0.05, 0.94)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position.y = 360.0
	visual.add_child(label)

	marker.mouse_entered.connect(func(): _on_marker_hovered(level_id))
	marker.mouse_exited.connect(func(): _on_marker_unhovered(level_id))
	marker.input_event.connect(func(_camera_node: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_on_marker_pressed(level_id)
	)
	_marker_by_id[level_id] = marker


func _on_marker_hovered(level_id: String) -> void:
	_hovered_level_id = level_id
	var marker := _marker_by_id.get(level_id) as Area3D
	if marker != null:
		level_focused.emit((marker.get_meta("profile", {}) as Dictionary).duplicate(true))
	_refresh_markers()


func _on_marker_unhovered(level_id: String) -> void:
	if _hovered_level_id == level_id:
		_hovered_level_id = ""
	_refresh_markers()


func _on_marker_pressed(level_id: String) -> void:
	var marker := _marker_by_id.get(level_id) as Area3D
	if marker == null:
		return
	var profile: Dictionary = marker.get_meta("profile", {})
	level_focused.emit(profile.duplicate(true))
	if bool(profile.get("unlocked", false)):
		level_activated.emit(level_id)


func _refresh_markers() -> void:
	for raw_id in _marker_by_id:
		var level_id := str(raw_id)
		var marker := _marker_by_id[level_id] as Area3D
		if marker == null:
			continue
		var profile: Dictionary = marker.get_meta("profile", {})
		var visual := marker.get_node_or_null("Visual") as Node3D
		if visual == null:
			continue
		var emphasized := level_id == _selected_level_id or level_id == _hovered_level_id
		visual.scale = Vector3.ONE * (1.22 if emphasized else 1.0)
		var base := visual.get_node_or_null("Base") as MeshInstance3D
		if base != null:
			var color := Color("#69d0aa") if bool(profile.get("completed", false)) else Color("#e6b950")
			if not bool(profile.get("unlocked", false)):
				color = Color("#69757a")
			base.material_override = _material(color, 0.58, 0.12)


func _find_hex_route(from_cell: Dictionary, to_cell: Dictionary, mode: String) -> Array[Dictionary]:
	if mode == "airship":
		return [from_cell, to_cell]
	var start_key := _cell_key(int(from_cell["col"]), int(from_cell["row"]))
	var target_key := _cell_key(int(to_cell["col"]), int(to_cell["row"]))
	var open: Array[String] = [start_key]
	var came_from: Dictionary = {}
	var costs: Dictionary = {start_key: 0.0}
	while not open.is_empty():
		var current_key := open[0]
		var current_score := float(costs[current_key]) + _route_heuristic(_cells[current_key], to_cell)
		for candidate_key in open:
			var candidate_score := float(costs[candidate_key]) + _route_heuristic(_cells[candidate_key], to_cell)
			if candidate_score < current_score:
				current_key = candidate_key
				current_score = candidate_score
		if current_key == target_key:
			return _reconstruct_route(came_from, current_key)
		open.erase(current_key)
		var current: Dictionary = _cells[current_key]
		for offset in _neighbor_offsets(int(current["row"])):
			var neighbor_key := _cell_key(int(current["col"]) + offset.x, int(current["row"]) + offset.y)
			var neighbor: Dictionary = _cells.get(neighbor_key, {})
			if neighbor.is_empty() or not _route_cell_allowed(neighbor, mode, target_key == neighbor_key):
				continue
			var new_cost := float(costs[current_key]) + _route_cell_cost(neighbor, mode)
			if not costs.has(neighbor_key) or new_cost < float(costs[neighbor_key]):
				costs[neighbor_key] = new_cost
				came_from[neighbor_key] = current_key
				if not open.has(neighbor_key):
					open.append(neighbor_key)
	return [from_cell, to_cell]


func _route_cell_allowed(cell: Dictionary, mode: String, is_target: bool) -> bool:
	if mode == "boat":
		return not bool(cell.get("floating", false)) and (not bool(cell["land"]) or is_target or int(cell["elevation"]) < 4)
	return bool(cell["land"]) and not bool(cell.get("floating", false)) and int(cell["elevation"]) < 4


func _route_cell_cost(cell: Dictionary, mode: String) -> float:
	if mode == "boat":
		return 1.0 if not bool(cell["land"]) else 4.5
	var elevation_cost := float(maxi(0, int(cell["elevation"]) - 1)) * 2.2
	var terrain_cost := 1.8 if str(cell["biome"]) == "forest" else 0.0
	return 1.0 + elevation_cost + terrain_cost


func _route_heuristic(a: Dictionary, b: Dictionary) -> float:
	var a_row := int(a["row"])
	var b_row := int(b["row"])
	var aq := int(a["col"]) - (a_row - (a_row & 1)) / 2
	var bq := int(b["col"]) - (b_row - (b_row & 1)) / 2
	var ar := a_row
	var br := b_row
	return float((abs(aq - bq) + abs(aq + ar - bq - br) + abs(ar - br)) / 2)


func _reconstruct_route(came_from: Dictionary, target_key: String) -> Array[Dictionary]:
	var keys: Array[String] = [target_key]
	var current := target_key
	while came_from.has(current):
		current = str(came_from[current])
		keys.push_front(current)
	var result: Array[Dictionary] = []
	for key in keys:
		result.append(_cells[key])
	return result


func _add_path_ribbon(parent: Node3D, points: Array, width: float, color: Color, lift: float) -> void:
	for i in range(points.size() - 1):
		var a := _world_from_normalized(points[i])
		var b := _world_from_normalized(points[i + 1])
		a.y += lift
		b.y += lift
		_add_world_ribbon(parent, a, b, width, color)


func _add_world_ribbon(parent: Node3D, a: Vector3, b: Vector3, width: float, color: Color) -> void:
	var direction := b - a
	var side := Vector3(-direction.z, 0.0, direction.x).normalized() * width * 0.5
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertex in [a - side, b - side, b + side, a - side, b + side, a + side]:
		surface.set_normal(Vector3.UP)
		surface.add_vertex(vertex)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = surface.commit()
	mesh_instance.material_override = _material(color, 0.63, 0.0)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh_instance)


func _add_route_arrow(parent: Node3D, position: Vector3, direction: Vector3, color: Color) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z).normalized()
	var side := Vector3(-flat.z, 0.0, flat.x)
	var tip := position + flat * 150.0
	var left := position - flat * 90.0 + side * 115.0
	var right := position - flat * 90.0 - side * 115.0
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertex in [left, right, tip]:
		surface.set_normal(Vector3.UP)
		surface.add_vertex(vertex)
	var arrow := MeshInstance3D.new()
	arrow.mesh = surface.commit()
	arrow.material_override = _emissive_material(color, 1.2)
	parent.add_child(arrow)


func _feature_position(cell: Dictionary, offset: Vector2, lift: float) -> Vector3:
	var center: Vector3 = cell["center"]
	return Vector3(center.x + offset.x * HEX_RADIUS, _cell_top(cell) + lift, center.z + offset.y * HEX_RADIUS)


func _marker_world_position(cell: Dictionary) -> Vector3:
	var center: Vector3 = cell["center"]
	return Vector3(center.x, _cell_top(cell) + 24.0, center.z)


func _world_from_normalized(p: Vector2) -> Vector3:
	var cell := _cell_from_normalized(p)
	if cell.is_empty():
		var col := clampi(roundi(p.x * float(COLS - 1)), 0, COLS - 1)
		var row := clampi(roundi(p.y * float(ROWS - 1)), 0, ROWS - 1)
		cell = _cells.get(_cell_key(col, row), {})
	var center: Vector3 = cell.get("center", Vector3.ZERO)
	return Vector3(center.x, _cell_top(cell), center.z)


func _cell_from_normalized(p: Vector2) -> Dictionary:
	var row := clampi(roundi(p.y * float(ROWS - 1)), 0, ROWS - 1)
	var col := clampi(roundi(p.x * float(COLS - 1)), 0, COLS - 1)
	var direct: Dictionary = _cells.get(_cell_key(col, row), {})
	if not direct.is_empty() and bool(direct.get("land", false)):
		return direct
	var best: Dictionary = {}
	var best_distance := INF
	for cell in _land_cells:
		var distance := (cell["normalized"] as Vector2).distance_squared_to(p)
		if distance < best_distance:
			best_distance = distance
			best = cell
	return best


func _nearest_water_cell(p: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := INF
	for raw_cell in _cells.values():
		var cell: Dictionary = raw_cell
		if bool(cell["land"]):
			continue
		var distance := (cell["normalized"] as Vector2).distance_squared_to(p)
		if distance < best_distance:
			best_distance = distance
			best = cell
	return best


func _cell_top(cell: Dictionary) -> float:
	if cell.is_empty() or not bool(cell.get("land", false)):
		return 0.0
	return float(cell.get("base_y", 0.0)) + float(cell.get("height", 0.0))


func _hex_center(col: int, row: int) -> Vector3:
	var x := (float(col) + (0.5 if row % 2 == 1 else 0.0)) * HEX_WIDTH
	var z := float(row) * ROW_STEP
	var total_width := (float(COLS) - 0.5) * HEX_WIDTH
	var total_depth := float(ROWS - 1) * ROW_STEP
	return Vector3(x - total_width * 0.5, 0.0, z - total_depth * 0.5)


func _hex_corner(center: Vector3, corner: int, y: float, radius: float) -> Vector3:
	var angle := deg_to_rad(60.0 * float(corner) + 30.0)
	return Vector3(center.x + cos(angle) * radius, y, center.z + sin(angle) * radius)


func _cell_key(col: int, row: int) -> String:
	return "%d:%d" % [col, row]


func _add_scene_asset(parent: Node3D, path: String, position: Vector3, scale_value: float, yaw: float) -> Node3D:
	var packed := _asset_cache.get(path) as PackedScene
	if packed == null:
		packed = load(path) as PackedScene
		if packed == null:
			return null
		_asset_cache[path] = packed
	var node := packed.instantiate() as Node3D
	if node == null:
		return null
	node.position = position
	node.scale = Vector3.ONE * scale_value
	node.rotation.y = yaw
	parent.add_child(node)
	return node


func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := _material(color, 0.42, 0.08)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


func _update_camera() -> void:
	if _camera == null:
		return
	var horizontal := cos(_camera_pitch) * _camera_distance
	var offset := Vector3(sin(_camera_yaw) * horizontal, sin(_camera_pitch) * _camera_distance, cos(_camera_yaw) * horizontal)
	_camera.position = _camera_target + offset
	_camera.size = _camera_size
	_camera.look_at(_camera_target, Vector3.UP)


func _editor_preview_profiles() -> Array[Dictionary]:
	var catalog = preload("res://src/level/level_catalog.gd").new()
	var result: Array[Dictionary] = []
	for raw_profile in catalog.levels().slice(0, 8):
		var profile: Dictionary = raw_profile.duplicate(true)
		profile["unlocked"] = true
		profile["completed"] = false
		result.append(profile)
	return result
