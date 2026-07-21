extends Control

var _hero: Dictionary = {}
var _dirty: bool = false
var _current_color: Color = C.CHARACTER_RED
var _color_idx: int = 0
var _color_list: Array = []
var _preview_instance = null
var _list_ref = null
var _use_custom_tex: bool = false
var _preview_orient: String = "D"
var _preview_base_pos: Vector2 = Vector2.ZERO
var _preview_move_offset: Vector2 = Vector2.ZERO

var _tab_basic: VBoxContainer
var _tab_deco: VBoxContainer
var _tab_skills: VBoxContainer
var _tab_tex: VBoxContainer
var _btn_bomb: Button
var _color_swatch_container: HBoxContainer
var _ui: CharacterEditorUI

const DECO_CATEGORIES = ["cap", "hair", "eye", "ear", "mouth", "cladorn", "fpack", "npack", "thadorn", "footprint"]

func _init(hero: Dictionary):
	_hero = hero.duplicate(true)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_update_size()
	get_viewport().size_changed.connect(_update_size)
	_list_ref = get_meta("list_ref") if has_meta("list_ref") else null
	_build_colors()
	_ui = CharacterEditorUI.new(self)
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
	_color_list = [C.CHARACTER_RED, C.CHARACTER_BLUE, C.CHARACTER_YELLOW, C.CHARACTER_GREEN, C.CHARACTER_ORANGE, C.CHARACTER_PINK, C.CHARACTER_PURPLE, C.CHARACTER_BLACK]

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

	_tab_basic = _ui.add_tab("Basic", tab_container)
	_tab_deco = _ui.add_tab("Decorations", tab_container)
	_tab_skills = _ui.add_tab("Skills", tab_container)
	_tab_tex = _ui.add_tab("Custom Textures", tab_container)

	var preview_bg = ColorRect.new()
	preview_bg.position = Vector2(500, TAB_Y)
	preview_bg.size = Vector2(290, TAB_H)
	preview_bg.color = Color(0.14, 0.15, 0.19)
	add_child(preview_bg)

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
	hint.text = "WASD: move  SPACE: bomb"
	hint.position = Vector2(505, TAB_Y + 32)
	hint.size = Vector2(280, 16)
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
	add_child(hint)

func _rebuild_ui() -> void:
	_ui.build_basic_tab(_tab_basic)
	_ui.build_deco_tab(_tab_deco)
	_ui.build_skills_tab(_tab_skills)
	_ui.build_tex_tab(_tab_tex)
	_render_preview()

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
	_preview_base_pos = Vector2(area_x + area_w * 0.5, area_y + area_h * 0.5 + 10)
	_preview_move_offset = Vector2.ZERO
	_preview_instance.position = _preview_base_pos
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

func _process(_delta: float) -> void:
	if _preview_instance == null:
		return
	var moving = false
	var new_orient = ""
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		moving = true
		new_orient = "U"
	elif Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		moving = true
		new_orient = "D"
	elif Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		moving = true
		new_orient = "L"
	elif Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		moving = true
		new_orient = "R"

	if moving:
		if new_orient != _preview_orient:
			_preview_orient = new_orient
			_preview_instance.set_orientation(_preview_orient)
		if not _preview_instance.is_moving():
			_preview_instance.set_moving(true)
	else:
		if _preview_instance.is_moving():
			_preview_instance.set_moving(false)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				get_viewport().set_input_as_handled()
				_start_bomb_preview()

func _start_bomb_preview() -> void:
	if _preview_instance == null:
		return
	var skin = _hero.get("decorations", {}).get("bomb_skin", "bomb1")
	if skin == "":
		skin = "bomb1"
	var bomb = BombLoader.get_bomb(skin)
	if bomb.is_empty() or bomb.get("STAND", []).is_empty():
		return
	_preview_instance.start_bomb(bomb["STAND"], bomb.get("INTERVAL", 300))

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