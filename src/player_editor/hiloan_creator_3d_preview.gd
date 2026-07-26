extends Control
class_name HiloanCreator3DPreview

const MESH_ROOT = "res://assets/creator/hiloan_3d/meshes/"
const TEXTURE_ROOT = "res://assets/creator/hiloan_3d/textures/"
const OUTFIT_TEXTURES = {
	"formal_suit": ["academy_robe_detail.png", ""],
	"field_suit": ["field_uniform_detail.png", ""],
	"travel_suit": ["coastal_tunic_detail.png", ""],
}
const SHOE_TEXTURES = {
	"travel_shoes": "travel_shoes_detail.png",
	"low_shoes": "low_shoes_detail.png",
	"travel_boots": "travel_boots_detail.png",
}
const HAIR_TEXTURES = {
	"short_hair": ["hair_short_detail.png", ""],
	"close_crop": ["hair_crop_detail.png", "hair_crop_normal.png"],
	"side_swept": ["hair_swept_detail.png", ""],
}
const BROW_TEXTURES = {
	"eyebrow_natural": "eyebrow_natural_detail.png",
	"eyebrow_arched": "eyebrow_arched_detail.png",
	"eyebrow_full": "eyebrow_full_detail.png",
}
const SKIN_COLORS = {
	"fair": Color("#e8bea0"),
	"warm": Color("#c98f69"),
	"tan": Color("#a66d4d"),
	"deep": Color("#704735"),
}
const HAIR_COLORS = {
	"black": Color("#201b1c"),
	"brown": Color("#5b3928"),
	"silver": Color("#aaa8a4"),
	"auburn": Color("#783424"),
}
const EYE_COLORS = {
	"brown": Color("#5a3924"),
	"blue": Color("#3d789d"),
	"green": Color("#48755b"),
	"amber": Color("#a16e2b"),
}
const LIP_COLORS = {
	"natural": Color("#89534e"),
	"rose": Color("#a85d68"),
	"muted": Color("#724c52"),
}
const CLOTHES_COLORS = {
	"navy": Color("#263f55"),
	"forest": Color("#2f5141"),
	"burgundy": Color("#5d3038"),
	"charcoal": Color("#35383d"),
}
const SHOE_COLORS = {
	"dark_brown": Color("#3d2b22"),
	"black": Color("#252326"),
	"tan": Color("#8a6040"),
}
const FRAME_COLORS = {
	"brass": Color("#a97935"),
	"silver": Color("#9fa4a8"),
	"black": Color("#232427"),
}
const FOCUS_CAMERA = {
	"Body": [Vector3(0.0, 0.0, 4.05), Vector3(0.0, 0.0, 0.0)],
	"Face": [Vector3(0.0, 0.79, 0.78), Vector3(0.0, 0.79, 0.0)],
	"Hair": [Vector3(0.0, 0.76, 0.88), Vector3(0.0, 0.76, 0.0)],
	"Outfit": [Vector3(0.0, 0.0, 4.05), Vector3(0.0, 0.0, 0.0)],
	"Extras": [Vector3(0.0, 0.54, 1.45), Vector3(0.0, 0.54, 0.0)],
}

var _hero: Dictionary = {}
var _focus := "Body"
var _viewport: SubViewport
var _viewport_container: SubViewportContainer
var _avatar: CharacterBody3D
var _camera: Camera3D
var _body_mesh: MeshInstance3D
var _morph_meshes: Array[MeshInstance3D] = []
var _yaw := 0.0
var _dragging := false
var _camera_distance_scale := 1.0


func _ready() -> void:
	set_process_input(true)
	_build_viewport()
	_rebuild_character()
	_apply_focus()


func set_hero(hero: Dictionary) -> void:
	_hero = hero.duplicate(true)
	if is_inside_tree():
		_rebuild_character()


func set_focus(page: String) -> void:
	_focus = page
	if is_inside_tree():
		_apply_focus()


func _build_viewport() -> void:
	_viewport_container = SubViewportContainer.new()
	_viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport_container.stretch = true
	_viewport_container.mouse_filter = Control.MOUSE_FILTER_STOP
	_viewport_container.gui_input.connect(_on_preview_input)
	add_child(_viewport_container)

	_viewport = SubViewport.new()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport_container.add_child(_viewport)

	var environment_node = WorldEnvironment.new()
	var environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#20252a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#dce4e8")
	environment.ambient_light_energy = 0.36
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	_viewport.add_child(environment_node)

	var key_light = DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-28.0, -32.0, 0.0)
	key_light.light_color = Color("#fff2dc")
	key_light.light_energy = 1.48
	key_light.shadow_enabled = true
	_viewport.add_child(key_light)

	var rim_light = DirectionalLight3D.new()
	rim_light.rotation_degrees = Vector3(-12.0, 145.0, 0.0)
	rim_light.light_color = Color("#b9d8e5")
	rim_light.light_energy = 0.46
	_viewport.add_child(rim_light)

	_avatar = CharacterBody3D.new()
	_avatar.name = "CreatorCharacter"
	_viewport.add_child(_avatar)

	var floor = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(2.7, 2.7)
	floor.mesh = plane
	floor.position.y = -0.845
	floor.material_override = _make_material(Color("#343b3f"), 0.92)
	_viewport.add_child(floor)

	_camera = Camera3D.new()
	_camera.fov = 28.0
	_camera.current = true
	_viewport.add_child(_camera)


func _rebuild_character() -> void:
	if _avatar == null or _hero.is_empty():
		return
	for child in _avatar.get_children():
		_avatar.remove_child(child)
		child.queue_free()
	_body_mesh = null
	_morph_meshes.clear()

	var creator: Dictionary = HeroData.normalize_creator_data(_hero.get("creator", {}))
	var body_type := str(creator.get("body_type", "lean"))
	var outfit_style := str(creator.get("clothes_style", "none"))
	var has_outfit := outfit_style != "none"
	var has_shoes := str(creator.get("shoes_style", "none")) != "none"
	var mask := "plain"
	if has_outfit and has_shoes:
		mask = outfit_style + "_shoes"
	elif has_outfit:
		mask = outfit_style
	elif has_shoes:
		mask = "shoes"

	var body_scene = _instantiate_model(MESH_ROOT + body_type + "/body_" + mask + ".glb")
	if body_scene == null:
		return
	_avatar.add_child(body_scene)
	for mesh_instance in _mesh_instances(body_scene):
		match str(mesh_instance.name):
			"Body":
				_body_mesh = mesh_instance
				_morph_meshes.append(mesh_instance)
				mesh_instance.material_override = _make_skin_material(
					SKIN_COLORS.get(str(creator.get("skin_tone", "warm")), SKIN_COLORS["warm"]),
					LIP_COLORS.get(str(creator.get("lip_color", "natural")), LIP_COLORS["natural"])
				)
			"EyeWhites":
				_morph_meshes.append(mesh_instance)
				mesh_instance.material_override = _make_material(Color("#f0ebe3"), 0.38)
			"Eyelashes":
				_morph_meshes.append(mesh_instance)
				mesh_instance.material_override = _make_alpha_material(
					Color("#35231f"),
					"eyelash_detail.png",
					0.92
				)

	_apply_face_morphs(creator)
	_add_irises(creator)
	_add_eyebrows(creator, body_type)

	if not has_outfit:
		var underwear = _instantiate_model(MESH_ROOT + body_type + "/underwear.glb")
		if underwear != null:
			_avatar.add_child(underwear)
			_set_model_material(underwear, _make_underwear_material())

	if str(creator.get("hair_style", "none")) != "none":
		var hair_style := str(creator.get("hair_style", "short_hair"))
		var hair = _instantiate_model(MESH_ROOT + body_type + "/" + hair_style + ".glb")
		if hair != null:
			_avatar.add_child(hair)
			_set_hair_materials(
				hair,
				_make_hair_material(
					hair_style,
					HAIR_COLORS.get(str(creator.get("hair_color", "black")), HAIR_COLORS["black"])
				),
				_make_material(
					HAIR_COLORS.get(
						str(creator.get("hair_color", "black")),
						HAIR_COLORS["black"]
					).lightened(0.16),
					0.84
				)
			)

	if has_outfit:
		var outfit = _instantiate_model(MESH_ROOT + body_type + "/" + outfit_style + ".glb")
		if outfit != null:
			_avatar.add_child(outfit)
			_set_outfit_materials(
				outfit,
				outfit_style,
				CLOTHES_COLORS.get(str(creator.get("clothes_color", "navy")), CLOTHES_COLORS["navy"])
			)

	if has_shoes:
		var shoe_style := str(creator.get("shoes_style", "travel_shoes"))
		var shoe_file := shoe_style + "_tucked.glb" if has_outfit else shoe_style + ".glb"
		var shoes = _instantiate_model(MESH_ROOT + body_type + "/" + shoe_file)
		if shoes != null:
			_avatar.add_child(shoes)
			_set_model_material(
				shoes,
				_make_textured_tint_material(
					SHOE_COLORS.get(str(creator.get("shoes_color", "dark_brown")), SHOE_COLORS["dark_brown"]),
					str(SHOE_TEXTURES.get(shoe_style, "travel_shoes_detail.png")),
					0.84
				)
			)

	_add_accessory_model(creator, body_type)
	_add_glasses(creator, body_type)
	_avatar.rotation.y = _yaw


func _apply_face_morphs(creator: Dictionary) -> void:
	if _body_mesh == null or _body_mesh.mesh == null:
		return
	var requested = [
		"face_" + str(creator.get("face_shape", "oval")),
		"ears_pointed" if str(creator.get("ears_style", "natural")) == "slightly_pointed" else "",
		"eyes_" + str(creator.get("eyes_style", "soft")),
		"nose_" + str(creator.get("nose_style", "straight")),
		"mouth_" + str(creator.get("mouth_style", "neutral")),
	]
	for morph_mesh in _morph_meshes:
		for index in morph_mesh.mesh.get_blend_shape_count():
			var blend_name := str(morph_mesh.mesh.get_blend_shape_name(index))
			morph_mesh.set_blend_shape_value(index, 1.0 if blend_name in requested else 0.0)


func _add_irises(creator: Dictionary) -> void:
	var eye_color: Color = EYE_COLORS.get(str(creator.get("eye_color", "brown")), EYE_COLORS["brown"])
	var eye_style := str(creator.get("eyes_style", "soft"))
	var radius := 0.0058
	var vertical_scale := 0.92
	var eye_y := 0.8207
	match eye_style:
		"narrow":
			radius = 0.0054
			vertical_scale = 0.78
			eye_y = 0.8202
		"tired":
			radius = 0.0056
			vertical_scale = 0.84
			eye_y = 0.8198
	for x in [-0.0293, 0.0293]:
		_add_eye_disc(
			"LimbalRing",
			Vector3(x, eye_y, 0.1457),
			radius * 1.08,
			vertical_scale,
			Color("#282027"),
			0.48
		)
		var iris = MeshInstance3D.new()
		iris.name = "IrisLeft" if x < 0.0 else "IrisRight"
		var iris_mesh = CylinderMesh.new()
		iris_mesh.top_radius = radius
		iris_mesh.bottom_radius = radius
		iris_mesh.height = 0.0011
		iris_mesh.radial_segments = 24
		iris.mesh = iris_mesh
		iris.rotation.x = PI * 0.5
		iris.scale.z = vertical_scale
		iris.position = Vector3(x, eye_y, 0.1464)
		iris.material_override = _make_material(eye_color, 0.42)
		_avatar.add_child(iris)

		var pupil = MeshInstance3D.new()
		pupil.name = "PupilLeft" if x < 0.0 else "PupilRight"
		var pupil_mesh = CylinderMesh.new()
		pupil_mesh.top_radius = radius * 0.4
		pupil_mesh.bottom_radius = radius * 0.4
		pupil_mesh.height = 0.0012
		pupil_mesh.radial_segments = 20
		pupil.mesh = pupil_mesh
		pupil.rotation.x = PI * 0.5
		pupil.scale.z = vertical_scale
		pupil.position = Vector3(x, eye_y, 0.1471)
		pupil.material_override = _make_material(Color("#151318"), 0.48)
		_avatar.add_child(pupil)
		_add_eye_disc(
			"EyeCatchlight",
			Vector3(x - 0.0015, eye_y + 0.0017, 0.1478),
			radius * 0.17,
			vertical_scale,
			Color("#f8f4eb"),
			0.18
		)


func _add_eye_disc(
	node_name: String,
	position_3d: Vector3,
	radius: float,
	vertical_scale: float,
	color: Color,
	roughness: float
) -> void:
	var disc = MeshInstance3D.new()
	disc.name = node_name
	var disc_mesh = CylinderMesh.new()
	disc_mesh.top_radius = radius
	disc_mesh.bottom_radius = radius
	disc_mesh.height = 0.0007
	disc_mesh.radial_segments = 24
	disc.mesh = disc_mesh
	disc.rotation.x = PI * 0.5
	disc.scale.z = vertical_scale
	disc.position = position_3d
	disc.material_override = _make_material(color, roughness)
	_avatar.add_child(disc)


func _add_eyebrows(creator: Dictionary, body_type: String) -> void:
	var style := str(creator.get("eyebrow_style", "eyebrow_natural"))
	if style == "none":
		return
	var eyebrows = _instantiate_model(MESH_ROOT + body_type + "/" + style + ".glb")
	if eyebrows == null:
		return
	eyebrows.name = "Eyebrows"
	_avatar.add_child(eyebrows)
	var color: Color = HAIR_COLORS.get(
		str(creator.get("eyebrow_color", "black")),
		HAIR_COLORS["black"]
	)
	var eyebrow_material = _make_alpha_material(
		color.lightened(0.12),
		str(BROW_TEXTURES.get(style, "eyebrow_natural_detail.png")),
		0.92
	)
	_set_model_material(eyebrows, eyebrow_material)


func _add_glasses(creator: Dictionary, body_type: String) -> void:
	var style := str(creator.get("glasses_style", "none"))
	if style == "none":
		return
	var asset_style := "angular" if style == "rectangular" else style
	var frame_color: Color = FRAME_COLORS.get(
		str(creator.get("glasses_color", "brass")),
		FRAME_COLORS["brass"]
	)
	var glasses = _instantiate_model(MESH_ROOT + body_type + "/glasses_" + asset_style + ".glb")
	if glasses == null:
		return
	glasses.name = "Glasses"
	_avatar.add_child(glasses)
	_set_model_material(glasses, _make_material(frame_color, 0.34, 0.62))


func _add_accessory_model(creator: Dictionary, body_type: String) -> void:
	var style := str(creator.get("accessory_style", "none"))
	if style == "none":
		return
	var accessory = _instantiate_model(MESH_ROOT + body_type + "/" + style + ".glb")
	if accessory == null:
		return
	accessory.name = "AccessoryDetails"
	_avatar.add_child(accessory)
	var color: Color = FRAME_COLORS.get(
		str(creator.get("accessory_color", "brass")),
		FRAME_COLORS["brass"]
	)
	var roughness := 0.9 if style == "scarf" else 0.38
	var metallic := 0.0 if style == "scarf" else 0.55
	_set_model_material(accessory, _make_material(color, roughness, metallic))


func _add_frame_bar(
	position_3d: Vector3,
	box_size: Vector3,
	frame_material: StandardMaterial3D,
	rotation_3d: Vector3 = Vector3.ZERO
) -> void:
	var bar = MeshInstance3D.new()
	bar.name = "GlassesFrame"
	var box = BoxMesh.new()
	box.size = box_size
	bar.mesh = box
	bar.position = position_3d
	bar.rotation = rotation_3d
	bar.material_override = frame_material
	_avatar.add_child(bar)


func _add_frame_rod(
	start: Vector3,
	end: Vector3,
	radius: float,
	frame_material: StandardMaterial3D
) -> void:
	var delta := end - start
	var rod = MeshInstance3D.new()
	rod.name = "GlassesTemple"
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = delta.length()
	cylinder.radial_segments = 12
	rod.mesh = cylinder
	rod.position = (start + end) * 0.5
	rod.quaternion = Quaternion(Vector3.UP, delta.normalized())
	rod.material_override = frame_material
	_avatar.add_child(rod)


func _instantiate_model(path: String) -> Node3D:
	var resource = load(path)
	if resource is PackedScene:
		return resource.instantiate()
	return null


func _mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		result.append(root)
	for child in root.get_children():
		result.append_array(_mesh_instances(child))
	return result


func _set_model_material(root: Node, value: StandardMaterial3D) -> void:
	for mesh_instance in _mesh_instances(root):
		mesh_instance.material_override = value


func _set_hair_materials(
	root: Node,
	strand_material: StandardMaterial3D,
	cap_material: StandardMaterial3D
) -> void:
	for mesh_instance in _mesh_instances(root):
		mesh_instance.material_override = (
			cap_material
			if "HairCap" in str(mesh_instance.name)
			else strand_material
		)


func _set_outfit_materials(root: Node, style: String, color: Color) -> void:
	for mesh_instance in _mesh_instances(root):
		var texture_name := ""
		var material_color := color
		var material_roughness := 0.9
		if style == "field_suit" and "Underlayer" in str(mesh_instance.name):
			texture_name = "underwear_detail.png"
			material_color = color.darkened(0.18)
			material_roughness = 0.96
		elif style == "travel_suit" and "Pants" in str(mesh_instance.name):
			texture_name = "coastal_pants_detail.png"
		else:
			var texture_files: Array = OUTFIT_TEXTURES.get(style, [])
			if not texture_files.is_empty():
				texture_name = str(texture_files[0])
		mesh_instance.material_override = _make_textured_tint_material(
			material_color,
			texture_name,
			material_roughness
		)


func _make_material(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var value = StandardMaterial3D.new()
	value.albedo_color = color
	value.roughness = roughness
	value.metallic = metallic
	return value


func _make_textured_tint_material(
	color: Color,
	texture_file: String,
	roughness: float
) -> StandardMaterial3D:
	var value = _make_material(color.lightened(0.16), roughness)
	if texture_file != "":
		var detail_texture = load(TEXTURE_ROOT + texture_file)
		if detail_texture is Texture2D:
			value.albedo_texture = detail_texture
	value.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return value


func _make_skin_material(color: Color, lip_color: Color) -> ShaderMaterial:
	var shader = Shader.new()
	shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 skin_color : source_color;
uniform vec4 lip_color : source_color;
uniform sampler2D skin_detail : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D skin_normal : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D skin_roughness : hint_default_white, filter_linear_mipmap_anisotropic;
uniform sampler2D lip_mask : hint_default_black, filter_linear_mipmap_anisotropic;
uniform sampler2D lip_detail : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D lip_normal : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D lip_roughness : hint_default_white, filter_linear_mipmap_anisotropic;
void fragment() {
	float mask = texture(lip_mask, UV).r;
	vec3 skin_albedo = skin_color.rgb * texture(skin_detail, UV).rgb;
	vec3 lip_albedo = lip_color.rgb * texture(lip_detail, UV).rgb;
	ALBEDO = mix(skin_albedo, lip_albedo, mask);
	NORMAL_MAP = mix(texture(skin_normal, UV).rgb, texture(lip_normal, UV).rgb, mask);
	NORMAL_MAP_DEPTH = mix(0.18, 0.24, mask);
	ROUGHNESS = mix(texture(skin_roughness, UV).r, texture(lip_roughness, UV).r, mask);
	SPECULAR = mix(0.18, 0.42, mask);
}
"""
	var value = ShaderMaterial.new()
	value.shader = shader
	value.set_shader_parameter("skin_color", color)
	value.set_shader_parameter("lip_color", lip_color)
	value.set_shader_parameter("skin_detail", load(TEXTURE_ROOT + "skin_detail.png"))
	value.set_shader_parameter("skin_normal", load(TEXTURE_ROOT + "skin_normal.png"))
	value.set_shader_parameter("skin_roughness", load(TEXTURE_ROOT + "skin_roughness.png"))
	value.set_shader_parameter("lip_mask", load(TEXTURE_ROOT + "lip_mask.png"))
	value.set_shader_parameter("lip_detail", load(TEXTURE_ROOT + "lip_detail.png"))
	value.set_shader_parameter("lip_normal", load(TEXTURE_ROOT + "lip_normal.png"))
	value.set_shader_parameter("lip_roughness", load(TEXTURE_ROOT + "lip_roughness.png"))
	return value


func _make_lip_material(color: Color) -> StandardMaterial3D:
	var value = _make_material(color, 0.44)
	var detail_texture = load(TEXTURE_ROOT + "lip_detail.png")
	var normal_texture = load(TEXTURE_ROOT + "lip_normal.png")
	var roughness_texture = load(TEXTURE_ROOT + "lip_roughness.png")
	if detail_texture is Texture2D:
		value.albedo_texture = detail_texture
	if normal_texture is Texture2D:
		value.normal_enabled = true
		value.normal_texture = normal_texture
		value.normal_scale = 0.24
	if roughness_texture is Texture2D:
		value.roughness_texture = roughness_texture
	value.metallic_specular = 0.42
	value.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return value


func _make_underwear_material() -> StandardMaterial3D:
	var value = _make_material(Color("#343d42"), 0.84)
	var detail_texture = load(TEXTURE_ROOT + "underwear_detail.png")
	var normal_texture = load(TEXTURE_ROOT + "underwear_normal.png")
	if detail_texture is Texture2D:
		value.albedo_texture = detail_texture
	if normal_texture is Texture2D:
		value.normal_enabled = true
		value.normal_texture = normal_texture
		value.normal_scale = 0.28
	value.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return value


func _make_alpha_material(color: Color, texture_file: String, roughness: float) -> StandardMaterial3D:
	var value = _make_material(color, roughness)
	var detail_texture = load(TEXTURE_ROOT + texture_file)
	if detail_texture is Texture2D:
		value.albedo_texture = detail_texture
	value.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	value.alpha_scissor_threshold = 0.32
	value.cull_mode = BaseMaterial3D.CULL_DISABLED
	value.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return value


func _make_hair_material(style: String, color: Color) -> StandardMaterial3D:
	var texture_files: Array = HAIR_TEXTURES.get(style, [])
	if texture_files.is_empty():
		return _make_material(color, 0.82)
	var value = _make_alpha_material(color.lightened(0.16), str(texture_files[0]), 0.8)
	if texture_files.size() > 1 and str(texture_files[1]) != "":
		var normal_texture = load(TEXTURE_ROOT + str(texture_files[1]))
		if normal_texture is Texture2D:
			value.normal_enabled = true
			value.normal_texture = normal_texture
			value.normal_scale = 0.35
	return value


func _make_outfit_material(style: String, color: Color) -> StandardMaterial3D:
	var value = _make_material(color.lightened(0.32), 0.9)
	var texture_files: Array = OUTFIT_TEXTURES.get(style, [])
	if texture_files.size() != 2:
		return value
	var detail_texture = load(TEXTURE_ROOT + str(texture_files[0]))
	var normal_texture = load(TEXTURE_ROOT + str(texture_files[1]))
	if detail_texture is Texture2D:
		value.albedo_texture = detail_texture
		value.uv1_scale = Vector3.ONE
	if normal_texture is Texture2D:
		value.normal_enabled = true
		value.normal_texture = normal_texture
		value.normal_scale = 0.55
	value.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return value


func _apply_focus() -> void:
	if _camera == null:
		return
	var camera_data: Array = FOCUS_CAMERA.get(_focus, FOCUS_CAMERA["Body"])
	var position_3d: Vector3 = camera_data[0] * _camera_distance_scale
	var target: Vector3 = camera_data[1]
	if _focus in ["Face", "Hair"]:
		position_3d.y = target.y
	_camera.position = position_3d
	_camera.look_at(target, Vector3.UP)


func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera_distance_scale = maxf(0.72, _camera_distance_scale - 0.08)
			_apply_focus()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera_distance_scale = minf(1.35, _camera_distance_scale + 0.08)
			_apply_focus()
	elif event is InputEventMouseMotion and _dragging:
		_yaw += event.relative.x * 0.012
		_avatar.rotation.y = _yaw
