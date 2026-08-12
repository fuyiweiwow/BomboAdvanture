@tool
class_name AdventureWorldMap3D
extends Node3D

signal level_focused(profile: Dictionary)
signal level_activated(level_id: String)

const MAP_WIDTH := 30.0
const MAP_DEPTH := 20.0
const MAP_SCALE := 800.0
const HEIGHT_SCALE := 160.0
const MARKER_SCALE := 180.0
const CAMERA_MIN_SIZE := 12000.0
const CAMERA_MAX_SIZE := 38000.0
const LEVEL_CATALOG := preload("res://src/level/level_catalog.gd")
const HILOAN_TERRAIN3D := preload("res://src/main/hiloan_terrain3d.tscn")
const MINIATURE_WATER_SHADER := preload("res://assets/environment/materials/miniature_water.gdshader")
const STYLIZED_NATURE_ROOT := "res://assets/environment/quaternius_stylized/"
const NATURE_MEGAKIT_ROOT := "res://assets/environment/quaternius_nature_megakit/"
const MEDIEVAL_VILLAGE_ROOT := "res://assets/environment/quaternius_medieval_village/"
const MODULAR_STREETS_ROOT := "res://assets/environment/quaternius_modular_streets/"
const SHIPS_ROOT := "res://assets/environment/quaternius_ships/"
const INDUSTRIAL_CITY_ROOT := "res://assets/environment/kenney_city_industrial/"
const COMMERCIAL_CITY_ROOT := "res://assets/environment/kenney_city_commercial/"
const KAYKIT_MEDIEVAL_ROOT := "res://assets/environment/kaykit_medieval/buildings/"
const KAYKIT_CITY_ROOT := "res://assets/environment/kaykit_city/"
const KAYKIT_SPACE_ROOT := "res://assets/environment/kaykit_space/"
const ROAD_TEXTURE_ROOT := "res://assets/environment/road_textures/polyhaven/"
const LOAND_RIVER_PATH := [Vector2(-4.0, -6.0), Vector2(-4.7, -5.0), Vector2(-4.5, -4.0), Vector2(-5.2, -3.0), Vector2(-4.9, -2.0), Vector2(-5.6, -0.9), Vector2(-5.1, 0.2), Vector2(-5.5, 1.3), Vector2(-4.6, 2.3), Vector2(-3.8, 3.2), Vector2(-2.4, 3.9), Vector2(-0.6, 4.3)]
const HEREN_RIVER_PATH := [Vector2(7.8, -8.2), Vector2(7.3, -7.2), Vector2(6.7, -6.3), Vector2(7.2, -5.4), Vector2(6.4, -4.5), Vector2(6.2, -3.7), Vector2(6.9, -2.9), Vector2(7.8, -2.2), Vector2(8.7, -1.4), Vector2(9.8, -0.7), Vector2(10.5, 0.2), Vector2(11.6, 0.0), Vector2(12.6, 0.5)]
const SOUTHERN_RIVER_PATH := [Vector2(-0.6, 4.3), Vector2(-0.1, 4.9), Vector2(-0.8, 5.6), Vector2(-0.3, 6.3), Vector2(-0.6, 7.0), Vector2(0.1, 7.6), Vector2(0.0, 8.2), Vector2(0.8, 8.8)]
const LOAND_WEST_TRIBUTARY := [Vector2(-10.2, -2.7), Vector2(-9.3, -2.3), Vector2(-8.6, -1.6), Vector2(-7.8, -1.8), Vector2(-7.0, -1.0), Vector2(-5.6, -0.9)]
const LOAND_NORTH_TRIBUTARY := [Vector2(-2.7, -5.8), Vector2(-3.2, -4.9), Vector2(-3.9, -4.1), Vector2(-3.7, -3.2), Vector2(-4.6, -2.4), Vector2(-5.4, -1.0)]
const HEREN_EAST_TRIBUTARY := [Vector2(10.6, -6.5), Vector2(10.0, -5.8), Vector2(9.3, -5.1), Vector2(9.5, -4.5), Vector2(8.3, -4.1), Vector2(7.4, -4.3), Vector2(6.3, -3.7)]
const WORLD_ROAD_PATHS := [
	["NetherRiverTrail", [Vector2(8.3, -8.7), Vector2(8.0, -8.6), Vector2(7.8, -8.2), Vector2(7.6, -7.6), Vector2(7.2, -7.2), Vector2(7.0, -6.8), Vector2(6.8, -6.4), Vector2(6.8, -6.0), Vector2(7.0, -5.8), Vector2(7.0, -5.4), Vector2(6.8, -5.0), Vector2(6.6, -4.6), Vector2(6.8, -4.4), Vector2(6.6, -4.0), Vector2(6.8, -4.0)], "trail"],
	["HerenWarmCurrentCoastRoad", [Vector2(6.8, -4.0), Vector2(7.0, -3.6), Vector2(7.8, -3.6), Vector2(8.4, -3.4), Vector2(9.0, -2.8), Vector2(9.6, -2.2), Vector2(10.2, -1.6), Vector2(10.6, -1.2), Vector2(10.6, -0.8), Vector2(10.2, -0.4), Vector2(10.2, 0.2), Vector2(9.6, 0.6)], "gravel"],
	["LoandRoyalRoad", [Vector2(-6.9, -2.4), Vector2(-6.4, -2.2), Vector2(-5.8, -2.2), Vector2(-5.2, -2.0), Vector2(-4.6, -2.0), Vector2(-4.2, -1.6), Vector2(-4.2, -1.2), Vector2(-3.8, -0.8), Vector2(-3.2, -0.4), Vector2(-2.6, 0.2), Vector2(-2.0, 0.2), Vector2(-1.4, 0.2), Vector2(-0.8, 0.2), Vector2(-0.6, -0.3)], "royal"],
	["NorthernMountainPass", [Vector2(6.8, -4.0), Vector2(6.6, -3.6), Vector2(6.2, -3.0), Vector2(5.8, -2.6), Vector2(5.0, -2.6), Vector2(4.4, -2.2), Vector2(3.8, -2.2), Vector2(3.2, -2.2), Vector2(2.6, -2.2), Vector2(2.0, -2.2), Vector2(1.4, -2.2), Vector2(0.8, -2.2), Vector2(0.2, -2.0), Vector2(-0.4, -2.0), Vector2(-1.0, -2.0), Vector2(-1.6, -2.0), Vector2(-2.2, -2.0), Vector2(-2.4, -1.4), Vector2(-2.1, -0.8), Vector2(-1.4, 0.2), Vector2(-0.6, -0.3)], "mountain"],
	["SouthernFrontierRoad", [Vector2(-4.2, -1.2), Vector2(-4.4, -0.8), Vector2(-4.8, -0.6), Vector2(-4.2, -0.2), Vector2(-4.0, 0.4), Vector2(-4.0, 1.0), Vector2(-3.8, 1.4), Vector2(-3.6, 1.8), Vector2(-3.6, 2.6), Vector2(-4.0, 3.0), Vector2(-4.0, 3.4), Vector2(-4.2, 3.6), Vector2(-4.2, 4.0), Vector2(-4.2, 4.6), Vector2(-4.4, 5.0), Vector2(-4.4, 5.6), Vector2(-4.8, 5.8)], "frontier"],
	["DattArterialRoad", [Vector2(-0.6, -0.3), Vector2(0.6, 1.0), Vector2(3.0, -0.2), Vector2(3.9, -1.4), Vector2(4.8, -1.0), Vector2(6.9, -0.8), Vector2(8.4, -2.8)], "paved"],
	["EasternPortRoad", [Vector2(4.8, -1.0), Vector2(5.4, -0.6), Vector2(6.0, -0.6), Vector2(6.6, -0.2), Vector2(7.2, -0.2), Vector2(7.8, -0.2), Vector2(8.4, 0.0), Vector2(9.0, 0.4), Vector2(9.6, 0.4), Vector2(10.2, 0.2), Vector2(10.6, 0.0), Vector2(11.4, 0.0)], "paved"],
]

var _profiles: Array[Dictionary] = []
var _camera: Camera3D
var _terrain3d: Node3D
var _camera_target := Vector3(0.0, 420.0, 1600.0)
var _camera_yaw := deg_to_rad(-12.0)
var _camera_pitch := deg_to_rad(40.0)
var _camera_distance := 29000.0
var _camera_size := 22000.0
var _left_dragging := false
var _pan_dragging := false
var _pointer_down := Vector2.ZERO
var _drag_distance := 0.0
var _hovered_level_id := ""
var _selected_level_id := ""
var _marker_by_id: Dictionary = {}
var _animated_vehicles: Array[Dictionary] = []
var _floating_islands: Array[Node3D] = []
var _elapsed := 0.0
var _surface_build_pending := false


func configure(profiles: Array[Dictionary]) -> void:
	_profiles.clear()
	for profile in profiles:
		_profiles.append(profile.duplicate(true))
	if is_inside_tree() and not _surface_build_pending:
		_build_campaign_layer()


func focus_level(level_id: String) -> void:
	if not _marker_by_id.has(level_id):
		return
	_selected_level_id = level_id
	_refresh_marker_emphasis()


func reset_camera() -> void:
	_camera_target = Vector3(0.0, 420.0, 1600.0)
	_camera_yaw = deg_to_rad(-12.0)
	_camera_pitch = deg_to_rad(40.0)
	_camera_distance = 29000.0
	_camera_size = 22000.0
	_update_camera()


func _ready() -> void:
	if not has_node("GeneratedWorld"):
		_build_world()
	_camera = get_node_or_null("GeneratedWorld/Camera3D") as Camera3D
	if Engine.is_editor_hint() and _profiles.is_empty():
		_profiles = _editor_preview_profiles()
	if not _surface_build_pending:
		_build_campaign_layer()
	_update_camera()
	set_process(true)
	set_process_input(not Engine.is_editor_hint())


func _process(delta: float) -> void:
	_elapsed += delta
	for level_id in _marker_by_id:
		var marker := _marker_by_id[level_id] as Area3D
		if marker == null:
			continue
		var base_y := float(marker.get_meta("base_y", marker.position.y))
		var phase := float(marker.get_meta("phase", 0.0))
		marker.position.y = base_y + sin(_elapsed * 2.0 + phase) * 18.0
		var halo := marker.get_node_or_null("Visual/Halo") as MeshInstance3D
		if halo != null:
			halo.rotation.y += delta * 0.8
	for i in range(_floating_islands.size()):
		var island := _floating_islands[i]
		if is_instance_valid(island):
			var base_y := float(island.get_meta("base_y", island.position.y))
			island.position.y = base_y + sin(_elapsed * 0.65 + float(i) * 1.7) * 22.0
	for vehicle_data in _animated_vehicles:
		var vehicle := vehicle_data.get("node") as Node3D
		if not is_instance_valid(vehicle):
			continue
		var speed := float(vehicle_data.get("speed", 0.05))
		var phase := float(vehicle_data.get("phase", 0.0))
		var t := fposmod(_elapsed * speed + phase, 1.0)
		var from_point: Vector3 = vehicle_data.get("from", Vector3.ZERO)
		var to_point: Vector3 = vehicle_data.get("to", Vector3.ZERO)
		vehicle.position = from_point.lerp(to_point, t)
		if vehicle.position.distance_squared_to(to_point) > 1.0:
			vehicle.look_at(to_point, Vector3.UP)


func _input(event: InputEvent) -> void:
	if _camera == null:
		return
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_button.pressed:
			_camera_size = maxf(CAMERA_MIN_SIZE, _camera_size - 1000.0)
			_update_camera()
			get_viewport().set_input_as_handled()
		elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_button.pressed:
			_camera_size = minf(CAMERA_MAX_SIZE, _camera_size + 1000.0)
			_update_camera()
			get_viewport().set_input_as_handled()
		elif mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button.pressed:
				_left_dragging = true
				_pointer_down = mouse_button.position
				_drag_distance = 0.0
			else:
				_left_dragging = false
				if _drag_distance < 7.0:
					_pick_level(mouse_button.position, false)
			get_viewport().set_input_as_handled()
		elif mouse_button.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_pan_dragging = mouse_button.pressed
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _left_dragging:
			_drag_distance += motion.relative.length()
			_camera_yaw -= motion.relative.x * 0.006
			_camera_pitch = clampf(_camera_pitch - motion.relative.y * 0.004, deg_to_rad(35.0), deg_to_rad(72.0))
			_update_camera()
			get_viewport().set_input_as_handled()
		elif _pan_dragging:
			_pan_camera(motion.relative)
			get_viewport().set_input_as_handled()
		else:
			_update_hover(motion.position)


func _build_world() -> void:
	_surface_build_pending = true
	var generated := Node3D.new()
	generated.name = "GeneratedWorld"
	_attach(self, generated)
	_add_environment(generated)
	_add_ocean(generated)
	_add_terrain(generated)
	call_deferred("_complete_surface_build", generated)


func _complete_surface_build(generated: Node3D) -> void:
	if not is_instance_valid(generated) or not is_instance_valid(_terrain3d):
		_surface_build_pending = false
		return
	var data = _terrain3d.call("get_data")
	if data == null or is_nan(float(data.call("get_height", Vector3.ZERO))):
		call_deferred("_complete_surface_build", generated)
		return
	_add_lakes(generated)
	_add_rivers_and_canals(generated)
	_add_world_roads(generated)
	_add_terrain_cover(generated)
	_add_biome_detail_clusters(generated)
	_add_geographic_detail_bands(generated)
	_add_roadside_asset_details(generated)
	_add_regional_architecture(generated)
	_add_river_mouth_ports(generated)
	_add_transport_network(generated)
	_add_southern_future_fleet(generated)
	_add_western_floating_islands(generated)
	_surface_build_pending = false
	_build_campaign_layer()


func _add_environment(parent: Node3D) -> void:
	var light := DirectionalLight3D.new()
	light.name = "SunLight"
	light.rotation_degrees = Vector3(-54.0, -32.0, 0.0)
	light.light_energy = 0.94
	light.shadow_enabled = true
	light.shadow_opacity = 0.58
	_attach(parent, light)

	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#173f47")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#b9d1c1")
	environment.ambient_light_energy = 0.46
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.02
	environment.adjustment_contrast = 1.08
	environment.adjustment_saturation = 1.16
	world_environment.environment = environment
	_attach(parent, world_environment)

	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.current = true
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = _camera_size
	camera.near = 8.0
	camera.far = 100000.0
	_attach(parent, camera)


func _add_ocean(parent: Node3D) -> void:
	var ocean := MeshInstance3D.new()
	ocean.name = "Ocean"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(100000.0, 100000.0)
	ocean.mesh = mesh
	ocean.position.y = 4.0
	ocean.material_override = _material(Color("#184f5c"), 0.52)
	_attach(parent, ocean)

func _add_terrain(parent: Node3D) -> void:
	_terrain3d = HILOAN_TERRAIN3D.instantiate() as Node3D
	_terrain3d.name = "ContinentalTerrain3D"
	var map_camera := parent.get_node_or_null("Camera3D") as Camera3D
	if map_camera != null:
		_terrain3d.call("set_camera", map_camera)
	_attach(parent, _terrain3d)


func _add_terrain_cover(parent: Node3D) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 0x48494C4F414E
	var broadleaf_a_transforms: Array[Transform3D] = []
	var broadleaf_b_transforms: Array[Transform3D] = []
	var birch_transforms: Array[Transform3D] = []
	var bush_transforms: Array[Transform3D] = []
	for _index in range(1180):
		var x := random.randf_range(-12.8, -1.0)
		var z := random.randf_range(-3.4, 4.8)
		var loand_forest := exp(-(pow((x + 6.1) / 5.0, 2.0) + pow((z + 0.7) / 3.4, 2.0)))
		var west_forest := exp(-(pow((x + 10.5) / 2.8, 2.0) + pow((z - 2.8) / 2.4, 2.0)))
		var density := maxf(loand_forest * 0.90, west_forest)
		if random.randf() > density or not _is_land(x, z) or _near_world_road(x, z, 0.19):
			continue
		var height := _height_at(x, z)
		if height <= 12.0 or height > 390.0 or _terrain_normal_at(x, z).y < 0.88:
			continue
		var tree_transform := _asset_transform(x, z, height, random.randf_range(42.0, 59.0), random.randf_range(0.0, TAU), 0.12, 2.0)
		var tree_variant := random.randf()
		if tree_variant < 0.06:
			birch_transforms.append(tree_transform)
		elif tree_variant < 0.55:
			broadleaf_b_transforms.append(tree_transform)
		else:
			broadleaf_a_transforms.append(tree_transform)
		if random.randf() < 0.34:
			var bush_x := x + random.randf_range(-0.12, 0.12)
			var bush_z := z + random.randf_range(-0.12, 0.12)
			bush_transforms.append(_asset_transform(bush_x, bush_z, _height_at(bush_x, bush_z), random.randf_range(34.0, 52.0), random.randf_range(0.0, TAU), 0.45, 1.0))

	var pine_a_transforms: Array[Transform3D] = []
	var pine_b_transforms: Array[Transform3D] = []
	for _index in range(920):
		var x := random.randf_range(-1.5, 11.2)
		var z := random.randf_range(-7.0, -3.0)
		var foothill_density := exp(-(pow((x - 5.0) / 7.0, 2.0) + pow((z + 4.8) / 1.8, 2.0)))
		if random.randf() > foothill_density * 0.72 or not _is_land(x, z) or _near_world_road(x, z, 0.19):
			continue
		var height := _height_at(x, z)
		if height < 70.0 or height > 590.0 or _terrain_normal_at(x, z).y < 0.84:
			continue
		var destination := pine_a_transforms if random.randf() < 0.56 else pine_b_transforms
		destination.append(_asset_transform(x, z, height, random.randf_range(46.0, 64.0), random.randf_range(0.0, TAU), 0.14, 2.0))

	var mountain_tree_transforms: Array[Transform3D] = []
	for _index in range(900):
		var x := random.randf_range(-10.8, 11.8)
		var z := random.randf_range(-7.2, 4.4)
		var loand_tree_line := exp(-(pow((x + 5.1) / 5.2, 2.0) + pow((z + 4.0) / 1.45, 2.0)))
		var heren_tree_line := exp(-(pow((x - 5.2) / 7.3, 2.0) + pow((z + 5.1) / 1.75, 2.0)))
		var southern_tree_line := exp(-(pow(x / 8.8, 2.0) + pow((z - 3.35) / 0.82, 2.0)))
		var mountain_density := maxf(loand_tree_line, maxf(heren_tree_line, southern_tree_line * 0.58))
		if random.randf() > mountain_density * 0.72 or not _is_land(x, z) or _near_world_road(x, z, 0.18):
			continue
		var height := _height_at(x, z)
		var tree_line_factor := clampf((920.0 - height) / 520.0, 0.0, 1.0)
		if height < 170.0 or height > 920.0 or random.randf() > tree_line_factor or _terrain_normal_at(x, z).y < 0.78:
			continue
		mountain_tree_transforms.append(_asset_transform(x, z, height, random.randf_range(40.0, 57.0), random.randf_range(0.0, TAU), 0.18, 2.0))

	var desert_dead_tree_transforms: Array[Transform3D] = []
	var desert_bush_transforms: Array[Transform3D] = []
	for _index in range(92):
		var x := random.randf_range(-9.2, 6.8)
		var z := random.randf_range(4.8, 8.4)
		if random.randf() > 0.48 or not _is_land(x, z) or _near_world_road(x, z, 0.18):
			continue
		var height := _height_at(x, z)
		if height > 360.0:
			continue
		if random.randf() < 0.32:
			desert_dead_tree_transforms.append(_asset_transform(x, z, height, random.randf_range(34.0, 48.0), random.randf_range(0.0, TAU), 0.12, 1.0))
		else:
			desert_bush_transforms.append(_asset_transform(x, z, height, random.randf_range(30.0, 46.0), random.randf_range(0.0, TAU), 0.34, 1.0))

	var island_palm_a_transforms: Array[Transform3D] = []
	var island_palm_b_transforms: Array[Transform3D] = []
	var island_centers := [
		Vector3(-7.1, 11.0, 1.65), Vector3(-2.9, 12.0, 1.20),
		Vector3(1.2, 11.2, 1.80), Vector3(5.6, 12.2, 1.35),
		Vector3(9.5, 11.0, 1.45), Vector3(12.8, 12.8, 0.82),
	]
	for raw_center in island_centers:
		var center: Vector3 = raw_center
		for _index in range(28):
			var angle: float = random.randf_range(0.0, TAU)
			var radius: float = sqrt(random.randf()) * 0.76
			var x: float = center.x + cos(angle) * radius * center.z
			var z: float = center.y + sin(angle) * radius * center.z * 0.58
			if not _is_land(x, z):
				continue
			var height := _height_at(x, z)
			if height <= 10.0:
				continue
			var destination := island_palm_a_transforms if random.randf() < 0.58 else island_palm_b_transforms
			destination.append(_asset_transform(x, z, height, random.randf_range(43.0, 62.0), random.randf_range(0.0, TAU), 0.12, 2.0))

	var low_rock_transforms: Array[Transform3D] = []
	var medium_rock_transforms: Array[Transform3D] = []
	var tall_rock_transforms: Array[Transform3D] = []
	var rock_cluster_centers := [
		Vector2(-8.6, -3.9), Vector2(-6.5, -4.5), Vector2(-4.4, -4.6), Vector2(-2.4, -4.2),
		Vector2(1.8, -6.4), Vector2(4.1, -6.9), Vector2(6.5, -7.0), Vector2(8.8, -6.5), Vector2(10.8, -5.7),
		Vector2(-6.1, 3.7), Vector2(-3.2, 3.9), Vector2(0.0, 3.8), Vector2(3.2, 3.9), Vector2(6.0, 3.7),
	]
	for center_index in range(rock_cluster_centers.size()):
		var center: Vector2 = rock_cluster_centers[center_index]
		for cluster_index in range(5 + center_index % 3):
			var angle := random.randf_range(0.0, TAU)
			var radius := random.randf_range(0.10, 0.46)
			var x := center.x + cos(angle) * radius
			var z := center.y + sin(angle) * radius * 0.68
			if not _is_land(x, z) or _near_world_road(x, z, 0.15):
				continue
			var height := _height_at(x, z)
			var rock_transform := _asset_transform(x, z, height, random.randf_range(48.0, 86.0), random.randf_range(0.0, TAU), 0.82, random.randf_range(10.0, 24.0))
			match (center_index + cluster_index) % 3:
				0: low_rock_transforms.append(rock_transform)
				1: medium_rock_transforms.append(rock_transform)
				2: tall_rock_transforms.append(rock_transform)

	var outcrop_transforms: Array[Transform3D] = []
	var outcrop_points := [
		Vector2(-8.6, -3.8), Vector2(-7.0, -4.6), Vector2(-5.2, -4.7), Vector2(-3.4, -4.3),
		Vector2(2.1, -6.7), Vector2(4.0, -7.2), Vector2(5.8, -7.6), Vector2(7.5, -7.0), Vector2(9.4, -6.5),
		Vector2(-6.5, 3.8), Vector2(-4.3, 4.1), Vector2(-1.9, 3.8), Vector2(0.8, 3.9), Vector2(3.1, 4.0), Vector2(5.6, 3.8),
	]
	for point_index in range(outcrop_points.size()):
		var point: Vector2 = outcrop_points[point_index]
		var height := _height_at(point.x, point.y)
		outcrop_transforms.append(_asset_transform(point.x, point.y, height, 78.0 + float(point_index % 4) * 9.0, float(point_index) * 1.37, 0.62, 16.0))

	_add_asset_multimesh(parent, "LoandBroadleafForestA", STYLIZED_NATURE_ROOT + "normal_tree_1.glb", broadleaf_a_transforms)
	_add_asset_multimesh(parent, "LoandBroadleafForestB", STYLIZED_NATURE_ROOT + "normal_tree_2.glb", broadleaf_b_transforms)
	_add_asset_multimesh(parent, "LoandBirchGroves", STYLIZED_NATURE_ROOT + "birch_tree_2.glb", birch_transforms)
	_add_asset_multimesh(parent, "LoandForestUnderstory", STYLIZED_NATURE_ROOT + "bush.glb", bush_transforms)
	_add_asset_multimesh(parent, "HerenPineForestA", STYLIZED_NATURE_ROOT + "pine_tree_1.glb", pine_a_transforms)
	_add_asset_multimesh(parent, "HerenPineForestB", STYLIZED_NATURE_ROOT + "pine_tree_2.glb", pine_b_transforms)
	_add_asset_multimesh(parent, "MountainTreeLine", STYLIZED_NATURE_ROOT + "pine_tree_2.glb", mountain_tree_transforms)
	_add_asset_multimesh(parent, "SouthernDeadWood", STYLIZED_NATURE_ROOT + "dead_tree_1.glb", desert_dead_tree_transforms)
	_add_asset_multimesh(parent, "SouthernDryBrush", STYLIZED_NATURE_ROOT + "bush_large.glb", desert_bush_transforms)
	_add_asset_multimesh(parent, "SouthernPalmGrovesA", STYLIZED_NATURE_ROOT + "palm_tree_1.glb", island_palm_a_transforms)
	_add_asset_multimesh(parent, "SouthernPalmGrovesB", STYLIZED_NATURE_ROOT + "palm_tree_2.glb", island_palm_b_transforms)
	_add_asset_multimesh(parent, "MountainRocksLow", NATURE_MEGAKIT_ROOT + "rock_medium_1.glb", low_rock_transforms)
	_add_asset_multimesh(parent, "MountainRocksMedium", NATURE_MEGAKIT_ROOT + "rock_medium_2.glb", medium_rock_transforms)
	_add_asset_multimesh(parent, "MountainRocksTall", NATURE_MEGAKIT_ROOT + "rock_medium_3.glb", tall_rock_transforms)
	_add_asset_multimesh(parent, "MountainCliffOutcrops", STYLIZED_NATURE_ROOT + "stone_outcrop_2.glb", outcrop_transforms)


func _add_biome_detail_clusters(parent: Node3D) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 0x4D494E4941545552
	var short_grass: Array[Transform3D] = []
	var tall_grass: Array[Transform3D] = []
	var wispy_grass: Array[Transform3D] = []
	var ferns: Array[Transform3D] = []
	var clover: Array[Transform3D] = []
	var flowers_a: Array[Transform3D] = []
	var flowers_b: Array[Transform3D] = []
	var flowering_bushes: Array[Transform3D] = []
	var dry_plants: Array[Transform3D] = []
	for _index in range(1900):
		var x := random.randf_range(-12.8, 12.4)
		var z := random.randf_range(-7.2, 8.2)
		if not _is_land(x, z) or _near_world_road(x, z, 0.10):
			continue
		var height := _height_at(x, z)
		var normal := _terrain_normal_at(x, z)
		if height < 14.0 or height > 720.0 or normal.y < 0.89:
			continue
		var southern_dryness := smoothstep(3.6, 7.0, z)
		var forest_moisture := exp(-(pow((x + 6.2) / 6.2, 2.0) + pow((z + 0.2) / 4.2, 2.0)))
		var detail_scale := random.randf_range(30.0, 49.0)
		var detail_transform := _asset_transform(x, z, height, detail_scale, random.randf_range(0.0, TAU), 0.58, 1.5)
		if southern_dryness > 0.58:
			if random.randf() < 0.56:
				dry_plants.append(detail_transform)
			else:
				wispy_grass.append(detail_transform)
		elif forest_moisture > 0.30 and random.randf() < 0.34:
			ferns.append(detail_transform)
		elif random.randf() < 0.18:
			clover.append(detail_transform)
		elif random.randf() < 0.52:
			short_grass.append(detail_transform)
		else:
			tall_grass.append(detail_transform)
		if x < -1.0 and z > -2.8 and z < 3.6 and random.randf() < 0.075:
			var flower_transform := _asset_transform(x, z, height, random.randf_range(29.0, 46.0), random.randf_range(0.0, TAU), 0.48, 1.0)
			if random.randf() < 0.5:
				flowers_a.append(flower_transform)
			else:
				flowers_b.append(flower_transform)
		if x < -1.5 and forest_moisture > 0.42 and random.randf() < 0.055:
			flowering_bushes.append(_asset_transform(x, z, height, random.randf_range(34.0, 52.0), random.randf_range(0.0, TAU), 0.42, 1.0))
	_add_asset_multimesh(parent, "GrasslandShortDetail", NATURE_MEGAKIT_ROOT + "grass_common_short.glb", short_grass)
	_add_asset_multimesh(parent, "GrasslandTallDetail", NATURE_MEGAKIT_ROOT + "grass_common_tall.glb", tall_grass)
	_add_asset_multimesh(parent, "DryWispyGrassDetail", NATURE_MEGAKIT_ROOT + "grass_wispy_tall.glb", wispy_grass)
	_add_asset_multimesh(parent, "LoandFernBeds", NATURE_MEGAKIT_ROOT + "fern_1.glb", ferns)
	_add_asset_multimesh(parent, "LoandCloverBeds", NATURE_MEGAKIT_ROOT + "clover_2.glb", clover)
	_add_asset_multimesh(parent, "LoandFlowerBedsA", NATURE_MEGAKIT_ROOT + "flower_3_group.glb", flowers_a)
	_add_asset_multimesh(parent, "LoandFlowerBedsB", NATURE_MEGAKIT_ROOT + "flower_4_group.glb", flowers_b)
	_add_asset_multimesh(parent, "LoandFloweringBushes", NATURE_MEGAKIT_ROOT + "bush_common_flowers.glb", flowering_bushes)
	_add_asset_multimesh(parent, "SouthernDryPlants", NATURE_MEGAKIT_ROOT + "plant_7_big.glb", dry_plants)

	var pebbles_a: Array[Transform3D] = []
	var pebbles_b: Array[Transform3D] = []
	var pebbles_c: Array[Transform3D] = []
	for _index in range(360):
		var x := random.randf_range(-11.8, 12.5)
		var z := random.randf_range(-7.8, 5.2)
		if not _is_land(x, z) or _near_world_road(x, z, 0.13):
			continue
		var height := _height_at(x, z)
		var normal := _terrain_normal_at(x, z)
		if height < 150.0 or normal.y < 0.70:
			continue
		var pebble_transform := _asset_transform(x, z, height, random.randf_range(18.0, 42.0), random.randf_range(0.0, TAU), 0.86, random.randf_range(4.0, 12.0))
		match random.randi_range(0, 2):
			0: pebbles_a.append(pebble_transform)
			1: pebbles_b.append(pebble_transform)
			2: pebbles_c.append(pebble_transform)
	_add_asset_multimesh(parent, "MountainPebbles_00", NATURE_MEGAKIT_ROOT + "pebble_round_1.glb", pebbles_a)
	_add_asset_multimesh(parent, "MountainPebbles_01", NATURE_MEGAKIT_ROOT + "pebble_round_2.glb", pebbles_b)
	_add_asset_multimesh(parent, "MountainPebbles_02", NATURE_MEGAKIT_ROOT + "pebble_round_3.glb", pebbles_c)


func _add_geographic_detail_bands(parent: Node3D) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 0x47454F4752415048
	var cliff_a: Array[Transform3D] = []
	var cliff_b: Array[Transform3D] = []
	var cliff_c: Array[Transform3D] = []
	var foothill_rocks: Array[Transform3D] = []
	var river_reeds: Array[Transform3D] = []
	var coast_grass: Array[Transform3D] = []
	var forest_edge_trees: Array[Transform3D] = []

	var ridge_paths := [
		[Vector2(1.4, -6.8), Vector2(4.5, -7.8), Vector2(8.2, -7.2), Vector2(11.8, -5.8)],
		[Vector2(-8.8, -3.5), Vector2(-6.1, -4.8), Vector2(-3.1, -4.5), Vector2(-1.1, -3.4)],
		[Vector2(-7.8, 3.8), Vector2(-3.8, 4.2), Vector2(0.2, 3.7), Vector2(4.3, 4.1), Vector2(8.0, 3.6)],
	]
	for ridge_index in range(ridge_paths.size()):
		var sampled := _densify_map_path(ridge_paths[ridge_index], 0.42)
		for point_index in range(sampled.size()):
			if point_index % 2 != 0 and random.randf() > 0.28:
				continue
			var point: Vector2 = sampled[point_index]
			var direction: Vector2
			if point_index == 0:
				direction = sampled[1] - sampled[0]
			elif point_index == sampled.size() - 1:
				direction = sampled[-1] - sampled[-2]
			else:
				direction = sampled[point_index + 1] - sampled[point_index - 1]
			var side: Vector2 = Vector2(-direction.y, direction.x).normalized()
			for side_sign in [-1.0, 1.0]:
				if random.randf() < 0.22:
					continue
				var distance := random.randf_range(0.22, 0.68)
				var rock_point: Vector2 = point + side * distance * side_sign + Vector2(random.randf_range(-0.10, 0.10), random.randf_range(-0.10, 0.10))
				if not _is_land(rock_point.x, rock_point.y) or _near_world_road(rock_point.x, rock_point.y, 0.12):
					continue
				var height := _height_at(rock_point.x, rock_point.y)
				var normal := _terrain_normal_at(rock_point.x, rock_point.y)
				if height < 150.0 or normal.y < 0.62:
					continue
				var transform := _asset_transform(rock_point.x, rock_point.y, height, random.randf_range(58.0, 112.0), random.randf_range(0.0, TAU), 0.74, random.randf_range(8.0, 28.0))
				match (ridge_index + point_index + int(side_sign > 0.0)) % 3:
					0: cliff_a.append(transform)
					1: cliff_b.append(transform)
					2: cliff_c.append(transform)

	for _index in range(420):
		var x := random.randf_range(-11.8, 12.2)
		var z := random.randf_range(-7.7, 4.8)
		if not _is_land(x, z) or _near_world_road(x, z, 0.11):
			continue
		var height := _height_at(x, z)
		var normal := _terrain_normal_at(x, z)
		if height < 95.0 or height > 720.0 or normal.y < 0.72 or normal.y > 0.94:
			continue
		foothill_rocks.append(_asset_transform(x, z, height, random.randf_range(24.0, 54.0), random.randf_range(0.0, TAU), 0.82, random.randf_range(4.0, 12.0)))

	var waterways := [LOAND_RIVER_PATH, HEREN_RIVER_PATH, SOUTHERN_RIVER_PATH, LOAND_WEST_TRIBUTARY, LOAND_NORTH_TRIBUTARY, HEREN_EAST_TRIBUTARY]
	for waterway_index in range(waterways.size()):
		var river_points := _densify_map_path(waterways[waterway_index], 0.30)
		for point_index in range(river_points.size()):
			if point_index % 2 != 0:
				continue
			var point: Vector2 = river_points[point_index]
			var next_point: Vector2 = river_points[min(point_index + 1, river_points.size() - 1)]
			var previous_point: Vector2 = river_points[max(point_index - 1, 0)]
			var side: Vector2 = Vector2(-(next_point - previous_point).y, (next_point - previous_point).x).normalized()
			for side_sign in [-1.0, 1.0]:
				if random.randf() < 0.32:
					continue
				var reed_point: Vector2 = point + side * random.randf_range(0.14, 0.24) * side_sign
				if not _is_land(reed_point.x, reed_point.y):
					continue
				river_reeds.append(_asset_transform(reed_point.x, reed_point.y, _height_at(reed_point.x, reed_point.y), random.randf_range(25.0, 43.0), random.randf_range(0.0, TAU), 0.56, 2.0))

	for _index in range(780):
		var x := random.randf_range(-14.3, 14.3)
		var z := random.randf_range(-8.8, 9.2)
		var height := _height_at(x, z)
		if height < 10.0 or height > 78.0 or _terrain_normal_at(x, z).y < 0.86:
			continue
		var scale_factor := random.randf_range(22.0, 41.0)
		coast_grass.append(_asset_transform(x, z, height, scale_factor, random.randf_range(0.0, TAU), 0.62, 1.0))

	var forest_fronts := [
		[Vector2(-11.2, -2.2), Vector2(-9.4, -1.1), Vector2(-8.4, 0.6), Vector2(-7.0, 1.9)],
		[Vector2(-3.5, -3.0), Vector2(-2.4, -1.8), Vector2(-2.2, 0.2), Vector2(-1.8, 2.1)],
	]
	for front_index in range(forest_fronts.size()):
		var front := _densify_map_path(forest_fronts[front_index], 0.36)
		for point in front:
			if random.randf() < 0.18:
				continue
			var tree_point: Vector2 = point + Vector2(random.randf_range(-0.25, 0.25), random.randf_range(-0.20, 0.20))
			if not _is_land(tree_point.x, tree_point.y) or _near_world_road(tree_point.x, tree_point.y, 0.18):
				continue
			forest_edge_trees.append(_asset_transform(tree_point.x, tree_point.y, _height_at(tree_point.x, tree_point.y), random.randf_range(38.0, 56.0), random.randf_range(0.0, TAU), 0.16, 2.0))

	_add_asset_multimesh(parent, "MountainCliffBandA", STYLIZED_NATURE_ROOT + "stone_outcrop_1.glb", cliff_a)
	_add_asset_multimesh(parent, "MountainCliffBandB", STYLIZED_NATURE_ROOT + "stone_outcrop_2.glb", cliff_b)
	_add_asset_multimesh(parent, "MountainCliffBandC", STYLIZED_NATURE_ROOT + "stone_outcrop_3.glb", cliff_c)
	_add_asset_multimesh(parent, "FoothillRockTransition", NATURE_MEGAKIT_ROOT + "rock_medium_2.glb", foothill_rocks)
	_add_asset_multimesh(parent, "RiverbankReedBands", NATURE_MEGAKIT_ROOT + "grass_common_tall.glb", river_reeds)
	_add_asset_multimesh(parent, "CoastalGrassTransition", NATURE_MEGAKIT_ROOT + "grass_wispy_tall.glb", coast_grass)
	_add_asset_multimesh(parent, "LoandForestEdge", STYLIZED_NATURE_ROOT + "normal_tree_2.glb", forest_edge_trees)


func _add_roadside_asset_details(parent: Node3D) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 0x524F414453494445
	var pebbles_a: Array[Transform3D] = []
	var pebbles_b: Array[Transform3D] = []
	var pebbles_c: Array[Transform3D] = []
	for road_data in WORLD_ROAD_PATHS:
		var style := str(road_data[2])
		if style == "paved":
			continue
		var path := _densify_map_path(road_data[1], 0.34)
		for index in range(1, path.size() - 1, 2):
			var direction: Vector2 = (path[index + 1] - path[index - 1]).normalized()
			var side := Vector2(-direction.y, direction.x)
			for side_sign in [-1.0, 1.0]:
				if random.randf() < 0.28:
					continue
				var point: Vector2 = path[index] + side * (0.095 + random.randf_range(0.0, 0.045)) * side_sign
				if not _is_land(point.x, point.y):
					continue
				var pebble_transform := _asset_transform(point.x, point.y, _height_at(point.x, point.y), random.randf_range(14.0, 28.0), random.randf_range(0.0, TAU), 0.86, 3.0)
				match random.randi_range(0, 2):
					0: pebbles_a.append(pebble_transform)
					1: pebbles_b.append(pebble_transform)
					2: pebbles_c.append(pebble_transform)
	_add_asset_multimesh(parent, "RoadsidePebbles_00", NATURE_MEGAKIT_ROOT + "pebble_round_1.glb", pebbles_a)
	_add_asset_multimesh(parent, "RoadsidePebbles_01", NATURE_MEGAKIT_ROOT + "pebble_round_2.glb", pebbles_b)
	_add_asset_multimesh(parent, "RoadsidePebbles_02", NATURE_MEGAKIT_ROOT + "pebble_round_3.glb", pebbles_c)


func _add_lakes(parent: Node3D) -> void:
	var lakes := [
		["CentralBasinLake", Vector2(-1.7, -0.7), Vector2(1.18, 0.68), 1.4],
		["DattBorderLake", Vector2(6.8, 1.8), Vector2(0.90, 0.58), 3.2],
		["SouthernSaltLake", Vector2(-2.3, 6.5), Vector2(1.28, 0.73), 5.1],
	]
	for lake_data in lakes:
		var lake := Node3D.new()
		lake.name = str(lake_data[0])
		lake.position = Vector3(lake_data[1].x * MAP_SCALE, 0.0, lake_data[1].y * MAP_SCALE)
		var radius: Vector2 = lake_data[2]
		var phase: float = lake_data[3]
		var shore := MeshInstance3D.new()
		shore.name = "Shore"
		shore.mesh = _build_irregular_lake_mesh(radius * MAP_SCALE * 1.08, 5.0, phase)
		shore.position.y = 5.0
		shore.material_override = _material(Color("#b9a66c"), 0.88)
		_attach(lake, shore)

		var water := MeshInstance3D.new()
		water.name = "Water"
		water.mesh = _build_irregular_lake_mesh(radius * MAP_SCALE, 4.0, phase)
		water.position.y = 9.0
		var water_material := ShaderMaterial.new()
		water_material.shader = MINIATURE_WATER_SHADER
		water.material_override = water_material
		_attach(lake, water)
		_attach(parent, lake)


func _build_irregular_lake_mesh(radius: Vector2, depth: float, phase: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 40
	var top_ring: Array[Vector3] = []
	var bottom_ring: Array[Vector3] = []
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		var contour := 1.0 + sin(angle * 3.0 + phase) * 0.075 + cos(angle * 5.0 - phase * 0.7) * 0.045 + sin(angle * 7.0 + phase * 1.6) * 0.025
		var point := Vector3(cos(angle) * radius.x * contour, depth * 0.5, sin(angle) * radius.y * contour)
		top_ring.append(point)
		bottom_ring.append(Vector3(point.x * 0.98, -depth * 0.5, point.z * 0.98))
	_add_surface_ring(surface, top_ring, bottom_ring)
	_add_surface_cap(surface, top_ring, Vector3(0.0, depth * 0.5, 0.0), true)
	surface.generate_normals()
	return surface.commit()


func _add_western_floating_islands(parent: Node3D) -> void:
	var cluster := Node3D.new()
	cluster.name = "WesternFloatingIslands"
	_attach(parent, cluster)
	var definitions := [
		Vector4(-15.4, -4.8, 820.0, 1750.0),
		Vector4(-17.4, -2.7, 650.0, 2360.0),
		Vector4(-15.8, -0.4, 760.0, 2050.0),
		Vector4(-17.7, 1.7, 590.0, 1620.0),
		Vector4(-15.7, 3.6, 700.0, 2200.0),
		Vector4(-18.3, 4.8, 500.0, 1890.0),
	]
	var shape_names := ["LongRidge", "TriangularCliff", "Teardrop", "TwinLobe", "BroadMesa", "VerticalShard"]
	for index in range(definitions.size()):
		var definition: Vector4 = definitions[index]
		var island := Node3D.new()
		island.name = "FloatingIsland_%02d_%s" % [index, shape_names[index]]
		island.position = Vector3(definition.x * MAP_SCALE, definition.w, definition.y * MAP_SCALE)
		island.set_meta("base_y", definition.w)
		island.set_meta("island_shape", shape_names[index])
		_attach(cluster, island)
		_floating_islands.append(island)

		var radius := definition.z
		var rock_height := radius * (1.42 if index % 2 == 0 else 1.68)
		var rock := MeshInstance3D.new()
		rock.name = "FacetedRock_%s" % shape_names[index]
		rock.mesh = _build_floating_rock_mesh(radius, rock_height, index)
		rock.material_override = _material(Color("#6d6258"), 0.92)
		_attach(island, rock)

		var crown := MeshInstance3D.new()
		crown.name = "GrassCrown_%s" % shape_names[index]
		crown.mesh = _build_floating_crown_mesh(radius, index)
		crown.material_override = _material(Color("#70ad66"), 0.86)
		_attach(island, crown)

		var lift_core := MeshInstance3D.new()
		lift_core.name = "MagicLiftCore"
		var lift_mesh := CylinderMesh.new()
		lift_mesh.top_radius = radius * 0.12
		lift_mesh.bottom_radius = radius * 0.03
		lift_mesh.height = rock_height * 0.62
		lift_mesh.radial_segments = 7
		lift_core.mesh = lift_mesh
		lift_core.position.y = -rock_height * 0.77
		lift_core.material_override = _material(Color("#67d9cf"), 0.12, true)
		_attach(island, lift_core)

		var ring := MeshInstance3D.new()
		ring.name = "LevitationRing"
		var ring_mesh := TorusMesh.new()
		ring_mesh.inner_radius = radius * 0.34
		ring_mesh.outer_radius = radius * 0.39
		ring_mesh.rings = 18
		ring_mesh.ring_segments = 8
		ring.mesh = ring_mesh
		ring.position.y = -rock_height * 0.56
		ring.material_override = _material(Color("#8bded4"), 0.10, true)
		_attach(island, ring)

		var tree_transforms: Array[Transform3D] = []
		var tree_count := 3 if radius > 380.0 else 2
		for tree_index in range(tree_count):
			var angle := TAU * float(tree_index) / float(tree_count) + float(index) * 0.71
			var distance := radius * (0.26 + 0.11 * float(tree_index % 2))
			var tree_scale := 84.0 + float((index + tree_index) % 3) * 12.0
			var basis := Basis(Vector3.UP, angle + 0.4).scaled(Vector3.ONE * tree_scale)
			tree_transforms.append(Transform3D(basis, Vector3(cos(angle) * distance, 48.0, sin(angle) * distance)))
		var island_tree_asset := "normal_tree_1.glb" if index % 2 == 0 else "normal_tree_2.glb"
		_add_asset_multimesh(island, "IslandTrees", STYLIZED_NATURE_ROOT + island_tree_asset, tree_transforms)


func _build_floating_rock_mesh(radius: float, depth: float, shape_index: int) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 11 + shape_index % 3
	var top: Array[Vector3] = []
	var shoulder: Array[Vector3] = []
	var lower: Array[Vector3] = []
	var tip: Array[Vector3] = []
	var tip_offset := Vector2(sin(float(shape_index) * 1.9) * radius * 0.18, cos(float(shape_index) * 1.37) * radius * 0.13)
	for segment_index in range(segments):
		var angle := TAU * float(segment_index) / float(segments)
		var outline := _floating_island_outline(radius, angle, shape_index)
		top.append(Vector3(outline.x, 0.0, outline.y))
		shoulder.append(Vector3(outline.x * 0.84 + tip_offset.x * 0.12, -depth * 0.24, outline.y * 0.84 + tip_offset.y * 0.12))
		lower.append(Vector3(outline.x * 0.38 + tip_offset.x * 0.58, -depth * 0.68, outline.y * 0.38 + tip_offset.y * 0.58))
		tip.append(Vector3(outline.x * 0.055 + tip_offset.x, -depth, outline.y * 0.055 + tip_offset.y))
	_add_surface_ring(surface, top, shoulder)
	_add_surface_ring(surface, shoulder, lower)
	_add_surface_ring(surface, lower, tip)
	_add_surface_cap(surface, top, Vector3.ZERO, true)
	surface.generate_normals()
	return surface.commit()


func _build_floating_crown_mesh(radius: float, shape_index: int) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 11 + shape_index % 3
	var top: Array[Vector3] = []
	var bottom: Array[Vector3] = []
	for segment_index in range(segments):
		var angle := TAU * float(segment_index) / float(segments)
		var outline := _floating_island_outline(radius, angle, shape_index)
		top.append(Vector3(outline.x * 1.04, 54.0, outline.y * 1.04))
		bottom.append(Vector3(outline.x * 0.97, 0.0, outline.y * 0.97))
	_add_surface_ring(surface, top, bottom)
	_add_surface_cap(surface, top, Vector3(0.0, 54.0, 0.0), true)
	surface.generate_normals()
	return surface.commit()


func _floating_island_outline(radius: float, angle: float, shape_index: int) -> Vector2:
	var axis_scale := Vector2.ONE
	var contour := 1.0
	match shape_index:
		0:
			axis_scale = Vector2(1.42, 0.70)
			contour += sin(angle * 3.0 + 0.4) * 0.08
		1:
			axis_scale = Vector2(1.04, 0.92)
			contour += cos(angle * 3.0 - 0.3) * 0.22
		2:
			axis_scale = Vector2(1.18, 0.86)
			contour += cos(angle) * 0.27 + sin(angle * 4.0) * 0.06
		3:
			axis_scale = Vector2(1.12, 0.84)
			contour += cos(angle * 2.0 + 0.35) * 0.24
		4:
			axis_scale = Vector2(1.28, 0.94)
			contour += cos(angle * 4.0 - 0.5) * 0.10
		5:
			axis_scale = Vector2(0.76, 1.46)
			contour += sin(angle * 3.0 + 0.8) * 0.16
	contour += sin(angle * float(5 + shape_index % 2) + float(shape_index) * 1.13) * 0.045
	return Vector2(cos(angle) * radius * axis_scale.x * contour, sin(angle) * radius * axis_scale.y * contour)


func _add_surface_ring(surface: SurfaceTool, upper: Array[Vector3], lower: Array[Vector3]) -> void:
	for index in range(upper.size()):
		var next := (index + 1) % upper.size()
		_add_surface_triangle(surface, upper[index], upper[next], lower[index])
		_add_surface_triangle(surface, upper[next], lower[next], lower[index])


func _add_surface_cap(surface: SurfaceTool, ring: Array[Vector3], center: Vector3, face_up: bool) -> void:
	for index in range(ring.size()):
		var next := (index + 1) % ring.size()
		if face_up:
			_add_surface_triangle(surface, center, ring[index], ring[next])
		else:
			_add_surface_triangle(surface, center, ring[next], ring[index])


func _add_surface_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)


func _asset_transform(x: float, z: float, height: float, scale_factor: float, angle: float, surface_alignment: float = 0.0, sink: float = 0.0) -> Transform3D:
	var surface_up := Vector3.UP.lerp(_terrain_normal_at(x, z), clampf(surface_alignment, 0.0, 1.0)).normalized()
	var forward := Vector3.BACK.rotated(Vector3.UP, angle)
	forward = (forward - surface_up * forward.dot(surface_up)).normalized()
	if forward.length_squared() < 0.001:
		forward = Vector3.RIGHT
	var right := surface_up.cross(forward).normalized()
	forward = right.cross(surface_up).normalized()
	var basis := Basis(right, surface_up, forward).scaled(Vector3.ONE * scale_factor)
	return Transform3D(basis, Vector3(x * MAP_SCALE, height - sink, z * MAP_SCALE))


func _add_asset_multimesh(parent: Node3D, node_name: String, scene_path: String, transforms: Array[Transform3D]) -> void:
	if transforms.is_empty():
		return
	var packed_scene := load(scene_path) as PackedScene
	if packed_scene == null:
		push_warning("Unable to load map asset: " + scene_path)
		return
	var source_root := packed_scene.instantiate()
	var source_meshes := source_root.find_children("*", "MeshInstance3D", true, false)
	if source_meshes.is_empty():
		source_root.free()
		push_warning("Map asset has no mesh: " + scene_path)
		return
	var group := Node3D.new()
	group.name = node_name
	_attach(parent, group)
	for mesh_index in range(source_meshes.size()):
		var source_mesh := source_meshes[mesh_index] as MeshInstance3D
		if source_mesh == null or source_mesh.mesh == null:
			continue
		var source_transform := _node_transform_relative_to(source_mesh, source_root)
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = _retint_asset_mesh(source_mesh.mesh, scene_path)
		multimesh.instance_count = transforms.size()
		for index in range(transforms.size()):
			multimesh.set_instance_transform(index, transforms[index] * source_transform)
		var instance := MultiMeshInstance3D.new()
		instance.name = "Part_%02d_%s" % [mesh_index, source_mesh.name]
		instance.multimesh = multimesh
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_attach(group, instance)
	source_root.free()


func _add_map_asset(parent: Node3D, node_name: String, scene_path: String, center: Vector2, target_size: float, yaw: float = 0.0, lift: float = 0.0, absolute_y: float = NAN) -> Node3D:
	var packed_scene := load(scene_path) as PackedScene
	if packed_scene == null:
		push_warning("Unable to load map asset: " + scene_path)
		return null
	var source_root := packed_scene.instantiate() as Node3D
	if source_root == null:
		push_warning("Map asset is not a Node3D: " + scene_path)
		return null
	var bounds := _scene_bounds(source_root)
	var largest_dimension := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	if largest_dimension <= 0.001:
		source_root.free()
		push_warning("Map asset has invalid bounds: " + scene_path)
		return null
	var wrapper := Node3D.new()
	wrapper.name = node_name
	wrapper.rotation.y = yaw
	var base_y := _height_at(center.x, center.y) + lift if is_nan(absolute_y) else absolute_y + lift
	wrapper.position = Vector3(center.x * MAP_SCALE, base_y, center.y * MAP_SCALE)
	var scale_factor := target_size / largest_dimension
	source_root.scale = Vector3.ONE * scale_factor
	var bounds_center := bounds.position + bounds.size * 0.5
	source_root.position = Vector3(-bounds_center.x, -bounds.position.y, -bounds_center.z) * scale_factor
	_tune_scene_asset(source_root)
	_attach(wrapper, source_root)
	_attach(parent, wrapper)
	return wrapper


func _add_local_map_asset(parent: Node3D, node_name: String, scene_path: String, local_position: Vector3, target_size: float, yaw: float = 0.0) -> Node3D:
	var packed_scene := load(scene_path) as PackedScene
	if packed_scene == null:
		push_warning("Unable to load local map asset: " + scene_path)
		return null
	var source_root := packed_scene.instantiate() as Node3D
	if source_root == null:
		return null
	var bounds := _scene_bounds(source_root)
	var largest_dimension := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	if largest_dimension <= 0.001:
		source_root.free()
		return null
	var wrapper := Node3D.new()
	wrapper.name = node_name
	wrapper.position = local_position
	wrapper.rotation.y = yaw
	var scale_factor := target_size / largest_dimension
	source_root.scale = Vector3.ONE * scale_factor
	var bounds_center := bounds.position + bounds.size * 0.5
	source_root.position = Vector3(-bounds_center.x, -bounds.position.y, -bounds_center.z) * scale_factor
	_tune_scene_asset(source_root)
	_attach(wrapper, source_root)
	_attach(parent, wrapper)
	return wrapper


func _scene_bounds(root_node: Node3D) -> AABB:
	var bounds := AABB()
	var has_point := false
	for raw_mesh in root_node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := raw_mesh as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var aabb := mesh_instance.get_aabb()
		var relative_transform := _node_transform_relative_to(mesh_instance, root_node)
		for corner_index in range(8):
			var corner := aabb.position + Vector3(
				aabb.size.x if corner_index & 1 else 0.0,
				aabb.size.y if corner_index & 2 else 0.0,
				aabb.size.z if corner_index & 4 else 0.0
			)
			var point := relative_transform * corner
			if has_point:
				bounds = bounds.expand(point)
			else:
				bounds = AABB(point, Vector3.ZERO)
				has_point = true
	return bounds


func _tune_scene_asset(root_node: Node3D) -> void:
	for raw_mesh in root_node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := raw_mesh as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var mesh := mesh_instance.mesh.duplicate(true) as Mesh
		for surface_index in range(mesh.get_surface_count()):
			var source_material := mesh.surface_get_material(surface_index)
			if not source_material is StandardMaterial3D:
				continue
			var material := source_material.duplicate(true) as StandardMaterial3D
			material.roughness = maxf(material.roughness, 0.82)
			material.metallic = 0.0
			material.normal_enabled = material.normal_texture != null
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			mesh.surface_set_material(surface_index, material)
		mesh_instance.mesh = mesh


func _node_transform_relative_to(node: Node3D, ancestor: Node) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != ancestor:
		if current is Node3D:
			result = (current as Node3D).transform * result
		current = current.get_parent()
	return result


func _retint_asset_mesh(source_mesh: Mesh, scene_path: String) -> Mesh:
	var mesh := source_mesh.duplicate(true) as Mesh
	var is_pine := scene_path.contains("pine")
	var is_birch := scene_path.contains("birch")
	var is_dead_tree := scene_path.contains("dead_tree")
	var is_dry_bush := scene_path.contains("bush_large")
	var is_rock := scene_path.contains("rock") or scene_path.contains("outcrop") or scene_path.contains("pebble")
	for surface_index in range(mesh.get_surface_count()):
		var source_material := mesh.surface_get_material(surface_index)
		if not source_material is StandardMaterial3D:
			continue
		var material := source_material.duplicate(true) as StandardMaterial3D
		var material_name := material.resource_name.to_lower()
		var has_authored_texture := material.albedo_texture != null
		if has_authored_texture and is_rock:
			material.albedo_color *= Color("#9ba198")
		if not has_authored_texture:
			if is_rock:
				material.albedo_color = Color("#78817b") if surface_index == 0 else Color("#8e9687")
			elif is_birch and material_name.contains("bark"):
				material.albedo_color = Color("#c9c3ae")
			elif material_name.contains("wood") or material_name.contains("bark"):
				material.albedo_color = Color("#806342")
			elif is_dead_tree:
				material.albedo_color = Color("#756348")
			elif is_dry_bush:
				material.albedo_color = Color("#8f8b55")
			elif is_pine:
				material.albedo_color = Color("#51775b")
			else:
				material.albedo_color = Color("#64845b")
		material.normal_enabled = material.normal_texture != null
		material.roughness = maxf(material.roughness, 0.82)
		material.emission_enabled = false
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		mesh.surface_set_material(surface_index, material)
	return mesh


func _add_mountains(parent: Node3D) -> void:
	# Northern highlands and the southern escarpment explain the continent's political limits.
	_add_mountain_chain(parent, "HerenHighlands", [Vector2(3.0, -6.8), Vector2(6.0, -7.2), Vector2(9.0, -6.9), Vector2(11.8, -6.1)], 1.10, true)
	_add_mountain_chain(parent, "EasternSpine", [Vector2(11.7, -3.6), Vector2(12.1, -1.3), Vector2(12.4, 0.8)], 0.78, false)
	_add_mountain_chain(parent, "LoandCrown", [Vector2(-7.3, -4.2), Vector2(-4.8, -4.8), Vector2(-2.4, -4.4)], 0.72, false)
	_add_mountain_chain(parent, "SouthernEscarpment", [Vector2(-5.5, 3.6), Vector2(-2.4, 3.9), Vector2(0.8, 3.7), Vector2(4.0, 3.9), Vector2(7.0, 3.6)], 0.66, false)


func _add_mountain_chain(parent: Node3D, node_name: String, anchors: Array[Vector2], scale_factor: float, snowy: bool) -> void:
	var chain := Node3D.new()
	chain.name = node_name
	_attach(parent, chain)
	var mountain_index := 0
	for anchor in anchors:
		for raw_offset in [-0.55, 0.25]:
			var offset: float = raw_offset
			var x: float = anchor.x + offset
			var z := anchor.y + sin(float(mountain_index) * 1.9) * 0.32
			var height := (1.65 + float(mountain_index % 3) * 0.34) * scale_factor
			var peak := MeshInstance3D.new()
			peak.name = "Peak_%02d" % mountain_index
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.03
			mesh.bottom_radius = 0.72 * scale_factor
			mesh.height = height
			mesh.radial_segments = 6
			peak.mesh = mesh
			peak.position = Vector3(x, _height_at(x, z) + height * 0.5 - 0.04, z)
			peak.material_override = _material(Color("#66705d") if not snowy else Color("#707b74"), 0.96)
			_attach(chain, peak)
			if snowy:
				var cap := MeshInstance3D.new()
				cap.name = "Snow_%02d" % mountain_index
				var cap_mesh := CylinderMesh.new()
				cap_mesh.top_radius = 0.01
				cap_mesh.bottom_radius = 0.29 * scale_factor
				cap_mesh.height = height * 0.30
				cap_mesh.radial_segments = 6
				cap.mesh = cap_mesh
				cap.position = peak.position + Vector3(0.0, height * 0.36, 0.0)
				cap.material_override = _material(Color("#dce8df"), 0.9)
				_attach(chain, cap)
			mountain_index += 1


func _add_rivers_and_canals(parent: Node3D) -> void:
	var waterways := Node3D.new()
	waterways.name = "DetailedWaterways"
	_attach(parent, waterways)
	_add_river_feature(waterways, "LoandMainRiver", LOAND_RIVER_PATH, 0.20)
	_add_river_feature(waterways, "HerenMainRiver", HEREN_RIVER_PATH, 0.18)
	_add_river_feature(waterways, "SouthernMainRiver", SOUTHERN_RIVER_PATH, 0.18)
	_add_river_feature(waterways, "LoandWestTributary", LOAND_WEST_TRIBUTARY, 0.105)
	_add_river_feature(waterways, "LoandNorthTributary", LOAND_NORTH_TRIBUTARY, 0.095)
	_add_river_feature(waterways, "HerenEastTributary", HEREN_EAST_TRIBUTARY, 0.095)

	var hub := Vector2(3.9, -1.4)
	var north_south_canal := [Vector2(3.9, -5.2), Vector2(3.9, -3.2), hub, Vector2(3.9, 1.1)]
	var west_east_canal := [Vector2(-3.8, -1.4), Vector2(0.2, -1.4), hub, Vector2(7.4, -1.1), Vector2(10.5, 0.2)]
	_add_surface_strip(waterways, "DattCanalNorthSouthBank", north_south_canal, 0.26, Color("#536c65"), 0.075)
	_add_surface_strip(waterways, "DattCanalNorthSouth", north_south_canal, 0.17, Color("#43a8b8"), 0.105)
	_add_surface_strip(waterways, "DattCanalWestEastBank", west_east_canal, 0.26, Color("#536c65"), 0.075)
	_add_surface_strip(waterways, "DattCanalWestEast", west_east_canal, 0.17, Color("#43a8b8"), 0.105)
	var canal_hub := MeshInstance3D.new()
	canal_hub.name = "CanalExchangeBasin"
	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = 520.0
	hub_mesh.bottom_radius = 520.0
	hub_mesh.height = 34.0
	hub_mesh.radial_segments = 24
	canal_hub.mesh = hub_mesh
	canal_hub.position = _surface_point(hub.x, hub.y, 0.13)
	canal_hub.material_override = _material(Color("#45a8b3"), 0.22, true)
	_attach(waterways, canal_hub)


func _add_river_feature(parent: Node3D, node_name: String, path: Array, width: float) -> void:
	var group := Node3D.new()
	group.name = node_name
	_attach(parent, group)
	_add_surface_strip(group, "EarthBank", path, width * 1.62, Color("#61735a"), 0.060)
	_add_surface_strip(group, "Water", path, width, Color("#4aa9bd"), 0.095)
	for bend_index in range(1, path.size() - 1):
		var bend: Vector2 = path[bend_index]
		var stone := MeshInstance3D.new()
		stone.name = "BankStone_%02d" % bend_index
		var stone_mesh := SphereMesh.new()
		stone_mesh.radius = width * MAP_SCALE * 0.32
		stone_mesh.height = width * MAP_SCALE * 0.42
		stone_mesh.radial_segments = 6
		stone_mesh.rings = 3
		stone.mesh = stone_mesh
		stone.position = _surface_point(bend.x + width * 0.95, bend.y, 0.12)
		stone.material_override = _material(Color("#78817b"), 0.88)
		_attach(group, stone)


func _add_world_roads(parent: Node3D) -> void:
	var roads := Node3D.new()
	roads.name = "OverlandRoadNetwork"
	_attach(parent, roads)
	for road_data in WORLD_ROAD_PATHS:
		_add_road_feature(roads, str(road_data[0]), road_data[1], str(road_data[2]))
	_add_road_bridge(roads, "LoandRiverBridge", Vector2(-5.15, -2.02), deg_to_rad(92.0), 390.0)
	_add_road_bridge(roads, "HerenEstuaryBridge", Vector2(10.22, 0.18), deg_to_rad(48.0), 430.0)
	_add_map_asset(roads, "DattFourWayTransitJunction", MODULAR_STREETS_ROOT + "street_4way.glb", Vector2(4.82, -1.02), 285.0, deg_to_rad(12.0), 20.0)
	_add_map_asset(roads, "DattCanalThreeWayJunction", MODULAR_STREETS_ROOT + "street_3way.glb", Vector2(6.92, -0.78), 255.0, deg_to_rad(78.0), 20.0)


func _add_road_feature(parent: Node3D, node_name: String, path: Array, style: String) -> void:
	var road := Node3D.new()
	road.name = node_name
	_attach(parent, road)
	var terrain_path := _densify_map_path(path, 0.20)
	_add_surface_strip(road, "Shoulder", terrain_path, 0.104, Color("#625a48"), 0.082, _road_material(style, true))
	_add_surface_strip(road, "TravelSurface", terrain_path, 0.070, Color("#aa9263"), 0.104, _road_material(style, false))


func _road_material(style: String, shoulder: bool) -> StandardMaterial3D:
	var texture_name := "gravel_road"
	if style in ["trail", "frontier"]:
		texture_name = "stony_dirt_path"
	elif style in ["royal", "paved"] and not shoulder:
		texture_name = "pavement_05"
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(ROAD_TEXTURE_ROOT + texture_name + "_diff_1k.jpg") as Texture2D
	material.normal_enabled = true
	material.normal_texture = load(ROAD_TEXTURE_ROOT + texture_name + "_nor_gl_1k.jpg") as Texture2D
	material.normal_scale = 0.86 if shoulder else 1.12
	material.roughness = 1.0
	material.roughness_texture = load(ROAD_TEXTURE_ROOT + texture_name + "_rough_1k.jpg") as Texture2D
	material.albedo_color = Color("#827b6d") if shoulder else Color(1.22, 1.16, 1.06, 1.0)
	if style == "paved" and not shoulder:
		material.albedo_color = Color(1.10, 1.20, 1.18, 1.0)
	elif style == "royal" and not shoulder:
		material.albedo_color = Color(1.26, 1.19, 1.05, 1.0)
	elif style == "frontier" and not shoulder:
		material.albedo_color = Color(1.28, 1.10, 0.92, 1.0)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	return material


func _add_road_bridge(parent: Node3D, node_name: String, center: Vector2, yaw: float, target_size: float) -> void:
	_add_map_asset(parent, node_name, MODULAR_STREETS_ROOT + "street_bridge_water.glb", center, target_size, yaw, 24.0)


func _add_transport_network(parent: Node3D) -> void:
	var rail_points := [Vector2(-7.4, 0.6), Vector2(-2.2, -0.2), Vector2(3.9, -1.0), Vector2(7.2, -0.7), Vector2(10.5, 0.6)]
	_add_surface_strip(parent, "MaglevBed", rail_points, 0.13, Color("#435654"), 0.105)
	_add_surface_strip(parent, "MaglevGuide", rail_points, 0.035, Color("#d5b85b"), 0.125)
	var train := Node3D.new()
	train.name = "MovingMaglev"
	_add_box_child(train, "Body", Vector3(620.0, 150.0, 210.0), Vector3(0.0, 80.0, 0.0), Color("#dce9e2"))
	_add_box_child(train, "WindowBand", Vector3(430.0, 72.0, 216.0), Vector3(15.0, 105.0, 0.0), Color("#56c9d0"), true)
	_attach(parent, train)
	_animated_vehicles.append({"node": train, "from": _surface_point(-6.8, 0.5, 0.72), "to": _surface_point(10.1, 0.5, 0.72), "speed": 0.045, "phase": 0.1})

	for index in range(2):
		var shuttle := Node3D.new()
		shuttle.name = "AirShuttle_%02d" % index
		_add_box_child(shuttle, "Cabin", Vector3(390.0, 125.0, 190.0), Vector3.ZERO, Color("#8bd8d2"), true)
		_add_box_child(shuttle, "Wing", Vector3(650.0, 35.0, 110.0), Vector3(0.0, -15.0, 0.0), Color("#e8ca62"), true)
		_attach(parent, shuttle)
		_animated_vehicles.append({
			"node": shuttle,
			"from": Vector3(2.8 * MAP_SCALE, 980.0 + index * 180.0, -2.0 * MAP_SCALE),
			"to": Vector3(11.5 * MAP_SCALE, 820.0 + index * 180.0, 1.3 * MAP_SCALE),
			"speed": 0.035 + index * 0.008,
			"phase": index * 0.48,
		})


func _add_regional_architecture(parent: Node3D) -> void:
	var architecture := Node3D.new()
	architecture.name = "RegionalArchitecture"
	_attach(parent, architecture)
	_add_kaykit_loand_settlements(architecture)
	_add_kaykit_datt_city(architecture)
	_add_kaykit_heren_industry(architecture)


func _add_kaykit_loand_settlements(parent: Node3D) -> void:
	var definitions := [
		["LoandRoyalCastle", "building_castle_blue.gltf", Vector2(-4.85, -1.62), 420.0, 0.10],
		["RoyalChurch", "building_church_blue.gltf", Vector2(-4.22, -1.10), 270.0, 0.52],
		["RoyalMarket", "building_market_blue.gltf", Vector2(-5.45, -1.02), 235.0, -0.28],
		["RiverWatermill", "building_watermill_blue.gltf", Vector2(-5.72, 0.78), 220.0, 0.18],
		["WestTownTavern", "building_tavern_blue.gltf", Vector2(-8.20, 0.88), 220.0, -0.58],
		["WestTownHomeA", "building_home_A_blue.gltf", Vector2(-8.58, 1.22), 178.0, -0.12],
		["WestTownHomeB", "building_home_B_blue.gltf", Vector2(-7.84, 1.30), 182.0, 0.38],
		["WestTownLumbermill", "building_lumbermill_blue.gltf", Vector2(-8.70, 0.48), 215.0, 0.74],
		["EastVillageBlacksmith", "building_blacksmith_blue.gltf", Vector2(-2.58, 1.05), 205.0, 0.78],
		["EastVillageHomeA", "building_home_A_blue.gltf", Vector2(-2.84, 1.58), 172.0, 0.18],
		["EastVillageHomeB", "building_home_B_blue.gltf", Vector2(-2.08, 1.52), 176.0, -0.44],
		["EastVillageWindmill", "building_windmill_blue.gltf", Vector2(-1.78, 0.88), 235.0, -0.22],
		["NorthernPassTower", "building_tower_A_blue.gltf", Vector2(-6.62, -2.72), 230.0, 0.10],
	]
	for definition in definitions:
		_add_map_asset(parent, definition[0], KAYKIT_MEDIEVAL_ROOT + definition[1], definition[2], definition[3], definition[4], 2.0)


func _add_kaykit_datt_city(parent: Node3D) -> void:
	var urban_definitions := [
		["DattWestApartments", "building_A.gltf", Vector2(2.25, -1.12), 300.0, 0.20],
		["DattNorthExchange", "building_H.gltf", Vector2(3.05, -2.18), 410.0, -0.08],
		["DattNorthOffice", "building_E.gltf", Vector2(4.72, -2.08), 355.0, 0.14],
		["DattSouthOffice", "building_G.gltf", Vector2(3.10, -0.56), 365.0, -0.18],
		["DattSouthApartments", "building_F.gltf", Vector2(4.72, -0.48), 330.0, 0.22],
		["DattEastCommerce", "building_D.gltf", Vector2(5.55, -1.22), 315.0, -0.32],
		["DattPortDistrict", "building_B.gltf", Vector2(7.45, -0.48), 300.0, 0.28],
	]
	for definition in urban_definitions:
		_add_map_asset(parent, definition[0], KAYKIT_CITY_ROOT + definition[1], definition[2], definition[3], definition[4], 2.0)

	var future_definitions := [
		["DattExchangeSpire", "structure_tall.gltf", Vector2(4.46, -1.70), 470.0, 0.12],
		["DattResearchModule", "basemodule_C.gltf", Vector2(2.72, -2.62), 290.0, -0.34],
		["DattTransitModule", "basemodule_A.gltf", Vector2(5.42, -2.45), 305.0, 0.42],
		["DattAerialTerminal", "landingpad_large.gltf", Vector2(6.16, -0.04), 330.0, -0.10],
		["DattAirTaxi", "lander_A.gltf", Vector2(6.22, -0.08), 175.0, 0.42],
		["DattSolarArray", "solarpanel.gltf", Vector2(6.76, -0.32), 190.0, -0.18],
	]
	for definition in future_definitions:
		_add_map_asset(parent, definition[0], KAYKIT_SPACE_ROOT + definition[1], definition[2], definition[3], definition[4], 3.0)


func _add_kaykit_heren_industry(parent: Node3D) -> void:
	var definitions := [
		["HerenNorthernMine", "drill_structure.gltf", Vector2(9.35, -4.72), 410.0, 0.18],
		["HerenOreDepot", "cargodepot_A.gltf", Vector2(10.18, -4.18), 350.0, -0.12],
		["HerenWindPlant", "windturbine_tall.gltf", Vector2(9.76, -3.70), 310.0, 0.16],
		["HerenSteelWorks", "structure_tall.gltf", Vector2(10.72, -3.38), 390.0, 0.32],
		["HerenCargoStacks", "containers_A.gltf", Vector2(10.18, -2.98), 215.0, -0.28],
		["HerenCoastalDepot", "cargodepot_B.gltf", Vector2(11.08, -2.58), 350.0, -0.24],
		["HerenMachineGarage", "basemodule_garage.gltf", Vector2(11.26, -1.86), 315.0, 0.20],
		["HerenSolarWorks", "roofmodule_solarpanels.gltf", Vector2(10.72, -1.52), 220.0, -0.16],
		["HerenPortWarehouse", "cargodepot_C.gltf", Vector2(11.40, -1.10), 330.0, 0.26],
		["HerenHauler", "spacetruck_large.gltf", Vector2(10.70, -2.12), 190.0, -0.48],
	]
	for definition in definitions:
		_add_map_asset(parent, definition[0], KAYKIT_SPACE_ROOT + definition[1], definition[2], definition[3], definition[4], 2.0)


func _add_collected_loand_assets(parent: Node3D) -> void:
	var definitions := [
		["RoyalBellTower", "bell_tower.glb", Vector2(-4.15, -1.05), 360.0, 0.18],
		["RiverTownInn", "inn.glb", Vector2(-8.15, 0.84), 330.0, -0.72],
		["RiverTownMill", "mill.glb", Vector2(-7.65, 1.28), 350.0, 0.62],
		["RiverTownHouseA", "house_1.glb", Vector2(-8.58, 1.22), 270.0, -0.18],
		["RiverTownHouseB", "house_3.glb", Vector2(-8.00, 1.52), 255.0, 0.44],
		["EastVillageBlacksmith", "blacksmith.glb", Vector2(-2.62, 1.08), 300.0, 0.82],
		["EastVillageStable", "stable.glb", Vector2(-2.08, 1.48), 310.0, -0.35],
		["EastVillageHouseA", "house_2.glb", Vector2(-2.72, 1.62), 255.0, 0.24],
		["EastVillageHouseB", "house_4.glb", Vector2(-1.82, 1.08), 245.0, -0.58],
		["LoandForestSawmill", "sawmill.glb", Vector2(-9.05, 0.30), 330.0, 0.55],
	]
	for definition in definitions:
		_add_map_asset(parent, definition[0], MEDIEVAL_VILLAGE_ROOT + definition[1], definition[2], definition[3], definition[4], 8.0)


func _add_loand_hamlet_ring(parent: Node3D) -> void:
	var hamlets := [
		["NorthPassHamlet", Vector2(-6.7, -2.75), ["house_2.glb", "house_4.glb", "stable.glb"]],
		["WesternWoodHamlet", Vector2(-10.1, 2.15), ["house_1.glb", "house_3.glb", "sawmill.glb"]],
		["SouthernMarketHamlet", Vector2(-5.8, 2.55), ["house_2.glb", "inn.glb", "house_4.glb"]],
		["CanalApproachHamlet", Vector2(-1.45, 0.45), ["house_1.glb", "blacksmith.glb", "house_3.glb"]],
	]
	var offsets := [Vector2(-0.24, -0.12), Vector2(0.20, -0.16), Vector2(0.04, 0.24)]
	for hamlet_index in range(hamlets.size()):
		var hamlet: Array = hamlets[hamlet_index]
		var center: Vector2 = hamlet[1]
		var asset_names: Array = hamlet[2]
		for asset_index in range(asset_names.size()):
			var point: Vector2 = center + offsets[asset_index]
			_add_map_asset(parent, "%s_%02d" % [hamlet[0], asset_index], MEDIEVAL_VILLAGE_ROOT + str(asset_names[asset_index]), point, 205.0 + float((hamlet_index + asset_index) % 3) * 24.0, float(hamlet_index) * 0.63 + float(asset_index) * 1.17, 6.0)


func _add_datt_urban_satellites(parent: Node3D) -> void:
	var definitions := [
		["DattWestResidentialA", "building-c.glb", Vector2(1.55, -0.82), 330.0, 0.24],
		["DattWestResidentialB", "building-f.glb", Vector2(2.05, -1.55), 360.0, -0.35],
		["DattCanalOfficeA", "building-skyscraper-b.glb", Vector2(3.10, -2.05), 470.0, 0.10],
		["DattCanalOfficeB", "building-j.glb", Vector2(4.58, -2.02), 420.0, -0.18],
		["DattEastOfficeA", "building-skyscraper-d.glb", Vector2(5.35, -1.43), 485.0, 0.26],
		["DattEastOfficeB", "building-h.glb", Vector2(5.85, -0.72), 390.0, -0.42],
		["DattSouthExchangeA", "building-l.glb", Vector2(3.15, -0.42), 385.0, 0.52],
		["DattSouthExchangeB", "building-n.glb", Vector2(4.18, 0.08), 345.0, -0.20],
		["DattPortApproachA", "building-skyscraper-a.glb", Vector2(7.35, -0.56), 440.0, 0.35],
		["DattPortApproachB", "building-e.glb", Vector2(8.05, -0.10), 350.0, -0.30],
	]
	for definition in definitions:
		_add_map_asset(parent, definition[0], COMMERCIAL_CITY_ROOT + definition[1], definition[2], definition[3], definition[4], 10.0)


func _add_heren_industrial_corridor(parent: Node3D) -> void:
	var definitions := [
		["HerenSteelWorks", "building-q.glb", Vector2(9.45, -4.65), 520.0, 0.24],
		["HerenOreRefinery", "building-r.glb", Vector2(10.25, -4.08), 490.0, -0.18],
		["HerenMachineWorks", "building-b.glb", Vector2(10.75, -3.38), 470.0, 0.42],
		["HerenCoastalSmelter", "building-t.glb", Vector2(11.15, -2.68), 500.0, -0.30],
		["HerenWarmCurrentWorks", "building-l.glb", Vector2(11.25, -1.88), 440.0, 0.12],
		["HerenPortWarehouse", "building-g.glb", Vector2(11.42, -1.12), 425.0, -0.22],
		["HerenIndustrialTankA", "detail-tank.glb", Vector2(9.90, -3.48), 220.0, 0.0],
		["HerenIndustrialTankB", "detail-tank.glb", Vector2(10.78, -2.22), 210.0, 0.0],
		["HerenIndustrialStackA", "chimney-large.glb", Vector2(9.78, -4.32), 340.0, 0.0],
		["HerenIndustrialStackB", "chimney-medium.glb", Vector2(10.94, -3.02), 300.0, 0.0],
		["HerenIndustrialStackC", "chimney-large.glb", Vector2(11.36, -1.55), 330.0, 0.0],
	]
	for definition in definitions:
		_add_map_asset(parent, definition[0], INDUSTRIAL_CITY_ROOT + definition[1], definition[2], definition[3], definition[4], 8.0)


func _add_datt_future_district(parent: Node3D, center: Vector2, scale_factor: float, node_name: String) -> void:
	var district := Node3D.new()
	district.name = node_name
	district.position = _structure_anchor(center, 720.0 * scale_factor, 0.02)
	_attach(parent, district)
	_add_cylinder_child(district, "TerracedBase", Vector3.ZERO, 720.0 * scale_factor, 64.0 * scale_factor, Color("#526b68"))

	var transit_ring := MeshInstance3D.new()
	transit_ring.name = "AerialTransitRing"
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 530.0 * scale_factor
	ring_mesh.outer_radius = 585.0 * scale_factor
	ring_mesh.rings = 28
	ring_mesh.ring_segments = 8
	transit_ring.mesh = ring_mesh
	transit_ring.position.y = 150.0 * scale_factor
	transit_ring.material_override = _material(Color("#64d5d0"), 0.18, true)
	_attach(district, transit_ring)

	var tower_count := 7 if scale_factor > 0.8 else 5
	for index in range(tower_count):
		var angle := TAU * float(index) / float(tower_count) + 0.18
		var height := (620.0 + float(index % 3) * 210.0) * scale_factor
		var position_ := Vector3(cos(angle) * 405.0 * scale_factor, 62.0 * scale_factor, sin(angle) * 335.0 * scale_factor)
		_add_cartoon_tower(district, "Arcology_%02d" % index, position_, height, 92.0 * scale_factor, Color("#9eb7b1"), Color("#55c9ce"))
	_add_cartoon_tower(district, "ExchangeSpire", Vector3(0.0, 62.0 * scale_factor, 0.0), 1280.0 * scale_factor, 128.0 * scale_factor, Color("#b6cbc4"), Color("#efce62"))
	_add_box_child(district, "MaglevTerminal", Vector3(760.0, 180.0, 300.0) * scale_factor, Vector3(780.0, 150.0, 0.0) * scale_factor, Color("#779b98"))
	_add_box_child(district, "TerminalLight", Vector3(520.0, 46.0, 310.0) * scale_factor, Vector3(780.0, 242.0, 0.0) * scale_factor, Color("#64d8d2"), true)


func _add_cartoon_tower(parent: Node3D, node_name: String, position_: Vector3, height: float, radius: float, body_color: Color, accent_color: Color) -> void:
	var tower := Node3D.new()
	tower.name = node_name
	tower.position = position_
	_attach(parent, tower)
	_add_cylinder_child(tower, "Body", Vector3.ZERO, radius, height, body_color)
	_add_cylinder_child(tower, "WindowCrown", Vector3(0.0, height * 0.70, 0.0), radius * 1.10, height * 0.13, accent_color, true)
	_add_cone_child(tower, "TaperedRoof", Vector3(0.0, height, 0.0), radius * 0.92, height * 0.24, accent_color, true, 8)


func _add_loand_castle_complex(parent: Node3D, center: Vector2) -> void:
	var castle := Node3D.new()
	castle.name = "LoandRoyalCastle"
	castle.position = _structure_anchor(center, 620.0 * 0.58, 0.01)
	castle.scale = Vector3.ONE * 0.58
	_attach(parent, castle)
	_add_cylinder_child(castle, "CastleHill", Vector3.ZERO, 620.0, 72.0, Color("#66815b"))
	_add_box_child(castle, "CentralKeep", Vector3(560.0, 440.0, 500.0), Vector3(0.0, 292.0, 0.0), Color("#a9997d"))
	_add_box_child(castle, "KeepGate", Vector3(150.0, 235.0, 42.0), Vector3(0.0, 188.0, 271.0), Color("#675849"))
	var tower_positions := [Vector3(-360.0, 72.0, -310.0), Vector3(360.0, 72.0, -310.0), Vector3(-360.0, 72.0, 310.0), Vector3(360.0, 72.0, 310.0)]
	for index in range(tower_positions.size()):
		var tower := Node3D.new()
		tower.name = "CastleTower_%02d" % index
		tower.position = tower_positions[index]
		_attach(castle, tower)
		_add_cylinder_child(tower, "StoneBody", Vector3.ZERO, 108.0, 590.0 + float(index % 2) * 80.0, Color("#ad9d7e"))
		_add_cone_child(tower, "BlueRoof", Vector3(0.0, 590.0 + float(index % 2) * 80.0, 0.0), 152.0, 245.0, Color("#4f7182"), false, 8)
	_add_cartoon_tower(castle, "RoyalMagicTower", Vector3(0.0, 72.0, -70.0), 910.0, 95.0, Color("#b5a587"), Color("#80c8c0"))


func _add_loand_village(parent: Node3D, center: Vector2, scale_factor: float, node_name: String) -> void:
	var village := Node3D.new()
	village.name = node_name
	village.position = _surface_point(center.x, center.y, 0.06)
	_attach(parent, village)
	for index in range(6):
		var angle := TAU * float(index) / 6.0 + 0.35
		var distance := (260.0 + float(index % 2) * 95.0) * scale_factor
		var local_x := cos(angle) * distance
		var local_z := sin(angle) * distance * 0.72
		var house_x := center.x + local_x / MAP_SCALE
		var house_z := center.y + local_z / MAP_SCALE
		var house := Node3D.new()
		house.name = "House_%02d" % index
		house.position = Vector3(local_x, _height_at(house_x, house_z) - village.position.y, local_z)
		house.rotation.y = -angle
		_attach(village, house)
		_add_box_child(house, "StoneHouse", Vector3(215.0, 165.0, 190.0) * scale_factor, Vector3(0.0, 86.0 * scale_factor, 0.0), Color("#c3ad85"))
		_add_cone_child(house, "TileRoof", Vector3(0.0, 168.0 * scale_factor, 0.0), 170.0 * scale_factor, 130.0 * scale_factor, Color("#8c5f4d"), false, 4)
	_add_cartoon_tower(village, "VillageMageTower", Vector3.ZERO, 450.0 * scale_factor, 68.0 * scale_factor, Color("#baa984"), Color("#77bdb3"))


func _add_river_mouth_ports(parent: Node3D) -> void:
	var ports := Node3D.new()
	ports.name = "RiverMouthPorts"
	_attach(parent, ports)
	_add_estuary_port(ports, "SouthernEstuaryPort", Vector2(0.8, 8.8), 0.0, 0.62, Color("#527a77"), Color("#e4c45c"))
	_add_estuary_port(ports, "EasternWarmCurrentPort", Vector2(12.6, 0.5), PI * 0.5, 0.68, Color("#486e72"), Color("#65d2cf"))


func _add_estuary_port(parent: Node3D, node_name: String, center: Vector2, yaw: float, scale_factor: float, body_color: Color, accent_color: Color) -> void:
	var port := Node3D.new()
	port.name = node_name
	var coastal_height := maxf(_height_at(center.x, center.y), 20.0)
	port.position = Vector3(center.x * MAP_SCALE, coastal_height + 24.0, center.y * MAP_SCALE)
	port.rotation.y = yaw
	port.scale = Vector3.ONE * scale_factor
	_attach(parent, port)

	var basin := MeshInstance3D.new()
	basin.name = "RiverSeaBasin"
	var basin_mesh := CylinderMesh.new()
	basin_mesh.top_radius = 390.0
	basin_mesh.bottom_radius = 390.0
	basin_mesh.height = 28.0
	basin_mesh.radial_segments = 24
	basin.mesh = basin_mesh
	basin.position = Vector3(0.0, 8.0, 170.0)
	basin.material_override = _material(Color("#3c9fb0"), 0.34)
	_attach(port, basin)

	_add_local_map_asset(port, "IntermodalTerminal", KAYKIT_SPACE_ROOT + "cargodepot_B.gltf", Vector3(0.0, 34.0, -330.0), 430.0, 0.08)
	_add_local_map_asset(port, "CommoditiesExchange", KAYKIT_CITY_ROOT + "building_E.gltf", Vector3(-480.0, 32.0, -300.0), 320.0, -0.16)
	_add_local_map_asset(port, "AirTransitPad", KAYKIT_SPACE_ROOT + "landingpad_large.gltf", Vector3(620.0, 28.0, -260.0), 330.0, 0.14)
	_add_local_map_asset(port, "HarborAirTaxi", KAYKIT_SPACE_ROOT + "lander_B.gltf", Vector3(620.0, 72.0, -260.0), 175.0, -0.20)
	_add_local_map_asset(port, "CargoStacks", KAYKIT_SPACE_ROOT + "containers_B.gltf", Vector3(-180.0, 30.0, -60.0), 210.0, 0.22)
	_add_local_map_asset(port, "PortHauler", KAYKIT_SPACE_ROOT + "spacetruck.gltf", Vector3(170.0, 30.0, -80.0), 155.0, -0.34)
	for pier_index in range(3):
		var pier_x := (float(pier_index) - 1.0) * 250.0
		_add_box_child(port, "Pier_%02d" % pier_index, Vector3(74.0, 34.0, 650.0), Vector3(pier_x, 42.0, 275.0), Color("#596b66"))
		_add_port_crane(port, "Crane_%02d" % pier_index, Vector3(pier_x + 72.0, 58.0, 28.0), body_color, accent_color)


func _add_port_crane(parent: Node3D, node_name: String, position_: Vector3, body_color: Color, accent_color: Color) -> void:
	var crane := Node3D.new()
	crane.name = node_name
	crane.position = position_
	_attach(parent, crane)
	_add_box_child(crane, "Mast", Vector3(48.0, 310.0, 48.0), Vector3(0.0, 155.0, 0.0), body_color)
	_add_box_child(crane, "Boom", Vector3(250.0, 38.0, 46.0), Vector3(86.0, 292.0, 0.0), accent_color)
	_add_box_child(crane, "Cable", Vector3(22.0, 165.0, 22.0), Vector3(190.0, 204.0, 0.0), Color("#3f5553"))


func _add_southern_future_fleet(parent: Node3D) -> void:
	var fleet := Node3D.new()
	fleet.name = "SouthernFutureFleet"
	_attach(parent, fleet)
	_add_future_ship(fleet, "StraitHydrofoil", Vector3(-10.2 * MAP_SCALE, 70.0, 9.15 * MAP_SCALE), Vector3(10.8 * MAP_SCALE, 70.0, 9.15 * MAP_SCALE), 0.92, 0, 0.04)
	_add_future_ship(fleet, "ArchipelagoExpress", Vector3(-9.0 * MAP_SCALE, 68.0, 13.15 * MAP_SCALE), Vector3(11.8 * MAP_SCALE, 68.0, 13.15 * MAP_SCALE), 0.78, 1, 0.46)
	_add_future_ship(fleet, "EasternCargoSkimmer", Vector3(15.5 * MAP_SCALE, 76.0, 9.8 * MAP_SCALE), Vector3(15.5 * MAP_SCALE, 76.0, 15.8 * MAP_SCALE), 1.16, 2, 0.29)
	_add_collected_ship_assets(fleet)


func _add_collected_ship_assets(parent: Node3D) -> void:
	var southern_liner := _add_map_asset(parent, "PsetiaPassengerLiner", SHIPS_ROOT + "cruiseship.glb", Vector2(-1.0, 9.55), 920.0, deg_to_rad(82.0), 0.0, 56.0)
	if southern_liner != null:
		_animated_vehicles.append({"node": southern_liner, "from": Vector3(-1.0 * MAP_SCALE, 56.0, 9.55 * MAP_SCALE), "to": Vector3(5.4 * MAP_SCALE, 56.0, 9.95 * MAP_SCALE), "speed": 0.012, "phase": 0.18})
	var eastern_liner := _add_map_asset(parent, "EasternOceanLiner", SHIPS_ROOT + "cruiseship.glb", Vector2(13.6, 1.15), 760.0, deg_to_rad(-8.0), 0.0, 56.0)
	if eastern_liner != null:
		_animated_vehicles.append({"node": eastern_liner, "from": Vector3(13.6 * MAP_SCALE, 56.0, 1.15 * MAP_SCALE), "to": Vector3(14.6 * MAP_SCALE, 56.0, 6.2 * MAP_SCALE), "speed": 0.010, "phase": 0.54})
	_add_map_asset(parent, "PsetiaHarborRescueBoat", SHIPS_ROOT + "lifeboat.glb", Vector2(1.8, 9.05), 330.0, deg_to_rad(70.0), 0.0, 58.0)


func _add_future_ship(parent: Node3D, node_name: String, from_point: Vector3, to_point: Vector3, scale_factor: float, ship_type: int, phase: float) -> void:
	var ship := Node3D.new()
	ship.name = node_name
	ship.position = from_point
	ship.scale = Vector3.ONE * scale_factor
	_attach(parent, ship)
	var hull_color := Color("#789a9b") if ship_type != 2 else Color("#607f83")
	for side in [-1.0, 1.0]:
		var hull := MeshInstance3D.new()
		hull.name = "StreamlinedHull_%s" % ("Port" if side < 0.0 else "Starboard")
		var hull_mesh := CapsuleMesh.new()
		hull_mesh.radius = 92.0
		hull_mesh.height = 690.0 if ship_type != 2 else 860.0
		hull_mesh.radial_segments = 8
		hull_mesh.rings = 4
		hull.mesh = hull_mesh
		hull.rotation_degrees.x = 90.0
		hull.position = Vector3(side * 165.0, 0.0, 0.0)
		hull.material_override = _material(hull_color, 0.34)
		_attach(ship, hull)
	_add_box_child(ship, "BridgeDeck", Vector3(420.0, 96.0, 430.0), Vector3(0.0, 92.0, -20.0), Color("#345f68"))
	_add_box_child(ship, "GlassCanopy", Vector3(285.0, 92.0, 235.0), Vector3(0.0, 176.0, -70.0), Color("#62c9d1"), true)
	_add_box_child(ship, "EnergyWing", Vector3(610.0, 28.0, 145.0), Vector3(0.0, 38.0, 80.0), Color("#e9c95e"), true)
	for side in [-1.0, 1.0]:
		_add_cylinder_child(ship, "Thruster_%s" % ("Port" if side < 0.0 else "Starboard"), Vector3(side * 165.0, -32.0, 330.0), 48.0, 92.0, Color("#69ded8"), true)
	_animated_vehicles.append({"node": ship, "from": from_point, "to": to_point, "speed": 0.025 + float(ship_type) * 0.006, "phase": phase})


func _add_landmarks(parent: Node3D) -> void:
	_add_floating_island_cluster(parent)
	_add_nether_source(parent, Vector2(8.4, -8.7))
	_add_future_city(parent, Vector2(3.9, -1.4))
	_add_factory_coast(parent)
	_add_modern_port(parent, Vector2(10.7, 0.9))
	_add_castle(parent, Vector2(-4.8, -1.5))
	_add_outpost(parent, Vector2(-1.6, 5.3))
	_add_world_label(parent, "洛安德联合王国", Vector3(-4.8, 2.1, -0.4), Color("#f0dfae"))
	_add_world_label(parent, "达特未来城", Vector3(3.9, 2.6, -2.1), Color("#f2d46f"))
	_add_world_label(parent, "赫伦寒原", Vector3(8.0, 3.1, -6.2), Color("#d9ece5"))
	_add_world_label(parent, "普赛提亚海洋联邦", Vector3(10.2, 1.9, 2.4), Color("#bceadf"))
	_add_world_label(parent, "南部边境拓殖带", Vector3(0.0, 1.7, 6.3), Color("#f0c47b"))


func _add_floating_island_cluster(parent: Node3D) -> void:
	var centers := [Vector3(-11.3, 5.4, -6.2), Vector3(-9.3, 6.1, -6.8), Vector3(-12.7, 4.8, -4.6), Vector3(-9.8, 5.0, -4.4)]
	for i in range(centers.size()):
		var center: Vector3 = centers[i]
		var island := Node3D.new()
		island.name = "FloatingIsland_%02d" % i
		island.position = center
		island.set_meta("base_y", center.y)
		var rock := MeshInstance3D.new()
		var rock_mesh := CylinderMesh.new()
		rock_mesh.top_radius = 0.78 if i > 0 else 1.15
		rock_mesh.bottom_radius = 0.12
		rock_mesh.height = 1.45 if i > 0 else 2.0
		rock_mesh.radial_segments = 7
		rock.mesh = rock_mesh
		rock.position.y = -0.75
		rock.material_override = _material(Color("#5b4939"), 0.96)
		_attach(island, rock)
		_add_cylinder_child(island, "GreenTop", Vector3.ZERO, 0.88 if i > 0 else 1.30, 0.22, Color("#6b9c67"))
		_add_cylinder_child(island, "MagicLift", Vector3(0.0, -1.55, 0.0), 0.13, 0.95, Color(0.40, 0.93, 0.92, 0.70), true)
		_attach(parent, island)
		_floating_islands.append(island)


func _add_nether_source(parent: Node3D, center: Vector2) -> void:
	var root := Node3D.new()
	root.name = "NetherRiverSource"
	root.position = _surface_point(center.x, center.y)
	_add_cylinder_child(root, "FrozenSeal", Vector3.ZERO, 0.62, 0.16, Color("#b9e1dc"), true)
	for i in range(3):
		_add_cylinder_child(root, "IceShard_%02d" % i, Vector3((i - 1) * 0.35, 0.1, sin(i) * 0.22), 0.09, 0.9 + i * 0.18, Color("#d9f0e9"), true)
	_attach(parent, root)


func _add_future_city(parent: Node3D, center: Vector2) -> void:
	var city := Node3D.new()
	city.name = "DattFutureCity"
	city.position = _surface_point(center.x, center.y)
	_add_cylinder_child(city, "TransitRing", Vector3.ZERO, 1.35, 0.18, Color("#375c61"))
	for i in range(7):
		var angle := TAU * float(i) / 7.0
		var height := 1.15 + float(i % 3) * 0.34
		_add_tower_child(city, "Arcology_%02d" % i, Vector3(cos(angle) * 0.90, 0.12, sin(angle) * 0.70), height, 0.16, Color("#d2ddd4"), Color("#58d4d0"))
	_add_cylinder_child(city, "ExchangeCore", Vector3(0.0, 0.14, 0.0), 0.34, 1.9, Color("#58cbd0"), true)
	_attach(parent, city)


func _add_factory_coast(parent: Node3D) -> void:
	var coast := Node3D.new()
	coast.name = "HerenIndustrialCoast"
	_attach(parent, coast)
	var centers := [Vector2(10.0, -4.7), Vector2(11.0, -3.7), Vector2(11.6, -2.6)]
	for i in range(centers.size()):
		var center: Vector2 = centers[i]
		var factory := Node3D.new()
		factory.name = "Factory_%02d" % i
		factory.position = _surface_point(center.x, center.y)
		_add_box_child(factory, "Hall", Vector3(0.85, 0.36, 0.62), Vector3.ZERO, Color("#6b6252"))
		_add_cylinder_child(factory, "StackA", Vector3(-0.22, 0.12, 0.0), 0.07, 0.95, Color("#3c4642"))
		_add_cylinder_child(factory, "StackB", Vector3(0.22, 0.12, 0.0), 0.07, 0.72, Color("#3c4642"))
		_attach(coast, factory)


func _add_modern_port(parent: Node3D, center: Vector2) -> void:
	var port := Node3D.new()
	port.name = "PsetiaGlobalPort"
	port.position = _surface_point(center.x, center.y)
	_add_box_child(port, "Terminal", Vector3(1.5, 0.28, 0.85), Vector3.ZERO, Color("#456b68"))
	for i in range(3):
		_add_box_child(port, "Pier_%02d" % i, Vector3(0.12, 0.12, 0.9), Vector3((i - 1) * 0.45, 0.0, 0.78), Color("#d2b85f"))
	_add_tower_child(port, "AirPortTower", Vector3(-0.48, 0.08, -0.15), 0.86, 0.13, Color("#d8e5dc"), Color("#efca5e"))
	_add_box_child(port, "CommoditiesExchange", Vector3(0.55, 0.48, 0.42), Vector3(0.42, 0.24, -0.05), Color("#7a674d"))
	_add_box_child(port, "FastLiner", Vector3(0.90, 0.15, 0.28), Vector3(1.35, 0.05, 0.78), Color("#6fc2ca"), true)
	_attach(parent, port)


func _add_castle(parent: Node3D, center: Vector2) -> void:
	var castle := Node3D.new()
	castle.name = "LoandClassicalCastle"
	castle.position = _surface_point(center.x, center.y)
	_add_box_child(castle, "Keep", Vector3(0.85, 0.72, 0.66), Vector3(0.0, 0.36, 0.0), Color("#a69270"))
	for i in range(4):
		_add_tower_child(castle, "Tower_%02d" % i, Vector3(-0.42 if i % 2 == 0 else 0.42, 0.05, -0.32 if i < 2 else 0.32), 0.82, 0.13, Color("#bda97f"), Color("#dfc361"))
	_attach(parent, castle)


func _add_outpost(parent: Node3D, center: Vector2) -> void:
	var outpost := Node3D.new()
	outpost.name = "SouthernFrontierOutpost"
	outpost.position = _surface_point(center.x, center.y)
	_add_box_child(outpost, "Fort", Vector3(0.82, 0.42, 0.66), Vector3.ZERO, Color("#8d663e"))
	_add_cylinder_child(outpost, "Beacon", Vector3(-0.25, 0.05, 0.0), 0.06, 0.95, Color("#5c4027"))
	_attach(parent, outpost)


func _build_campaign_layer() -> void:
	var old_layer := get_node_or_null("CampaignLayer")
	if old_layer != null:
		remove_child(old_layer)
		old_layer.queue_free()
	_marker_by_id.clear()
	_hovered_level_id = ""
	var layer := Node3D.new()
	layer.name = "CampaignLayer"
	_attach(self, layer)
	if _profiles.is_empty():
		return

	for route_index in range(_profiles.size() - 1):
		_add_travel_direction_route(layer, _profiles[route_index], _profiles[route_index + 1], route_index)
	for profile_index in range(_profiles.size()):
		_add_level_marker(layer, _profiles[profile_index], profile_index)


func _add_travel_direction_route(parent: Node3D, from_profile: Dictionary, to_profile: Dictionary, route_index: int) -> void:
	if not bool(from_profile.get("completed", false)):
		return
	var start := _level_position(from_profile)
	var finish := _level_position(to_profile)
	var mode := _travel_mode_between(from_profile, to_profile)
	var flat_delta := Vector2(finish.x - start.x, finish.z - start.z)
	if flat_delta.length_squared() < 1.0:
		return
	var route_path := _travel_route_path(start, finish, mode)
	var route_length := _world_path_length(route_path)
	if route_length < 1.0:
		return
	var arrow_count := clampi(int(route_length / 620.0), 4, 18)
	var completed := bool(to_profile.get("completed", false))
	var color := _travel_mode_color(mode, completed)
	var route := Node3D.new()
	route.name = "Direction_%02d_%s" % [route_index, mode.capitalize()]
	_attach(parent, route)
	var midpoint := Vector3.ZERO
	var midpoint_direction := Vector3.FORWARD
	for arrow_index in range(arrow_count):
		var progress := (float(arrow_index) + 0.65) / float(arrow_count)
		var distance := route_length * progress
		var point := _sample_world_path(route_path, distance)
		var before := _sample_world_path(route_path, maxf(0.0, distance - 32.0))
		var after := _sample_world_path(route_path, minf(route_length, distance + 32.0))
		point.y = _travel_route_height(point, mode, start, finish, progress)
		before.y = point.y
		after.y = point.y
		var arrow := MeshInstance3D.new()
		arrow.name = "Arrow_%02d" % arrow_index
		arrow.mesh = _build_direction_arrow_mesh(260.0, 180.0)
		arrow.position = point
		var direction := after - point if after.distance_squared_to(point) > 0.01 else point - before
		arrow.rotation.y = atan2(-direction.x, -direction.z)
		var arrow_material := _material(color, 0.76, not completed)
		arrow_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		arrow.material_override = arrow_material
		arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_attach(route, arrow)
		if arrow_index == floori(float(arrow_count) * 0.5):
			midpoint = point
			midpoint_direction = direction
	if not completed and mode == "boat":
		_add_route_boat_icon(route, midpoint, midpoint_direction)


func _travel_route_path(start: Vector3, finish: Vector3, mode: String) -> Array[Vector3]:
	if mode == "walk":
		return _road_route_path(start, finish)
	var flat_delta := Vector2(finish.x - start.x, finish.z - start.z)
	var normal := Vector2(-flat_delta.y, flat_delta.x).normalized()
	var bend := minf(flat_delta.length() * 0.13, 1.2 * MAP_SCALE)
	if mode == "boat":
		bend = maxf(bend, 4.5 * MAP_SCALE)
		if normal.x < 0.0:
			normal = -normal
	var control := (start + finish) * 0.5 + Vector3(normal.x * bend, 0.0, normal.y * bend)
	var result: Array[Vector3] = []
	for step in range(25):
		result.append(_quadratic_point(start, control, finish, float(step) / 24.0))
	return result


func _road_route_path(start: Vector3, finish: Vector3) -> Array[Vector3]:
	var graph := _build_road_graph()
	if graph.is_empty():
		return [start, finish]
	var start_key := _nearest_road_node_key(Vector2(start.x / MAP_SCALE, start.z / MAP_SCALE), graph)
	var finish_key := _nearest_road_node_key(Vector2(finish.x / MAP_SCALE, finish.z / MAP_SCALE), graph)
	var open_nodes: Array[String] = [start_key]
	var costs := {start_key: 0.0}
	var previous: Dictionary = {}
	while not open_nodes.is_empty():
		var current := _lowest_cost_road_node(open_nodes, costs)
		open_nodes.erase(current)
		if current == finish_key:
			break
		var current_node: Dictionary = graph[current]
		var neighbors: Dictionary = current_node["neighbors"]
		for raw_neighbor in neighbors:
			var neighbor := str(raw_neighbor)
			var next_cost := float(costs[current]) + float(neighbors[neighbor])
			if not costs.has(neighbor) or next_cost < float(costs[neighbor]):
				costs[neighbor] = next_cost
				previous[neighbor] = current
				if not open_nodes.has(neighbor):
					open_nodes.append(neighbor)
	if start_key != finish_key and not previous.has(finish_key):
		return [start, finish]
	var node_keys: Array[String] = [finish_key]
	while node_keys[0] != start_key:
		node_keys.push_front(str(previous[node_keys[0]]))
	var result: Array[Vector3] = [start]
	for node_key in node_keys:
		var point: Vector2 = graph[node_key]["point"]
		result.append(Vector3(point.x * MAP_SCALE, 0.0, point.y * MAP_SCALE))
	result.append(finish)
	return result


func _build_road_graph() -> Dictionary:
	var graph: Dictionary = {}
	for road_data in WORLD_ROAD_PATHS:
		var path: Array = road_data[1]
		for index in range(path.size() - 1):
			_add_road_graph_edge(graph, path[index], path[index + 1])
	return graph


func _add_road_graph_edge(graph: Dictionary, from_point: Vector2, to_point: Vector2) -> void:
	var from_key := _road_point_key(from_point)
	var to_key := _road_point_key(to_point)
	if not graph.has(from_key):
		graph[from_key] = {"point": from_point, "neighbors": {}}
	if not graph.has(to_key):
		graph[to_key] = {"point": to_point, "neighbors": {}}
	var distance := from_point.distance_to(to_point)
	var from_node: Dictionary = graph[from_key]
	var from_neighbors: Dictionary = from_node["neighbors"]
	from_neighbors[to_key] = distance
	from_node["neighbors"] = from_neighbors
	graph[from_key] = from_node
	var to_node: Dictionary = graph[to_key]
	var to_neighbors: Dictionary = to_node["neighbors"]
	to_neighbors[from_key] = distance
	to_node["neighbors"] = to_neighbors
	graph[to_key] = to_node


func _nearest_road_node_key(point: Vector2, graph: Dictionary) -> String:
	var nearest_key := ""
	var nearest_distance := INF
	for raw_key in graph:
		var key := str(raw_key)
		var road_point: Vector2 = graph[key]["point"]
		var distance := point.distance_squared_to(road_point)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_key = key
	return nearest_key


func _lowest_cost_road_node(open_nodes: Array[String], costs: Dictionary) -> String:
	var best := open_nodes[0]
	for key in open_nodes:
		if float(costs.get(key, INF)) < float(costs.get(best, INF)):
			best = key
	return best


func _road_point_key(point: Vector2) -> String:
	return "%.3f,%.3f" % [point.x, point.y]


func _world_path_length(path: Array[Vector3]) -> float:
	var length := 0.0
	for index in range(path.size() - 1):
		length += path[index].distance_to(path[index + 1])
	return length


func _sample_world_path(path: Array[Vector3], distance: float) -> Vector3:
	var remaining := maxf(distance, 0.0)
	for index in range(path.size() - 1):
		var segment_length := path[index].distance_to(path[index + 1])
		if remaining <= segment_length:
			return path[index].lerp(path[index + 1], remaining / maxf(segment_length, 0.001))
		remaining -= segment_length
	return path[path.size() - 1]


func _travel_mode_between(from_profile: Dictionary, to_profile: Dictionary) -> String:
	var from_set := str(from_profile.get("map_set", ""))
	var to_set := str(to_profile.get("map_set", ""))
	if from_set == "MiZhiDi" or to_set == "MiZhiDi":
		return "airship"
	if from_set == "NuFeng" and to_set == "NuFeng":
		return "boat"
	return str(to_profile.get("travel_mode", "walk"))


func _travel_mode_color(mode: String, completed: bool) -> Color:
	var color := Color("#e5be55")
	if mode == "boat":
		color = Color("#54c9d3")
	elif mode == "airship":
		color = Color("#9ad5ca")
	return color.darkened(0.32) if completed else color


func _quadratic_point(start: Vector3, control: Vector3, finish: Vector3, t: float) -> Vector3:
	var one_minus_t := 1.0 - t
	return start * one_minus_t * one_minus_t + control * 2.0 * one_minus_t * t + finish * t * t


func _travel_route_height(point: Vector3, mode: String, start: Vector3, finish: Vector3, t: float) -> float:
	if mode == "airship":
		return maxf(start.y, finish.y) + 260.0 + sin(t * PI) * 220.0
	var map_x := point.x / MAP_SCALE
	var map_z := point.z / MAP_SCALE
	if mode == "boat" and not _is_land(map_x, map_z):
		return 58.0
	return _height_at(map_x, map_z) + 58.0


func _build_direction_arrow_mesh(length: float, width: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outline := PackedVector2Array([
		Vector2(-width * 0.5, length * 0.46),
		Vector2(0.0, -length * 0.54),
		Vector2(width * 0.5, length * 0.46),
		Vector2(width * 0.18, length * 0.18),
		Vector2(0.0, -length * 0.14),
		Vector2(-width * 0.18, length * 0.18),
	])
	var indices := Geometry2D.triangulate_polygon(outline)
	for triangle_index in range(0, indices.size(), 3):
		var a := outline[indices[triangle_index]]
		var b := outline[indices[triangle_index + 1]]
		var c := outline[indices[triangle_index + 2]]
		_add_up_facing_triangle(surface, Vector3(a.x, 0.0, a.y), Vector3(b.x, 0.0, b.y), Vector3(c.x, 0.0, c.y))
	return surface.commit()


func _add_route_boat_icon(parent: Node3D, position_: Vector3, direction: Vector3) -> void:
	var boat := Node3D.new()
	boat.name = "TravelBoat"
	boat.position = position_ + Vector3(0.0, 42.0, 0.0)
	boat.rotation.y = atan2(-direction.x, -direction.z)
	_attach(parent, boat)
	var hull := MeshInstance3D.new()
	var hull_mesh := CapsuleMesh.new()
	hull_mesh.radius = 48.0
	hull_mesh.height = 260.0
	hull_mesh.radial_segments = 8
	hull_mesh.rings = 3
	hull.mesh = hull_mesh
	hull.rotation_degrees.x = 90.0
	hull.material_override = _material(Color("#547d7f"), 0.78)
	_attach(boat, hull)
	_add_box_child(boat, "Cabin", Vector3(96.0, 54.0, 104.0), Vector3(0.0, 48.0, 18.0), Color("#d9e0cd"))
	_add_box_child(boat, "Canopy", Vector3(70.0, 34.0, 62.0), Vector3(0.0, 84.0, 10.0), Color("#58b9c2"), true)


func _add_level_marker(parent: Node3D, profile: Dictionary, marker_index: int) -> void:
	var level_id := str(profile.get("id", ""))
	if level_id.is_empty():
		return
	var completed := bool(profile.get("completed", false))
	var marker := Area3D.new()
	marker.name = "Level_%s" % level_id
	marker.position = _level_position(profile)
	marker.set_meta("level_profile", profile.duplicate(true))
	marker.set_meta("base_y", marker.position.y)
	marker.set_meta("phase", float(marker_index) * 0.72)
	marker.collision_layer = 1
	marker.collision_mask = 0

	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.52 * MARKER_SCALE
	collision.shape = shape
	collision.position.y = 0.35 * MARKER_SCALE
	_attach(marker, collision)

	var visual := Node3D.new()
	visual.name = "Visual"
	visual.scale = Vector3.ONE * MARKER_SCALE
	_attach(marker, visual)
	var base_color := Color("#55c9bd") if completed else Color("#e7bd4d")
	_add_cylinder_child(visual, "Pedestal", Vector3.ZERO, 0.34, 0.18, base_color.darkened(0.34))
	var core := MeshInstance3D.new()
	core.name = "Core"
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.27
	core_mesh.height = 0.54
	core.mesh = core_mesh
	core.position.y = 0.43
	core.material_override = _material(base_color, 0.16, true)
	_attach(visual, core)
	var halo := MeshInstance3D.new()
	halo.name = "Halo"
	var halo_mesh := TorusMesh.new()
	halo_mesh.inner_radius = 0.35
	halo_mesh.outer_radius = 0.41
	halo_mesh.rings = 12
	halo_mesh.ring_segments = 8
	halo.mesh = halo_mesh
	halo.position.y = 0.42
	halo.material_override = _material(base_color.lightened(0.18), 0.15, true)
	_attach(visual, halo)

	var label := Label3D.new()
	label.name = "LevelName"
	label.text = "%s  %s" % [str(profile.get("local_number", marker_index + 1)), str(profile.get("name", level_id))]
	label.position = Vector3(0.0, 0.96 * MARKER_SCALE, 0.0)
	label.font_size = 18
	label.outline_size = 5
	label.pixel_size = 20.0
	label.modulate = Color("#fff3cf")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.fixed_size = false
	label.no_depth_test = true
	label.visible = not completed
	_attach(marker, label)

	_attach(parent, marker)
	_marker_by_id[level_id] = marker


func _pick_level(screen_position: Vector2, activate: bool) -> void:
	var profile := _profile_at_screen_position(screen_position)
	if profile.is_empty():
		return
	var level_id := str(profile.get("id", ""))
	_selected_level_id = level_id
	_refresh_marker_emphasis()
	level_focused.emit(profile.duplicate(true))
	if activate:
		level_activated.emit(level_id)


func _update_hover(screen_position: Vector2) -> void:
	var profile := _profile_at_screen_position(screen_position)
	var level_id := str(profile.get("id", ""))
	if level_id == _hovered_level_id:
		return
	_hovered_level_id = level_id
	_refresh_marker_emphasis()


func _profile_at_screen_position(screen_position: Vector2) -> Dictionary:
	if _camera == null or get_world_3d() == null:
		return {}
	var ray_from := _camera.project_ray_origin(screen_position)
	var ray_to := ray_from + _camera.project_ray_normal(screen_position) * 100000.0
	var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to, 1)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}
	var collider := hit.get("collider") as Area3D
	if collider == null:
		return {}
	var profile = collider.get_meta("level_profile", {})
	return profile if profile is Dictionary else {}


func _refresh_marker_emphasis() -> void:
	for raw_level_id in _marker_by_id:
		var level_id := str(raw_level_id)
		var marker := _marker_by_id[level_id] as Area3D
		if marker == null:
			continue
		var emphasized: bool = level_id == _hovered_level_id or level_id == _selected_level_id
		var visual := marker.get_node_or_null("Visual") as Node3D
		if visual != null:
			visual.scale = Vector3.ONE * MARKER_SCALE * (1.23 if emphasized else 1.0)
		var label := marker.get_node_or_null("LevelName") as Label3D
		if label != null:
			var profile: Dictionary = marker.get_meta("level_profile", {})
			label.visible = emphasized or not bool(profile.get("completed", false))


func _pan_camera(relative: Vector2) -> void:
	var right := _camera.global_basis.x
	var forward := -_camera.global_basis.z
	right.y = 0.0
	forward.y = 0.0
	right = right.normalized()
	forward = forward.normalized()
	var amount := _camera_size * 0.0018
	_camera_target += (-right * relative.x + forward * relative.y) * amount
	_camera_target.x = clampf(_camera_target.x, -5600.0, 5600.0)
	_camera_target.z = clampf(_camera_target.z, -4000.0, 4000.0)
	_update_camera()


func _update_camera() -> void:
	if _camera == null:
		return
	var horizontal := cos(_camera_pitch) * _camera_distance
	var offset := Vector3(sin(_camera_yaw) * horizontal, sin(_camera_pitch) * _camera_distance, cos(_camera_yaw) * horizontal)
	_camera.position = _camera_target + offset
	_camera.look_at(_camera_target, Vector3.UP)
	_camera.size = _camera_size


func _level_position(profile: Dictionary) -> Vector3:
	var normalized: Vector2 = profile.get("map_position", Vector2(0.5, 0.5))
	var x := (normalized.x - 0.5) * MAP_WIDTH
	var z := (normalized.y - 0.5) * MAP_DEPTH
	if str(profile.get("map_set", "")) == "MiZhiDi":
		var local_index := int(profile.get("local_index", 0))
		return Vector3(x * MAP_SCALE, 560.0 + float(local_index % 2) * 55.0, z * MAP_SCALE)
	return _surface_point(x, z, 0.30)


func _surface_point(x: float, z: float, lift: float = 0.0) -> Vector3:
	return Vector3(x * MAP_SCALE, _height_at(x, z) + lift * HEIGHT_SCALE, z * MAP_SCALE)


func _densify_map_path(path: Array, maximum_step: float) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if path.is_empty():
		return result
	for index in range(path.size() - 1):
		var start: Vector2 = path[index]
		var finish: Vector2 = path[index + 1]
		var subdivisions := maxi(1, int(ceil(start.distance_to(finish) / maximum_step)))
		for step in range(subdivisions):
			result.append(start.lerp(finish, float(step) / float(subdivisions)))
	result.append(path[path.size() - 1])
	return result


func _near_world_road(x: float, z: float, clearance: float) -> bool:
	var point := Vector2(x, z)
	for road_data in WORLD_ROAD_PATHS:
		var path: Array = road_data[1]
		for index in range(path.size() - 1):
			var closest := Geometry2D.get_closest_point_to_segment(point, path[index], path[index + 1])
			if point.distance_squared_to(closest) <= clearance * clearance:
				return true
	return false


func _structure_anchor(center: Vector2, radius_world: float, lift: float = 0.0) -> Vector3:
	var highest := _height_at(center.x, center.y)
	var radius_map := radius_world / MAP_SCALE
	for sample_index in range(8):
		var angle := TAU * float(sample_index) / 8.0
		var sample_x := center.x + cos(angle) * radius_map
		var sample_z := center.y + sin(angle) * radius_map
		highest = maxf(highest, _height_at(sample_x, sample_z))
	return Vector3(center.x * MAP_SCALE, highest + lift * HEIGHT_SCALE, center.y * MAP_SCALE)


func _add_surface_strip(parent: Node3D, node_name: String, points_2d: Array, width: float, color: Color, lift: float, custom_material: Material = null) -> void:
	if points_2d.size() < 2:
		return
	var points: Array[Vector3] = []
	for raw_point in points_2d:
		var point: Vector2 = raw_point
		points.append(_surface_point(point.x, point.y, lift))
	var left: Array[Vector3] = []
	var right: Array[Vector3] = []
	var distances: Array[float] = [0.0]
	for index in range(points.size()):
		var previous := points[maxi(index - 1, 0)]
		var following := points[mini(index + 1, points.size() - 1)]
		var tangent := following - previous
		tangent.y = 0.0
		var side := Vector3(-tangent.z, 0.0, tangent.x).normalized() * width * MAP_SCALE
		left.append(points[index] + side)
		right.append(points[index] - side)
		if index > 0:
			distances.append(distances[index - 1] + points[index - 1].distance_to(points[index]))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(points.size() - 1):
		var current_v := distances[index] / 420.0
		var next_v := distances[index + 1] / 420.0
		_add_up_facing_textured_triangle(surface, left[index], Vector2(0.0, current_v), right[index], Vector2(1.0, current_v), left[index + 1], Vector2(0.0, next_v))
		_add_up_facing_textured_triangle(surface, right[index], Vector2(1.0, current_v), right[index + 1], Vector2(1.0, next_v), left[index + 1], Vector2(0.0, next_v))
	var strip := MeshInstance3D.new()
	strip.name = node_name
	strip.mesh = surface.commit()
	if custom_material != null:
		strip.material_override = custom_material
	else:
		var strip_material := _material(color, 0.42)
		strip_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		strip.material_override = strip_material
	_attach(parent, strip)


func _add_up_facing_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	for vertex in [a, b, c]:
		surface.set_normal(Vector3.UP)
		surface.add_vertex(vertex)


func _add_up_facing_textured_triangle(surface: SurfaceTool, a: Vector3, uv_a: Vector2, b: Vector3, uv_b: Vector2, c: Vector3, uv_c: Vector2) -> void:
	for vertex_data in [[a, uv_a], [b, uv_b], [c, uv_c]]:
		surface.set_normal(Vector3.UP)
		surface.set_uv(vertex_data[1])
		surface.add_vertex(vertex_data[0])


func _add_box_child(parent: Node3D, node_name: String, size: Vector3, position_: Vector3, color: Color, emission: bool = false) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = position_
	instance.material_override = _material(color, 0.78, emission)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_attach(parent, instance)
	return instance


func _add_tower_child(parent: Node3D, node_name: String, position_: Vector3, height: float, radius: float, body_color: Color, cap_color: Color) -> Node3D:
	var tower := Node3D.new()
	tower.name = node_name
	tower.position = position_
	_attach(parent, tower)
	_add_cylinder_child(tower, "Body", Vector3.ZERO, radius, height, body_color)
	_add_cylinder_child(tower, "Cap", Vector3(0.0, height * 0.55, 0.0), radius * 1.15, 0.20, cap_color, true)
	return tower


func _add_cylinder_child(parent: Node3D, node_name: String, position_: Vector3, radius: float, height: float, color: Color, emission: bool = false) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.88
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	instance.mesh = mesh
	instance.position = position_ + Vector3(0.0, height * 0.5, 0.0)
	instance.material_override = _material(color, 0.78, emission)
	_attach(parent, instance)
	return instance


func _add_cone_child(parent: Node3D, node_name: String, position_: Vector3, radius: float, height: float, color: Color, emission: bool = false, sides: int = 8) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	instance.mesh = mesh
	instance.position = position_ + Vector3(0.0, height * 0.5, 0.0)
	instance.material_override = _material(color, 0.72, emission)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_attach(parent, instance)
	return instance


func _add_world_label(parent: Node3D, value: String, position_: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.name = value
	label.text = value
	label.position = position_
	label.font_size = 24
	label.outline_size = 5
	label.pixel_size = 0.018
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.fixed_size = false
	label.no_depth_test = false
	_attach(parent, label)


func _is_land(x: float, z: float) -> bool:
	return _height_at(x, z) > 8.0


func _height_at(x: float, z: float) -> float:
	if _terrain3d != null:
		var data = _terrain3d.call("get_data")
		if data != null:
			var terrain_height := float(data.call("get_height", Vector3(x * MAP_SCALE, 0.0, z * MAP_SCALE)))
			if not is_nan(terrain_height):
				return terrain_height
	var east := clampf((x / (MAP_WIDTH * 0.5) + 1.0) * 0.5, 0.0, 1.0)
	var north := clampf((-z / (MAP_DEPTH * 0.5) + 1.0) * 0.5, 0.0, 1.0)
	var relief := sin(x * 0.72 + z * 0.18) * 0.10 + cos(z * 0.66 - x * 0.12) * 0.08
	var southern_plateau := smoothstep(2.8, 5.0, z) * 0.42
	return maxf(0.16, 0.28 + east * 0.48 + north * 0.72 + southern_plateau + relief) * HEIGHT_SCALE


func _terrain_normal_at(x: float, z: float) -> Vector3:
	if _terrain3d != null:
		var data = _terrain3d.call("get_data")
		if data != null:
			var normal: Vector3 = data.call("get_normal", Vector3(x * MAP_SCALE, 0.0, z * MAP_SCALE))
			if normal.is_finite() and normal.length_squared() > 0.25:
				return normal.normalized()
	var sample_distance := 0.06
	var left := _height_at(x - sample_distance, z)
	var right := _height_at(x + sample_distance, z)
	var near := _height_at(x, z - sample_distance)
	var far := _height_at(x, z + sample_distance)
	return Vector3(left - right, sample_distance * MAP_SCALE * 2.0, near - far).normalized()


func _terrain_color(x: float, z: float) -> Color:
	var east := clampf((x / (MAP_WIDTH * 0.5) + 1.0) * 0.5, 0.0, 1.0)
	var north := clampf((-z / (MAP_DEPTH * 0.5) + 1.0) * 0.5, 0.0, 1.0)
	var color := Color("#749866").lerp(Color("#7b8064"), east * 0.42)
	if z > 3.1:
		color = color.lerp(Color("#b3864f"), 0.58)
	if north > 0.72:
		color = color.lerp(Color("#c0d0c4"), (north - 0.72) * 2.2)
	if x > 8.5 and z < -1.5:
		color = color.lerp(Color("#6f8d68"), 0.36)
	var variation := sin(x * 2.7 + z * 1.9) * 0.025
	return color.lightened(maxf(variation, 0.0)).darkened(maxf(-variation, 0.0))


func _material(color: Color, roughness: float, emission: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = maxf(roughness, 0.68)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	if color.a < 0.999:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission:
		material.emission_enabled = true
		material.emission = Color(color.r, color.g, color.b)
		material.emission_energy_multiplier = 1.15
	return material


func _editor_preview_profiles() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var catalog = LEVEL_CATALOG.new()
	for raw_profile in catalog.levels():
		var profile := raw_profile.duplicate(true)
		profile["unlocked"] = true
		profile["completed"] = true
		result.append(profile)
	if not result.is_empty():
		result[result.size() - 1]["completed"] = false
	return result


func _attach(parent: Node, child: Node) -> void:
	parent.add_child(child)
	if Engine.is_editor_hint() and get_tree() != null and get_tree().edited_scene_root != null:
		var scene_root := get_tree().edited_scene_root
		if scene_root == child or scene_root.is_ancestor_of(child):
			_assign_editor_owner(child, scene_root)


func _assign_editor_owner(node: Node, scene_root: Node) -> void:
	if node != scene_root:
		node.owner = scene_root
	for child in node.get_children():
		_assign_editor_owner(child, scene_root)
