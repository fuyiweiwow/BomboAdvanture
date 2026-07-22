extends Control

const MAP_CATALOG := preload("res://src/map/map_catalog.gd")
const MAP_EDITOR_REGISTRY := preload("res://src/editor/map_editor_registry.gd")

var _cell: int = 40
const PAL_W = 200
const IMG_ROOT = "res://assets/img/"
const FRAME_ROOT = "res://assets/frame/"
const EDITOR_ASSET_ROOT = "res://assets/editor/bomb_survivors/"
const EDITOR_MIN_SIZE := Vector2i(1024, 640)
const TOOLBAR_HEIGHT := 46
const ICON_SIZE := 28

var _grid_f: Array = []
var _grid_o: Array = []
var _obs_inst: Array = []

var _mw: int = 25
var _mh: int = 13
var _map_name: String = "NewMap"
var _scroll: Vector2i = Vector2i(5, 0)
var _music: String = ""
var _begin: Vector2i = Vector2i(0, 0)
var _finish: Vector2i = Vector2i(0, 0)

var _layer: int = 0
var _tool: int = 0
var _sel_type: String = "exploration"
var _sel_name: String = ""
var _sel_w: int = 1
var _sel_h: int = 1
var _pal_floor: Dictionary = {}
var _pal_obs: Dictionary = {}
var _pal_type_order: PackedStringArray = []
var _rect_origin: Vector2i = Vector2i(-1, -1)
var _drag: bool = false
var _last_paint: Vector2i = Vector2i(-1, -1)
var _hover: Vector2i = Vector2i(-1, -1)
var _dirty: bool = false
var _loading: bool = false
var _save_mode: bool = true
var _current_path: String = ""
var _pending_action: String = ""
var _save_after_action: String = ""

var _grid_draw: Control
var _elem_scroll: ScrollContainer
var _elem_vbox: VBoxContainer
var _elem_group: ButtonGroup
var _elem_btns: Array = []
var _type_label: Label
var _status_label: Label
var _preview_rect: TextureRect
var _file_dialog: FileDialog
var _import_dialog: FileDialog
var _unsaved_dialog: ConfirmationDialog

var _name_edit: LineEdit
var _w_spin: SpinBox
var _h_spin: SpinBox
var _bx_spin: SpinBox
var _by_spin: SpinBox
var _fx_spin: SpinBox
var _fy_spin: SpinBox

var _set_marker_mode: int = -1
var _tex_cache: Dictionary = {}
var _icon_cache: Dictionary = {}
var _zoom: float = 1.0
var _main_vb: VBoxContainer
var _map_catalog
var _editor_registry

func _mark_dirty() -> void:
	if not _loading:
		_dirty = true

func _floor_cell(type: String, name: String) -> Dictionary:
	return {"type": type, "name": name}

func _obstacle_inst(type: String, name: String, x: int, y: int, w: int, h: int) -> Dictionary:
	return {"type": type, "name": name, "x": x, "y": y, "w": max(1, w), "h": max(1, h)}

func _inst_type(inst: Dictionary) -> String:
	return str(inst.get("type", ""))

func _inst_name(inst: Dictionary) -> String:
	return str(inst.get("name", ""))

func _inst_x(inst: Dictionary) -> int:
	return int(inst.get("x", 0))

func _inst_y(inst: Dictionary) -> int:
	return int(inst.get("y", 0))

func _inst_w(inst: Dictionary) -> int:
	return max(1, int(inst.get("w", 1)))

func _inst_h(inst: Dictionary) -> int:
	return max(1, int(inst.get("h", 1)))

func _load_json(path: String) -> Variant:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	return data

func _get_obstacle_size(type: String, name: String) -> Vector2i:
	if _editor_registry != null:
		return _editor_registry.obstacle_size(type, name)
	var json = _load_json(FRAME_ROOT + "obstacle/" + type + "/" + name + ".json")
	if json != null and typeof(json) == TYPE_DICTIONARY:
		return Vector2i(max(1, int(json.get("WIDTH", 1))), max(1, int(json.get("HEIGHT", 1))))
	return Vector2i.ONE

func _array_to_vec2i(value: Variant, fallback: Vector2i) -> Vector2i:
	if typeof(value) != TYPE_ARRAY:
		return fallback
	var arr: Array = value
	return Vector2i(int(arr[0]) if arr.size() > 0 else fallback.x, int(arr[1]) if arr.size() > 1 else fallback.y)

func _make_ui_icon(kind: String) -> Texture2D:
	if _icon_cache.has(kind):
		return _icon_cache[kind]
	var asset_path = _editor_icon_path(kind)
	if asset_path != "":
		var asset_tex = _load_scaled_texture(asset_path, Vector2i(ICON_SIZE, ICON_SIZE))
		if asset_tex != null:
			_icon_cache[kind] = asset_tex
			return asset_tex
	var img = Image.create(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ink = Color(0.23, 0.12, 0.06, 1.0)
	var gold = Color(1.0, 0.72, 0.14, 1.0)
	var gold_hi = Color(1.0, 0.93, 0.32, 1.0)
	var orange = Color(0.88, 0.28, 0.02, 1.0)
	var blue = Color(0.24, 0.58, 0.86, 1.0)
	var green = Color(0.22, 0.68, 0.22, 1.0)
	var red = Color(0.88, 0.18, 0.10, 1.0)
	var paper = Color(1.0, 0.86, 0.55, 1.0)
	_fill_icon_rect(img, Rect2i(2, 2, ICON_SIZE - 4, ICON_SIZE - 4), Color(0.08, 0.07, 0.05, 0.28))
	match kind:
		"save":
			_fill_icon_rect(img, Rect2i(5, 4, 18, 20), blue)
			_fill_icon_rect(img, Rect2i(8, 5, 10, 5), Color(0.87, 0.94, 1.0, 1.0))
			_fill_icon_rect(img, Rect2i(8, 15, 12, 7), paper)
			_fill_icon_rect(img, Rect2i(18, 6, 3, 5), ink)
		"load":
			_fill_icon_rect(img, Rect2i(4, 9, 20, 13), gold)
			_fill_icon_rect(img, Rect2i(6, 6, 8, 5), gold_hi)
			_fill_icon_rect(img, Rect2i(9, 13, 10, 3), orange)
		"new":
			_fill_icon_rect(img, Rect2i(7, 4, 14, 20), paper)
			_fill_icon_rect(img, Rect2i(10, 16, 8, 3), green)
			_fill_icon_rect(img, Rect2i(12, 13, 3, 9), green)
		"back":
			_fill_icon_rect(img, Rect2i(11, 5, 10, 18), red)
			_fill_icon_rect(img, Rect2i(6, 13, 13, 4), gold_hi)
			_fill_icon_rect(img, Rect2i(6, 10, 4, 10), gold_hi)
		"zoom_in":
			_draw_magnifier(img, blue, ink, true)
		"zoom_out":
			_draw_magnifier(img, blue, ink, false)
		"floor":
			for y in range(5, 23, 6):
				for x in range(5, 23, 6):
					_fill_icon_rect(img, Rect2i(x, y, 5, 5), green if ((x + y) / 6) % 2 == 0 else Color(0.40, 0.78, 0.30, 1.0))
		"obstacle":
			_fill_icon_rect(img, Rect2i(5, 8, 18, 13), Color(0.55, 0.50, 0.45, 1.0))
			_fill_icon_rect(img, Rect2i(7, 10, 5, 4), Color(0.72, 0.67, 0.58, 1.0))
			_fill_icon_rect(img, Rect2i(15, 15, 6, 4), Color(0.36, 0.32, 0.28, 1.0))
		"paint":
			_fill_icon_rect(img, Rect2i(16, 5, 4, 14), gold)
			_fill_icon_rect(img, Rect2i(9, 15, 9, 4), orange)
			_fill_icon_rect(img, Rect2i(6, 18, 7, 6), blue)
		"erase":
			_fill_icon_rect(img, Rect2i(7, 14, 14, 7), Color(0.96, 0.58, 0.64, 1.0))
			_fill_icon_rect(img, Rect2i(12, 9, 10, 7), Color(0.90, 0.82, 0.72, 1.0))
			_fill_icon_rect(img, Rect2i(6, 21, 16, 2), Color(0.50, 0.40, 0.32, 1.0))
		"fill":
			_fill_icon_rect(img, Rect2i(8, 6, 10, 8), gold)
			_fill_icon_rect(img, Rect2i(6, 14, 14, 4), orange)
			_fill_icon_rect(img, Rect2i(10, 19, 10, 4), blue)
		"import":
			_fill_icon_rect(img, Rect2i(4, 10, 18, 12), gold)
			_fill_icon_rect(img, Rect2i(14, 4, 3, 11), green)
			_fill_icon_rect(img, Rect2i(10, 8, 11, 3), green)
		"start":
			_fill_icon_rect(img, Rect2i(12, 5, 4, 16), green)
			_fill_icon_rect(img, Rect2i(9, 5, 10, 7), Color(0.50, 0.95, 0.30, 1.0))
			_fill_icon_rect(img, Rect2i(8, 20, 12, 3), ink)
		"finish":
			_fill_icon_rect(img, Rect2i(8, 5, 3, 18), ink)
			for y in range(5, 17, 4):
				for x in range(11, 23, 4):
					_fill_icon_rect(img, Rect2i(x, y, 4, 4), red if ((x + y) / 4) % 2 == 0 else paper)
		_:
			_fill_icon_rect(img, Rect2i(7, 7, 14, 14), gold)
	_draw_icon_border(img, ink)
	var tex = ImageTexture.create_from_image(img)
	_icon_cache[kind] = tex
	return tex

func _load_scaled_texture(path: String, target_size: Vector2i) -> Texture2D:
	var img: Image = null
	var tex = _try_load_texture(path)
	if tex != null:
		img = tex.get_image()
	if (img == null or img.is_empty()) and path.begins_with("res://") and FileAccess.file_exists(path):
		img = Image.load_from_file(path)
	if img == null or img.is_empty():
		return null
	img.resize(max(1, target_size.x), max(1, target_size.y), Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)

func _editor_icon_path(kind: String) -> String:
	var icons = {
		"save": "icons/map_smooth.png",
		"save_as": "icons/map_set_height.png",
		"load": "icons/map_set_height.png",
		"new": "icons/map_add.png",
		"back": "icons/map_remove.png",
		"zoom_in": "icons/flow_add.png",
		"zoom_out": "icons/flow_remove.png",
		"floor": "icons/color_add.png",
		"obstacle": "icons/object_add.png",
		"paint": "icons/paint.png",
		"erase": "icons/object_remove.png",
		"fill": "icons/map_flatten.png",
		"import": "icons/map_add.png",
		"start": "icons/color_add.png",
		"finish": "icons/color_remove.png"
	}
	var rel = icons.get(kind, "")
	return EDITOR_ASSET_ROOT + rel if rel != "" else ""

func _fill_icon_rect(img: Image, rect: Rect2i, color: Color) -> void:
	for y in range(max(0, rect.position.y), min(ICON_SIZE, rect.position.y + rect.size.y)):
		for x in range(max(0, rect.position.x), min(ICON_SIZE, rect.position.x + rect.size.x)):
			img.set_pixel(x, y, color)

func _draw_icon_border(img: Image, color: Color) -> void:
	for x in range(4, ICON_SIZE - 4):
		img.set_pixel(x, 3, color)
		img.set_pixel(x, ICON_SIZE - 4, color)
	for y in range(4, ICON_SIZE - 4):
		img.set_pixel(3, y, color)
		img.set_pixel(ICON_SIZE - 4, y, color)

func _draw_magnifier(img: Image, color: Color, ink: Color, plus: bool) -> void:
	_fill_icon_rect(img, Rect2i(17, 17, 7, 4), ink)
	for y in range(5, 17):
		for x in range(5, 17):
			var d = Vector2(x - 11, y - 11).length()
			if d <= 6.0 and d >= 4.0:
				img.set_pixel(x, y, color)
	_fill_icon_rect(img, Rect2i(8, 10, 7, 3), ink)
	if plus:
		_fill_icon_rect(img, Rect2i(10, 8, 3, 7), ink)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	custom_minimum_size = Vector2(EDITOR_MIN_SIZE)
	DisplayServer.window_set_min_size(EDITOR_MIN_SIZE)
	_map_catalog = MAP_CATALOG.new()
	_editor_registry = MAP_EDITOR_REGISTRY.new()
	_build_ui()
	_scan_elements()
	_resize_grid()
	call_deferred("_calc_cell_size")
	_update_preview()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		if _grid_draw != null:
			_calc_cell_size()
			_grid_draw.queue_redraw()

func _build_ui() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	var main_vb = VBoxContainer.new()
	main_vb.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(main_vb)
	_main_vb = main_vb

	# ========== Toolbar ==========
	var tb = HBoxContainer.new()
	tb.custom_minimum_size.y = TOOLBAR_HEIGHT
	tb.add_theme_constant_override("separation", 5)
	tb.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vb.add_child(tb)

	var logo = TextureRect.new()
	logo.name = "EditorLogo"
	logo.texture = _load_scaled_texture(EDITOR_ASSET_ROOT + "art/bomb_shell.png", Vector2i(30, 30))
	logo.custom_minimum_size = Vector2(30, 30)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tb.add_child(logo)

	var tl = Label.new()
	tl.text = "MAP EDITOR"
	tl.custom_minimum_size.x = 132
	tl.add_theme_font_size_override("font_size", 18)
	tl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.32))
	tb.add_child(tl)

	var spacer = Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	tb.add_child(spacer)

	_make_btn(tb, "Save", _on_save, "save", true)
	_make_btn(tb, "Save As", _on_save_as, "save_as", true)
	_make_btn(tb, "Open", _on_load, "load", true)
	_make_btn(tb, "New", _on_new, "new", true)
	tb.add_child(VSeparator.new())
	_make_btn(tb, "Exit", _on_back, "back", true)
	tb.add_child(VSeparator.new())
	_make_btn(tb, "Zoom In", func(): _zoom *= 1.25; _calc_cell_size(); _grid_draw.queue_redraw(), "zoom_in")
	_make_btn(tb, "Zoom Out", func(): _zoom = max(0.25, _zoom * 0.8); _calc_cell_size(); _grid_draw.queue_redraw(), "zoom_out")

	# ========== Map settings row ==========
	var settings_scroll = ScrollContainer.new()
	settings_scroll.custom_minimum_size.y = 42
	settings_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	settings_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	main_vb.add_child(settings_scroll)

	var sr = HBoxContainer.new()
	sr.custom_minimum_size.x = 760
	sr.add_theme_constant_override("separation", 6)
	settings_scroll.add_child(sr)

	var name_lbl = Label.new()
	name_lbl.text = "Name"
	sr.add_child(name_lbl)
	_name_edit = LineEdit.new()
	_name_edit.custom_minimum_size.x = 140
	_name_edit.text_changed.connect(func(t): _map_name = t; _mark_dirty())
	sr.add_child(_name_edit)

	sr.add_child(VSeparator.new())

	var w_lbl = Label.new()
	w_lbl.text = "W"
	sr.add_child(w_lbl)
	_w_spin = SpinBox.new()
	_w_spin.min_value = 3
	_w_spin.max_value = 200
	_w_spin.value = _mw
	_w_spin.custom_minimum_size.x = 55
	_w_spin.value_changed.connect(func(v): _change_size(int(v), _mh))
	sr.add_child(_w_spin)

	var h_lbl = Label.new()
	h_lbl.text = "H"
	sr.add_child(h_lbl)
	_h_spin = SpinBox.new()
	_h_spin.min_value = 3
	_h_spin.max_value = 200
	_h_spin.value = _mh
	_h_spin.custom_minimum_size.x = 55
	_h_spin.value_changed.connect(func(v): _change_size(_mw, int(v)))
	sr.add_child(_h_spin)

	sr.add_child(VSeparator.new())

	var sb_lbl = Label.new()
	sb_lbl.text = "Start"
	sr.add_child(sb_lbl)
	_bx_spin = SpinBox.new()
	_bx_spin.min_value = 0
	_bx_spin.max_value = 199
	_bx_spin.value = _begin.x
	_bx_spin.custom_minimum_size.x = 42
	_bx_spin.value_changed.connect(func(v): _begin.x = clampi(int(v), 0, _mw - 1); _mark_dirty(); _grid_draw.queue_redraw())
	sr.add_child(_bx_spin)
	_by_spin = SpinBox.new()
	_by_spin.min_value = 0
	_by_spin.max_value = 199
	_by_spin.value = _begin.y
	_by_spin.custom_minimum_size.x = 42
	_by_spin.value_changed.connect(func(v): _begin.y = clampi(int(v), 0, _mh - 1); _mark_dirty(); _grid_draw.queue_redraw())
	sr.add_child(_by_spin)
	var set_e_btn: Button = null
	var set_s_btn = Button.new()
	set_s_btn.text = ""
	set_s_btn.icon = _make_ui_icon("start")
	set_s_btn.expand_icon = true
	set_s_btn.tooltip_text = "Set Start"
	set_s_btn.custom_minimum_size = Vector2(38, 34)
	set_s_btn.toggle_mode = true
	set_s_btn.pressed.connect(func(): _toggle_marker(0, set_s_btn, set_e_btn))
	sr.add_child(set_s_btn)

	var eb_lbl = Label.new()
	eb_lbl.text = "End"
	sr.add_child(eb_lbl)
	_fx_spin = SpinBox.new()
	_fx_spin.min_value = 0
	_fx_spin.max_value = 199
	_fx_spin.value = _finish.x
	_fx_spin.custom_minimum_size.x = 42
	_fx_spin.value_changed.connect(func(v): _finish.x = clampi(int(v), 0, _mw - 1); _mark_dirty(); _grid_draw.queue_redraw())
	sr.add_child(_fx_spin)
	_fy_spin = SpinBox.new()
	_fy_spin.min_value = 0
	_fy_spin.max_value = 199
	_fy_spin.value = _finish.y
	_fy_spin.custom_minimum_size.x = 42
	_fy_spin.value_changed.connect(func(v): _finish.y = clampi(int(v), 0, _mh - 1); _mark_dirty(); _grid_draw.queue_redraw())
	sr.add_child(_fy_spin)
	set_e_btn = Button.new()
	set_e_btn.text = ""
	set_e_btn.icon = _make_ui_icon("finish")
	set_e_btn.expand_icon = true
	set_e_btn.tooltip_text = "Set End"
	set_e_btn.custom_minimum_size = Vector2(38, 34)
	set_e_btn.toggle_mode = true
	set_e_btn.pressed.connect(func(): _toggle_marker(1, set_e_btn, set_s_btn))
	sr.add_child(set_e_btn)

	# ========== Center area ==========
	var mid = HBoxContainer.new()
	mid.size_flags_horizontal = SIZE_EXPAND_FILL
	mid.size_flags_vertical = SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 6)
	main_vb.add_child(mid)

	# ========== Left panel ==========
	var left = VBoxContainer.new()
	left.custom_minimum_size.x = 254
	left.size_flags_vertical = SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 4)
	mid.add_child(left)

	# -- Layer --
	var sec1 = _make_section(left, "Layer")
	var lh = HBoxContainer.new()
	var layer_group = ButtonGroup.new()
	_make_toggle(lh, "Floor", true, func(on): if on: _set_layer(0), layer_group, "floor")
	_make_toggle(lh, "Obstacle", false, func(on): if on: _set_layer(1), layer_group, "obstacle")
	sec1.add_child(lh)

	# -- Tool --
	var sec2 = _make_section(left, "Tool")
	var th = HBoxContainer.new()
	var tool_group = ButtonGroup.new()
	_make_toggle(th, "Paint", true, func(on): if on: _set_tool(0), tool_group, "paint")
	_make_toggle(th, "Erase", false, func(on): if on: _set_tool(1), tool_group, "erase")
	_make_toggle(th, "Fill", false, func(on): if on: _set_tool(2), tool_group, "fill")
	sec2.add_child(th)

	# -- Element --
	var sec3 = _make_section(left, "Element")
	sec3.size_flags_vertical = SIZE_EXPAND_FILL
	_type_label = Label.new()
	_type_label.text = "..."
	_type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_type_label.size_flags_horizontal = SIZE_EXPAND_FILL
	sec3.add_child(_type_label)

	_elem_scroll = ScrollContainer.new()
	_elem_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	_elem_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sec3.add_child(_elem_scroll)
	_elem_group = ButtonGroup.new()
	_elem_vbox = VBoxContainer.new()
	_elem_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	_elem_scroll.add_child(_elem_vbox)

	var imp_btn = Button.new()
	imp_btn.text = "Import"
	imp_btn.icon = _make_ui_icon("import")
	imp_btn.expand_icon = true
	imp_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	imp_btn.custom_minimum_size.y = 36
	imp_btn.pressed.connect(_on_import)
	sec3.add_child(imp_btn)

	# -- Preview --
	_preview_rect = TextureRect.new()
	_preview_rect.custom_minimum_size = Vector2(_cell + 8, _cell + 8)
	_preview_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_rect.modulate = Color(1, 1, 1, 0.85)
	left.add_child(_preview_rect)

	# ========== Grid view ==========
	var sc = ScrollContainer.new()
	sc.size_flags_horizontal = SIZE_EXPAND_FILL
	sc.size_flags_vertical = SIZE_EXPAND_FILL
	mid.add_child(sc)

	_grid_draw = Control.new()
	_grid_draw.mouse_filter = MOUSE_FILTER_STOP
	_grid_draw.gui_input.connect(_on_grid_input)
	_grid_draw.draw.connect(_on_grid_draw)
	_grid_draw.resized.connect(_on_grid_resized)
	sc.add_child(_grid_draw)

	# ========== Status bar ==========
	_status_label = Label.new()
	_status_label.text = "Ready"
	main_vb.add_child(_status_label)

	# ========== File dialog ==========
	_file_dialog = FileDialog.new()
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.file_selected.connect(_on_file_selected)
	_file_dialog.canceled.connect(_on_file_dialog_canceled)
	_file_dialog.hide()
	add_child(_file_dialog)

	_import_dialog = FileDialog.new()
	_import_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	_import_dialog.add_filter("*.png", "PNG Image")
	_import_dialog.files_selected.connect(_on_import_files)
	_import_dialog.hide()
	add_child(_import_dialog)

	_unsaved_dialog = ConfirmationDialog.new()
	_unsaved_dialog.title = "Unsaved Changes"
	_unsaved_dialog.dialog_text = "Save changes before continuing?"
	_unsaved_dialog.ok_button_text = "Save"
	_unsaved_dialog.cancel_button_text = "Cancel"
	_unsaved_dialog.confirmed.connect(_on_unsaved_save)
	_unsaved_dialog.canceled.connect(func(): _pending_action = "")
	var discard_btn = _unsaved_dialog.add_button("Discard", false, "discard")
	discard_btn.pressed.connect(_on_unsaved_discard)
	add_child(_unsaved_dialog)

	_grid_draw.mouse_entered.connect(func(): _grid_draw.queue_redraw())
	_grid_draw.mouse_exited.connect(func(): _hover = Vector2i(-1, -1); _grid_draw.queue_redraw())

func _make_btn(parent: Control, text: String, fn: Callable, icon_name: String = "", show_text: bool = false) -> Button:
	var b = Button.new()
	b.text = text if show_text or icon_name == "" else ""
	if icon_name != "":
		b.icon = _make_ui_icon(icon_name)
		b.expand_icon = not show_text
		b.tooltip_text = text
		b.custom_minimum_size = Vector2(96 if show_text else 40, 36)
	b.pressed.connect(fn)
	parent.add_child(b)
	return b

func _make_toggle(parent: Control, text: String, on: bool, fn: Callable, group: ButtonGroup = null, icon_name: String = "") -> Button:
	var b = Button.new()
	b.text = text
	if icon_name != "":
		b.icon = _make_ui_icon(icon_name)
		b.expand_icon = true
		b.tooltip_text = text
	b.custom_minimum_size = Vector2(76, 36)
	b.size_flags_horizontal = SIZE_EXPAND_FILL
	b.toggle_mode = true
	b.button_pressed = on
	if group:
		b.button_group = group
	b.pressed.connect(func(): fn.call(b.button_pressed))
	parent.add_child(b)
	return b

func _make_section(parent: VBoxContainer, title: String) -> VBoxContainer:
	var l = Label.new()
	l.text = title
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", Color(0.7, 0.75, 0.9))
	parent.add_child(l)
	var vb = VBoxContainer.new()
	parent.add_child(vb)
	return vb

func _set_layer(l: int) -> void:
	_layer = l
	_populate_element_list()
	_set_marker_mode = -1
	var layer_name = _editor_registry.layer_name(l) if _editor_registry != null else ("Floor" if l == 0 else "Obstacle")
	_status("Layer: " + layer_name)

func _set_tool(t: int) -> void:
	_tool = t
	_rect_origin = Vector2i(-1, -1)
	_set_marker_mode = -1
	_status("Tool: " + ["Paint - left click to place", "Erase - left click to remove", "Fill - click two corners"][t])

func _toggle_marker(mode: int, btn: Button, other: Button) -> void:
	if _set_marker_mode == mode:
		_set_marker_mode = -1
		btn.button_pressed = false
		_status("Ready")
	else:
		_set_marker_mode = mode
		btn.button_pressed = true
		other.button_pressed = false
		_status("Click on the grid to place " + ("Start" if mode == 0 else "End") + " point")

func _change_size(w: int, h: int) -> void:
	if w == _mw and h == _mh: return
	_mw = w
	_mh = h
	_resize_grid(true)
	_mark_dirty()
	_status("Size: %d x %d" % [w, h])

func _resize_grid(recalc: bool = false) -> void:
	var old_f = _grid_f
	_mw = max(1, _mw)
	_mh = max(1, _mh)

	var new_f: Array = []
	new_f.resize(_mh)
	for y in _mh:
		new_f[y] = []
		new_f[y].resize(_mw)
		for x in _mw:
			new_f[y][x] = null
			if y < old_f.size() and old_f[y] != null and x < old_f[y].size():
				new_f[y][x] = old_f[y][x]
	_grid_f = new_f
	_rebuild_obstacle_grid()
	_clamp_markers()
	_sync_marker_limits()

	_calc_cell_size()
	if _grid_draw != null:
		_grid_draw.queue_redraw()

func _make_empty_obstacle_grid() -> Array:
	var grid: Array = []
	grid.resize(_mh)
	for y in _mh:
		grid[y] = []
		grid[y].resize(_mw)
		for x in _mw:
			grid[y][x] = -1
	return grid

func _rebuild_obstacle_grid() -> void:
	_grid_o = _make_empty_obstacle_grid()
	var valid: Array = []
	for raw in _obs_inst:
		if raw == null or typeof(raw) != TYPE_DICTIONARY:
			continue
		var inst := _obstacle_inst(_inst_type(raw), _inst_name(raw), _inst_x(raw), _inst_y(raw), _inst_w(raw), _inst_h(raw))
		if _can_place_obstacle(inst, _grid_o):
			var id = valid.size()
			valid.append(inst)
			_mark_obstacle(inst, id, _grid_o)
	_obs_inst = valid

func _clamp_markers() -> void:
	_begin.x = clampi(_begin.x, 0, _mw - 1)
	_begin.y = clampi(_begin.y, 0, _mh - 1)
	_finish.x = clampi(_finish.x, 0, _mw - 1)
	_finish.y = clampi(_finish.y, 0, _mh - 1)

func _sync_marker_limits() -> void:
	if _bx_spin == null:
		return
	_bx_spin.max_value = max(0, _mw - 1)
	_fx_spin.max_value = max(0, _mw - 1)
	_by_spin.max_value = max(0, _mh - 1)
	_fy_spin.max_value = max(0, _mh - 1)

func _on_grid_resized() -> void:
	_calc_cell_size()
	_grid_draw.queue_redraw()

func _calc_cell_size() -> void:
	if _grid_draw == null or _mw <= 0 or _mh <= 0:
		return
	var sc = _grid_draw.get_parent() as ScrollContainer
	if sc == null:
		return
	var avail = sc.size
	if avail.x <= 0 or avail.y <= 0:
		return
	var cw = floor(avail.x / _mw)
	var ch = floor(avail.y / _mh)
	_cell = max(12, int(min(cw, ch) * _zoom))
	_grid_draw.custom_minimum_size = Vector2(_mw * _cell, _mh * _cell)

# === Palette scanning ===

func _scan_elements() -> void:
	var palette = _editor_registry.build_palette() if _editor_registry != null else {}
	_pal_floor = palette.get("floor", {})
	_pal_obs = palette.get("obstacle", {})
	_populate_element_list()

func _populate_element_list() -> void:
	var catalog = _pal_floor if _layer == 0 else _pal_obs
	_pal_type_order.clear()
	for k in catalog.keys():
		_pal_type_order.append(k)
	_pal_type_order.sort()
	_show_type()

func _show_type() -> void:
	for c in _elem_vbox.get_children():
		c.queue_free()
	_elem_btns.clear()
	if _pal_type_order.size() == 0:
		_type_label.text = "---"
		_sel_type = ""
		_sel_name = ""
		_preview_rect.texture = null
		_status("No placeable assets for this layer")
		return
	var catalog = _pal_floor if _layer == 0 else _pal_obs
	_type_label.text = "%d types" % [_pal_type_order.size()]
	_sel_type = _pal_type_order[0]
	var total_items = 0
	for t in _pal_type_order:
		var items = catalog.get(t, [])
		total_items += items.size()
		var hdr = Label.new()
		hdr.text = t + " (%d)" % items.size()
		hdr.add_theme_font_size_override("font_size", 10)
		hdr.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
		_elem_vbox.add_child(hdr)
		if items.size() == 0:
			continue
		var sub = GridContainer.new()
		sub.columns = 3
		sub.size_flags_horizontal = SIZE_EXPAND_FILL
		_elem_vbox.add_child(sub)
		for n in items:
			_add_elem_btn(sub, t, n)
	_type_label.text = "%d types (%d items)" % [_pal_type_order.size(), total_items]
	if _elem_btns.size() > 0:
		_elem_btns[0].button_pressed = true
		_on_elem_selected(_elem_btns[0].get_meta("elem_type"), _elem_btns[0].get_meta("elem_name"))
	_status("Total: %d elements in %d types" % [total_items, _pal_type_order.size()])

func _add_elem_btn(parent: GridContainer, type: String, name: String) -> void:
	var tile = Control.new()
	tile.custom_minimum_size = Vector2(64, 72)

	var vbox = VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.add_theme_constant_override("separation", 1)
	tile.add_child(vbox)

	var tex_rect = TextureRect.new()
	tex_rect.custom_minimum_size = Vector2(48, 48)
	tex_rect.size_flags_horizontal = SIZE_EXPAND_FILL
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var tex = _get_tex(_layer, type, name)
	if tex:
		tex_rect.texture = tex
	else:
		tex_rect.modulate = _name_color(name, 0.6, 0.5)
	vbox.add_child(tex_rect)

	var lbl = Label.new()
	lbl.text = name
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.max_lines_visible = 2
	vbox.add_child(lbl)

	var btn = Button.new()
	btn.anchor_right = 1.0
	btn.anchor_bottom = 1.0
	btn.flat = true
	btn.mouse_filter = MOUSE_FILTER_STOP
	btn.toggle_mode = true
	btn.button_group = _elem_group
	btn.set_meta("elem_type", type)
	btn.set_meta("elem_name", name)
	btn.toggled.connect(func(on: bool): tile.modulate = Color(1, 1, 0.7) if on else Color(1, 1, 1))
	btn.pressed.connect(func(): _on_elem_selected(type, name))
	tile.add_child(btn)

	parent.add_child(tile)
	_elem_btns.append(btn)

func _on_elem_selected(type: String, name: String) -> void:
	_sel_type = type
	_sel_name = name
	_sel_w = 1
	_sel_h = 1
	if _layer == 1:
		var size = _get_obstacle_size(_sel_type, _sel_name)
		_sel_w = size.x
		_sel_h = size.y
	_update_preview()
	_status("Selected: %s/%s [%dx%d]" % [_sel_type, _sel_name, _sel_w, _sel_h])

func _update_preview() -> void:
	var tex: Texture2D = null
	if _sel_name == "":
		_preview_rect.texture = null
		return
	if _layer == 0:
		var path = _editor_registry.floor_texture_path(_sel_type, _sel_name) if _editor_registry != null else IMG_ROOT + "mapElem/" + _sel_type + "/" + _sel_name + ".png"
		tex = _try_load_texture(path)
	elif _layer == 1:
		var path = _editor_registry.obstacle_texture_path(_sel_type, _sel_name) if _editor_registry != null else ""
		if path != "":
			tex = _try_load_texture(path)
	_preview_rect.texture = tex

func _try_load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return ResourceLoader.load(path)
	if path.begins_with("res://") and FileAccess.file_exists(path):
		var img = Image.load_from_file(path)
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return null

func _get_tex(layer: int, type: String, name: String) -> Texture2D:
	var key = str(layer) + "/" + type + "/" + name
	if _tex_cache.has(key):
		return _tex_cache[key]
	var tex: Texture2D = null
	if layer == 0:
		var path = _editor_registry.floor_texture_path(type, name) if _editor_registry != null else IMG_ROOT + "mapElem/" + type + "/" + name + ".png"
		tex = _try_load_texture(path)
	elif layer == 1:
		var path = _editor_registry.obstacle_texture_path(type, name) if _editor_registry != null else ""
		if path != "":
			tex = _try_load_texture(path)
	_tex_cache[key] = tex
	return tex

func _clear_tex_cache() -> void:
	_tex_cache.clear()

# === Grid drawing ===

func _on_grid_draw() -> void:
	var draw = _grid_draw
	var r = Rect2(Vector2.ZERO, draw.size)

	draw.draw_rect(r, Color(0.15, 0.15, 0.18))

	for y in _mh:
		for x in _mw:
			var cr = Rect2(x * _cell, y * _cell, _cell, _cell)
			var bg = Color(0.22, 0.22, 0.25)
			if (x + y) % 2 == 0:
				bg = Color(0.25, 0.25, 0.28)
			draw.draw_rect(cr, bg)

	for y in _mh:
		for x in _mw:
			var f = _grid_f[y][x]
			if f != null:
				var f_type = str(f.get("type", ""))
				var f_name = str(f.get("name", ""))
				var tex = _get_tex(0, f_type, f_name)
				if tex:
					draw.draw_texture_rect(tex, Rect2(x * _cell, y * _cell, _cell, _cell), false)
				else:
					var cr = Rect2(x * _cell + 1, y * _cell + 1, _cell - 2, _cell - 2)
					var col = _name_color(f_name, 0.6, 0.5)
					col.a = 0.7
					draw.draw_rect(cr, col)

	for y in _mh:
		for x in _mw:
			var oid = _grid_o[y][x]
			if oid >= 0 and oid < _obs_inst.size() and _obs_inst[oid] != null:
				var inst = _obs_inst[oid]
				var inst_x = _inst_x(inst)
				var inst_y = _inst_y(inst)
				if inst_x == x and inst_y == y:
					var w = _inst_w(inst)
					var h = _inst_h(inst)
					var inst_name = _inst_name(inst)
					var tex = _get_tex(1, _inst_type(inst), inst_name)
					if tex:
						draw.draw_texture_rect(tex, Rect2(x * _cell, y * _cell, _cell, _cell), false)
						draw.draw_rect(Rect2(x * _cell, y * _cell, w * _cell, h * _cell), Color(1, 1, 1, 0.15), false, 1.0)
					else:
						var col = _name_color(inst_name, 0.7, 0.6)
						col.a = 0.85
						draw.draw_rect(Rect2(x * _cell + 1, y * _cell + 1, w * _cell - 2, h * _cell - 2), col, false, 2.0)
						draw.draw_rect(Rect2(x * _cell + 3, y * _cell + 3, w * _cell - 6, h * _cell - 6), Color(col.r * 0.6, col.g * 0.6, col.b * 0.6, 0.4))
					var cx = (x + 0.5 * w) * _cell
					var cy = (y + 0.5 * h) * _cell
					var abbr = inst_name.trim_prefix("elem")
					draw.draw_string(ThemeDB.fallback_font, Vector2(cx - 4, cy + 4), abbr, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)

	if _begin.x >= 0 and _begin.x < _mw and _begin.y >= 0 and _begin.y < _mh:
		var bx = _begin.x * _cell
		var by = _begin.y * _cell
		draw.draw_circle(Vector2(bx + _cell * 0.5, by + _cell * 0.5), _cell * 0.3, Color(0.2, 0.9, 0.2, 0.7))
		draw.draw_string(ThemeDB.fallback_font, Vector2(bx + 4, by + 14), "S", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

	if _finish.x >= 0 and _finish.x < _mw and _finish.y >= 0 and _finish.y < _mh:
		var fx = _finish.x * _cell
		var fy = _finish.y * _cell
		draw.draw_circle(Vector2(fx + _cell * 0.5, fy + _cell * 0.5), _cell * 0.3, Color(0.9, 0.2, 0.2, 0.7))
		draw.draw_string(ThemeDB.fallback_font, Vector2(fx + 4, fy + 14), "E", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

	if _hover.x >= 0 and _hover.x < _mw and _hover.y >= 0 and _hover.y < _mh:
		var col = Color(1, 1, 1, 0.15)
		if _tool == 1:
			col = Color(1, 0.3, 0.3, 0.2)
		var w = _sel_w if (_layer == 1 and _tool != 1) else 1
		var h = _sel_h if (_layer == 1 and _tool != 1) else 1
		if _hover.x + w <= _mw and _hover.y + h <= _mh:
			draw.draw_rect(Rect2(_hover.x * _cell, _hover.y * _cell, w * _cell, h * _cell), col, true)

	if _rect_origin.x >= 0:
		var ox = _rect_origin.x * _cell
		var oy = _rect_origin.y * _cell
		draw.draw_rect(Rect2(ox, oy, _cell, _cell), Color(1, 1, 0, 0.3), true)

func _name_color(name: String, sat: float, val: float) -> Color:
	var h = abs(name.hash()) % 360 / 360.0
	return Color.from_hsv(h, sat, val)

# === Mouse handling ===

func _on_grid_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var pos = _grid_to_grid(event.position)
		if pos != _hover:
			_hover = pos
			_grid_draw.queue_redraw()
		if _drag and _tool != 2 and pos != _last_paint and pos.x >= 0:
			_do_paint(pos.x, pos.y)
			_last_paint = pos
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var gp = _grid_to_grid(event.position)
			if gp.x < 0 or gp.y >= _mh or gp.x >= _mw: return

			if _set_marker_mode >= 0:
				if _set_marker_mode == 0:
					_begin = gp
				else:
					_finish = gp
				_grid_draw.queue_redraw()
				_dirty = true
				_set_marker_mode = -1
				_status("Ready")
				return

			if _tool == 0 or _tool == 1:
				_do_paint(gp.x, gp.y)
				_last_paint = gp
				_drag = true
			elif _tool == 2:
				if _rect_origin.x < 0:
					_rect_origin = gp
				else:
					_do_rect_fill(_rect_origin.x, _rect_origin.y, gp.x, gp.y)
					_rect_origin = Vector2i(-1, -1)
					_grid_draw.queue_redraw()
		else:
			_drag = false

		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var gp = _grid_to_grid(event.position)
			if gp.x >= 0:
				_erase_at(gp.x, gp.y)

func _grid_to_grid(pos: Vector2) -> Vector2i:
	var gx = int(pos.x / _cell)
	var gy = int(pos.y / _cell)
	if gx < 0 or gx >= _mw or gy < 0 or gy >= _mh:
		return Vector2i(-1, -1)
	return Vector2i(gx, gy)

func _do_paint(x: int, y: int) -> void:
	if x < 0 or x >= _mw or y < 0 or y >= _mh:
		return
	if _sel_name == "":
		_status("No element selected")
		return

	if _tool == 1:
		_erase_at(x, y)
		return

	if _layer == 0:
		_grid_f[y][x] = _floor_cell(_sel_type, _sel_name)
	else:
		if not _place_obstacle(x, y):
			return

	_dirty = true
	_grid_draw.queue_redraw()

func _place_obstacle(x: int, y: int) -> bool:
	var result = _try_place_obstacle(_sel_type, _sel_name, x, y, _sel_w, _sel_h)
	if not bool(result.get("ok", false)):
		_status(str(result.get("message", "")))
		return false
	return true

func _try_place_obstacle(type: String, name: String, x: int, y: int, w: int, h: int) -> Dictionary:
	var inst = _obstacle_inst(type, name, x, y, w, h)
	if not _obstacle_in_bounds(inst):
		return {"ok": false, "message": "Out of bounds"}
	if not _can_place_obstacle(inst, _grid_o):
		return {"ok": false, "message": "Cell occupied"}
	var id = _obs_inst.size()
	_obs_inst.append(inst)
	_mark_obstacle(inst, id, _grid_o)
	return {"ok": true, "message": ""}

func _obstacle_in_bounds(inst: Dictionary) -> bool:
	var x = _inst_x(inst)
	var y = _inst_y(inst)
	return x >= 0 and y >= 0 and x + _inst_w(inst) <= _mw and y + _inst_h(inst) <= _mh

func _can_place_obstacle(inst: Dictionary, grid: Array) -> bool:
	if not _obstacle_in_bounds(inst):
		return false
	for dy in _inst_h(inst):
		for dx in _inst_w(inst):
			if grid[_inst_y(inst) + dy][_inst_x(inst) + dx] >= 0:
				return false
	return true

func _mark_obstacle(inst: Dictionary, id: int, grid: Array) -> void:
	for dy in _inst_h(inst):
		for dx in _inst_w(inst):
			grid[_inst_y(inst) + dy][_inst_x(inst) + dx] = id

func _erase_at(x: int, y: int) -> void:
	if x < 0 or x >= _mw or y < 0 or y >= _mh:
		return
	if _layer == 0:
		if _grid_f[y][x] != null:
			_grid_f[y][x] = null
			_dirty = true
			_grid_draw.queue_redraw()
	else:
		var id = _grid_o[y][x]
		if id >= 0 and id < _obs_inst.size() and _obs_inst[id] != null:
			var inst = _obs_inst[id]
			for dy in _inst_h(inst):
				for dx in _inst_w(inst):
					_grid_o[_inst_y(inst) + dy][_inst_x(inst) + dx] = -1
			_obs_inst[id] = null
			_dirty = true
			_grid_draw.queue_redraw()

func _do_rect_fill(x1: int, y1: int, x2: int, y2: int) -> void:
	if _sel_name == "":
		_status("No element selected")
		return
	var minx = clampi(min(x1, x2), 0, _mw - 1)
	var maxx = clampi(max(x1, x2), 0, _mw - 1)
	var miny = clampi(min(y1, y2), 0, _mh - 1)
	var maxy = clampi(max(y1, y2), 0, _mh - 1)

	if _layer == 0:
		for y in range(miny, maxy + 1):
			for x in range(minx, maxx + 1):
				_grid_f[y][x] = _floor_cell(_sel_type, _sel_name)
	else:
		for y in range(miny, maxy + 1):
			for x in range(minx, maxx + 1):
				if _grid_o[y][x] < 0:
					_try_place_obstacle(_sel_type, _sel_name, x, y, _sel_w, _sel_h)

	_dirty = true
	_grid_draw.queue_redraw()

# === File I/O ===

func _on_new() -> void:
	_request_unsaved_action("new")

func _create_new_map() -> void:
	_loading = true
	_map_name = "NewMap"
	_current_path = ""
	_mw = 25
	_mh = 13
	_scroll = Vector2i(5, 0)
	_music = ""
	_begin = Vector2i(0, 0)
	_finish = Vector2i(0, 0)
	_obs_inst.clear()
	_resize_grid()
	for y in _mh:
		for x in _mw:
			_grid_f[y][x] = null
			_grid_o[y][x] = -1
	_grid_draw.queue_redraw()
	_dirty = false
	_clear_tex_cache()
	_sync_toolbar()
	_loading = false
	_status("New map created")

func _on_save() -> void:
	if _map_name == "":
		_map_name = "untitled"
	if _current_path != "":
		_on_save_file(_current_path)
		return
	_open_save_dialog()

func _on_save_as() -> void:
	if _map_name == "":
		_map_name = "untitled"
	_open_save_dialog()

func _open_save_dialog() -> void:
	_save_mode = true
	_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_file_dialog.clear_filters()
	_file_dialog.add_filter("*.json", "Map JSON")
	_file_dialog.current_file = _current_path.get_file() if _current_path != "" else _map_name.replace(" ", "") + ".json"
	_file_dialog.current_dir = ProjectSettings.globalize_path("res://assets/map/")
	_file_dialog.popup_centered(Vector2i(600, 400))

func _on_save_file(path: String) -> void:
	path = _normalize_json_path(path)
	var data = _build_json()
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_status("Failed to save: " + path)
		return
	var json_string = JSON.stringify(data, "\t", true, 0)
	file.store_string(json_string)
	file.close()
	_current_path = path
	_dirty = false
	if _map_catalog != null:
		_map_catalog.reload()
	_status("Saved: " + path)
	_run_save_after_action()

func _on_load() -> void:
	_request_unsaved_action("load")

func _open_load_dialog() -> void:
	_save_mode = false
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.clear_filters()
	_file_dialog.add_filter("*.json", "Map JSON")
	_file_dialog.current_dir = ProjectSettings.globalize_path("res://assets/map/")
	_file_dialog.popup_centered(Vector2i(600, 400))

func _on_file_selected(path: String) -> void:
	if _save_mode:
		_on_save_file(path)
	else:
		_on_load_file(path)

func _on_file_dialog_canceled() -> void:
	_save_after_action = ""
	_status("File action canceled")

func _on_load_file(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_status("Failed to load: " + path)
		return
	var json = JSON.parse_string(file.get_as_text())
	file.close()
	if json == null or typeof(json) != TYPE_DICTIONARY:
		_status("Invalid JSON")
		return
	_load_from_json(json)
	_current_path = path
	_status("Loaded: " + path)

func _on_back() -> void:
	_request_unsaved_action("exit")

func _exit_editor() -> void:
	var game = get_node_or_null("/root/Game")
	if game != null and game.has_method("_return_to_title"):
		game._return_to_title()
	else:
		get_tree().change_scene_to_file("res://main.tscn")
	queue_free()

func _request_unsaved_action(action: String) -> void:
	if not _dirty:
		_execute_pending_action(action)
		return
	_pending_action = action
	_unsaved_dialog.dialog_text = "Save changes to %s before %s?" % [_map_name, _action_label(action)]
	_unsaved_dialog.popup_centered(Vector2i(420, 170))

func _on_unsaved_save() -> void:
	_save_after_action = _pending_action
	_pending_action = ""
	_on_save()

func _on_unsaved_discard() -> void:
	var action = _pending_action
	_pending_action = ""
	_save_after_action = ""
	_dirty = false
	_unsaved_dialog.hide()
	_execute_pending_action(action)

func _execute_pending_action(action: String) -> void:
	match action:
		"new":
			_create_new_map()
		"load":
			_open_load_dialog()
		"exit":
			_exit_editor()

func _run_save_after_action() -> void:
	if _save_after_action == "":
		return
	var action = _save_after_action
	_save_after_action = ""
	_execute_pending_action(action)

func _normalize_json_path(path: String) -> String:
	return path if path.to_lower().ends_with(".json") else path + ".json"

func _action_label(action: String) -> String:
	match action:
		"new":
			return "creating a new map"
		"load":
			return "opening another map"
		"exit":
			return "exiting"
	return "continuing"

func _build_json() -> Dictionary:
	var data = {
		"basic": {
			"name": _map_name,
			"width": _mw,
			"height": _mh,
			"scroll": [_scroll.x, _scroll.y],
			"music": _music,
			"begin": [_begin.x, _begin.y],
			"finish": [_finish.x, _finish.y]
		},
		"floors": [],
		"floor": [],
		"obstacles": [],
		"obstacle": [],
		"districts": []
	}

	var floor_rects = _merge_rects(0)
	data.floors = floor_rects[0]
	data.floor = floor_rects[1]

	var obs_rects = _merge_rects(1)
	data.obstacles = obs_rects[0]
	data.obstacle = obs_rects[1]

	return data

func _merge_rects(layer: int) -> Array:
	var rects: Array = []
	var singles: Array = []

	if layer == 0:
		var visited = []
		visited.resize(_mh)
		for y in _mh:
			visited[y] = []
			visited[y].resize(_mw)
			for x in _mw:
				visited[y][x] = false

		for sy in _mh:
			for sx in _mw:
				if visited[sy][sx]:
					continue
				var cell = _grid_f[sy][sx]
				if cell == null:
					visited[sy][sx] = true
					continue

				var rw = 0
				for x in range(sx, _mw):
					if visited[sy][x] or not _same_floor_cell(cell, _grid_f[sy][x]):
						break
					rw += 1

				var rh = 1
				for y in range(sy + 1, _mh):
					var row_ok = true
					for x in range(sx, sx + rw):
						if visited[y][x] or not _same_floor_cell(cell, _grid_f[y][x]):
							row_ok = false
							break
					if not row_ok:
						break
					rh += 1

				if rw > 1 or rh > 1:
					rects.append({
						"type": cell.get("type", ""),
						"name": cell.get("name", ""),
						"squares": [{"x1": sx, "y1": sy, "x2": sx + rw - 1, "y2": sy + rh - 1}]
					})
					for y in range(sy, sy + rh):
						for x in range(sx, sx + rw):
							visited[y][x] = true
				else:
					visited[sy][sx] = true
					singles.append({
						"type": cell.get("type", ""),
						"name": cell.get("name", ""),
						"points": [{"x": sx, "y": sy}]
					})

		singles = _merge_points(singles)
	else:
		for inst in _obs_inst:
			if inst == null or typeof(inst) != TYPE_DICTIONARY:
				continue
			singles.append({
				"type": _inst_type(inst),
				"name": _inst_name(inst),
				"points": [{"x": _inst_x(inst), "y": _inst_y(inst)}]
			})
		singles = _merge_points(singles)

	return [rects, singles]

func _same_floor_cell(a: Variant, b: Variant) -> bool:
	if a == null or b == null or typeof(a) != TYPE_DICTIONARY or typeof(b) != TYPE_DICTIONARY:
		return false
	return a.get("type", "") == b.get("type", "") and a.get("name", "") == b.get("name", "")

func _merge_points(singles: Array) -> Array:
	var grouped := {}
	var order: Array = []
	for entry in singles:
		if entry == null or typeof(entry) != TYPE_DICTIONARY:
			continue
		var type = str(entry.get("type", ""))
		var name = str(entry.get("name", ""))
		var key = type + "\n" + name
		if not grouped.has(key):
			grouped[key] = {"type": type, "name": name, "points": []}
			order.append(key)
		for point in entry.get("points", []):
			grouped[key]["points"].append(point)
	var out: Array = []
	for key in order:
		out.append(grouped[key])
	return out

func _load_from_json(json: Dictionary) -> void:
	_loading = true

	var basic = json.get("basic", {})
	_map_name = basic.get("name", "Map")
	_mw = max(1, int(basic.get("width", 25)))
	_mh = max(1, int(basic.get("height", 13)))
	_scroll = _array_to_vec2i(basic.get("scroll", [5, 0]), Vector2i(5, 0))
	_music = basic.get("music", "")
	_begin = _array_to_vec2i(basic.get("begin", [0, 0]), Vector2i.ZERO)
	_finish = _array_to_vec2i(basic.get("finish", [0, 0]), Vector2i.ZERO)

	_obs_inst.clear()
	_resize_grid()

	for y in _mh:
		for x in _mw:
			_grid_f[y][x] = null
			_grid_o[y][x] = -1

	for entry in json.get("floors", []):
		var t = str(entry.get("type", ""))
		var n = str(entry.get("name", ""))
		for sq in entry.get("squares", []):
			var x1 = int(sq.get("x1", 0))
			var y1 = int(sq.get("y1", 0))
			var x2 = int(sq.get("x2", x1))
			var y2 = int(sq.get("y2", y1))
			for y in range(y1, y2 + 1):
				for x in range(x1, x2 + 1):
					if y >= 0 and y < _mh and x >= 0 and x < _mw:
						_grid_f[y][x] = _floor_cell(t, n)

	for entry in json.get("floor", []):
		var t = str(entry.get("type", ""))
		var n = str(entry.get("name", ""))
		for pt in entry.get("points", []):
			var x = int(pt.get("x", 0))
			var y = int(pt.get("y", 0))
			if y >= 0 and y < _mh and x >= 0 and x < _mw:
				_grid_f[y][x] = _floor_cell(t, n)

	for entry in json.get("obstacles", []):
		var t = str(entry.get("type", ""))
		var n = str(entry.get("name", ""))
		for sq in entry.get("squares", []):
			var x1 = int(sq.get("x1", 0))
			var y1 = int(sq.get("y1", 0))
			var x2 = int(sq.get("x2", x1))
			var y2 = int(sq.get("y2", y1))
			var size = _get_obstacle_size(t, n)
			for y in range(y1, y2 + 1):
				for x in range(x1, x2 + 1):
					if y >= 0 and y < _mh and x >= 0 and x < _mw and _grid_o[y][x] < 0:
						_try_place_obstacle(t, n, x, y, size.x, size.y)

	for entry in json.get("obstacle", []):
		var t = str(entry.get("type", ""))
		var n = str(entry.get("name", ""))
		for pt in entry.get("points", []):
			var x = int(pt.get("x", 0))
			var y = int(pt.get("y", 0))
			if y >= 0 and y < _mh and x >= 0 and x < _mw and _grid_o[y][x] < 0:
				var size = _get_obstacle_size(t, n)
				_try_place_obstacle(t, n, x, y, size.x, size.y)

	_grid_draw.queue_redraw()
	_loading = false
	_dirty = false
	_clear_tex_cache()
	_sync_toolbar()

func _status(msg: String) -> void:
	if _status_label != null:
		_status_label.text = msg

func _sync_toolbar() -> void:
	var was_loading = _loading
	_loading = true
	_clamp_markers()
	_sync_marker_limits()
	_name_edit.text = _map_name
	_w_spin.set_value_no_signal(_mw)
	_h_spin.set_value_no_signal(_mh)
	_bx_spin.set_value_no_signal(_begin.x)
	_by_spin.set_value_no_signal(_begin.y)
	_fx_spin.set_value_no_signal(_finish.x)
	_fy_spin.set_value_no_signal(_finish.y)
	_loading = was_loading

# === Import ===

func _on_import() -> void:
	if _pal_type_order.size() == 0:
		_status("No types available")
		return
	_import_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
	_import_dialog.popup_centered(Vector2i(600, 400))

func _on_import_files(paths: PackedStringArray) -> void:
	if paths.size() == 0:
		return
	var target_dir = ProjectSettings.globalize_path(IMG_ROOT + "mapElem/" + _sel_type + "/")
	if not DirAccess.dir_exists_absolute(target_dir):
		DirAccess.make_dir_recursive_absolute(target_dir)
	var count = 0
	for src in paths:
		var filename = src.get_file()
		if not filename.to_lower().ends_with(".png"):
			continue
		var dst = target_dir + filename
		if DirAccess.copy_absolute(src, dst) == OK:
			count += 1
	if count > 0:
		_status("Imported %d file(s) to %s" % [count, _sel_type])
		_clear_tex_cache()
		_scan_elements()
	else:
		_status("No files imported")
