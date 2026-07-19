extends Control

var _cell: int = 40
const PAL_W = 200
const IMG_ROOT = "res://assets/img/"
const FRAME_ROOT = "res://assets/frame/"

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

var _name_edit: LineEdit
var _w_spin: SpinBox
var _h_spin: SpinBox
var _bx_spin: SpinBox
var _by_spin: SpinBox
var _fx_spin: SpinBox
var _fy_spin: SpinBox

var _set_marker_mode: int = -1
var _tex_cache: Dictionary = {}
var _zoom: float = 1.0
var _main_vb: VBoxContainer

func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	_build_ui()
	_scan_elements()
	_resize_grid()
	call_deferred("_calc_cell_size")
	_update_preview()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		if _main_vb != null:
			_main_vb.size = size
		if _grid_draw != null:
			_calc_cell_size()
			_grid_draw.queue_redraw()

func _build_ui() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0

	var main_vb = VBoxContainer.new()
	main_vb.anchors_preset = PRESET_FULL_RECT
	main_vb.size = size
	add_child(main_vb)
	_main_vb = main_vb

	# ========== Toolbar ==========
	var tb = HBoxContainer.new()
	tb.add_theme_constant_override("separation", 6)
	main_vb.add_child(tb)

	var tl = Label.new()
	tl.text = "MAP EDITOR"
	tl.add_theme_font_size_override("font_size", 16)
	tl.add_theme_color_override("font_color", Color(0.8, 0.85, 1.0))
	tb.add_child(tl)

	tb.add_child(Control.new())  # spacer

	_make_btn(tb, "Save", _on_save)
	_make_btn(tb, "Load", _on_load)
	_make_btn(tb, "New", _on_new)
	tb.add_child(VSeparator.new())
	_make_btn(tb, "Back", _on_back)
	tb.add_child(VSeparator.new())
	_make_btn(tb, "+", func(): _zoom *= 1.25; _calc_cell_size(); _grid_draw.queue_redraw())
	_make_btn(tb, "-", func(): _zoom = max(0.25, _zoom * 0.8); _calc_cell_size(); _grid_draw.queue_redraw())

	# ========== Map settings row ==========
	var sr = HBoxContainer.new()
	sr.add_theme_constant_override("separation", 6)
	main_vb.add_child(sr)

	var name_lbl = Label.new()
	name_lbl.text = "Name"
	sr.add_child(name_lbl)
	_name_edit = LineEdit.new()
	_name_edit.custom_minimum_size.x = 140
	_name_edit.text_changed.connect(func(t): _map_name = t; _dirty = true)
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
	_bx_spin.value_changed.connect(func(v): _begin.x = int(v); _dirty = true; _grid_draw.queue_redraw())
	sr.add_child(_bx_spin)
	_by_spin = SpinBox.new()
	_by_spin.min_value = 0
	_by_spin.max_value = 199
	_by_spin.value = _begin.y
	_by_spin.custom_minimum_size.x = 42
	_by_spin.value_changed.connect(func(v): _begin.y = int(v); _dirty = true; _grid_draw.queue_redraw())
	sr.add_child(_by_spin)
	var set_e_btn: Button = null
	var set_s_btn = Button.new()
	set_s_btn.text = "Set"
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
	_fx_spin.value_changed.connect(func(v): _finish.x = int(v); _dirty = true; _grid_draw.queue_redraw())
	sr.add_child(_fx_spin)
	_fy_spin = SpinBox.new()
	_fy_spin.min_value = 0
	_fy_spin.max_value = 199
	_fy_spin.value = _finish.y
	_fy_spin.custom_minimum_size.x = 42
	_fy_spin.value_changed.connect(func(v): _finish.y = int(v); _dirty = true; _grid_draw.queue_redraw())
	sr.add_child(_fy_spin)
	set_e_btn = Button.new()
	set_e_btn.text = "Set"
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
	left.custom_minimum_size.x = 220
	left.size_flags_vertical = SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 4)
	mid.add_child(left)

	# -- Layer --
	var sec1 = _make_section(left, "Layer")
	var lh = HBoxContainer.new()
	var layer_group = ButtonGroup.new()
	_make_toggle(lh, "Floor", true, func(on): if on: _set_layer(0), layer_group)
	_make_toggle(lh, "Obstacle", false, func(on): if on: _set_layer(1), layer_group)
	sec1.add_child(lh)

	# -- Tool --
	var sec2 = _make_section(left, "Tool")
	var th = HBoxContainer.new()
	var tool_group = ButtonGroup.new()
	_make_toggle(th, "Paint", true, func(on): if on: _set_tool(0), tool_group)
	_make_toggle(th, "Erase", false, func(on): if on: _set_tool(1), tool_group)
	_make_toggle(th, "Fill", false, func(on): if on: _set_tool(2), tool_group)
	sec2.add_child(th)

	# -- Element --
	var sec3 = _make_section(left, "Element")
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
	imp_btn.text = "+ Import"
	imp_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	imp_btn.pressed.connect(_on_import)
	sec3.add_child(imp_btn)

	# -- Preview --
	_preview_rect = TextureRect.new()
	_preview_rect.custom_minimum_size = Vector2(_cell + 8, _cell + 8)
	_preview_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview_rect.expand_mode = TextureRect.EXPAND_KEEP_SIZE
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
	_file_dialog.hide()
	add_child(_file_dialog)

	_import_dialog = FileDialog.new()
	_import_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	_import_dialog.add_filter("*.png", "PNG Image")
	_import_dialog.files_selected.connect(_on_import_files)
	_import_dialog.hide()
	add_child(_import_dialog)

	_grid_draw.mouse_entered.connect(func(): _grid_draw.queue_redraw())
	_grid_draw.mouse_exited.connect(func(): _hover = Vector2i(-1, -1); _grid_draw.queue_redraw())

func _make_btn(parent: Control, text: String, fn: Callable) -> Button:
	var b = Button.new()
	b.text = text
	b.pressed.connect(fn)
	parent.add_child(b)
	return b

func _make_toggle(parent: Control, text: String, on: bool, fn: Callable, group: ButtonGroup = null) -> Button:
	var b = Button.new()
	b.text = text
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
	_status("Layer: " + ("Floor" if l == 0 else "Obstacle"))

func _set_tool(t: int) -> void:
	_tool = t
	_rect_origin = Vector2i(-1, -1)
	_set_marker_mode = -1
	_status("Tool: " + ["Paint �?left click to place", "Erase �?left click to remove", "Fill �?click two corners"][t])

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
	var ow = _mw
	var oh = _mh
	_mw = w
	_mh = h
	_resize_grid(true)
	_status("Size: %d x %d" % [w, h])

func _resize_grid(recalc: bool = false) -> void:
	var old_h = _grid_f.size()
	var old_w = _grid_f[0].size() if old_h > 0 else 0

	if recalc:
		_grid_f.resize(_mh)
		_grid_o.resize(_mh)
		for y in _mh:
			if _grid_f[y] == null or _grid_f[y].size() != _mw:
				_grid_f[y] = []
				_grid_f[y].resize(_mw)
			if _grid_o[y] == null or _grid_o[y].size() != _mw:
				_grid_o[y] = []
				_grid_o[y].resize(_mw)
			for x in _mw:
				if y >= old_h or x >= old_w:
					_grid_f[y][x] = null
					_grid_o[y][x] = -1

	_grid_f.resize(_mh)
	_grid_o.resize(_mh)
	for y in _mh:
		if _grid_f[y] == null or _grid_f[y].size() != _mw:
			_grid_f[y] = []
			_grid_f[y].resize(_mw)
		if _grid_o[y] == null or _grid_o[y].size() != _mw:
			_grid_o[y] = []
			_grid_o[y].resize(_mw)
		for x in _mw:
			if _grid_o[y][x] == null:
				_grid_o[y][x] = -1

	_calc_cell_size()
	_grid_draw.queue_redraw()

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
	_scan_floor_elements()
	_scan_obstacle_elements()
	_populate_element_list()

func _scan_floor_elements() -> void:
	_pal_floor.clear()
	var da = DirAccess.open(IMG_ROOT + "mapElem")
	if da == null: return
	da.list_dir_begin()
	var t = da.get_next()
	while t != "":
		if da.current_is_dir() and not t.begins_with("."):
			var sub = DirAccess.open(IMG_ROOT + "mapElem/" + t)
			if sub:
				var names: Array = []
				sub.list_dir_begin()
				var fn = sub.get_next()
				while fn != "":
					if fn.ends_with(".png") or fn.ends_with(".import"):
						fn = fn.trim_suffix(".import")
						if fn.ends_with(".png"):
							fn = fn.trim_suffix(".png").trim_suffix(".png")
							var frame_keywords = ["_stand_", "_die_", "_trigger_", "_push_"]
							var base = fn
							for kw in frame_keywords:
								var idx = fn.find(kw)
								if idx != -1:
									base = fn.substr(0, idx)
									break
							if not names.has(base):
								names.append(base)
					fn = sub.get_next()
				sub.list_dir_end()
				names.sort()
				_pal_floor[t] = names
		t = da.get_next()
	da.list_dir_end()

func _scan_obstacle_elements() -> void:
	_pal_obs.clear()
	var da = DirAccess.open(FRAME_ROOT + "obstacle")
	if da == null: return
	da.list_dir_begin()
	var t = da.get_next()
	while t != "":
		if da.current_is_dir() and not t.begins_with("."):
			var sub = DirAccess.open(FRAME_ROOT + "obstacle/" + t)
			if sub:
				var names: Array = []
				sub.list_dir_begin()
				var fn = sub.get_next()
				while fn != "":
					if fn.ends_with(".json"):
						names.append(fn.trim_suffix(".json"))
					fn = sub.get_next()
				sub.list_dir_end()
				names.sort()
				_pal_obs[t] = names
		t = da.get_next()
	da.list_dir_end()

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
	tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
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
		var path = FRAME_ROOT + "obstacle/" + _sel_type + "/" + _sel_name + ".json"
		var json = RM.get_json(path)
		if json != null and typeof(json) == TYPE_DICTIONARY:
			_sel_w = int(json.get("WIDTH", 1))
			_sel_h = int(json.get("HEIGHT", 1))
	_update_preview()
	_status("Selected: %s/%s [%dx%d]" % [_sel_type, _sel_name, _sel_w, _sel_h])

func _update_preview() -> void:
	var tex: Texture2D = null
	if _sel_name == "":
		_preview_rect.texture = null
		return
	if _layer == 0:
		tex = _try_load_texture(IMG_ROOT + "mapElem/" + _sel_type + "/" + _sel_name + ".png")
	elif _layer == 1:
		var path = FRAME_ROOT + "obstacle/" + _sel_type + "/" + _sel_name + ".json"
		var json = RM.get_json(path)
		if json != null and typeof(json) == TYPE_DICTIONARY:
			var imgs = json.get("STAND", {}).get("IMG", [])
			if imgs.size() > 0:
				tex = _try_load_texture(IMG_ROOT + "mapElem/" + _sel_type + "/" + imgs[0])
	_preview_rect.texture = tex

func _try_load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return ResourceLoader.load(path)
	return null

func _get_tex(layer: int, type: String, name: String) -> Texture2D:
	var key = str(layer) + "/" + type + "/" + name
	if _tex_cache.has(key):
		return _tex_cache[key]
	var tex: Texture2D = null
	if layer == 0:
		tex = _try_load_texture(IMG_ROOT + "mapElem/" + type + "/" + name + ".png")
	elif layer == 1:
		var path = FRAME_ROOT + "obstacle/" + type + "/" + name + ".json"
		var json = RM.get_json(path)
		if json != null and typeof(json) == TYPE_DICTIONARY:
			var imgs = json.get("STAND", {}).get("IMG", [])
			if imgs.size() > 0:
				tex = _try_load_texture(IMG_ROOT + "mapElem/" + type + "/" + imgs[0])
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
				var tex = _get_tex(0, f.type, f.name)
				if tex:
					draw.draw_texture_rect(tex, Rect2(x * _cell, y * _cell, _cell, _cell), false)
				else:
					var cr = Rect2(x * _cell + 1, y * _cell + 1, _cell - 2, _cell - 2)
					var col = _name_color(f.name, 0.6, 0.5)
					col.a = 0.7
					draw.draw_rect(cr, col)

	for y in _mh:
		for x in _mw:
			var oid = _grid_o[y][x]
			if oid >= 0 and oid < _obs_inst.size() and _obs_inst[oid] != null:
				var inst = _obs_inst[oid]
				if inst.x == x and inst.y == y:
					var w = inst.w
					var h = inst.h
					var tex = _get_tex(1, inst.type, inst.name)
					if tex:
						draw.draw_texture_rect(tex, Rect2(x * _cell, y * _cell, _cell, _cell), false)
						draw.draw_rect(Rect2(x * _cell, y * _cell, w * _cell, h * _cell), Color(1, 1, 1, 0.15), false, 1.0)
					else:
						var col = _name_color(inst.name, 0.7, 0.6)
						col.a = 0.85
						draw.draw_rect(Rect2(x * _cell + 1, y * _cell + 1, w * _cell - 2, h * _cell - 2), col, false, 2.0)
						draw.draw_rect(Rect2(x * _cell + 3, y * _cell + 3, w * _cell - 6, h * _cell - 6), Color(col.r * 0.6, col.g * 0.6, col.b * 0.6, 0.4))
					var cx = (x + 0.5 * w) * _cell
					var cy = (y + 0.5 * h) * _cell
					var abbr = inst.name.trim_prefix("elem")
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
	if _sel_name == "":
		_status("No element selected")
		return

	if _tool == 1:
		_erase_at(x, y)
		return

	if _layer == 0:
		_grid_f[y][x] = {"type": _sel_type, "name": _sel_name}
	else:
		_place_obstacle(x, y)

	_dirty = true
	_grid_draw.queue_redraw()

func _place_obstacle(x: int, y: int) -> void:
	if x + _sel_w > _mw or y + _sel_h > _mh:
		_status("Out of bounds")
		return
	for dy in _sel_h:
		for dx in _sel_w:
			if _grid_o[y + dy][x + dx] >= 0:
				_status("Cell occupied")
				return

	var id = _obs_inst.size()
	var inst = {"type": _sel_type, "name": _sel_name, "x": x, "y": y, "w": _sel_w, "h": _sel_h}
	_obs_inst.append(inst)
	for dy in _sel_h:
		for dx in _sel_w:
			_grid_o[y + dy][x + dx] = id

func _erase_at(x: int, y: int) -> void:
	if _layer == 0:
		if _grid_f[y][x] != null:
			_grid_f[y][x] = null
			_dirty = true
			_grid_draw.queue_redraw()
	else:
		var id = _grid_o[y][x]
		if id >= 0 and id < _obs_inst.size() and _obs_inst[id] != null:
			var inst = _obs_inst[id]
			for dy in inst.h:
				for dx in inst.w:
					_grid_o[inst.y + dy][inst.x + dx] = -1
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
				_grid_f[y][x] = {"type": _sel_type, "name": _sel_name}
	else:
		for y in range(miny, maxy + 1):
			for x in range(minx, maxx + 1):
				if _grid_o[y][x] < 0:
					var id = _obs_inst.size()
					_obs_inst.append({"type": _sel_type, "name": _sel_name, "x": x, "y": y, "w": 1, "h": 1})
					_grid_o[y][x] = id

	_dirty = true
	_grid_draw.queue_redraw()

# === File I/O ===

func _on_new() -> void:
	_map_name = "NewMap"
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
	_status("New map created")

func _on_save() -> void:
	if _map_name == "":
		_map_name = "untitled"
	_save_mode = true
	_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_file_dialog.add_filter("*.json", "Map JSON")
	_file_dialog.current_file = _map_name.replace(" ", "") + ".json"
	_file_dialog.current_dir = ProjectSettings.globalize_path("res://assets/map/")
	_file_dialog.popup_centered(Vector2i(600, 400))

func _on_save_file(path: String) -> void:
	var data = _build_json()
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_status("Failed to save: " + path)
		return
	var json_string = JSON.stringify(data, "\t", true, 0)
	file.store_string(json_string)
	file.close()
	_dirty = false
	_status("Saved: " + path)

func _on_load() -> void:
	_save_mode = false
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.add_filter("*.json", "Map JSON")
	_file_dialog.current_dir = ProjectSettings.globalize_path("res://assets/map/")
	_file_dialog.popup_centered(Vector2i(600, 400))

func _on_file_selected(path: String) -> void:
	if _save_mode:
		_on_save_file(path)
	else:
		_on_load_file(path)

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
	_status("Loaded: " + path)

func _on_back() -> void:
	if _dirty:
		_status("Unsaved changes! Save first.")
		return
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(800, 600)
	Game._return_to_title()
	queue_free()

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
				if visited[sy][sx]: continue
				var cell = _grid_f[sy][sx]
				if cell == null:
					visited[sy][sx] = true
					continue

				var max_x = _mw
				var max_y = _mh
				for y in range(sy, _mh):
					var row_ok = true
					for x in range(sx, _mw):
						if _grid_f[y][x] == null or _grid_f[y][x].name != cell.name or _grid_f[y][x].type != cell.type:
							row_ok = false
							max_x = min(max_x, x)
							break
					if not row_ok:
						max_y = y
						break
					else:
						max_x = min(max_x, _mw)

				var rw = max_x - sx
				var rh = max_y - sy
				if rw > 1 or rh > 1:
					rects.append({
						"type": cell.type,
						"name": cell.name,
						"squares": [{"x1": sx, "y1": sy, "x2": sx + rw - 1, "y2": sy + rh - 1}]
					})
					for y in range(sy, sy + rh):
						for x in range(sx, sx + rw):
							visited[y][x] = true
				else:
					visited[sy][sx] = true
					singles.append({
						"type": cell.type,
						"name": cell.name,
						"points": [{"x": sx, "y": sy}]
					})

		singles = _merge_points(singles)
	else:
		var visited = []
		visited.resize(_mh)
		for y in _mh:
			visited[y] = []
			visited[y].resize(_mw)
			for x in _mw:
				visited[y][x] = false

		for sy in _mh:
			for sx in _mw:
				if visited[sy][sx]: continue
				var oid = _grid_o[sy][sx]
				if oid < 0 or oid >= _obs_inst.size() or _obs_inst[oid] == null:
					if oid >= 0: visited[sy][sx] = true
					continue
				var inst = _obs_inst[oid]
				if inst.x != sx or inst.y != sy:
					visited[sy][sx] = true
					continue

				if inst.w > 1 or inst.h > 1:
					rects.append({
						"type": inst.type,
						"name": inst.name,
						"squares": [{"x1": inst.x, "y1": inst.y, "x2": inst.x + inst.w - 1, "y2": inst.y + inst.h - 1}]
					})
					for dy in inst.h:
						for dx in inst.w:
							visited[inst.y + dy][inst.x + dx] = true
				else:
					visited[sy][sx] = true
					singles.append({
						"type": inst.type,
						"name": inst.name,
						"points": [{"x": sx, "y": sy}]
					})

		singles = _merge_points(singles)

	return [rects, singles]

func _merge_points(singles: Array) -> Array:
	return singles

func _load_from_json(json: Dictionary) -> void:
	_loading = true

	var basic = json.get("basic", {})
	_map_name = basic.get("name", "Map")
	_mw = basic.get("width", 25)
	_mh = basic.get("height", 13)
	_scroll = Vector2i(basic.get("scroll", [5, 0]))
	_music = basic.get("music", "")
	var b = basic.get("begin", [0, 0])
	_begin = Vector2i(b[0] if b.size() > 0 else 0, b[1] if b.size() > 1 else 0)
	var f = basic.get("finish", [0, 0])
	_finish = Vector2i(f[0] if f.size() > 0 else 0, f[1] if f.size() > 1 else 0)

	_obs_inst.clear()
	_resize_grid()

	for y in _mh:
		for x in _mw:
			_grid_f[y][x] = null
			_grid_o[y][x] = -1

	for entry in json.get("floors", []):
		var t = entry.get("type", "")
		var n = entry.get("name", "")
		for sq in entry.get("squares", []):
			var x1 = sq.get("x1", 0)
			var y1 = sq.get("y1", 0)
			var x2 = sq.get("x2", x1)
			var y2 = sq.get("y2", y1)
			for y in range(y1, y2 + 1):
				for x in range(x1, x2 + 1):
					if y < _mh and x < _mw:
						_grid_f[y][x] = {"type": t, "name": n}

	for entry in json.get("floor", []):
		var t = entry.get("type", "")
		var n = entry.get("name", "")
		for pt in entry.get("points", []):
			var x = pt.get("x", 0)
			var y = pt.get("y", 0)
			if y < _mh and x < _mw:
				_grid_f[y][x] = {"type": t, "name": n}

	for entry in json.get("obstacles", []):
		var t = entry.get("type", "")
		var n = entry.get("name", "")
		for sq in entry.get("squares", []):
			var x1 = sq.get("x1", 0)
			var y1 = sq.get("y1", 0)
			var x2 = sq.get("x2", x1)
			var y2 = sq.get("y2", y1)

			var oid = _obs_inst.size()
			_obs_inst.append({"type": t, "name": n, "x": x1, "y": y1, "w": x2 - x1 + 1, "h": y2 - y1 + 1})
			for y in range(y1, y2 + 1):
				for x in range(x1, x2 + 1):
					if y < _mh and x < _mw:
						_grid_o[y][x] = oid

	for entry in json.get("obstacle", []):
		var t = entry.get("type", "")
		var n = entry.get("name", "")
		for pt in entry.get("points", []):
			var x = pt.get("x", 0)
			var y = pt.get("y", 0)
			if y < _mh and x < _mw and _grid_o[y][x] < 0:
				var oid = _obs_inst.size()
				_obs_inst.append({"type": t, "name": n, "x": x, "y": y, "w": 1, "h": 1})
				_grid_o[y][x] = oid

	_grid_draw.queue_redraw()
	_loading = false
	_dirty = false
	_clear_tex_cache()
	_sync_toolbar()

func _status(msg: String) -> void:
	_status_label.text = msg

func _sync_toolbar() -> void:
	_name_edit.text = _map_name
	_w_spin.value = _mw
	_h_spin.value = _mh
	_bx_spin.value = _begin.x
	_by_spin.value = _begin.y
	_fx_spin.value = _finish.x
	_fy_spin.value = _finish.y

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
