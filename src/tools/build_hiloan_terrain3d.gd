extends SceneTree

const DATA_DIRECTORY := "res://assets/terrain3d/hiloan"
const SCENE_PATH := "res://src/main/hiloan_terrain3d.tscn"
const MAP_SIZE := 1024
const REGION_SIZE := 256
const VERTEX_SPACING := 64.0
const WORLD_SCALE := 800.0
const HEIGHT_SCALE := 160.0
const WORLD_ORIGIN := -32768.0

const TEXTURE_GRASS := 0
const TEXTURE_FOREST := 1
const TEXTURE_ROCK := 2
const TEXTURE_SAND := 3
const TEXTURE_SNOW := 4

const LOAND_RIVER := [
	Vector2(-4.0, -6.0), Vector2(-5.1, -3.4), Vector2(-5.6, -0.6),
	Vector2(-4.6, 2.0), Vector2(-3.2, 3.2),
]
const HEREN_RIVER := [
	Vector2(7.8, -8.2), Vector2(7.0, -5.7), Vector2(6.2, -3.8), Vector2(5.2, -2.1),
]
const SOUTHERN_RIVER := [
	Vector2(-0.6, 4.3), Vector2(-0.9, 5.9), Vector2(-0.3, 7.5), Vector2(0.8, 8.8),
]
const LOAND_WEST_TRIBUTARY := [
	Vector2(-10.2, -2.7), Vector2(-8.4, -1.8), Vector2(-7.0, -0.9), Vector2(-5.6, -0.6),
]
const LOAND_NORTH_TRIBUTARY := [
	Vector2(-2.7, -5.8), Vector2(-3.8, -4.0), Vector2(-4.8, -2.4), Vector2(-5.5, -0.8),
]
const HEREN_EAST_TRIBUTARY := [
	Vector2(10.6, -6.5), Vector2(9.4, -5.2), Vector2(8.0, -4.2), Vector2(6.3, -3.7),
]


func _initialize() -> void:
	call_deferred("_build_terrain")


func _build_terrain() -> void:
	var absolute_directory := ProjectSettings.globalize_path(DATA_DIRECTORY)
	DirAccess.make_dir_recursive_absolute(absolute_directory)

	var height_map := Image.create(MAP_SIZE, MAP_SIZE, false, Image.FORMAT_RF)
	var control_map := Image.create(MAP_SIZE, MAP_SIZE, false, Image.FORMAT_RF)
	var color_map := Image.create(MAP_SIZE, MAP_SIZE, false, Image.FORMAT_RGBA8)
	for pixel_z in range(MAP_SIZE):
		var world_z := WORLD_ORIGIN + float(pixel_z) * VERTEX_SPACING
		for pixel_x in range(MAP_SIZE):
			var world_x := WORLD_ORIGIN + float(pixel_x) * VERTEX_SPACING
			var map_x := world_x / WORLD_SCALE
			var map_z := world_z / WORLD_SCALE
			var map_height := _world_height(map_x, map_z)
			var height := map_height * HEIGHT_SCALE
			height_map.set_pixel(pixel_x, pixel_z, Color(height, 0.0, 0.0, 1.0))
			control_map.set_pixel(pixel_x, pixel_z, _world_control(map_x, map_z, map_height))
			color_map.set_pixel(pixel_x, pixel_z, _world_color(map_x, map_z, map_height))

	var height_path := DATA_DIRECTORY + "/hiloan_height.exr"
	var color_path := DATA_DIRECTORY + "/hiloan_color.png"
	assert(height_map.save_exr(ProjectSettings.globalize_path(height_path)) == OK)
	assert(color_map.save_png(ProjectSettings.globalize_path(color_path)) == OK)

	var terrain := ClassDB.instantiate("Terrain3D") as Node3D
	assert(terrain != null)
	var build_camera := Camera3D.new()
	build_camera.current = true
	build_camera.position = Vector3(0.0, 28000.0, 26000.0)
	root.add_child(build_camera)
	terrain.name = "HiloanTerrain3D"
	terrain.set("region_size", REGION_SIZE)
	terrain.set("vertex_spacing", VERTEX_SPACING)
	terrain.set("data_directory", DATA_DIRECTORY)
	terrain.set("mesh_lods", 7)
	terrain.set("mesh_size", 48)
	terrain.set("free_editor_textures", false)
	terrain.set("show_region_grid", false)
	terrain.set("assets", _create_terrain_assets())
	terrain.call("set_camera", build_camera)
	root.add_child(terrain)
	await process_frame
	var material = terrain.call("get_material")
	assert(material != null)
	material.set("show_checkered", false)
	material.set("show_colormap", true)
	material.set("auto_shader", false)
	terrain.set("show_checkered", false)
	terrain.set("show_colormap", true)

	var data = terrain.call("get_data")
	assert(data != null)
	var maps: Array[Image] = []
	maps.resize(3)
	maps[0] = height_map
	maps[1] = control_map
	maps[2] = color_map
	data.call("import_images", maps, Vector3(WORLD_ORIGIN, 0.0, WORLD_ORIGIN), 0.0, 1.0)
	data.call("calc_height_range", true)
	assert(int(data.call("get_region_count")) > 0)
	data.call("save_directory", DATA_DIRECTORY)

	var packed_scene := PackedScene.new()
	assert(packed_scene.pack(terrain) == OK)
	assert(ResourceSaver.save(packed_scene, SCENE_PATH) == OK)

	print("HILOAN_TERRAIN3D_OK regions=", data.call("get_region_count"), " range=", data.call("get_height_range"))
	root.remove_child(terrain)
	terrain.free()
	build_camera.queue_free()
	quit(0)


func _create_terrain_assets() -> Resource:
	var assets := ClassDB.instantiate("Terrain3DAssets") as Resource
	assert(assets != null)
	var texture_definitions := [
		["Cartoon Grassland", TEXTURE_GRASS, "res://assets/environment/terrain_textures/packed/grassland_alb_ht.png", "res://assets/environment/terrain_textures/packed/grassland_nrm_rgh.png", Color("#6b9656"), 0.0022],
		["Cartoon Forest", TEXTURE_FOREST, "res://assets/environment/terrain_textures/packed/grassland_alb_ht.png", "res://assets/environment/terrain_textures/packed/grassland_nrm_rgh.png", Color("#356940"), 0.0024],
		["Cartoon Mountain Rock", TEXTURE_ROCK, "res://assets/environment/terrain_textures/packed/mountain_rock_alb_ht.png", "res://assets/environment/terrain_textures/packed/mountain_rock_nrm_rgh.png", Color("#707977"), 0.0020],
		["Cartoon Southern Sand", TEXTURE_SAND, "res://assets/environment/terrain_textures/packed/sand_01_alb_ht.png", "res://assets/environment/terrain_textures/packed/sand_01_nrm_rgh.png", Color("#c0924e"), 0.0018],
		["Northern Peak Snow", TEXTURE_SNOW, "res://assets/environment/terrain_textures/packed/snow_02_alb_ht.png", "res://assets/environment/terrain_textures/packed/snow_02_nrm_rgh.png", Color("#e7eee9"), 0.0020],
	]
	for definition in texture_definitions:
		var texture_asset := ClassDB.instantiate("Terrain3DTextureAsset") as Resource
		texture_asset.set("name", definition[0])
		texture_asset.set("id", definition[1])
		texture_asset.set("albedo_texture", load(definition[2]))
		texture_asset.set("normal_texture", load(definition[3]))
		texture_asset.set("albedo_color", definition[4])
		texture_asset.set("normal_depth", 0.12)
		texture_asset.set("roughness", 0.32)
		texture_asset.set("uv_scale", definition[5])
		texture_asset.set("detiling_rotation", 0.13)
		_set_texture_asset(assets, int(definition[1]), texture_asset)

	var mesh_definitions := [
		["Broadleaf Tree", "res://assets/environment/kenney_nature/tree_default.glb", 0.46],
		["Oak Tree", "res://assets/environment/kenney_nature/tree_oak.glb", 0.48],
		["Northern Pine", "res://assets/environment/kenney_nature/tree_pineDefaultA.glb", 0.48],
		["Mountain Rock", "res://assets/environment/kenney_nature/rock_largeA.glb", 0.24],
		["Desert Cactus", "res://assets/environment/kenney_nature/cactus_tall.glb", 0.44],
	]
	for mesh_id in range(mesh_definitions.size()):
		var definition: Array = mesh_definitions[mesh_id]
		var mesh_asset := ClassDB.instantiate("Terrain3DMeshAsset") as Resource
		mesh_asset.set("name", definition[0])
		mesh_asset.set("id", mesh_id)
		mesh_asset.set("scene_file", load(definition[1]))
		mesh_asset.set("height_offset", definition[2])
		mesh_asset.set("last_lod", 2)
		mesh_asset.set("last_shadow_lod", 1)
		_set_mesh_asset(assets, mesh_id, mesh_asset)
	return assets


func _set_texture_asset(assets: Resource, texture_id: int, texture_asset: Resource) -> void:
	if assets.has_method("set_texture_asset"):
		assets.call("set_texture_asset", texture_id, texture_asset)
	else:
		assets.call("set_texture", texture_id, texture_asset)


func _set_mesh_asset(assets: Resource, mesh_id: int, mesh_asset: Resource) -> void:
	assets.call("set_mesh_asset", mesh_id, mesh_asset)


func _world_height(x: float, z: float) -> float:
	var field := _land_field(x, z)
	var coast := smoothstep(-0.11, 0.075, field)
	if coast <= 0.001:
		return -2.6 + sin(x * 0.17) * cos(z * 0.19) * 0.12

	var east := clampf((x + 15.0) / 30.0, 0.0, 1.0)
	var north := clampf((-z + 10.0) / 20.0, 0.0, 1.0)
	var broad_relief := _terrain_noise(x * 0.52, z * 0.52) * 0.22
	var land_height := 0.48 + east * 0.38 + north * 0.58 + broad_relief

	# Loand's protected fertile basin and Datt's broad, buildable transport plain.
	var loand_basin := _gaussian(x, z, -5.2, -0.6, 4.5, 3.2)
	land_height = lerpf(land_height, 0.64 + _terrain_noise(x * 0.8, z * 0.8) * 0.08, loand_basin * 0.52)
	var datt_plain := _gaussian(x, z, 3.9, -1.4, 3.8, 2.7)
	land_height = lerpf(land_height, 0.82, datt_plain * 0.72)

	# Continuous ridges make the main ranges legible at continent scale.
	var ridge_detail := 0.70 + absf(_terrain_noise(x * 1.35, z * 1.35)) * 0.46
	var heren_ridge := _ridge_mask(Vector2(x, z), [Vector2(1.4, -6.8), Vector2(4.5, -7.8), Vector2(8.2, -7.2), Vector2(11.8, -5.8)], 0.82)
	var loand_crown := _ridge_mask(Vector2(x, z), [Vector2(-8.8, -3.5), Vector2(-6.1, -4.8), Vector2(-3.1, -4.5), Vector2(-1.1, -3.4)], 0.68)
	var eastern_spine := _ridge_mask(Vector2(x, z), [Vector2(11.7, -5.1), Vector2(12.4, -2.9), Vector2(12.1, -0.4), Vector2(11.4, 1.2)], 0.58)
	var heren_peaks := 0.58 + pow(absf(sin(x * 0.92 + z * 0.18)), 1.7) * 0.52
	land_height += heren_ridge * 12.2 * ridge_detail * heren_peaks
	land_height += loand_crown * 8.0 * ridge_detail
	land_height += eastern_spine * 5.4 * ridge_detail
	for peak in [Vector4(2.4, -7.1, 0.54, 4.1), Vector4(5.7, -7.7, 0.50, 5.3), Vector4(8.7, -6.9, 0.54, 5.8), Vector4(-6.0, -4.7, 0.50, 3.5), Vector4(-3.2, -4.4, 0.48, 3.0)]:
		land_height += _gaussian(x, z, peak.x, peak.y, peak.z, peak.z) * peak.w
	var heren_inner_spur := _ridge_mask(Vector2(x, z), [Vector2(2.0, -6.1), Vector2(4.0, -5.1), Vector2(5.8, -3.9)], 0.54)
	var loand_west_spur := _ridge_mask(Vector2(x, z), [Vector2(-10.0, -3.0), Vector2(-10.7, -1.0), Vector2(-9.0, 0.9)], 0.58)
	land_height += heren_inner_spur * 3.2 * ridge_detail
	land_height += loand_west_spur * 2.4 * ridge_detail

	# This escarpment keeps Datt from cheaply absorbing the distant southern belt.
	var barrier := _ridge_mask(Vector2(x, z), [Vector2(-7.8, 3.8), Vector2(-3.8, 4.2), Vector2(0.2, 3.7), Vector2(4.3, 4.1), Vector2(8.0, 3.6)], 0.66)
	var pass_factor := 1.0
	for pass_x in [-4.2, 1.7, 7.3]:
		pass_factor *= 1.0 - _gaussian(x, z, pass_x, 3.85, 0.52, 0.68) * 0.86
	land_height += barrier * pass_factor * 7.0 * ridge_detail
	var southern_spurs := maxf(
		_ridge_mask(Vector2(x, z), [Vector2(-5.8, 4.0), Vector2(-4.6, 5.0), Vector2(-4.0, 6.2)], 0.50),
		_ridge_mask(Vector2(x, z), [Vector2(4.8, 4.0), Vector2(5.9, 5.0), Vector2(6.5, 6.1)], 0.50)
	)
	land_height += southern_spurs * 2.2 * ridge_detail
	var mountain_detail_mask := maxf(heren_ridge, maxf(loand_crown, maxf(barrier, maxf(heren_inner_spur, loand_west_spur))))
	land_height += mountain_detail_mask * absf(_terrain_noise(x * 3.1 + 1.0, z * 3.1 - 2.0)) * 0.46
	land_height += smoothstep(4.2, 7.8, z) * 0.76
	var dune_field := smoothstep(4.6, 7.4, z) * (1.0 - eastern_spine)
	land_height += dune_field * (sin(x * 2.15 + z * 0.52) + sin(x * 1.08 - z * 1.34)) * 0.09

	# Natural river valleys remain below the surrounding relief.
	land_height = _carve_valley(land_height, Vector2(x, z), LOAND_RIVER, 0.42, 0.58)
	land_height = _carve_valley(land_height, Vector2(x, z), HEREN_RIVER, 0.38, 0.62)
	land_height = _carve_valley(land_height, Vector2(x, z), SOUTHERN_RIVER, 0.40, 0.70)
	land_height = _carve_valley(land_height, Vector2(x, z), LOAND_WEST_TRIBUTARY, 0.24, 0.34)
	land_height = _carve_valley(land_height, Vector2(x, z), LOAND_NORTH_TRIBUTARY, 0.22, 0.31)
	land_height = _carve_valley(land_height, Vector2(x, z), HEREN_EAST_TRIBUTARY, 0.22, 0.34)

	# The later engineered canals cross inside Datt; they are narrow and shallow here.
	var north_south := _distance_to_segment(Vector2(x, z), Vector2(3.9, -5.2), Vector2(3.9, 1.1))
	var west_east := _distance_to_polyline(Vector2(x, z), [Vector2(-3.8, -1.4), Vector2(3.9, -1.4), Vector2(7.4, -1.1), Vector2(10.5, 0.2)])
	var canal_blend := maxf(exp(-pow(north_south / 0.15, 2.0)), exp(-pow(west_east / 0.15, 2.0)))
	land_height = lerpf(land_height, -0.06, canal_blend * 0.97)

	# Three distinct inland lakes: a western basin lake, a Datt-border lake, and a southern salt lake.
	var lake_mask := maxf(
		_gaussian(x, z, -1.7, -0.7, 1.25, 0.72),
		maxf(_gaussian(x, z, 6.8, 1.8, 0.95, 0.62), _gaussian(x, z, -2.3, 6.5, 1.35, 0.78))
	)
	land_height = lerpf(land_height, -0.08, smoothstep(0.30, 0.72, lake_mask))

	# The southern federation is a low, fertile island chain beyond a navigable strait.
	var archipelago := smoothstep(-0.08, 0.20, _southern_archipelago_field(x, z))
	var island_relief := 0.54 + _terrain_noise(x * 1.15 + 4.0, z * 1.15) * 0.13
	land_height = lerpf(land_height, island_relief, archipelago * 0.94)

	var detail := _terrain_noise(x * 1.65, z * 1.65) * 0.09
	land_height += detail * clampf((land_height - 0.35) / 2.8, 0.0, 1.0)
	return lerpf(-2.6, land_height, coast)


func _land_field(x: float, z: float) -> float:
	var nx := x / 14.5
	var nz := (z + 0.25) / 9.5
	var angle := atan2(nz, nx)
	var coast_waves := sin(angle * 5.0 + 0.7) * 0.095 + sin(angle * 9.0 - 1.1) * 0.055
	coast_waves += _terrain_noise(x * 0.82, z * 0.82) * 0.065
	var mainland := 1.0 - (pow(absf(nx), 2.18) + pow(absf(nz), 2.02)) + coast_waves

	# Headlands and coastal bights break the silhouette without changing the political layout.
	mainland += _gaussian(x, z, -11.8, -4.7, 3.2, 2.0) * 0.22
	mainland += _gaussian(x, z, 9.8, -5.2, 3.1, 2.2) * 0.18
	mainland += _gaussian(x, z, -10.6, 5.2, 2.7, 1.9) * 0.17
	mainland -= _gaussian(x, z, -13.2, 0.5, 2.5, 2.7) * 0.78
	mainland -= _gaussian(x, z, -9.8, 7.4, 2.0, 1.7) * 0.42
	mainland -= _gaussian(x, z, 6.0, 7.8, 3.0, 2.0) * 0.72
	mainland -= _gaussian(x, z, 13.4, -0.8, 1.8, 2.0) * 0.46
	mainland -= _gaussian(x, z, 13.4, 2.5, 2.1, 2.6) * 0.50

	var north_crown := 1.0 - (pow((x - 4.2) / 10.2, 2.0) + pow((z + 7.5) / 3.1, 2.0))
	var mainland_shape := maxf(mainland, north_crown * 0.82)
	# Keep an open sea channel between the continent and the southern island federation.
	mainland_shape -= _gaussian(x, z, 5.7, 8.5, 6.7, 1.35) * 0.70
	return maxf(mainland_shape, _southern_archipelago_field(x, z))


func _southern_archipelago_field(x: float, z: float) -> float:
	var field := -INF
	var islands := [
		Vector4(-7.1, 11.0, 2.05, 1.12),
		Vector4(-2.9, 12.0, 1.55, 0.92),
		Vector4(1.2, 11.2, 2.25, 1.22),
		Vector4(5.6, 12.2, 1.75, 1.00),
		Vector4(9.5, 11.0, 1.88, 1.08),
		Vector4(12.8, 12.8, 1.18, 0.72),
		Vector4(-5.0, 14.0, 1.12, 0.66),
		Vector4(3.0, 14.4, 1.28, 0.72),
		Vector4(8.0, 14.3, 0.92, 0.56),
	]
	for island in islands:
		var offset := Vector2((x - island.x) / island.z, (z - island.y) / island.w)
		var island_field := 1.0 - pow(offset.length(), 2.0)
		island_field += _terrain_noise(x * 1.8 + island.x, z * 1.8) * 0.08
		field = maxf(field, island_field)
	return field


func _world_color(x: float, z: float, height: float) -> Color:
	if height < 0.05:
		return Color("#2d7180")
	var color := Color("#5d8d49")
	var loand_forest := _gaussian(x, z, -6.0, -0.8, 5.0, 3.4)
	var west_forest := _gaussian(x, z, -10.5, 2.8, 2.8, 2.4)
	var forest_pattern := smoothstep(-0.28, 0.42, _terrain_noise(x * 1.32 + 2.0, z * 1.32 - 1.0))
	var forest := maxf(loand_forest * 0.92, west_forest) * (0.52 + forest_pattern * 0.48)
	color = color.lerp(Color("#245b38"), forest * 0.88)

	var datt_plain := _gaussian(x, z, 3.8, -1.3, 4.6, 3.0)
	color = color.lerp(Color("#729a50"), datt_plain * 0.74)
	var south_dryness := smoothstep(2.8, 7.0, z) * (1.0 - _gaussian(x, z, 10.5, 4.2, 3.2, 2.8) * 0.5)
	color = color.lerp(Color("#b9843f"), south_dryness * 0.92)
	var dunes := south_dryness * (sin(x * 2.15 + z * 0.52) * 0.5 + 0.5)
	color = color.lerp(Color("#d2a552"), dunes * 0.20)
	var archipelago := smoothstep(-0.06, 0.20, _southern_archipelago_field(x, z))
	color = color.lerp(Color("#558c58"), archipelago * 0.96)

	var heren_coast := _gaussian(x, z, 10.7, -3.4, 2.2, 2.4)
	color = color.lerp(Color("#4c7854"), heren_coast * 0.54)
	var northern_cold := smoothstep(4.8, 8.8, -z)
	color = color.lerp(Color("#778e83"), northern_cold * 0.30)
	var exposed_rock := smoothstep(2.2, 4.7, height)
	color = color.lerp(Color("#5c6462"), exposed_rock * 0.86)
	var snow := _snow_mask(z, height)
	color = color.lerp(Color("#e2ebe5"), snow)
	# Slow painterly color drift keeps the terrain soft at the campaign-map scale.
	var variation := _terrain_noise(x * 0.62, z * 0.62) * 0.026
	return color.lightened(maxf(variation, 0.0)).darkened(maxf(-variation, 0.0))


func _world_control(x: float, z: float, height: float) -> Color:
	var base_id := TEXTURE_GRASS
	var overlay_id := TEXTURE_FOREST
	var blend := 0.0
	if height < 0.05:
		base_id = TEXTURE_ROCK
		overlay_id = TEXTURE_ROCK
	else:
		var loand_forest := _gaussian(x, z, -6.0, -0.8, 5.0, 3.4)
		var west_forest := _gaussian(x, z, -10.5, 2.8, 2.8, 2.4)
		blend = clampf(maxf(loand_forest * 0.92, west_forest), 0.0, 0.92)
		var desert := smoothstep(2.8, 7.0, z)
		if desert > 0.05:
			overlay_id = TEXTURE_SAND
			blend = desert
		var archipelago := smoothstep(-0.06, 0.20, _southern_archipelago_field(x, z))
		if archipelago > 0.05:
			base_id = TEXTURE_GRASS
			overlay_id = TEXTURE_FOREST
			blend = archipelago * 0.28
		var rock := smoothstep(1.85, 3.75, height)
		if rock > 0.05:
			overlay_id = TEXTURE_ROCK
			blend = rock
		var snow := _snow_mask(z, height)
		if snow > 0.05:
			base_id = TEXTURE_ROCK
			overlay_id = TEXTURE_SNOW
			blend = snow
	var bits := Terrain3DUtil.enc_base(base_id)
	bits |= Terrain3DUtil.enc_overlay(overlay_id)
	bits |= Terrain3DUtil.enc_blend(roundi(clampf(blend, 0.0, 1.0) * 255.0))
	return Color(Terrain3DUtil.as_float(bits), 0.0, 0.0, 1.0)


func _snow_mask(z: float, height: float) -> float:
	var northern_latitude := smoothstep(5.4, 7.2, -z)
	var high_peak := smoothstep(10.0, 14.2, height)
	return northern_latitude * high_peak


func _carve_valley(height: float, point: Vector2, polyline: Array, width: float, depth: float) -> float:
	var distance := _distance_to_polyline(point, polyline)
	var influence := exp(-pow(distance / width, 2.0))
	var valley_height := height - influence * depth
	return lerpf(valley_height, -0.055, influence * 0.92)


func _ridge_mask(point: Vector2, polyline: Array, width: float) -> float:
	var distance := _distance_to_polyline(point, polyline)
	return exp(-pow(distance / width, 2.0))


func _terrain_noise(x: float, z: float) -> float:
	return (
		sin(x * 0.73 + z * 0.29)
		+ cos(z * 1.11 - x * 0.41) * 0.58
		+ sin((x + z) * 2.03) * 0.24
	) / 1.82


func _distance_to_polyline(point: Vector2, polyline: Array) -> float:
	var distance := INF
	for i in range(polyline.size() - 1):
		distance = minf(distance, _distance_to_segment(point, polyline[i], polyline[i + 1]))
	return distance


func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment := finish - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.000001:
		return point.distance_to(start)
	var t := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * t)


func _gaussian(x: float, z: float, center_x: float, center_z: float, radius_x: float, radius_z: float) -> float:
	return exp(-(pow((x - center_x) / radius_x, 2.0) + pow((z - center_z) / radius_z, 2.0)))
