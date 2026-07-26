extends SceneTree

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)


func _run() -> void:
	await process_frame
	var hero = HeroData.create_hiloan_creator_hero("Creator3DSmokeTest")
	var editor = load("res://src/player_editor/character_editor.gd").new(hero)
	var layer = CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	layer.add_child(editor)
	for _frame in 12:
		await process_frame

	_check(editor._preview_instance is HiloanCreator3DPreview, "3D creator preview was not created")
	var preview: HiloanCreator3DPreview = editor._preview_instance
	_check(preview._avatar is CharacterBody3D, "Preview root is not CharacterBody3D")
	_check(preview._body_mesh != null, "Body MeshInstance3D was not loaded")
	if preview._body_mesh != null:
		_check(preview._body_mesh.mesh.get_blend_shape_count() == 12, "Unexpected face morph count")
		_check(_active_morph(preview) == "face_oval", "Default face shape morph is not active")
		var skin_material = preview._body_mesh.material_override as ShaderMaterial
		_check(skin_material != null, "Body skin/lip shader was not applied")
		if skin_material != null:
			_check(skin_material.get_shader_parameter("skin_detail") != null, "Body skin detail texture was not applied")
			_check(skin_material.get_shader_parameter("skin_normal") != null, "Body skin normal map was not applied")
			_check(skin_material.get_shader_parameter("lip_mask") != null, "Integrated lip mask was not applied")
	_check(not _has_model(preview._avatar, "Lips"), "Separate overlapping lip shell is still present")
	var eyelashes_node = _find_model(preview._avatar, "Eyelashes")
	var eyelashes_mesh = _first_mesh(eyelashes_node) if eyelashes_node != null else null
	if eyelashes_mesh != null:
		var eyelashes_material = eyelashes_mesh.material_override as StandardMaterial3D
		_check(
			eyelashes_material != null and eyelashes_material.albedo_texture != null,
			"Eyelash decal texture was not applied"
		)
		_check(
			eyelashes_material != null
			and eyelashes_material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR,
			"Eyelash alpha cutout is not enabled"
		)
	_check(editor._hero["creator"]["hair_style"] == "none", "New creator should start bald")
	_check(editor._hero["creator"]["clothes_style"] == "none", "New creator should start without clothes")
	_check(editor._hero["creator"]["shoes_style"] == "none", "New creator should start without shoes")
	_check(_has_model(preview._avatar, "Underwear"), "Unclothed body has no underwear coverage")
	_check(_has_model(preview._avatar, "UnderwearWaistband"), "Underwear has no modeled elastic waistband")
	_check(_has_model(preview._avatar, "Eyebrows"), "Default eyebrows were not attached")
	await _capture("/tmp/bombo_character_creator_3d_body.png")
	preview._yaw = 0.72
	preview._avatar.rotation.y = preview._yaw
	await _capture("/tmp/bombo_character_creator_3d_body_side.png")
	preview._yaw = PI
	preview._avatar.rotation.y = preview._yaw
	await _capture("/tmp/bombo_character_creator_3d_body_back.png")
	preview._yaw = 0.0
	preview._avatar.rotation.y = preview._yaw
	editor._ui._set_creator_page("Face")
	for _frame in 5:
		await process_frame
	await _capture("/tmp/bombo_character_creator_3d_face_default.png")
	preview._yaw = 0.72
	preview._avatar.rotation.y = preview._yaw
	await _capture("/tmp/bombo_character_creator_3d_face_default_side.png")
	preview._yaw = 0.0
	preview._avatar.rotation.y = preview._yaw

	editor._hero["creator"]["body_type"] = "standard"
	editor._ui._set_creator_page("Body")
	editor._render_preview()
	for _frame in 8:
		await process_frame
	await _capture("/tmp/bombo_character_creator_3d_body_standard.png")

	var original_preview = preview
	editor._hero["creator"].merge(
		{
			"body_type": "standard",
			"skin_tone": "deep",
			"face_shape": "angular",
			"ears_style": "slightly_pointed",
			"eyes_style": "narrow",
			"eye_color": "green",
			"eyebrow_style": "eyebrow_full",
			"eyebrow_color": "brown",
			"nose_style": "broad",
			"mouth_style": "firm",
			"hair_style": "short_hair",
			"hair_color": "silver",
			"glasses_style": "rectangular",
			"glasses_color": "black",
			"clothes_style": "travel_suit",
			"clothes_color": "charcoal",
			"shoes_style": "travel_shoes",
			"shoes_color": "black",
			"accessory_style": "belt_vial",
			"accessory_color": "silver",
		},
		true
	)
	editor._render_preview()
	for _frame in 12:
		await process_frame

	preview = editor._preview_instance
	_check(preview == original_preview, "Changing an option recreated the 3D viewport")
	_check(preview._body_mesh != null, "Changed body mesh was not loaded")
	if preview._body_mesh != null:
		var active = _active_morphs(preview)
		for expected in ["face_angular", "ears_pointed", "eyes_narrow", "nose_broad", "mouth_firm"]:
			_check(expected in active, "Morph was not applied: " + expected)
	_check(_has_model(preview._avatar, "CoastalTunic"), "3D tunic was not attached")
	_check(_has_model(preview._avatar, "CoastalPants"), "3D trousers were not attached")
	_check(_has_model(preview._avatar, "TravelShoes"), "3D shoes were not attached")
	_check(_has_model(preview._avatar, "ShortHair"), "3D hair was not attached")
	_check(_has_model(preview._avatar, "HairCap"), "3D hair has no fitted scalp cap")
	_check(_has_model(preview._avatar, "Eyebrows"), "Changed 3D eyebrows were not attached")
	_check(_has_model(preview._avatar, "IrisLeft"), "Left iris was not attached")
	_check(_has_model(preview._avatar, "IrisRight"), "Right iris was not attached")
	_check(_has_model(preview._avatar, "LimbalRing"), "Eyes have no modeled limbal ring")
	_check(_has_model(preview._avatar, "EyeCatchlight"), "Eyes have no catchlight")
	_check(_has_model(preview._avatar, "GlassesAngular"), "Fitted glasses asset was not attached")
	_check(not _has_model(preview._avatar, "OutfitDetails"), "Legacy geometric outfit details are still attached")
	_check(_has_model(preview._avatar, "AccessoryDetails"), "3D accessory details were not attached")
	_check(HeroData.list_creator_options("accessory_style").size() == 4, "Accessory options were not restored")
	_check(HeroData.list_creator_options("eyebrow_style").size() == 4, "Eyebrow options were not added")
	var hair_mesh = _first_mesh(_find_model(preview._avatar, "ShortHair"))
	if hair_mesh != null:
		var hair_material = hair_mesh.material_override as StandardMaterial3D
		_check(hair_material != null and hair_material.albedo_texture != null, "Hair strand texture was not applied")
		_check(
			hair_material != null and hair_material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR,
			"Hair alpha cutout is not enabled"
		)

	for outfit_case in [
		["travel_suit", "CoastalTunic"],
		["field_suit", "FrostfieldUniform"],
		["formal_suit", "AcademyRobe"],
	]:
		editor._hero["creator"]["clothes_style"] = outfit_case[0]
		editor._render_preview()
		for _frame in 4:
			await process_frame
		var outfit_node = _find_model(preview._avatar, outfit_case[1])
		_check(outfit_node != null, "3D outfit was not attached: " + outfit_case[0])
		var outfit_mesh = _first_mesh(outfit_node)
		_check(outfit_mesh != null, "3D outfit has no mesh: " + outfit_case[0])
		if outfit_mesh != null:
			var outfit_material = outfit_mesh.material_override as StandardMaterial3D
			_check(outfit_material != null, "3D outfit has no material: " + outfit_case[0])
			if outfit_material != null:
				_check(outfit_material.albedo_texture != null, "3D outfit has no detail texture: " + outfit_case[0])
		if outfit_case[0] == "field_suit":
			_check(
				_has_model(preview._avatar, "FrostfieldUnderlayer"),
				"Frostfield armor has no fitted cloth underlayer"
			)
		await _capture("/tmp/bombo_character_creator_3d_" + outfit_case[0] + ".png")

	editor._hero["creator"]["body_type"] = "lean"
	for outfit_case in [
		["travel_suit", "CoastalTunic"],
		["field_suit", "FrostfieldUniform"],
		["formal_suit", "AcademyRobe"],
	]:
		editor._hero["creator"]["clothes_style"] = outfit_case[0]
		editor._render_preview()
		for _frame in 4:
			await process_frame
		_check(
			_has_model(preview._avatar, outfit_case[1]),
			"Lean body outfit was not attached: " + outfit_case[0]
		)
		await _capture(
			"/tmp/bombo_character_creator_3d_lean_" + outfit_case[0] + ".png"
		)

	for accessory_style in ["pendant", "scarf", "belt_vial"]:
		editor._hero["creator"]["accessory_style"] = accessory_style
		editor._render_preview()
		for _frame in 4:
			await process_frame
		var accessory_node = _find_model(preview._avatar, "AccessoryDetails")
		_check(accessory_node != null, "3D accessory was not attached: " + accessory_style)
		if accessory_node != null:
			_check(accessory_node.get_child_count() >= 3, "3D accessory is missing modeled parts: " + accessory_style)

	editor._ui._set_creator_page("Face")
	for _frame in 5:
		await process_frame
	_check(preview._camera.position.y > 0.7, "Face page did not move the camera to the head")
	await _capture("/tmp/bombo_character_creator_3d_face.png")

	editor._ui._set_creator_page("Outfit")
	for _frame in 5:
		await process_frame
	await _capture("/tmp/bombo_character_creator_3d_outfit.png")

	preview._yaw = 0.72
	preview._avatar.rotation.y = preview._yaw
	await _capture("/tmp/bombo_character_creator_3d_outfit_side.png")

	if not _failed:
		print("CREATOR_3D_SMOKE_OK")
	quit(1 if _failed else 0)


func _active_morph(preview: HiloanCreator3DPreview) -> String:
	var active = _active_morphs(preview)
	return active[0] if not active.is_empty() else ""


func _active_morphs(preview: HiloanCreator3DPreview) -> Array[String]:
	var active: Array[String] = []
	for index in preview._body_mesh.mesh.get_blend_shape_count():
		if preview._body_mesh.get_blend_shape_value(index) > 0.5:
			active.append(str(preview._body_mesh.mesh.get_blend_shape_name(index)))
	return active


func _has_model(root_node: Node, model_name: String) -> bool:
	return _find_model(root_node, model_name) != null


func _find_model(root_node: Node, model_name: String) -> Node:
	if str(root_node.name) == model_name:
		return root_node
	for child in root_node.get_children():
		var found = _find_model(child, model_name)
		if found != null:
			return found
	return null


func _first_mesh(root_node: Node) -> MeshInstance3D:
	if root_node is MeshInstance3D:
		return root_node
	for child in root_node.get_children():
		var found = _first_mesh(child)
		if found != null:
			return found
	return null


func _capture(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	for _frame in 6:
		await process_frame
	var image = root.get_texture().get_image()
	if image != null and not image.is_empty():
		image.save_png(path)
