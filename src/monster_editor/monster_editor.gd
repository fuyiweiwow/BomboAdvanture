extends Control

var _monster: Dictionary = {}
var _dirty: bool = false
var _preview: CharacterPreview = null
var _list_ref = null
var _preview_orient: String = "D"
var _ui: MonsterEditorUI
var _preview_bg: ColorRect

var _btn_back: Button
var _btn_save: Button
var _btn_delete: Button
var _btn_new: Button
var _btn_bomb: Button
var _btn_char_frame: Button

var _tab_basic: VBoxContainer
var _tab_char: VBoxContainer
var _tab_skills: VBoxContainer
var _tab_drops: VBoxContainer

const MAX_SCALE = 2.0
const MIN_SCALE = 0.5

func _init(monster: Dictionary):
	_monster = monster.duplicate(true)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_list_ref = get_meta("list_ref") if has_meta("list_ref") else null
	_ui = MonsterEditorUI.new(self)
	_build_layout()

func _build_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var vb = VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 10)
	margin.add_child(vb)

	var bar = HBoxContainer.new()
	bar.custom_minimum_size = Vector2(0, 40)
	bar.add_theme_constant_override("separation", 8)
	vb.add_child(bar)

	_btn_back = Button.new()
	_btn_back.text = "< Back"
	_btn_back.pressed.connect(_on_back)
	bar.add_child(_btn_back)

	_btn_save = Button.new()
	_btn_save.text = "Save"
	_btn_save.pressed.connect(_on_save)
	bar.add_child(_btn_save)

	_btn_delete = Button.new()
	_btn_delete.text = "Delete"
	_btn_delete.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	_btn_delete.pressed.connect(_on_delete)
	bar.add_child(_btn_delete)

	bar.add_spacer(false)

	var title = Label.new()
	title.text = str(_monster.get("name", "Unknown"))
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.9, 0.92, 0.95))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)

	_btn_new = Button.new()
	_btn_new.text = "+ New"
	_btn_new.pressed.connect(_on_new_monster)
	bar.add_child(_btn_new)

	var hb_body = HBoxContainer.new()
	hb_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(hb_body)

	var left = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hb_body.add_child(left)

	var tc = TabContainer.new()
	tc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(tc)

	_tab_basic = _ui.add_tab("Basic", tc)
	_tab_char = _ui.add_tab("Character", tc)
	_tab_skills = _ui.add_tab("Skills", tc)
	_tab_drops = _ui.add_tab("Drops", tc)

	var right_margin = MarginContainer.new()
	right_margin.custom_minimum_size = Vector2(300, 0)
	right_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_margin.add_theme_constant_override("margin_left", 10)
	right_margin.add_theme_constant_override("margin_top", 4)
	right_margin.add_theme_constant_override("margin_right", 4)
	right_margin.add_theme_constant_override("margin_bottom", 4)
	hb_body.add_child(right_margin)

	var right = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 4)
	right_margin.add_child(right)

	var plb = Label.new()
	plb.text = "Preview"
	plb.add_theme_font_size_override("font_size", 16)
	plb.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	right.add_child(plb)

	var hint = Label.new()
	hint.text = "WASD: move  SPACE: test bomb"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
	right.add_child(hint)

	_preview_bg = ColorRect.new()
	_preview_bg.color = Color(0.14, 0.15, 0.19)
	_preview_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_bg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(_preview_bg)

	_ui.build_basic_tab(_tab_basic)
	_ui.build_character_tab(_tab_char)
	_ui.build_skills_tab(_tab_skills)
	_ui.build_drops_tab(_tab_drops)
	_render_preview()

func _on_int_changed(value: float, key: String) -> void:
	_monster[key] = int(value); _dirty = true

func _on_float_changed(value: float, key: String) -> void:
	_monster[key] = value; _dirty = true

func _on_pick_bomb_skin() -> void:
	var skins = HeroData.list_bomb_skins()
	var menu = PopupMenu.new()
	menu.add_item("None")
	for s in skins:
		menu.add_item(s)
	menu.id_pressed.connect(func(id):
		if id == 0:
			_monster.erase("bomb_skin"); _btn_bomb.text = "None"
		else:
			_monster["bomb_skin"] = skins[id - 1]; _btn_bomb.text = skins[id - 1]
		_dirty = true)
	_add_child(menu); menu.position = get_viewport().get_mouse_position(); menu.popup()

func _on_pick_character() -> void:
	var frames = MonsterData.list_character_frames()
	var menu = PopupMenu.new()
	for f in frames:
		menu.add_item(f)
	menu.id_pressed.connect(func(id):
		_monster["character"] = frames[id]; _btn_char_frame.text = frames[id]
		_dirty = true; _render_preview(); _ui.build_character_tab(_tab_char))
	_add_child(menu); menu.position = get_viewport().get_mouse_position(); menu.popup()

func _on_color_changed(c: Color, comp: String, _p: ColorPickerButton) -> void:
	if not _monster.has("colors"): _monster["colors"] = {}
	_monster["colors"][comp] = [c.r, c.g, c.b, c.a]; _dirty = true; _render_preview()

func _on_color_clear(comp: String, picker: ColorPickerButton) -> void:
	var colors = _monster.get("colors", {})
	colors.erase(comp); _monster["colors"] = colors
	picker.color = Color.WHITE; _dirty = true; _render_preview()

func _on_edit_skill(idx: int) -> void:
	var skills = _monster.get("skills", [])
	if idx >= skills.size(): return
	_ui.show_skill_dialog("Edit Skill", skills[idx], func(d): _set_skill(idx, d))

func _on_add_skill() -> void:
	_ui.show_skill_dialog("Add Skill", {"name": "", "init": 3000, "interval": 10000, "max": 3}, func(d): _add_skill(d))

func _set_skill(idx: int, data: Dictionary) -> void:
	var skills = _monster.get("skills", [])
	if idx >= skills.size(): return
	skills[idx] = data; _dirty = true; _ui.build_skills_tab(_tab_skills)

func _add_skill(data: Dictionary) -> void:
	var skills = _monster.get("skills", [])
	skills.append(data); _monster["skills"] = skills; _dirty = true; _ui.build_skills_tab(_tab_skills)

func _on_delete_skill(idx: int) -> void:
	var skills = _monster.get("skills", [])
	if idx >= skills.size(): return
	skills.remove_at(idx); _dirty = true; _ui.build_skills_tab(_tab_skills)

func _on_add_gift() -> void:
	_ui.show_gift_dialog("Add Drop", {"id": "", "weight": 10, "min": 1, "max": 1},
		func(data):
			if str(data.get("id", "")).strip_edges() == "": return
			var gifts = _monster.get("gifts", [])
			gifts.append(data); _monster["gifts"] = gifts; _dirty = true
			_ui.build_drops_tab(_tab_drops))

func _on_edit_gift(idx: int) -> void:
	var gifts = _monster.get("gifts", [])
	if idx >= gifts.size(): return
	_ui.show_gift_dialog("Edit Drop", gifts[idx],
		func(data):
			if str(data.get("id", "")).strip_edges() == "": return
			gifts[idx] = data; _dirty = true
			_ui.build_drops_tab(_tab_drops))

func _on_delete_gift(idx: int) -> void:
	var gifts = _monster.get("gifts", [])
	if idx >= gifts.size(): return
	gifts.remove_at(idx); _dirty = true
	_ui.build_drops_tab(_tab_drops)

func _measure_bounds(data: Dictionary) -> Vector2:
	var max_w = 1; var max_h = 1
	for orient in CharacterLoader.CHARACTER_ORIENTS:
		if not data.has(orient): continue
		for comp in data[orient]:
			if comp in ["Cx", "Cy"]: continue
			var frames: Array = data[orient][comp]
			for f in frames:
				if not (f is Frame): continue
				var t = f.texture
				if t == null: continue
				max_w = maxi(max_w, t.get_width())
				max_h = maxi(max_h, t.get_height())
	return Vector2(max_w, max_h)

func _calc_preview_scale(bounds: Vector2) -> float:
	if _preview_bg == null or not is_inside_tree():
		return 1.0
	var g = _preview_bg.get_global_rect()
	if g.size.x <= 0 or g.size.y <= 0:
		return 1.0
	var pad = 0.7
	var sx = g.size.x * pad / bounds.x
	var sy = g.size.y * pad / bounds.y
	return clampf(minf(sx, sy), MIN_SCALE, MAX_SCALE)

func _render_preview() -> void:
	if _preview != null:
		_preview.queue_free(); _preview = null
	var char_name = str(_monster.get("character", ""))
	if char_name == "": return

	var component_colors = {}
	for comp in _monster.get("colors", {}):
		var val = _monster["colors"][comp]
		if val is Array:
			component_colors[comp] = Color(val[0], val[1], val[2], val[3]) if val.size() >= 4 else Color(val[0], val[1], val[2])

	var result = CharacterGenerator.generate(char_name, Color.WHITE, {}, {}, component_colors, false)
	if result.is_empty(): return
	var bounds = _measure_bounds(result)
	var scale = _calc_preview_scale(bounds)
	_preview = CharacterPreview.new()
	_preview.set_character(result, _preview_orient, Color.WHITE)
	_preview.scale = Vector2(scale, scale)
	add_child(_preview)
	_position_preview.call_deferred()

func _position_preview() -> void:
	if _preview == null or _preview_bg == null or not is_inside_tree():
		return
	var g = _preview_bg.get_global_rect()
	if g.size.x <= 0 or g.size.y <= 0:
		return
	_preview.position = Vector2(g.position.x + g.size.x * 0.5, g.position.y + g.size.y * 0.5 + 10)

func _on_save() -> void:
	var name = str(_monster.get("name", "")).strip_edges()
	if name == "":
		_show_notice("Name cannot be empty!", Color(1, 0.3, 0.3)); return
	if MonsterData.save_monster(_monster):
		_dirty = false; _show_notice("Saved!", Color(0.3, 1, 0.3))
		await get_tree().create_timer(0.5).timeout; _do_quit()
		var p = get_parent()
		if p != null:
			p.add_child(load("res://src/monster_editor/monster_list.gd").new())
	else:
		_show_notice("Save failed!", Color(1, 0.3, 0.3))

func _on_delete() -> void:
	var name = str(_monster.get("name", ""))
	if name == "": return
	var dlg = ConfirmationDialog.new()
	dlg.dialog_text = "Delete monster '%s'?" % name
	dlg.ok_button_text = "Delete"; dlg.cancel_button_text = "Cancel"
	dlg.confirmed.connect(func():
		MonsterData.delete_monster(name); _do_quit()
		var p = get_parent()
		if p != null:
			p.add_child(load("res://src/monster_editor/monster_list.gd").new()))
	_add_child(dlg); dlg.popup_centered()

func _on_new_monster() -> void:
	for c in get_children(): c.queue_free()
	_preview = null; _preview_bg = null
	_monster = {
		"name": "NewMonster", "chs_name": "", "character": "CharacterBlank",
		"blood": 5000, "speed": 0, "contact": 500, "defense": 0, "resent_dist": 8,
		"boss_mode": false, "self_damage_blood": 0,
		"skills": [], "colors": {},
	}
	_dirty = true; _build_layout()

func _show_notice(msg: String, color: Color) -> void:
	var n = Label.new()
	n.text = msg; n.position = Vector2(300, 48); n.size = Vector2(200, 24)
	n.add_theme_font_size_override("font_size", 16)
	n.add_theme_color_override("font_color", color)
	add_child(n)
	await get_tree().create_timer(1.5).timeout
	if is_inside_tree(): n.queue_free()

func _on_back() -> void:
	if _dirty:
		var dlg = ConfirmationDialog.new()
		dlg.dialog_text = "Unsaved changes will be lost. Continue?"
		dlg.ok_button_text = "Discard"; dlg.cancel_button_text = "Cancel"
		dlg.confirmed.connect(_do_quit); add_child(dlg); dlg.popup_centered()
	else:
		_do_quit()

func _do_quit() -> void:
	if _list_ref != null and is_instance_valid(_list_ref):
		get_parent().add_child(_list_ref)
	queue_free()

func _process(_d: float) -> void:
	if _preview == null: return
	_position_preview()
	var moving = false; var orient = ""
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): moving = true; orient = "U"
	elif Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): moving = true; orient = "D"
	elif Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): moving = true; orient = "L"
	elif Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): moving = true; orient = "R"
	if moving:
		if orient != _preview_orient: _preview_orient = orient; _preview.set_orientation(orient)
		if not _preview.is_moving(): _preview.set_moving(true)
	else:
		if _preview.is_moving(): _preview.set_moving(false)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		get_viewport().set_input_as_handled(); _start_bomb_preview()

func _start_bomb_preview() -> void:
	if _preview == null: return
	if not _monster.has("bomb_skin"): return
	var skin = str(_monster["bomb_skin"])
	if skin == "" or skin == "None": return
	var bomb = BombLoader.get_bomb(skin)
	if bomb.is_empty() or bomb.get("STAND", []).is_empty(): return
	_preview.start_bomb(bomb["STAND"], bomb.get("INTERVAL", 300))

func _add_child(n: Node) -> void:
	add_child(n)

func _draw() -> void:
	var win = get_viewport_rect().size
	draw_rect(Rect2(0, 0, win.x, win.y), Color(0.08, 0.08, 0.12))

func _exit_tree() -> void:
	_preview = null
