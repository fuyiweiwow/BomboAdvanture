extends SceneTree

const SOURCE_DIRECTORY := "res://assets/environment/terrain_textures/source"
const OUTPUT_DIRECTORY := "res://assets/environment/terrain_textures/packed"

const TEXTURE_SETS := {
	"sand_01": {
		"albedo": "sand_01_diff_1k.png",
		"height": "sand_01_disp_1k.png",
		"normal": "sand_01_nor_gl_1k.png",
		"roughness": "sand_01_rough_1k.png",
	},
	"snow_02": {
		"albedo": "snow_02_diff_1k.png",
		"height": "snow_02_disp_1k.png",
		"normal": "snow_02_nor_gl_1k.png",
		"roughness": "snow_02_rough_1k.png",
	},
}


func _initialize() -> void:
	call_deferred("_pack_all")


func _pack_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIRECTORY))
	for texture_name in TEXTURE_SETS:
		var files: Dictionary = TEXTURE_SETS[texture_name]
		_pack_texture_set(str(texture_name), files)
	print("HILOAN_TEXTURE_PACK_OK sets=", TEXTURE_SETS.size())
	quit(0)


func _pack_texture_set(texture_name: String, files: Dictionary) -> void:
	var albedo := _load_image(str(files["albedo"]))
	var height := _load_image(str(files["height"]))
	var normal := _load_image(str(files["normal"]))
	var roughness := _load_image(str(files["roughness"]))
	assert(albedo.get_size() == height.get_size())
	assert(normal.get_size() == roughness.get_size())
	albedo.convert(Image.FORMAT_RGBA8)
	height.convert(Image.FORMAT_RF)
	normal.convert(Image.FORMAT_RGBA8)
	roughness.convert(Image.FORMAT_RF)

	for y in range(albedo.get_height()):
		for x in range(albedo.get_width()):
			var albedo_pixel := albedo.get_pixel(x, y)
			albedo_pixel.a = height.get_pixel(x, y).r
			albedo.set_pixel(x, y, albedo_pixel)
	for y in range(normal.get_height()):
		for x in range(normal.get_width()):
			var normal_pixel := normal.get_pixel(x, y)
			normal_pixel.a = roughness.get_pixel(x, y).r
			normal.set_pixel(x, y, normal_pixel)

	var albedo_path := ProjectSettings.globalize_path("%s/%s_alb_ht.png" % [OUTPUT_DIRECTORY, texture_name])
	var normal_path := ProjectSettings.globalize_path("%s/%s_nrm_rgh.png" % [OUTPUT_DIRECTORY, texture_name])
	assert(albedo.save_png(albedo_path) == OK)
	assert(normal.save_png(normal_path) == OK)


func _load_image(file_name: String) -> Image:
	var image := Image.load_from_file(ProjectSettings.globalize_path("%s/%s" % [SOURCE_DIRECTORY, file_name]))
	assert(image != null and not image.is_empty())
	return image
