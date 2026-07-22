class_name CharacterEditorUI
extends RefCounted

var _editor

func _init(editor):
	_editor = editor

func clear_container(c: Node) -> void:
	for ch in c.get_children():
		c.remove_child(ch)
		ch.queue_free()

func add_tab(name: String, tab_container: TabContainer) -> VBoxContainer:
	var sc = ScrollContainer.new()
	sc.name = name
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var vb = VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 6)
	sc.add_child(vb)
	tab_container.add_child(sc)
	return vb

func add_field(vb: VBoxContainer, label: String, input: Control, label_w: int = 120) -> void:
	var hb = HBoxContainer.new()
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lb = Label.new()
	lb.text = label + ":"
	lb.custom_minimum_size = Vector2(label_w, 24)
	lb.add_theme_font_size_override("font_size", 15)
	lb.add_theme_color_override("font_color", Color(0.85, 0.87, 0.9))
	hb.add_child(lb)
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(input)
	vb.add_child(hb)

func _build_basic_fields(inner: VBoxContainer) -> void:
	var stat_fields = [
		["Name", "name", 0],
		["Blood", "blood", 0],
		["Speed", "speed", 1],
		["Bomb Count", "bomb", 0],
		["Power", "power", 0],
		["Restore (ms)", "restore", 0],
		["Damage", "damage", 0],
		["Defense", "defense", 0],
	]
	for f in stat_fields:
		if f[0] == "Name":
			var le = LineEdit.new()
			le.text = str(_editor._hero.get(f[1], ""))
			le.add_theme_font_size_override("font_size", 14)
			le.text_changed.connect(_editor._on_field_changed.bind(f[1]))
			add_field(inner, f[0], le, 110)
		elif f[2] == 1:
			var sb = SpinBox.new()
			sb.min_value = 0
			sb.max_value = 999.999
			sb.step = 0.01
			sb.value = float(_editor._hero.get(f[1], 0))
			sb.add_theme_font_size_override("font_size", 14)
			sb.value_changed.connect(_editor._on_float_changed.bind(f[1]))
			add_field(inner, f[0], sb, 110)
		else:
			var sb = SpinBox.new()
			sb.min_value = 0
			sb.max_value = 99999
			sb.step = 1
			sb.value = int(_editor._hero.get(f[1], 0))
			sb.add_theme_font_size_override("font_size", 14)
			sb.value_changed.connect(_editor._on_int_changed.bind(f[1]))
			add_field(inner, f[0], sb, 110)

	var hb_bomb = HBoxContainer.new()
	hb_bomb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lb_bomb = Label.new()
	lb_bomb.text = "Bomb Skin:"
	lb_bomb.custom_minimum_size = Vector2(110, 24)
	lb_bomb.add_theme_font_size_override("font_size", 14)
	lb_bomb.add_theme_color_override("font_color", Color(0.85, 0.87, 0.9))
	hb_bomb.add_child(lb_bomb)
	_editor._btn_bomb = Button.new()
	var current_bomb = _editor._hero.get("decorations", {}).get("bomb_skin", "")
	_editor._btn_bomb.text = "none" if current_bomb == "" else current_bomb
	_editor._btn_bomb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_editor._btn_bomb.add_theme_font_size_override("font_size", 13)
	_editor._btn_bomb.pressed.connect(_on_pick_bomb_skin.bind(_editor._btn_bomb))
	hb_bomb.add_child(_editor._btn_bomb)
	inner.add_child(hb_bomb)

func _on_pick_bomb_skin(btn: Button) -> void:
	var skins = HeroData.list_bomb_skins()
	var menu = PopupMenu.new()
	for s in skins:
		menu.add_item(s)
	if skins.size() > 0:
		menu.add_separator()
	menu.add_item("[none]")
	menu.id_pressed.connect(func(id):
		var skin = "" if id >= skins.size() else skins[id]
		_apply_bomb_skin(skin, btn))
	_editor.add_child(menu)
	menu.position = _editor.get_viewport().get_mouse_position()
	menu.popup()

func _apply_bomb_skin(skin: String, btn: Button) -> void:
	if not _editor._hero.has("decorations"):
		_editor._hero["decorations"] = {}
	_editor._hero["decorations"]["bomb_skin"] = skin
	btn.text = skin if skin != "" else "none"
	_editor._dirty = true

var _deco_selected_cat: String = ""
var _deco_color_map = {"body":"Body","foot":"Foot","leg":"Leg","cloth":"Cloth","face":"Face","hair":"Hair","cap":"Cap","ear":"Ear","fpack":"Fpack","npack":"Npack","thadorn":"Thadorn"}
var _deco_skip = ["footprint", "eye_eyeball", "eye_iris", "eye_pupil", "eye_highlight"]

func build_deco_tab(vb: VBoxContainer) -> void:
	clear_container(vb)
	vb.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var hb = HBoxContainer.new()
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var left_sc = ScrollContainer.new()
	left_sc.custom_minimum_size = Vector2(60, 0)
	left_sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left_vb = VBoxContainer.new()
	left_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vb.add_theme_constant_override("separation", 1)

	if _deco_selected_cat == "":
		_deco_selected_cat = _first_valid_cat()

	var basic_btn = Button.new()
	basic_btn.text = "Basic"
	basic_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	basic_btn.flat = true
	basic_btn.add_theme_font_size_override("font_size", 10)
	basic_btn.custom_minimum_size = Vector2(0, 24)
	if _deco_selected_cat == "basic":
		var hl = StyleBoxFlat.new()
		hl.bg_color = Color(0.2, 0.22, 0.26)
		hl.border_width_left = 2
		hl.border_color = Color(0.3, 0.8, 0.3)
		basic_btn.add_theme_stylebox_override("normal", hl)
		basic_btn.add_theme_stylebox_override("hover", hl)
		basic_btn.add_theme_stylebox_override("pressed", hl)
	basic_btn.pressed.connect(_on_deco_cat_select.bind("basic"))
	left_vb.add_child(basic_btn)

	var part_sep = HSeparator.new()
	part_sep.custom_minimum_size = Vector2(0, 2)
	left_vb.add_child(part_sep)

	for cat in _editor.DECO_CATEGORIES:
		if cat in _deco_skip:
			continue
		var valid = HeroData.list_valid_decorations(cat)
		if valid.is_empty():
			continue
		var btn = Button.new()
		btn.text = cat.capitalize()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.flat = true
		btn.add_theme_font_size_override("font_size", 9)
		btn.custom_minimum_size = Vector2(0, 22)
		if cat == _deco_selected_cat:
			var hl = StyleBoxFlat.new()
			hl.bg_color = Color(0.2, 0.22, 0.26)
			hl.border_width_left = 2
			hl.border_color = Color(0.3, 0.8, 0.3)
			btn.add_theme_stylebox_override("normal", hl)
			btn.add_theme_stylebox_override("hover", hl)
			btn.add_theme_stylebox_override("pressed", hl)
		btn.pressed.connect(_on_deco_cat_select.bind(cat))
		left_vb.add_child(btn)

	left_sc.add_child(left_vb)
	hb.add_child(left_sc)

	var sep = VSeparator.new()
	sep.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hb.add_child(sep)

	var right_sc = ScrollContainer.new()
	right_sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var right_vb = VBoxContainer.new()
	right_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vb.add_theme_constant_override("separation", 6)

	if _deco_selected_cat == "basic":
		_build_basic_panel(right_vb)
	elif _deco_selected_cat != "":
		_build_gallery_panel(right_vb, _deco_selected_cat)

	right_sc.add_child(right_vb)
	hb.add_child(right_sc)
	vb.add_child(hb)

func _build_basic_panel(right_vb: VBoxContainer) -> void:
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 8)
	var inner = VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 4)
	_build_basic_fields(inner)
	margin.add_child(inner)
	right_vb.add_child(margin)

func _first_valid_cat() -> String:
	for cat in _editor.DECO_CATEGORIES:
		if cat in _deco_skip:
			continue
		var valid = HeroData.list_valid_decorations(cat)
		if not valid.is_empty():
			return cat
	return ""

func _build_gallery_panel(vb: VBoxContainer, cat: String) -> void:
	var valid = HeroData.list_valid_decorations(cat)
	if valid.is_empty():
		var empty_lb = Label.new()
		empty_lb.text = "No valid variants found"
		empty_lb.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
		vb.add_child(empty_lb)
		return

	var header = Label.new()
	header.text = "Variant Gallery"
	header.add_theme_font_size_override("font_size", 10)
	header.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	vb.add_child(header)

	var grid = GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)

	var current_val = _editor._hero.get("decorations", {}).get(cat, null)
	for v in valid:
		grid.add_child(_make_gallery_item(cat, v, v == current_val))

	vb.add_child(grid)

	if _deco_color_map.has(cat):
		vb.add_child(HSeparator.new())
		_make_color_row(vb, cat, _deco_color_map[cat])

func _on_deco_cat_select(cat: String) -> void:
	_deco_selected_cat = cat
	build_deco_tab(_editor._tab_deco)

func _make_gallery_item(category: String, variant: String, selected: bool) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(56, 62)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.22, 0.26) if selected else Color(0.1, 0.11, 0.14)
	style.border_width_left = 1 if selected else 0
	style.border_width_top = 1 if selected else 0
	style.border_width_right = 1 if selected else 0
	style.border_width_bottom = 1 if selected else 0
	style.border_color = Color(0.3, 0.8, 0.3)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	panel.add_theme_stylebox_override("panel", style)

	var vb = VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vb)

	var tr = TextureRect.new()
	tr.texture = HeroData.get_variant_thumbnail(category, variant)
	tr.custom_minimum_size = Vector2(36, 36)
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(tr)

	var lb = Label.new()
	lb.text = variant
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.add_theme_font_size_override("font_size", 7)
	lb.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(lb)

	panel.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_gallery_select(category, variant))
	return panel

func _make_color_row(inner: VBoxContainer, cat: String, comp_name: String) -> void:
	var existing = _editor._hero.get("colors", {})

	var color_row = HBoxContainer.new()
	color_row.alignment = BoxContainer.ALIGNMENT_CENTER

	var color_lb = Label.new()
	color_lb.text = "Color:"
	color_lb.add_theme_font_size_override("font_size", 10)
	color_lb.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	color_row.add_child(color_lb)

	var current = null
	if existing.has(comp_name):
		var val = existing[comp_name]
		if val is Array:
			current = Color(val[0], val[1], val[2], val[3]) if val.size() >= 4 else Color(val[0], val[1], val[2])

	var picker = ColorPickerButton.new()
	picker.color = current if current != null else Color.WHITE
	picker.custom_minimum_size = Vector2(28, 18)
	picker.color_changed.connect(_on_gallery_color_changed.bind(comp_name))
	color_row.add_child(picker)

	var clear_btn = Button.new()
	clear_btn.text = "X"
	clear_btn.custom_minimum_size = Vector2(18, 18)
	clear_btn.add_theme_font_size_override("font_size", 9)
	clear_btn.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	clear_btn.pressed.connect(_on_gallery_color_clear.bind(comp_name, picker))
	color_row.add_child(clear_btn)

	var st = Label.new()
	st.text = "custom" if current != null else "default"
	st.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4) if current != null else Color(0.5, 0.55, 0.6))
	st.add_theme_font_size_override("font_size", 9)
	color_row.add_child(st)

	inner.add_child(color_row)

func _on_gallery_select(category: String, variant: String) -> void:
	if not _editor._hero.has("decorations"):
		_editor._hero["decorations"] = {}
	var current = _editor._hero["decorations"].get(category, null)
	if current == variant:
		_editor._hero["decorations"][category] = null
	else:
		_editor._hero["decorations"][category] = variant
	_editor._dirty = true
	_editor._render_preview()
	build_deco_tab(_editor._tab_deco)

func _on_gallery_color_changed(c: Color, comp_name: String) -> void:
	if not _editor._hero.has("colors"):
		_editor._hero["colors"] = {}
	_editor._hero["colors"][comp_name] = [c.r, c.g, c.b, c.a]
	_editor._dirty = true
	_editor._render_preview()

func _on_gallery_color_clear(comp_name: String, picker: ColorPickerButton) -> void:
	var colors = _editor._hero.get("colors", {})
	colors.erase(comp_name)
	_editor._hero["colors"] = colors
	picker.color = Color.WHITE
	_editor._dirty = true
	_editor._render_preview()

func build_skills_tab(vb: VBoxContainer) -> void:
	clear_container(vb)
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)

	var inner = VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 4)

	var skills = _editor._hero.get("skills", [])
	for i in skills.size():
		var s = skills[i]
		var hb = HBoxContainer.new()
		hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var lb_s = Label.new()
		lb_s.text = "%d: %s" % [i + 1, str(s.get("name", ""))]
		lb_s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lb_s.add_theme_font_size_override("font_size", 14)
		lb_s.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
		hb.add_child(lb_s)

		var btn_edit = Button.new()
		btn_edit.text = "Edit"
		btn_edit.custom_minimum_size = Vector2(50, 24)
		btn_edit.add_theme_font_size_override("font_size", 13)
		btn_edit.pressed.connect(_on_edit_skill.bind(i))
		hb.add_child(btn_edit)

		var btn_del = Button.new()
		btn_del.text = "X"
		btn_del.custom_minimum_size = Vector2(28, 24)
		btn_del.add_theme_font_size_override("font_size", 13)
		btn_del.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
		btn_del.pressed.connect(_on_delete_skill.bind(i))
		hb.add_child(btn_del)

		inner.add_child(hb)

	inner.add_child(HSeparator.new())

	var btn_add = Button.new()
	btn_add.text = "+ Add Skill"
	btn_add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_add.add_theme_font_size_override("font_size", 14)
	btn_add.pressed.connect(_on_add_skill)
	inner.add_child(btn_add)

	margin.add_child(inner)
	vb.add_child(margin)

func _on_edit_skill(idx: int) -> void:
	var skills = _editor._hero.get("skills", [])
	if idx >= skills.size():
		return
	var s = skills[idx]
	_show_skill_dialog("Edit Skill", s, func(data): _set_skill(idx, data))

func _on_add_skill() -> void:
	var s = {"name": "", "init": 3000, "interval": 10000, "max": 3}
	_show_skill_dialog("Add Skill", s, func(data): _add_skill(data))

func _show_skill_dialog(title: String, defaults: Dictionary, on_confirm: Callable) -> void:
	var dlg = AcceptDialog.new()
	dlg.title = title
	dlg.dialog_text = ""

	var vb = VBoxContainer.new()
	vb.size = Vector2(300, 200)

	var fields = {}
	for pair in [["Name", "name"], ["Init (ms)", "init"], ["Interval (ms)", "interval"], ["Max Uses", "max"]]:
		var hb = HBoxContainer.new()
		var lb = Label.new()
		lb.text = pair[0] + ":"
		lb.size = Vector2(100, 24)
		hb.add_child(lb)

		var key = pair[1]
		if key == "name":
			var le = LineEdit.new()
			le.text = str(defaults.get(key, ""))
			le.size = Vector2(180, 24)
			hb.add_child(le)
			fields[key] = le
		else:
			var sb = SpinBox.new()
			sb.min_value = 0
			sb.max_value = 99999
			sb.step = 1
			sb.value = int(defaults.get(key, 0))
			sb.size = Vector2(180, 24)
			hb.add_child(sb)
			fields[key] = sb
		vb.add_child(hb)

	dlg.add_child(vb)
	dlg.confirmed.connect(func():
		var data = {
			"name": fields["name"].text,
			"init": int(fields["init"].value),
			"interval": int(fields["interval"].value),
			"max": int(fields["max"].value),
		}
		on_confirm.call(data))
	_editor.add_child(dlg)
	dlg.popup_centered()

func _set_skill(idx: int, data: Dictionary) -> void:
	var skills = _editor._hero.get("skills", [])
	if idx >= skills.size():
		return
	skills[idx] = data
	_editor._dirty = true
	build_skills_tab(_editor._tab_skills)

func _add_skill(data: Dictionary) -> void:
	var skills = _editor._hero.get("skills", [])
	skills.append(data)
	_editor._hero["skills"] = skills
	_editor._dirty = true
	build_skills_tab(_editor._tab_skills)

func _on_delete_skill(idx: int) -> void:
	var skills = _editor._hero.get("skills", [])
	if idx >= skills.size():
		return
	skills.remove_at(idx)
	_editor._dirty = true
	build_skills_tab(_editor._tab_skills)
