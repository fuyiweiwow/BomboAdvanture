extends Control

var _hero: Dictionary = {}
var _dirty: bool = false
var _current_color: Color = C.CHARACTER_RED
var _color_idx: int = 0
var _color_names: Array = []
var _color_list: Array = []
var _preview_instance = null
var _list_ref = null

var _colors_container: Node
var _skills_container: Node
var _decos_container: Node
var _fields_node: Node
var _custom_tex_container: Node
var _use_custom_tex: bool = false

const DECO_CATEGORIES = ["cap", "hair", "eye", "ear", "mouth", "cladorn", "fpack", "npack", "thadorn", "footprint"]

func _init(hero: Dictionary):
	_hero = hero.duplicate(true)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_update_size()
	get_viewport().size_changed.connect(_update_size)
	queue_redraw()
	_list_ref = get_meta("list_ref") if has_meta("list_ref") else null

	_build_colors()
	_build_buttons()
	_build_preview_area()

	_fields_node = Node.new()
	add_child(_fields_node)
	_skills_container = Node.new()
	add_child(_skills_container)
	_decos_container = Node.new()
	add_child(_decos_container)
	_custom_tex_container = Node.new()
	add_child(_custom_tex_container)
	_use_custom_tex = _hero.get("use_custom_textures", false)
	_rebuild_ui()

	_build_dir_hint()

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

func _build_buttons() -> void:
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

func _build_preview_area() -> void:
	var lb = Label.new()
	lb.text = "Preview"
	lb.position = Vector2(580, 48)
	lb.size = Vector2(200, 24)
	lb.add_theme_font_size_override("font_size", 17)
	lb.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	add_child(lb)

	var 	hint = Label.new()
	hint.text = "[ U / D / L / R keys to rotate ]"
	hint.position = Vector2(580, 68)
	hint.size = Vector2(200, 18)
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
	add_child(hint)

func _build_dir_hint() -> void:
	var hint = Label.new()
	hint.text = "Arrow keys to rotate preview"
	hint.position = Vector2(10, 560)
	hint.size = Vector2(300, 20)
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.4, 0.45, 0.5))
	add_child(hint)

func _rebuild_ui() -> void:
	_build_fields()
	_build_skills()
	_build_decorations()
	_build_custom_texture_ui()
	_render_preview()

func _build_fields() -> void:
	_clear_container(_fields_node)
	var y_start = 100
	var x_label = 20
	var x_input = 180
	var line_h = 32

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

	for i in stat_fields.size():
		var f = stat_fields[i]
		var y = y_start + i * line_h
		var lb = Label.new()
		lb.text = f[0] + ":"
		lb.position = Vector2(x_label, y)
		lb.size = Vector2(150, 28)
		lb.add_theme_font_size_override("font_size", 17)
		lb.add_theme_color_override("font_color", Color(0.85, 0.87, 0.9))
		_fields_node.add_child(lb)

		if f[0] == "Name":
			var le = LineEdit.new()
			le.text = str(_hero.get(f[1], ""))
			le.position = Vector2(x_input, y)
			le.size = Vector2(180, 26)
			le.add_theme_font_size_override("font_size", 16)
			le.text_changed.connect(_on_field_changed.bind(f[1]))
			_fields_node.add_child(le)
		elif f[2] == 1:
			var sb = SpinBox.new()
			sb.min_value = 0
			sb.max_value = 999.999
			sb.step = 0.01
			sb.value = float(_hero.get(f[1], 0))
			sb.position = Vector2(x_input, y)
			sb.size = Vector2(140, 26)
			sb.add_theme_font_size_override("font_size", 16)
			sb.value_changed.connect(_on_float_changed.bind(f[1]))
			_fields_node.add_child(sb)
		else:
			var sb = SpinBox.new()
			sb.min_value = 0
			sb.max_value = 99999
			sb.step = 1
			sb.value = int(_hero.get(f[1], 0))
			sb.position = Vector2(x_input, y)
			sb.size = Vector2(140, 26)
			sb.add_theme_font_size_override("font_size", 16)
			sb.value_changed.connect(_on_int_changed.bind(f[1]))
			_fields_node.add_child(sb)

	var y_after = y_start + stat_fields.size() * line_h + 8
	var lb_bomb = Label.new()
	lb_bomb.text = "Bomb Skin:"
	lb_bomb.position = Vector2(x_label, y_after)
	lb_bomb.size = Vector2(150, 28)
	lb_bomb.add_theme_font_size_override("font_size", 17)
	lb_bomb.add_theme_color_override("font_color", Color(0.85, 0.87, 0.9))
	_fields_node.add_child(lb_bomb)

	var btn_bomb = Button.new()
	var current_bomb = _hero.get("decorations", {}).get("bomb_skin", "")
	btn_bomb.text = "none" if current_bomb == "" else current_bomb
	btn_bomb.position = Vector2(x_input, y_after)
	btn_bomb.size = Vector2(140, 26)
	btn_bomb.add_theme_font_size_override("font_size", 15)
	btn_bomb.pressed.connect(_on_pick_bomb_skin.bind(btn_bomb))
	_fields_node.add_child(btn_bomb)

	var y_color = y_after + 36
	var lb_color = Label.new()
	lb_color.text = "Color:"
	lb_color.position = Vector2(x_label, y_color)
	lb_color.size = Vector2(150, 28)
	lb_color.add_theme_font_size_override("font_size", 17)
	lb_color.add_theme_color_override("font_color", Color(0.85, 0.87, 0.9))
	_fields_node.add_child(lb_color)

	_colors_container = Node.new()
	_fields_node.add_child(_colors_container)
	_rebuild_color_swatches()

func _rebuild_color_swatches() -> void:
	_clear_container(_colors_container)
	var x_input = 180
	var cw = 26
	var y_color = 50 + 8 * 32 + 8 + 36
	for i in _color_list.size():
		var cbtn = ColorRect.new()
		cbtn.color = _color_list[i]
		cbtn.position = Vector2(x_input + i * (cw + 4), y_color)
		cbtn.size = Vector2(cw, cw)
		cbtn.mouse_filter = Control.MOUSE_FILTER_STOP
		cbtn.gui_input.connect(_on_color_click.bind(i))
		_colors_container.add_child(cbtn)

		var border = ColorRect.new()
		border.color = Color(0, 0, 0, 0.7) if i != _color_idx else Color(1, 1, 1)
		border.position = Vector2(x_input + i * (cw + 4) - 1, y_color - 1)
		border.size = Vector2(cw + 2, cw + 2)
		border.mouse_filter = Control.MOUSE_FILTER_PASS
		_colors_container.add_child(border)

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

func _on_color_click(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_color_idx = idx
		_current_color = _color_list[idx]
		_rebuild_color_swatches()
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

func _build_skills() -> void:
	_clear_container(_skills_container)
	var x_label = 20
	var y_start = 400
	var line_h = 26

	var lb = Label.new()
	lb.text = "Skills:"
	lb.position = Vector2(x_label, y_start)
	lb.size = Vector2(100, 26)
	lb.add_theme_font_size_override("font_size", 17)
	lb.add_theme_color_override("font_color", Color(0.85, 0.87, 0.9))
	_skills_container.add_child(lb)

	var skills = _hero.get("skills", [])
	for i in skills.size():
		var y = y_start + 28 + i * line_h
		var s = skills[i]
		var lb_s = Label.new()
		lb_s.text = "  %d: %s" % [i + 1, str(s.get("name", ""))]
		lb_s.position = Vector2(x_label, y)
		lb_s.size = Vector2(180, 22)
		lb_s.add_theme_font_size_override("font_size", 15)
		lb_s.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
		_skills_container.add_child(lb_s)

		var btn_edit = Button.new()
		btn_edit.text = "Edit"
		btn_edit.position = Vector2(200, y - 1)
		btn_edit.size = Vector2(55, 22)
		btn_edit.add_theme_font_size_override("font_size", 13)
		btn_edit.pressed.connect(_on_edit_skill.bind(i))
		_skills_container.add_child(btn_edit)

		var btn_del = Button.new()
		btn_del.text = "X"
		btn_del.position = Vector2(260, y - 1)
		btn_del.size = Vector2(30, 22)
		btn_del.add_theme_font_size_override("font_size", 13)
		btn_del.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
		btn_del.pressed.connect(_on_delete_skill.bind(i))
		_skills_container.add_child(btn_del)

	var add_y = y_start + 28 + max(skills.size(), 1) * line_h
	var btn_add = Button.new()
	btn_add.text = "+ Add Skill"
	btn_add.position = Vector2(x_label, add_y)
	btn_add.size = Vector2(120, 26)
	btn_add.add_theme_font_size_override("font_size", 14)
	btn_add.pressed.connect(_on_add_skill)
	_skills_container.add_child(btn_add)

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
	_build_skills()

func _add_skill(data: Dictionary) -> void:
	var skills = _hero.get("skills", [])
	skills.append(data)
	_hero["skills"] = skills
	_dirty = true
	_build_skills()

func _on_delete_skill(idx: int) -> void:
	var skills = _hero.get("skills", [])
	if idx >= skills.size():
		return
	skills.remove_at(idx)
	_dirty = true
	_build_skills()

func _build_decorations() -> void:
	_clear_container(_decos_container)
	var x_label = 380
	var y_start = 100
	var line_h = 28
	var deco_data = _hero.get("decorations", {})

	var lb = Label.new()
	lb.text = "Decorations"
	lb.position = Vector2(x_label, y_start)
	lb.size = Vector2(150, 26)
	lb.add_theme_font_size_override("font_size", 17)
	lb.add_theme_color_override("font_color", Color(0.85, 0.87, 0.9))
	_decos_container.add_child(lb)

	for i in DECO_CATEGORIES.size():
		var cat = DECO_CATEGORIES[i]
		var y = y_start + 28 + i * line_h
		var val = deco_data.get(cat, null)
		var display = str(val) if val != null else "-"

		var lb_cat = Label.new()
		lb_cat.text = cat
		lb_cat.position = Vector2(x_label + 10, y)
		lb_cat.size = Vector2(80, 22)
		lb_cat.add_theme_font_size_override("font_size", 14)
		lb_cat.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
		_decos_container.add_child(lb_cat)

		var btn_val = Button.new()
		btn_val.text = display
		btn_val.position = Vector2(x_label + 95, y)
		btn_val.size = Vector2(100, 22)
		btn_val.add_theme_font_size_override("font_size", 13)
		btn_val.pressed.connect(_on_pick_decoration.bind(cat, btn_val))
		_decos_container.add_child(btn_val)

		var btn_clr = Button.new()
		btn_clr.text = "x"
		btn_clr.position = Vector2(x_label + 200, y)
		btn_clr.size = Vector2(22, 22)
		btn_clr.add_theme_font_size_override("font_size", 12)
		btn_clr.add_theme_color_override("font_color", Color(1, 0.5, 0.5))
		btn_clr.pressed.connect(_clear_decoration.bind(cat, btn_val))
		_decos_container.add_child(btn_clr)

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

func _render_preview() -> void:
	if _preview_instance != null:
		_preview_instance.queue_free()
		_preview_instance = null
	var hero_name = str(_hero.get("name", ""))
	var custom_textures = {}
	if _use_custom_tex and hero_name != "":
		var offsets = _hero.get("custom_texture_offsets", {})
		custom_textures = HeroData.build_custom_textures_dict(hero_name, offsets)
	if custom_textures.is_empty():
		var char_name = str(_hero.get("character", ""))
		if char_name == "":
			return
		var decorations = _load_decorations()
		var result = CharacterLoader.get_character(char_name, _current_color, decorations)
		if result.is_empty():
			return
		_preview_instance = CharacterPreview.new()
		_preview_instance.set_character(result)
	else:
		var result = CharacterLoader.get_character("", _current_color, {}, false, custom_textures)
		if result.is_empty():
			return
		_preview_instance = CharacterPreview.new()
		_preview_instance.set_character(result)
	_preview_instance.position = Vector2(680, 230)
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
		"character": "" if use_custom else "Character10301",
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
	notice.position = Vector2(120, 48)
	notice.size = Vector2(200, 24)
	notice.add_theme_font_size_override("font_size", 16)
	notice.add_theme_color_override("font_color", color)
	add_child(notice)
	await get_tree().create_timer(1.5).timeout
	if is_inside_tree():
		notice.queue_free()

func _build_custom_texture_ui() -> void:
	_clear_container(_custom_tex_container)
	var x_label = 380
	var y_start = 420

	var lb = Label.new()
	lb.text = "Custom Textures"
	lb.position = Vector2(x_label, y_start)
	lb.size = Vector2(200, 24)
	lb.add_theme_font_size_override("font_size", 17)
	lb.add_theme_color_override("font_color", Color(0.85, 0.87, 0.9))
	_custom_tex_container.add_child(lb)

	var toggle = CheckBox.new()
	toggle.text = "Use Custom Textures"
	toggle.button_pressed = _use_custom_tex
	toggle.position = Vector2(x_label + 140, y_start)
	toggle.size = Vector2(180, 24)
	toggle.add_theme_font_size_override("font_size", 14)
	toggle.toggled.connect(_on_toggle_custom_tex)
	_custom_tex_container.add_child(toggle)

	if not _use_custom_tex:
		return

	var hero_name = str(_hero.get("name", ""))
	var offsets = _hero.get("custom_texture_offsets", {})
	var line_h = 28

	for i in HeroData.CUSTOM_TEX_COMPONENTS.size():
		var comp = HeroData.CUSTOM_TEX_COMPONENTS[i]
		var y = y_start + 30 + i * line_h

		var lb_c = Label.new()
		lb_c.text = comp
		lb_c.position = Vector2(x_label + 10, y)
		lb_c.size = Vector2(70, 22)
		lb_c.add_theme_font_size_override("font_size", 14)
		lb_c.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
		_custom_tex_container.add_child(lb_c)

		var has_tex = false
		if hero_name != "" and HeroData.has_custom_texture(hero_name, comp):
			has_tex = true

		var btn_import = Button.new()
		btn_import.text = "Clear" if has_tex else "Import"
		btn_import.position = Vector2(x_label + 90, y)
		btn_import.size = Vector2(70, 22)
		btn_import.add_theme_font_size_override("font_size", 12)
		btn_import.pressed.connect(_on_tex_btn_clicked.bind(comp, btn_import))
		_custom_tex_container.add_child(btn_import)

		var lb_cx = Label.new()
		lb_cx.text = "Cx"
		lb_cx.position = Vector2(x_label + 168, y)
		lb_cx.size = Vector2(20, 22)
		lb_cx.add_theme_font_size_override("font_size", 11)
		lb_cx.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
		_custom_tex_container.add_child(lb_cx)

		var sb_cx = SpinBox.new()
		sb_cx.min_value = -200
		sb_cx.max_value = 200
		sb_cx.step = 1
		var cur_cx = offsets.get(comp, {}).get("cx", 0)
		sb_cx.value = cur_cx
		sb_cx.position = Vector2(x_label + 186, y)
		sb_cx.size = Vector2(56, 22)
		sb_cx.add_theme_font_size_override("font_size", 12)
		sb_cx.value_changed.connect(_on_offset_changed.bind(comp, "cx"))
		sb_cx.editable = has_tex
		_custom_tex_container.add_child(sb_cx)

		var lb_cy = Label.new()
		lb_cy.text = "Cy"
		lb_cy.position = Vector2(x_label + 248, y)
		lb_cy.size = Vector2(20, 22)
		lb_cy.add_theme_font_size_override("font_size", 11)
		lb_cy.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
		_custom_tex_container.add_child(lb_cy)

		var sb_cy = SpinBox.new()
		sb_cy.min_value = -200
		sb_cy.max_value = 200
		sb_cy.step = 1
		var cur_cy = offsets.get(comp, {}).get("cy", 0)
		sb_cy.value = cur_cy
		sb_cy.position = Vector2(x_label + 266, y)
		sb_cy.size = Vector2(56, 22)
		sb_cy.add_theme_font_size_override("font_size", 12)
		sb_cy.value_changed.connect(_on_offset_changed.bind(comp, "cy"))
		sb_cy.editable = has_tex
		_custom_tex_container.add_child(sb_cy)

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
			var orient = ""
			if event.keycode == KEY_U or event.keycode == KEY_UP:
				orient = "U"
			elif event.keycode == KEY_D or event.keycode == KEY_DOWN:
				orient = "D"
			elif event.keycode == KEY_L or event.keycode == KEY_LEFT:
				orient = "L"
			elif event.keycode == KEY_R or event.keycode == KEY_RIGHT:
				orient = "R"
			if orient != "":
				_preview_instance.set_orientation(orient)

func _draw() -> void:
	var win = get_viewport_rect().size
	draw_rect(Rect2(0, 0, win.x, win.y), Color(0.08, 0.08, 0.12))
	var font = ThemeDB.fallback_font
	if font == null:
		return

	var name_str = str(_hero.get("name", "Unknown"))
	var ts = 28
	var tw = font.get_string_size(name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, ts).x
	draw_string(font, Vector2(380 + (260 - tw) * 0.5, 90), name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, ts, Color(0.9, 0.92, 0.95))

func _exit_tree() -> void:
	_preview_instance = null
