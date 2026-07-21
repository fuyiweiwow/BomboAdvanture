extends Control

var _hero: Dictionary = {}
var _dirty: bool = false
var _current_color: Color = C.CHARACTER_RED
var _color_idx: int = 0
var _color_names: Array = []
var _color_list: Array = []
var _preview_instance = null
var _list_ref = null
var _use_custom_tex: bool = false
var _preview_orient: String = "D"

var _tab_basic: VBoxContainer
var _tab_deco: VBoxContainer
var _tab_skills: VBoxContainer
var _tab_tex: VBoxContainer
var _btn_bomb: Button
var _preview_bg: ColorRect
var _color_swatch_container: HBoxContainer

const DECO_CATEGORIES = ["cap", "hair", "eye", "ear", "mouth", "cladorn", "fpack", "npack", "thadorn", "footprint"]

func _init(hero: Dictionary):
	_hero = hero.duplicate(true)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_update_size()
	get_viewport().size_changed.connect(_update_size)
	_list_ref = get_meta("list_ref") if has_meta("list_ref") else null
	_build_colors()
	_build_top_bar()
	_build_tabs()
	_use_custom_tex = _hero.get("use_custom_textures", false)
	_rebuild_ui()
	queue_redraw()

func _update_size() -> void:
	var win = get_viewport_rect().size
	size = win
	position = Vector2(0, 0)

func _build_colors() -> void:
	_color_names = ["Red", "Blue", "Yellow", "Green", "Orange", "Pink", "Purple", "Black"]
	_color_list = [C.CHARACTER_RED, C.CHARACTER_BLUE, C.CHARACTER_YELLOW, C.CHARACTER_GREEN, C.CHARACTER_ORANGE, C.CHARACTER_PINK, C.CHARACTER_PURPLE, C.CHARACTER_BLACK]

func _clear_container(c: Node) -> void:
	for ch in c.get_children():
		c.remove_child(ch)
		ch.queue_free()

func _build_top_bar() -> void:
	var btn_back = Button.new()
	btn_back.text = "< Back"
	btn_back.position = Vector2(10, 10)
	btn_back.size = Vector2(90, 30)
	btn_back.add_theme_font_size_override("font_size", 16)
	btn_back.pressed.connect(_on_back)
	add_child(btn_back)

	var btn_save = Button.new()
	btn_save.text = "Save"
	btn_save.position = Vector2(110, 10)
	btn_save.size = Vector2(70, 30)
	btn_save.add_theme_font_size_override("font_size", 16)
	btn_save.pressed.connect(_on_save)
	add_child(btn_save)

	if _hero.get("_src", "origin") == "custom":
		var btn_reset = Button.new()
		btn_reset.text = "Restore Defaults"
		btn_reset.position = Vector2(190, 10)
		btn_reset.size = Vector2(140, 30)
		btn_reset.add_theme_font_size_override("font_size", 14)
		btn_reset.pressed.connect(_on_restore)
		add_child(btn_reset)

	var btn_new = Button.new()
	btn_new.text = "+ New"
	btn_new.position = Vector2(660, 10)
	btn_new.size = Vector2(80, 30)
	btn_new.add_theme_font_size_override("font_size", 14)
	btn_new.pressed.connect(_on_new_character)
	add_child(btn_new)

func _build_tabs() -> void:
	var LEFT_W = 480
	var TAB_Y = 80
	var TAB_H = 510

	var tab_container = TabContainer.new()
	tab_container.position = Vector2(10, TAB_Y)
	tab_container.size = Vector2(LEFT_W, TAB_H)
	add_child(tab_container)

	_tab_basic = _add_tab("Basic", tab_container)
	_tab_deco = _add_tab("Decorations", tab_container)
	_tab_skills = _add_tab("Skills", tab_container)
	_tab_tex = _add_tab("Custom Textures", tab_container)

	_preview_bg = ColorRect.new()
	_preview_bg.position = Vector2(500, TAB_Y)
	_preview_bg.size = Vector2(290, TAB_H)
	_preview_bg.color = Color(0.14, 0.15, 0.19)
	add_child(_preview_bg)

	var preview_border = ColorRect.new()
	preview_border.position = Vector2(500, TAB_Y)
	preview_border.size = Vector2(290, TAB_H)
	preview_border.color = Color(0.3, 0.32, 0.38)
	preview_border.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(preview_border)

	var lb_preview = Label.new()
	lb_preview.text = "Preview"
	lb_preview.position = Vector2(510, TAB_Y + 10)
	lb_preview.size = Vector2(120, 24)
	lb_preview.add_theme_font_size_override("font_size", 17)
	lb_preview.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	add_child(lb_preview)

	var hint = Label.new()
	hint.text = "[ W / A / S / D to rotate ]"
	hint.position = Vector2(510, TAB_Y + 32)
	hint.size = Vector2(180, 16)
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
	add_child(hint)

func _add_tab(name: String, tab_container: TabContainer) -> VBoxContainer:
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

func _add_field(vb: VBoxContainer, label: String, input: Control, label_w: int = 120) -> void:
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

func _rebuild_ui() -> void:
	_build_basic_tab()
	_build_deco_tab()
	_build_skills_tab()
	_build_tex_tab()
	_render_preview()

func _build_basic_tab() -> void:
	_clear_container(_tab_basic)
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)

	var vb = VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 6)

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
			le.text = str(_hero.get(f[1], ""))
			le.add_theme_font_size_override("font_size", 15)
			le.text_changed.connect(_on_field_changed.bind(f[1]))
			_add_field(vb, f[0], le, 130)
		elif f[2] == 1:
			var sb = SpinBox.new()
			sb.min_value = 0
			sb.max_value = 999.999
			sb.step = 0.01
			sb.value = float(_hero.get(f[1], 0))
			sb.add_theme_font_size_override("font_size", 15)
			sb.value_changed.connect(_on_float_changed.bind(f[1]))
			_add_field(vb, f[0], sb, 130)
		else:
			var sb = SpinBox.new()
			sb.min_value = 0
			sb.max_value = 99999
			sb.step = 1
			sb.value = int(_hero.get(f[1], 0))
			sb.add_theme_font_size_override("font_size", 15)
			sb.value_changed.connect(_on_int_changed.bind(f[1]))
			_add_field(vb, f[0], sb, 130)

	var hb_bomb = HBoxContainer.new()
	hb_bomb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lb_bomb = Label.new()
	lb_bomb.text = "Bomb Skin:"
	lb_bomb.custom_minimum_size = Vector2(130, 24)
	lb_bomb.add_theme_font_size_override("font_size", 15)
	lb_bomb.add_theme_color_override("font_color", Color(0.85, 0.87, 0.9))
	hb_bomb.add_child(lb_bomb)

	_btn_bomb = Button.new()
	var current_bomb = _hero.get("decorations", {}).get("bomb_skin", "")
	_btn_bomb.text = "none" if current_bomb == "" else current_bomb
	_btn_bomb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_bomb.add_theme_font_size_override("font_size", 14)
	_btn_bomb.pressed.connect(_on_pick_bomb_skin.bind(_btn_bomb))
	hb_bomb.add_child(_btn_bomb)
	vb.add_child(hb_bomb)

	var hb_color = HBoxContainer.new()
	hb_color.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lb_color = Label.new()
	lb_color.text = "Color:"
	lb_color.custom_minimum_size = Vector2(130, 24)
	lb_color.add_theme_font_size_override("font_size", 15)
	lb_color.add_theme_color_override("font_color", Color(0.85, 0.87, 0.9))
	hb_color.add_child(lb_color)

	_color_swatch_container = HBoxContainer.new()
	_color_swatch_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_color_swatch_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb_color.add_child(_color_swatch_container)
	_fill_swatches()

	vb.add_child(hb_color)
	margin.add_child(vb)
	_tab_basic.add_child(margin)

func _on_field_changed(new_text: String, key: String) -> void:
	if key == "name":
		_hero[key] = new_text
	_dirty = true

func _on_int_changed(value: float, key: String) -> void:
	_hero[key] = int(value)
	_dirty = true

func _on_float_changed(value: float, key: String) -> void:
	_hero[key] = value
	_dirty = true

func _fill_swatches() -> void:
	_clear_container(_color_swatch_container)
	var cw = 26
	for i in _color_list.size():
		var cbtn = ColorRect.new()
		cbtn.color = _color_list[i]
		cbtn.custom_minimum_size = Vector2(cw, cw)
		cbtn.mouse_filter = Control.MOUSE_FILTER_STOP
		cbtn.gui_input.connect(_on_color_click.bind(i))

		var border = ColorRect.new()
		border.color = Color(0, 0, 0, 0.7) if i != _color_idx else Color(1, 1, 1)
		border.size = Vector2(cw + 2, cw + 2)
		border.mouse_filter = Control.MOUSE_FILTER_PASS

		var ctn = Control.new()
		ctn.custom_minimum_size = Vector2(cw + 4, cw + 4)
		border.position = Vector2(0, 0)
		ctn.add_child(border)
		cbtn.position = Vector2(1, 1)
		cbtn.size = Vector2(cw, cw)
		ctn.add_child(cbtn)
		_color_swatch_container.add_child(ctn)

func _on_color_click(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_color_idx = idx
		_current_color = _color_list[idx]
		_fill_swatches()
		_render_preview()
		_dirty = true

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
	add_child(menu)
	menu.position = get_viewport().get_mouse_position()
	menu.popup()

func _apply_bomb_skin(skin: String, btn: Button) -> void:
	if not _hero.has("decorations"):
		_hero["decorations"] = {}
	_hero["decorations"]["bomb_skin"] = skin
	btn.text = skin if skin != "" else "none"
	_dirty = true

func _build_deco_tab() -> void:
	_clear_container(_tab_deco)
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)

	var vb = VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 6)

	var deco_data = _hero.get("decorations", {})

	for i in DECO_CATEGORIES.size():
		var cat = DECO_CATEGORIES[i]
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

		vb.add_child(hb)

	margin.add_child(vb)
	_tab_deco.add_child(margin)

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
	add_child(menu)
	menu.position = get_viewport().get_mouse_position()
	menu.popup()

func _apply_decoration(category: String, value, btn: Button) -> void:
	if not _hero.has("decorations"):
		_hero["decorations"] = {}
	_hero["decorations"][category] = value
	btn.text = str(value) if value != null else "-"
	_dirty = true
	_render_preview()

func _clear_decoration(category: String, btn: Button) -> void:
	if not _hero.has("decorations"):
		_hero["decorations"] = {}
	_hero["decorations"][category] = null
	btn.text = "-"
	_dirty = true
	_render_preview()

func _build_skills_tab() -> void:
	_clear_container(_tab_skills)
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)

	var vb = VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 4)

	var skills = _hero.get("skills", [])
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

		vb.add_child(hb)

	vb.add_child(HSeparator.new())

	var btn_add = Button.new()
	btn_add.text = "+ Add Skill"
	btn_add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_add.add_theme_font_size_override("font_size", 14)
	btn_add.pressed.connect(_on_add_skill)
	vb.add_child(btn_add)

	margin.add_child(vb)
	_tab_skills.add_child(margin)

func _on_edit_skill(idx: int) -> void:
	var skills = _hero.get("skills", [])
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
	add_child(dlg)
	dlg.popup_centered()

func _set_skill(idx: int, data: Dictionary) -> void:
	var skills = _hero.get("skills", [])
	if idx >= skills.size():
		return
	skills[idx] = data
	_dirty = true
	_build_skills_tab()

func _add_skill(data: Dictionary) -> void:
	var skills = _hero.get("skills", [])
	skills.append(data)
	_hero["skills"] = skills
	_dirty = true
	_build_skills_tab()

func _on_delete_skill(idx: int) -> void:
	var skills = _hero.get("skills", [])
	if idx >= skills.size():
		return
	skills.remove_at(idx)
	_dirty = true
	_build_skills_tab()

func _build_tex_tab() -> void:
	_clear_container(_tab_tex)
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)

	var vb = VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 6)

	var toggle = HBoxContainer.new()
	var lb_toggle = Label.new()
	lb_toggle.text = "Use Custom Textures:"
	lb_toggle.add_theme_font_size_override("font_size", 14)
	lb_toggle.add_theme_color_override("font_color", Color(0.85, 0.87, 0.9))
	toggle.add_child(lb_toggle)

	var cb = CheckBox.new()
	cb.button_pressed = _use_custom_tex
	cb.toggled.connect(_on_toggle_custom_tex)
	toggle.add_child(cb)
	vb.add_child(toggle)

	if not _use_custom_tex:
		margin.add_child(vb)
		_tab_tex.add_child(margin)
		return

	vb.add_child(HSeparator.new())

	var hero_name = str(_hero.get("name", ""))
	var offsets = _hero.get("custom_texture_offsets", {})

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
	vb.add_child(header)

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

		vb.add_child(hb)

	margin.add_child(vb)
	_tab_tex.add_child(margin)

func _on_toggle_custom_tex(toggled: bool) -> void:
	_use_custom_tex = toggled
	_hero["use_custom_textures"] = toggled
	_dirty = true
	_rebuild_ui()

func _on_tex_btn_clicked(component: String, btn: Button) -> void:
	var hero_name = str(_hero.get("name", ""))
	if btn.text == "Import":
		if hero_name == "":
			_show_notice("Save hero first before importing textures!", Color(1, 0.3, 0.3))
			return
		var fd = FileDialog.new()
		fd.title = "Import " + component + " texture"
		fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		fd.add_filter("*.png", "PNG Images")
		fd.use_native_dialog = true
		fd.file_selected.connect(func(path): _on_texture_imported(path, component, btn))
		add_child(fd)
		fd.popup_centered()
	else:
		HeroData.delete_texture(hero_name, component)
		btn.text = "Import"
		_dirty = true
		_render_preview()
		_show_notice(component + " cleared", Color(0.8, 0.8, 0.3))

func _on_texture_imported(path: String, component: String, btn: Button) -> void:
	var hero_name = str(_hero.get("name", ""))
	if hero_name == "":
		return
	var result = HeroData.import_texture(hero_name, component, path)
	if result.ok:
		btn.text = "Clear"
		_dirty = true
		_render_preview()
		_show_notice(component + " imported!", Color(0.3, 1, 0.3))
	else:
		_show_notice("Import failed: " + result.error, Color(1, 0.3, 0.3))

func _on_offset_changed(value: float, comp: String, axis: String) -> void:
	if not _hero.has("custom_texture_offsets"):
		_hero["custom_texture_offsets"] = {}
	if not _hero["custom_texture_offsets"].has(comp):
		_hero["custom_texture_offsets"][comp] = {}
	_hero["custom_texture_offsets"][comp][axis] = int(value)
	_dirty = true
	_render_preview()

func _render_preview() -> void:
	if _preview_instance != null:
		_preview_instance.queue_free()
		_preview_instance = null

	var hero_name = str(_hero.get("name", ""))
	var custom_textures = {}
	if _use_custom_tex and hero_name != "":
		var offsets = _hero.get("custom_texture_offsets", {})
		custom_textures = HeroData.build_custom_textures_dict(hero_name, offsets)

	var result = {}
	if not custom_textures.is_empty():
		result = CharacterLoader.get_character("", _current_color, {}, false, custom_textures)
	else:
		var char_name = str(_hero.get("character", ""))
		if char_name == "":
			return
		var decorations = _load_decorations()
		result = CharacterLoader.get_character(char_name, _current_color, decorations)

	if result.is_empty():
		return

	_preview_instance = CharacterPreview.new()
	_preview_instance.set_character(result, _preview_orient)

	var area_x = 500
	var area_y = 80
	var area_w = 290
	var area_h = 510
	_preview_instance.position = Vector2(area_x + area_w * 0.5, area_y + area_h * 0.5 + 10)
	_preview_instance.scale = Vector2(2.0, 2.0)
	add_child(_preview_instance)

func _load_decorations() -> Dictionary:
	var deco: Dictionary = {}
	var deco_data = _hero.get("decorations", {})
	for component in DECO_CATEGORIES:
		var name = deco_data.get(component, null)
		if name == null:
			continue
		if component == "footprint":
			continue
		var path = G.FRAME_ROOT + component + "/" + str(name) + ".json"
		var j = Utils.load_json(path)
		if j != null:
			deco[component.capitalize()] = j
	return deco

func _on_save() -> void:
	if not _hero.has("name") or str(_hero["name"]).strip_edges() == "":
		_show_notice("Name cannot be empty!", Color(1, 0.3, 0.3))
		return
	if not _use_custom_tex:
		if not _hero.has("character") or str(_hero["character"]).strip_edges() == "":
			_show_notice("Character frame is missing!", Color(1, 0.3, 0.3))
			return
	if HeroData.save_hero(_hero):
		_dirty = false
		_hero["_src"] = "custom"
		_show_notice("Saved!", Color(0.3, 1, 0.3))
		await get_tree().create_timer(0.5).timeout
		_do_quit()
		var p = get_parent()
		if p != null:
			var list = load("res://src/player_editor/character_list.gd").new()
			p.add_child(list)
	else:
		_show_notice("Save failed!", Color(1, 0.3, 0.3))

func _on_restore() -> void:
	var hero_name = str(_hero.get("name", ""))
	if hero_name == "":
		return
	HeroData.restore_defaults(hero_name)
	var fresh = HeroData.load_hero(hero_name)
	if fresh.is_empty():
		return
	_hero = fresh.duplicate(true)
	_dirty = false
	_rebuild_ui()

func _on_new_character() -> void:
	var use_custom = _use_custom_tex
	var template = {
		"name": "NewHero",
		"character": "" if use_custom else "CharacterBlank",
		"icon_img": "",
		"use_custom_textures": use_custom,
		"decorations": {
			"disable_foot_and_leg": false, "bomb_skin": "bomb1",
			"cap": null, "hair": null, "eye": null, "ear": null, "mouth": null,
			"cladorn": null, "fpack": null, "npack": null, "thadorn": null, "footprint": null,
			"head_effect": null, "body_effect": null
		},
		"blood": 4500, "speed": 5.83333, "bomb": 7, "restore": 700,
		"power": 3, "damage": 3500, "defense": 0, "skills": []
	}
	if use_custom:
		template["custom_texture_offsets"] = {}
	_hero = template
	_dirty = true
	_rebuild_ui()

func _show_notice(msg: String, color: Color) -> void:
	var notice = Label.new()
	notice.text = msg
	notice.position = Vector2(300, 48)
	notice.size = Vector2(200, 24)
	notice.add_theme_font_size_override("font_size", 16)
	notice.add_theme_color_override("font_color", color)
	add_child(notice)
	await get_tree().create_timer(1.5).timeout
	if is_inside_tree():
		notice.queue_free()

func _on_back() -> void:
	if _dirty:
		var dlg = ConfirmationDialog.new()
		dlg.dialog_text = "Unsaved changes will be lost. Continue?"
		dlg.ok_button_text = "Discard"
		dlg.cancel_button_text = "Cancel"
		dlg.confirmed.connect(_do_quit)
		add_child(dlg)
		dlg.popup_centered()
	else:
		_do_quit()

func _do_quit() -> void:
	if _list_ref != null and is_instance_valid(_list_ref):
		get_parent().add_child(_list_ref)
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if _preview_instance != null:
			if event.keycode == KEY_W or event.keycode == KEY_UP:
				_preview_orient = "U"
			elif event.keycode == KEY_S or event.keycode == KEY_DOWN:
				_preview_orient = "D"
			elif event.keycode == KEY_A or event.keycode == KEY_LEFT:
				_preview_orient = "L"
			elif event.keycode == KEY_D or event.keycode == KEY_RIGHT:
				_preview_orient = "R"
			else:
				return
			_preview_instance.set_orientation(_preview_orient)

func _draw() -> void:
	var win = get_viewport_rect().size
	draw_rect(Rect2(0, 0, win.x, win.y), Color(0.08, 0.08, 0.12))
	var font = ThemeDB.fallback_font
	if font == null:
		return

	var name_str = str(_hero.get("name", "Unknown"))
	var ts = 28
	draw_string(font, Vector2(250, 55), name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, ts, Color(0.9, 0.92, 0.95))

func _exit_tree() -> void:
	_preview_instance = null
