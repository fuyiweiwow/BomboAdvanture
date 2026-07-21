@tool
extends SceneTree

# SpriteSheet Packer
# Run once from command line to pack per-component PNG files
# into power-of-2 texture atlases + JSON metadata.
#
# Usage: godot --path <project> --script res://src/tools/sprite_sheet_packer.gd
# Generated: assets/img/{component}/{component}.atlas.png + .atlas.json

const INITIAL_SIZE := 1024

func _initialize() -> void:
	pack_all()
	quit()


# --------------------------------------------------------------------------
# Entry point — pack every sub-directory under assets/img/
# --------------------------------------------------------------------------
static func pack_all() -> void:
	var img_root := "res://assets/img/"
	var dir := DirAccess.open(img_root)
	if dir == null:
		push_error("sprite_sheet_packer: cannot open " + img_root)
		return
	for component_dir in dir.get_directories():
		pack_component(img_root.path_join(component_dir) + "/")


# --------------------------------------------------------------------------
# Pack all PNGs in a single component directory into one atlas.
# --------------------------------------------------------------------------
static func pack_component(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("sprite_sheet_packer: cannot open " + dir_path)
		return

	var pngs := PackedStringArray()
	for f in dir.get_files():
		if f.ends_with(".png") and not f.ends_with(".atlas.png"):
			pngs.append(f)
	if pngs.is_empty():
		return

	var images := []
	for fname in pngs:
		var img := Image.new()
		if img.load(dir_path.path_join(fname)) == OK:
			images.append({"filename": fname, "image": img, "w": img.get_width(), "h": img.get_height()})

	if images.is_empty():
		return

	# Sort by height descending, then width descending
	images.sort_custom(func(a, b): return a.h > b.h if a.h != b.h else a.w > b.w)

	var atlas_w: int = max(INITIAL_SIZE, next_pow2(images[0]["w"]))
	var shelves := []  # [{y: int, h: int, cursor_x: int}]
	var frames := {}

	for img_data in images:
		var fw: int = img_data["w"]
		var fh: int = img_data["h"]
		var placed := false

		# Try to fit into an existing shelf
		var shelf_idx := 0
		while shelf_idx < shelves.size() and not placed:
			var shelf = shelves[shelf_idx]
			if fw <= atlas_w - shelf.cursor_x and fh <= shelf.h:
				frames[img_data["filename"]] = {"x": shelf.cursor_x, "y": shelf.y, "w": fw, "h": fh}
				shelf.cursor_x += fw
				placed = true
			shelf_idx += 1

		if placed:
			continue

		# Start a new shelf below the last one
		var new_y := 0
		if shelves.size() > 0:
			var last = shelves[shelves.size() - 1]
			new_y = last.y + last.h

		if fw > atlas_w:
			atlas_w = next_pow2(fw)

		shelves.append({"y": new_y, "h": fh, "cursor_x": fw})
		frames[img_data["filename"]] = {"x": 0, "y": new_y, "w": fw, "h": fh}

	if shelves.is_empty():
		return

	var total_h: int = shelves[shelves.size() - 1].y + shelves[shelves.size() - 1].h
	var atlas_h: int = next_pow2(total_h)

	# Build the atlas image
	var atlas_img := Image.create(atlas_w, atlas_h, false, Image.FORMAT_RGBA8)
	atlas_img.fill(Color(0, 0, 0, 0))

	for img_data in images:
		var f = frames[img_data["filename"]]
		atlas_img.blit_rect(img_data["image"], Rect2i(0, 0, f["w"], f["h"]), Vector2i(f["x"], f["y"]))
		img_data["image"] = null

	# Write atlas PNG
	var component_name := dir_path.trim_suffix("/").get_file()
	var atlas_path := dir_path + component_name + ".atlas.png"
	var png_err := atlas_img.save_png(atlas_path)
	if png_err != OK:
		push_error("sprite_sheet_packer: failed to save " + atlas_path)
		return

	# Write atlas JSON
	var json_out := {"frames": {}}
	for fn in frames:
		var f = frames[fn]
		json_out["frames"][fn] = {"frame": {"x": f["x"], "y": f["y"], "w": f["w"], "h": f["h"]}}

	var json_path := dir_path + component_name + ".atlas.json"
	var file := FileAccess.open(json_path, FileAccess.WRITE)
	if file == null:
		push_error("sprite_sheet_packer: failed to write " + json_path)
		return
	file.store_string(JSON.stringify(json_out, "\t", true))
	file.close()

	print("Packed %s: %d frames -> %dx%d atlas (%s)" % [component_name, images.size(), atlas_w, atlas_h, atlas_path])


static func next_pow2(v: int) -> int:
	var p := 1
	while p < v:
		p <<= 1
	return p
