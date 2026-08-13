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

func build_basic_tab(vb: VBoxContainer) -> void:
	clear_container(vb)
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)

	var inner = VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 6)

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
			le.add_theme_font_size_override("font_size", 15)
			le.text_changed.connect(_editor._on_field_changed.bind(f[1]))
			add_field(inner, f[0], le, 130)
		elif f[2] == 1:
			var sb = SpinBox.new()
			sb.min_value = 0
			sb.max_value = 999.999
			sb.step = 0.01
			sb.value = float(_editor._hero.get(f[1], 0))
			sb.add_theme_font_size_override("font_size", 15)
			sb.value_changed.connect(_editor._on_float_changed.bind(f[1]))
			add_field(inner, f[0], sb, 130)
		else:
			var sb = SpinBox.new()
			sb.min_value = 0
			sb.max_value = 99999
			sb.step = 1
			sb.value = int(_editor._hero.get(f[1], 0))
			sb.add_theme_font_size_override("font_size", 15)
			sb.value_changed.connect(_editor._on_int_changed.bind(f[1]))
			add_field(inner, f[0], sb, 130)

	var hb_bomb = HBoxContainer.new()
	hb_bomb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lb_bomb = Label.new()
	lb_bomb.text = "Bomb Skin:"
	lb_bomb.custom_minimum_size = Vector2(130, 24)
	lb_bomb.add_theme_font_size_override("font_size", 15)
	lb_bomb.add_theme_color_override("font_color", Color(0.85, 0.87, 0.9))
	hb_bomb.add_child(lb_bomb)

	_editor._btn_bomb = Button.new()
	var current_bomb = _editor._hero.get("decorations", {}).get("bomb_skin", "")
	_editor._btn_bomb.text = "none" if current_bomb == "" else current_bomb
	_editor._btn_bomb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_editor._btn_bomb.add_theme_font_size_override("font_size", 14)
	_editor._btn_bomb.pressed.connect(_on_pick_bomb_skin.bind(_editor._btn_bomb))
	hb_bomb.add_child(_editor._btn_bomb)
	inner.add_child(hb_bomb)

	var hb_color = HBoxContainer.new()
	hb_color.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lb_color = Label.new()
	lb_color.text = "Color:"
	lb_color.custom_minimum_size = Vector2(130, 24)
	lb_color.add_theme_font_size_override("font_size", 15)
	lb_color.add_theme_color_override("font_color", Color(0.85, 0.87, 0.9))
	hb_color.add_child(lb_color)

	_editor._color_swatch_container = HBoxContainer.new()
	_editor._color_swatch_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_editor._color_swatch_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb_color.add_child(_editor._color_swatch_container)
	fill_swatches()

	inner.add_child(hb_color)
	margin.add_child(inner)
	vb.add_child(margin)

func fill_swatches() -> void:
	clear_container(_editor._color_swatch_container)
	var cw = 26
	for i in _editor._color_list.size():
		var cbtn = ColorRect.new()
		cbtn.color = _editor._color_list[i]
		cbtn.custom_minimum_size = Vector2(cw, cw)
		cbtn.mouse_filter = Control.MOUSE_FILTER_STOP
		cbtn.gui_input.connect(_on_color_click.bind(i))

		var border = ColorRect.new()
		border.color = Color(0, 0, 0, 0.7) if i != _editor._color_idx else Color(1, 1, 1)
		border.size = Vector2(cw + 2, cw + 2)
		border.mouse_filter = Control.MOUSE_FILTER_PASS

		var ctn = Control.new()
		ctn.custom_minimum_size = Vector2(cw + 4, cw + 4)
		border.position = Vector2(0, 0)
		ctn.add_child(border)
		cbtn.position = Vector2(1, 1)
		cbtn.size = Vector2(cw, cw)
		ctn.add_child(cbtn)
		_editor._color_swatch_container.add_child(ctn)

func _on_color_click(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_editor._color_idx = idx
		_editor._current_color = _editor._color_list[idx]
		fill_swatches()
		_editor._render_preview()
		_editor._dirty = true

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

func build_deco_tab(vb: VBoxContainer) -> void:
	clear_container(vb)
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)

	var inner = VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 6)

	var deco_data = _editor._hero.get("decorations", {})

	for i in _editor.DECO_CATEGORIES.size():
		var cat = _editor.DECO_CATEGORIES[i]
		var val = deco_data.get(cat, null)
		var display = str(val) if val != null else "-"

		var hb = HBoxContainer.new()
		hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var lb_cat = Label.new()
		lb_cat.text = cat
		lb_cat.custom_minimum_size = Vector2(100, 24)
		lb_cat.add_theme_font_size_override("font_size", 14)
		lb_cat.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
		hb.add_child(lb_cat)

		var btn_val = Button.new()
		btn_val.text = display
		btn_val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_val.add_theme_font_size_override("font_size", 13)
		btn_val.pressed.connect(_on_pick_decoration.bind(cat, btn_val))
		hb.add_child(btn_val)

		var btn_clr = Button.new()
		btn_clr.text = "x"
		btn_clr.custom_minimum_size = Vector2(26, 24)
		btn_clr.add_theme_font_size_override("font_size", 12)
		btn_clr.add_theme_color_override("font_color", Color(1, 0.5, 0.5))
		btn_clr.pressed.connect(_clear_decoration.bind(cat, btn_val))
		hb.add_child(btn_clr)

		inner.add_child(hb)

	margin.add_child(inner)
	vb.add_child(margin)

func _on_pick_decoration(category: String, btn: Button) -> void:
	var items = HeroData.list_decorations(category)
	var menu = PopupMenu.new()
	menu.add_item("[none]")
	menu.set_item_metadata(0, null)
	for item in items:
		var id = menu.get_item_count()
		menu.add_item(item, id)
		menu.set_item_metadata(id, item)
	var cat = category
	menu.id_pressed.connect(func(id):
		var val = menu.get_item_metadata(id) if id > 0 else null
		_apply_decoration(cat, val, btn))
	_editor.add_child(menu)
	menu.position = _editor.get_viewport().get_mouse_position()
	menu.popup()

func _apply_decoration(category: String, value, btn: Button) -> void:
	if not _editor._hero.has("decorations"):
		_editor._hero["decorations"] = {}
	_editor._hero["decorations"][category] = value
	btn.text = str(value) if value != null else "-"
	_editor._dirty = true
	_editor._render_preview()

func _clear_decoration(category: String, btn: Button) -> void:
	if not _editor._hero.has("decorations"):
		_editor._hero["decorations"] = {}
	_editor._hero["decorations"][category] = null
	btn.text = "-"
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

func build_tex_tab(vb: VBoxContainer) -> void:
	clear_container(vb)
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)

	var inner = VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 6)

	var toggle = HBoxContainer.new()
	var lb_toggle = Label.new()
	lb_toggle.text = "Use Custom Textures:"
	lb_toggle.add_theme_font_size_override("font_size", 14)
	lb_toggle.add_theme_color_override("font_color", Color(0.85, 0.87, 0.9))
	toggle.add_child(lb_toggle)

	var cb = CheckBox.new()
	cb.button_pressed = _editor._use_custom_tex
	cb.toggled.connect(_on_toggle_custom_tex)
	toggle.add_child(cb)
	inner.add_child(toggle)

	if not _editor._use_custom_tex:
		margin.add_child(inner)
		vb.add_child(margin)
		return

	inner.add_child(HSeparator.new())

	var hero_name = str(_editor._hero.get("name", ""))
	var offsets = _editor._hero.get("custom_texture_offsets", {})

	var header = HBoxContainer.new()
	var hname = Label.new()
	hname.text = "Component"
	hname.custom_minimum_size = Vector2(100, 24)
	hname.add_theme_font_size_override("font_size", 13)
	hname.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	header.add_child(hname)
	var haction = Label.new()
	haction.text = "Action"
	haction.custom_minimum_size = Vector2(80, 24)
	haction.add_theme_font_size_override("font_size", 13)
	haction.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	header.add_child(haction)
	var hcx = Label.new()
	hcx.text = "Cx"
	hcx.custom_minimum_size = Vector2(60, 24)
	hcx.add_theme_font_size_override("font_size", 13)
	hcx.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	header.add_child(hcx)
	var hcy = Label.new()
	hcy.text = "Cy"
	hcy.custom_minimum_size = Vector2(60, 24)
	hcy.add_theme_font_size_override("font_size", 13)
	hcy.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	header.add_child(hcy)
	inner.add_child(header)

	for comp in HeroData.CUSTOM_TEX_COMPONENTS:
		var hb = HBoxContainer.new()
		hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var lb_c = Label.new()
		lb_c.text = comp
		lb_c.custom_minimum_size = Vector2(100, 24)
		lb_c.add_theme_font_size_override("font_size", 13)
		lb_c.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
		hb.add_child(lb_c)

		var has_tex = false
		if hero_name != "" and HeroData.has_custom_texture(hero_name, comp):
			has_tex = true

		var btn_import = Button.new()
		btn_import.text = "Clear" if has_tex else "Import"
		btn_import.custom_minimum_size = Vector2(70, 24)
		btn_import.add_theme_font_size_override("font_size", 11)
		btn_import.pressed.connect(_on_tex_btn_clicked.bind(comp, btn_import))
		hb.add_child(btn_import)

		var sb_cx = SpinBox.new()
		sb_cx.min_value = -200
		sb_cx.max_value = 200
		sb_cx.step = 1
		sb_cx.value = offsets.get(comp, {}).get("cx", 0)
		sb_cx.custom_minimum_size = Vector2(60, 24)
		sb_cx.add_theme_font_size_override("font_size", 12)
		sb_cx.value_changed.connect(_on_offset_changed.bind(comp, "cx"))
		sb_cx.editable = has_tex
		hb.add_child(sb_cx)

		var sb_cy = SpinBox.new()
		sb_cy.min_value = -200
		sb_cy.max_value = 200
		sb_cy.step = 1
		sb_cy.value = offsets.get(comp, {}).get("cy", 0)
		sb_cy.custom_minimum_size = Vector2(60, 24)
		sb_cy.add_theme_font_size_override("font_size", 12)
		sb_cy.value_changed.connect(_on_offset_changed.bind(comp, "cy"))
		sb_cy.editable = has_tex
		hb.add_child(sb_cy)

		inner.add_child(hb)

	margin.add_child(inner)
	vb.add_child(margin)

func _on_toggle_custom_tex(toggled: bool) -> void:
	_editor._use_custom_tex = toggled
	_editor._hero["use_custom_textures"] = toggled
	_editor._dirty = true
	_editor._rebuild_ui()

func _on_tex_btn_clicked(component: String, btn: Button) -> void:
	var hero_name = str(_editor._hero.get("name", ""))
	if btn.text == "Import":
		if hero_name == "":
			_editor._show_notice("Save hero first before importing textures!", Color(1, 0.3, 0.3))
			return
		var fd = FileDialog.new()
		fd.title = "Import " + component + " texture"
		fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		fd.add_filter("*.png", "PNG Images")
		fd.use_native_dialog = true
		fd.file_selected.connect(func(path): _on_texture_imported(path, component, btn))
		_editor.add_child(fd)
		fd.popup_centered()
	else:
		HeroData.delete_texture(hero_name, component)
		btn.text = "Import"
		_editor._dirty = true
		_editor._render_preview()
		_editor._show_notice(component + " cleared", Color(0.8, 0.8, 0.3))

func _on_texture_imported(path: String, component: String, btn: Button) -> void:
	var hero_name = str(_editor._hero.get("name", ""))
	if hero_name == "":
		return
	var result = HeroData.import_texture(hero_name, component, path)
	if result.ok:
		btn.text = "Clear"
		_editor._dirty = true
		_editor._render_preview()
		_editor._show_notice(component + " imported!", Color(0.3, 1, 0.3))
	else:
		_editor._show_notice("Import failed: " + result.error, Color(1, 0.3, 0.3))

func _on_offset_changed(value: float, comp: String, axis: String) -> void:
	if not _editor._hero.has("custom_texture_offsets"):
		_editor._hero["custom_texture_offsets"] = {}
	if not _editor._hero["custom_texture_offsets"].has(comp):
		_editor._hero["custom_texture_offsets"][comp] = {}
	_editor._hero["custom_texture_offsets"][comp][axis] = int(value)
	_editor._dirty = true
	_editor._render_preview()