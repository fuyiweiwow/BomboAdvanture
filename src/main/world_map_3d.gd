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

var _profiles: Array[Dictionary] = []
var _camera: Camera3D
var _terrain3d: Node3D
var _camera_target := Vector3(0.0, 420.0, 1600.0)
var _camera_yaw := deg_to_rad(-12.0)
var _camera_pitch := deg_to_rad(40.0)
var _camera_distance := 29000.0
var _camera_size := 25500.0
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


func configure(profiles: Array[Dictionary]) -> void:
	_profiles.clear()
	for profile in profiles:
		_profiles.append(profile.duplicate(true))
	if is_inside_tree():
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
	_camera_size = 25500.0
	_update_camera()


func _ready() -> void:
	if not has_node("GeneratedWorld"):
		_build_world()
	_camera = get_node_or_null("GeneratedWorld/Camera3D") as Camera3D
	if Engine.is_editor_hint() and _profiles.is_empty():
		_profiles = _editor_preview_profiles()
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
	var generated := Node3D.new()
	generated.name = "GeneratedWorld"
	_attach(self, generated)
	_add_environment(generated)
	_add_ocean(generated)
	_add_terrain(generated)
	_add_lakes(generated)
	_add_terrain_cover(generated)
	_add_western_floating_islands(generated)


func _add_environment(parent: Node3D) -> void:
	var light := DirectionalLight3D.new()
	light.name = "SunLight"
	light.rotation_degrees = Vector3(-54.0, -32.0, 0.0)
	light.light_energy = 0.72
	light.shadow_enabled = true
	_attach(parent, light)

	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#173f47")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#9daea4")
	environment.ambient_light_energy = 0.34
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
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
	ocean.material_override = _material(Color("#184f5c"), 0.34)
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
	var broadleaf_transforms: Array[Transform3D] = []
	var oak_transforms: Array[Transform3D] = []
	for _index in range(430):
		var x := random.randf_range(-12.8, -1.0)
		var z := random.randf_range(-3.4, 4.8)
		var loand_forest := exp(-(pow((x + 6.1) / 5.0, 2.0) + pow((z + 0.7) / 3.4, 2.0)))
		var west_forest := exp(-(pow((x + 10.5) / 2.8, 2.0) + pow((z - 2.8) / 2.4, 2.0)))
		var density := maxf(loand_forest * 0.90, west_forest)
		if random.randf() > density or not _is_land(x, z):
			continue
		var height := _height_at(x, z)
		if height <= 12.0 or height > 390.0:
			continue
		var destination := oak_transforms if random.randf() < 0.32 else broadleaf_transforms
		destination.append(_asset_transform(x, z, height, random.randf_range(190.0, 255.0), random.randf_range(0.0, TAU)))

	var pine_transforms: Array[Transform3D] = []
	var small_pine_transforms: Array[Transform3D] = []
	for _index in range(230):
		var x := random.randf_range(-1.5, 11.2)
		var z := random.randf_range(-7.0, -3.0)
		var foothill_density := exp(-(pow((x - 5.0) / 7.0, 2.0) + pow((z + 4.8) / 1.8, 2.0)))
		if random.randf() > foothill_density * 0.72 or not _is_land(x, z):
			continue
		var height := _height_at(x, z)
		if height < 70.0 or height > 590.0:
			continue
		var destination := small_pine_transforms if random.randf() < 0.36 else pine_transforms
		destination.append(_asset_transform(x, z, height, random.randf_range(195.0, 265.0), random.randf_range(0.0, TAU)))

	var cactus_transforms: Array[Transform3D] = []
	for _index in range(92):
		var x := random.randf_range(-9.2, 6.8)
		var z := random.randf_range(4.8, 8.4)
		if random.randf() > 0.48 or not _is_land(x, z):
			continue
		var height := _height_at(x, z)
		if height > 360.0:
			continue
		cactus_transforms.append(_asset_transform(x, z, height, random.randf_range(195.0, 275.0), random.randf_range(0.0, TAU)))

	var island_tree_transforms: Array[Transform3D] = []
	var island_centers := [
		Vector3(-7.1, 11.0, 1.65), Vector3(-2.9, 12.0, 1.20),
		Vector3(1.2, 11.2, 1.80), Vector3(5.6, 12.2, 1.35),
		Vector3(9.5, 11.0, 1.45), Vector3(12.8, 12.8, 0.82),
	]
	for raw_center in island_centers:
		var center: Vector3 = raw_center
		for _index in range(16):
			var angle: float = random.randf_range(0.0, TAU)
			var radius: float = sqrt(random.randf()) * 0.76
			var x: float = center.x + cos(angle) * radius * center.z
			var z: float = center.y + sin(angle) * radius * center.z * 0.58
			if not _is_land(x, z):
				continue
			var height := _height_at(x, z)
			if height <= 10.0:
				continue
			island_tree_transforms.append(_asset_transform(x, z, height, random.randf_range(150.0, 205.0), random.randf_range(0.0, TAU)))

	var rock_transforms: Array[Transform3D] = []
	var tall_rock_transforms: Array[Transform3D] = []
	for _index in range(190):
		var x := random.randf_range(-9.5, 12.5)
		var z := random.randf_range(-8.2, 4.5)
		if not _is_land(x, z):
			continue
		var height := _height_at(x, z)
		if height < 270.0 or random.randf() > clampf((height - 250.0) / 620.0, 0.18, 0.86):
			continue
		var destination := tall_rock_transforms if random.randf() < 0.25 else rock_transforms
		destination.append(_asset_transform(x, z, height, random.randf_range(300.0, 470.0), random.randf_range(0.0, TAU)))

	_add_asset_multimesh(parent, "LoandBroadleafForest", "res://assets/environment/kenney_nature/tree_default.glb", broadleaf_transforms)
	_add_asset_multimesh(parent, "LoandOakForest", "res://assets/environment/kenney_nature/tree_oak.glb", oak_transforms)
	_add_asset_multimesh(parent, "HerenPineForest", "res://assets/environment/kenney_nature/tree_pineDefaultA.glb", pine_transforms)
	_add_asset_multimesh(parent, "HerenSmallPines", "res://assets/environment/kenney_nature/tree_pineSmallA.glb", small_pine_transforms)
	_add_asset_multimesh(parent, "SouthernCacti", "res://assets/environment/kenney_nature/cactus_tall.glb", cactus_transforms)
	_add_asset_multimesh(parent, "SouthernIslandGroves", "res://assets/environment/kenney_nature/tree_oak.glb", island_tree_transforms)
	_add_asset_multimesh(parent, "MountainRocks", "res://assets/environment/kenney_nature/rock_largeA.glb", rock_transforms)
	_add_asset_multimesh(parent, "MountainSpireRocks", "res://assets/environment/kenney_nature/rock_tallA.glb", tall_rock_transforms)


func _add_lakes(parent: Node3D) -> void:
	var lakes := [
		["CentralBasinLake", Vector2(-1.7, -0.7), Vector2(1.18, 0.68)],
		["DattBorderLake", Vector2(6.8, 1.8), Vector2(0.90, 0.58)],
		["SouthernSaltLake", Vector2(-2.3, 6.5), Vector2(1.28, 0.73)],
	]
	for lake_data in lakes:
		var lake := Node3D.new()
		lake.name = str(lake_data[0])
		lake.position = Vector3(lake_data[1].x * MAP_SCALE, 0.0, lake_data[1].y * MAP_SCALE)
		var radius: Vector2 = lake_data[2]
		var shore := MeshInstance3D.new()
		shore.name = "Shore"
		var shore_mesh := CylinderMesh.new()
		shore_mesh.top_radius = 1.0
		shore_mesh.bottom_radius = 1.0
		shore_mesh.height = 5.0
		shore_mesh.radial_segments = 48
		shore.mesh = shore_mesh
		shore.position.y = 5.0
		shore.scale = Vector3(radius.x * MAP_SCALE * 1.08, 1.0, radius.y * MAP_SCALE * 1.08)
		shore.material_override = _material(Color("#b9a66c"), 0.88)
		_attach(lake, shore)

		var water := MeshInstance3D.new()
		water.name = "Water"
		var water_mesh := CylinderMesh.new()
		water_mesh.top_radius = 1.0
		water_mesh.bottom_radius = 1.0
		water_mesh.height = 4.0
		water_mesh.radial_segments = 48
		water.mesh = water_mesh
		water.position.y = 9.0
		water.scale = Vector3(radius.x * MAP_SCALE, 1.0, radius.y * MAP_SCALE)
		var water_material := ShaderMaterial.new()
		water_material.shader = MINIATURE_WATER_SHADER
		water.material_override = water_material
		_attach(lake, water)
		_attach(parent, lake)


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
	for index in range(definitions.size()):
		var definition: Vector4 = definitions[index]
		var island := Node3D.new()
		island.name = "FloatingIsland_%02d" % index
		island.position = Vector3(definition.x * MAP_SCALE, definition.w, definition.y * MAP_SCALE)
		island.set_meta("base_y", definition.w)
		_attach(cluster, island)
		_floating_islands.append(island)

		var radius := definition.z
		var rock_height := radius * (1.42 if index % 2 == 0 else 1.68)
		var rock := MeshInstance3D.new()
		rock.name = "TaperedRock"
		var rock_mesh := CylinderMesh.new()
		rock_mesh.top_radius = radius
		rock_mesh.bottom_radius = radius * 0.10
		rock_mesh.height = rock_height
		rock_mesh.radial_segments = 9
		rock.mesh = rock_mesh
		rock.position.y = -rock_height * 0.5
		rock.material_override = _material(Color("#62564b"), 0.96)
		_attach(island, rock)

		var crown := MeshInstance3D.new()
		crown.name = "GrassCrown"
		var crown_mesh := CylinderMesh.new()
		crown_mesh.top_radius = radius * 1.04
		crown_mesh.bottom_radius = radius * 0.96
		crown_mesh.height = 52.0
		crown_mesh.radial_segments = 12
		crown.mesh = crown_mesh
		crown.position.y = 18.0
		crown.material_override = _material(Color("#5d8e60"), 0.90)
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
			var tree_scale := 165.0 + float((index + tree_index) % 3) * 22.0
			var basis := Basis(Vector3.UP, angle + 0.4).scaled(Vector3.ONE * tree_scale)
			tree_transforms.append(Transform3D(basis, Vector3(cos(angle) * distance, 48.0, sin(angle) * distance)))
		_add_asset_multimesh(island, "IslandTrees", "res://assets/environment/kenney_nature/tree_pineDefaultA.glb", tree_transforms)


func _asset_transform(x: float, z: float, height: float, scale_factor: float, angle: float) -> Transform3D:
	var basis := Basis(Vector3.UP, angle).scaled(Vector3.ONE * scale_factor)
	return Transform3D(basis, Vector3(x * MAP_SCALE, height, z * MAP_SCALE))


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
	var source_mesh := source_meshes[0] as MeshInstance3D
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _retint_asset_mesh(source_mesh.mesh, scene_path)
	multimesh.instance_count = transforms.size()
	for index in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if scene_path.contains("rock") else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_attach(parent, instance)
	source_root.free()


func _retint_asset_mesh(source_mesh: Mesh, scene_path: String) -> Mesh:
	var mesh := source_mesh.duplicate(true) as Mesh
	var is_pine := scene_path.contains("pine")
	var is_cactus := scene_path.contains("cactus")
	var is_rock := scene_path.contains("rock")
	for surface_index in range(mesh.get_surface_count()):
		var source_material := mesh.surface_get_material(surface_index)
		if not source_material is StandardMaterial3D:
			continue
		var material := source_material.duplicate(true) as StandardMaterial3D
		var material_name := material.resource_name.to_lower()
		if is_rock:
			material.albedo_color = Color("#85877f") if surface_index == 0 else Color("#929985")
		elif material_name.contains("wood") or material_name.contains("bark"):
			material.albedo_color = Color("#8a6542")
		elif is_cactus:
			material.albedo_color = Color("#668f4f")
		elif is_pine:
			material.albedo_color = Color("#4f7f61")
		else:
			material.albedo_color = Color("#5d945b")
		material.roughness = 0.88
		material.emission_enabled = true
		material.emission = material.albedo_color
		material.emission_energy_multiplier = 0.10
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
	_add_surface_path(parent, "LoandRiver", [Vector2(-4.0, -6.0), Vector2(-5.1, -3.4), Vector2(-5.6, -0.6), Vector2(-4.6, 2.0), Vector2(-3.2, 3.2)], 0.22, Color("#66bbb8"))
	_add_surface_path(parent, "HerenRiver", [Vector2(7.8, -8.2), Vector2(7.0, -5.7), Vector2(6.2, -3.8), Vector2(5.2, -2.1)], 0.20, Color("#69c2c0"))
	_add_surface_path(parent, "SouthernRiver", [Vector2(-0.6, 4.3), Vector2(-0.9, 5.9), Vector2(-0.3, 7.5), Vector2(0.8, 8.8)], 0.20, Color("#5aaca9"))

	var hub := Vector2(3.9, -1.4)
	_add_surface_path(parent, "DattCanalNorthSouth", [Vector2(3.9, -5.2), Vector2(3.9, -3.2), hub, Vector2(3.9, 1.1)], 0.32, Color("#3f9dab"))
	_add_surface_path(parent, "DattCanalWestEast", [Vector2(-3.8, -1.4), Vector2(0.2, -1.4), hub, Vector2(7.4, -1.1), Vector2(10.5, 0.2)], 0.32, Color("#3f9dab"))
	var canal_hub := MeshInstance3D.new()
	canal_hub.name = "CanalExchangeBasin"
	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = 0.72
	hub_mesh.bottom_radius = 0.72
	hub_mesh.height = 0.08
	hub_mesh.radial_segments = 20
	canal_hub.mesh = hub_mesh
	canal_hub.position = _surface_point(hub.x, hub.y, 0.11)
	canal_hub.material_override = _material(Color("#45a8b3"), 0.22, true)
	_attach(parent, canal_hub)


func _add_transport_network(parent: Node3D) -> void:
	var rail_points := [Vector2(-7.4, 0.6), Vector2(-2.2, -0.2), Vector2(3.9, -1.0), Vector2(7.2, -0.7), Vector2(10.5, 0.6)]
	_add_surface_path(parent, "MaglevBed", rail_points, 0.15, Color("#30393a"), 0.22)
	_add_surface_path(parent, "MaglevGlow", rail_points, 0.055, Color("#e6ca59"), 0.25, true)
	var train := Node3D.new()
	train.name = "MovingMaglev"
	_add_box_child(train, "Body", Vector3(0.85, 0.22, 0.28), Vector3.ZERO, Color("#d8e7df"), true)
	_attach(parent, train)
	_animated_vehicles.append({"node": train, "from": _surface_point(-6.8, 0.5, 0.55), "to": _surface_point(10.1, 0.5, 0.55), "speed": 0.045, "phase": 0.1})

	for index in range(2):
		var shuttle := Node3D.new()
		shuttle.name = "AirShuttle_%02d" % index
		_add_box_child(shuttle, "Cabin", Vector3(0.56, 0.16, 0.24), Vector3.ZERO, Color("#77d9d4"), true)
		_add_box_child(shuttle, "Wing", Vector3(0.82, 0.04, 0.12), Vector3.ZERO, Color("#ebcc63"), true)
		_attach(parent, shuttle)
		_animated_vehicles.append({"node": shuttle, "from": Vector3(2.8, 4.0 + index, -2.0), "to": Vector3(11.5, 3.2 + index, 1.3), "speed": 0.035 + index * 0.008, "phase": index * 0.48})


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

	for i in range(_profiles.size() - 1):
		var from_profile := _profiles[i]
		var to_profile := _profiles[i + 1]
		_add_level_route(layer, from_profile, to_profile, i)
	for profile_index in range(_profiles.size()):
		_add_level_marker(layer, _profiles[profile_index], profile_index)


func _add_level_route(parent: Node3D, from_profile: Dictionary, to_profile: Dictionary, route_index: int) -> void:
	var start := _level_position(from_profile)
	var finish := _level_position(to_profile)
	var flat_delta := Vector2(finish.x - start.x, finish.z - start.z)
	var normal := Vector2(-flat_delta.y, flat_delta.x).normalized()
	var bend := minf(flat_delta.length() * 0.12, 1.1 * MAP_SCALE) * (1.0 if route_index % 2 == 0 else -1.0)
	var control := (start + finish) * 0.5 + Vector3(normal.x * bend, 0.8 * HEIGHT_SCALE, normal.y * bend)
	var points: Array[Vector3] = []
	for step in range(13):
		var t := float(step) / 12.0
		var point := start.lerp(control, t).lerp(control.lerp(finish, t), t)
		point.y += (0.22 + sin(t * PI) * 0.18) * HEIGHT_SCALE
		points.append(point)
	var completed := bool(from_profile.get("completed", false))
	var color := Color("#6ad5c5") if completed else Color("#e6bd4f")
	_add_ribbon(parent, "LevelRoute_%02d" % route_index, points, 0.075, color, true)
	for bead_index in range(1, 4):
		var bead_t := float(bead_index) / 4.0
		var bead_position := points[int(round(bead_t * float(points.size() - 1)))]
		var bead := MeshInstance3D.new()
		bead.name = "RouteLight_%02d_%02d" % [route_index, bead_index]
		var bead_mesh := SphereMesh.new()
		bead_mesh.radius = 0.09 * MAP_SCALE
		bead_mesh.height = 0.18 * MAP_SCALE
		bead.mesh = bead_mesh
		bead.position = bead_position
		bead.material_override = _material(color.lightened(0.18), 0.18, true)
		_attach(parent, bead)


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


func _add_surface_path(parent: Node3D, node_name: String, points_2d: Array, width: float, color: Color, lift: float = 0.10, emission: bool = false) -> void:
	var points: Array[Vector3] = []
	for raw_point in points_2d:
		var point: Vector2 = raw_point
		points.append(_surface_point(point.x, point.y, lift))
	_add_ribbon(parent, node_name, points, width, color, emission)


func _add_ribbon(parent: Node3D, node_name: String, points: Array[Vector3], width: float, color: Color, emission: bool = false) -> void:
	var path := Node3D.new()
	path.name = node_name
	_attach(parent, path)
	for i in range(points.size() - 1):
		var start := points[i]
		var finish := points[i + 1]
		var direction := finish - start
		var length := direction.length()
		if length <= 0.001:
			continue
		var segment := MeshInstance3D.new()
		segment.name = "Segment_%02d" % i
		var mesh := CylinderMesh.new()
		mesh.top_radius = width * MAP_SCALE
		mesh.bottom_radius = width * MAP_SCALE
		mesh.height = length
		mesh.radial_segments = 8
		segment.mesh = mesh
		segment.transform = Transform3D(_basis_from_up(direction), (start + finish) * 0.5)
		segment.material_override = _material(color, 0.28, emission)
		_attach(path, segment)


func _basis_from_up(direction: Vector3) -> Basis:
	var up := direction.normalized()
	var right := up.cross(Vector3.FORWARD)
	if right.length_squared() < 0.001:
		right = up.cross(Vector3.RIGHT)
	right = right.normalized()
	var forward := right.cross(up).normalized()
	return Basis(right, up, forward)


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
	material.roughness = roughness
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
		profile["completed"] = false
		result.append(profile)
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
