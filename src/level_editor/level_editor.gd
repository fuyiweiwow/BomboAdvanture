extends Control

var _level_data: Dictionary = {
	"name": "",
	"display_name": "",
	"description": "",
	"maps": [],
}

var _editing_name: String = ""
var _selected_map_idx: int = -1
var _map_list_container: VBoxContainer
var _property_container: VBoxContainer
var _name_edit: LineEdit
var _display_name_edit: LineEdit
var _desc_edit: TextEdit
var _available_maps: Array = []
var _read_only: bool = false

func _ready() -> void:
	_update_size()
	get_viewport().size_changed.connect(_update_size)
	_refresh_available_maps()
	_rebuild_all()

func _update_size() -> void:
	var win = get_viewport_rect().size
	size = win
	position = Vector2(0, 0)

func set_read_only(v: bool) -> void:
	_read_only = v

func set_level_name(name: String) -> void:
	_editing_name = name
	var data = LevelData.load_level(name)
	if data and not data.is_empty():
		_level_data = data
		_editing_name = name

func _refresh_available_maps() -> void:
	_available_maps.clear()
	var dir = DirAccess.open("res://assets/map/")
	if dir:
		dir.list_dir_begin()
		var fname = dir.get_next()
		while fname != "":
			if fname.ends_with(".json"):
				_available_maps.append(fname.trim_suffix(".json"))
			fname = dir.get_next()
		dir.list_dir_end()
	_available_maps.sort()

func _on_back() -> void:
	var list = load("res://src/level_editor/level_list.gd").new()
	get_tree().root.add_child(list)
	queue_free()

func _on_save() -> void:
	if _read_only:
		return
	_level_data["display_name"] = _display_name_edit.text
	_level_data["description"] = _desc_edit.text
	var new_name = _name_edit.text.strip_edges()
	if new_name == "":
		return
	var old_name = _level_data.get("name", "")
	_level_data["name"] = new_name

	if not LevelData.save_level(_level_data):
		return
	if old_name != "" and old_name != new_name:
		LevelData.delete_level(old_name)
	_on_back()

func _on_add_map() -> void:
	_level_data["maps"].append({
		"type": "predefined",
		"play_mode": "adventure",
		"map_id": _available_maps[0] if _available_maps.size() > 0 else "",
	})
	_selected_map_idx = _level_data["maps"].size() - 1
	_rebuild_all()

func _on_remove_map() -> void:
	if _selected_map_idx < 0 or _selected_map_idx >= _level_data["maps"].size():
		return
	_level_data["maps"].remove_at(_selected_map_idx)
	_selected_map_idx = -1
	_rebuild_all()

func _on_map_click(idx: int) -> void:
	_selected_map_idx = idx
	_rebuild_all()

func _on_map_move_up() -> void:
	if _selected_map_idx <= 0:
		return
	var maps = _level_data["maps"]
	var temp = maps[_selected_map_idx]
	maps[_selected_map_idx] = maps[_selected_map_idx - 1]
	maps[_selected_map_idx - 1] = temp
	_selected_map_idx -= 1
	_rebuild_all()

func _on_map_move_down() -> void:
	var maps = _level_data["maps"]
	if _selected_map_idx < 0 or _selected_map_idx >= maps.size() - 1:
		return
	var temp = maps[_selected_map_idx]
	maps[_selected_map_idx] = maps[_selected_map_idx + 1]
	maps[_selected_map_idx + 1] = temp
	_selected_map_idx += 1
	_rebuild_all()

func _rebuild_all() -> void:
	for c in get_children():
		c.queue_free()
	_build_ui()

func _build_ui() -> void:
	_build_top_bar()

func _build_top_bar() -> void:
	var bar = HBoxContainer.new()
	bar.position = Vector2(10, 10)
	bar.size = Vector2(size.x - 20, 36)
	add_child(bar)

	if _read_only:
		var compat_lb = Label.new()
		compat_lb.text = "[Read Only] " + _level_data.get("name", _editing_name)
		compat_lb.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))
		compat_lb.add_theme_font_size_override("font_size", 18)
		compat_lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.add_child(compat_lb)
	else:
		_name_edit = LineEdit.new()
		_name_edit.placeholder_text = "Level ID (filename)"
		_name_edit.text = _level_data.get("name", _editing_name)
		_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.add_child(_name_edit)

		var btn_save = Button.new()
		btn_save.text = "Save"
		btn_save.pressed.connect(_on_save)
		bar.add_child(btn_save)

	var btn_back = Button.new()
	btn_back.text = "Back"
	btn_back.pressed.connect(_on_back)
	bar.add_child(btn_back)

	var bar_h = 50

	if _read_only:
		var dn_lb = Label.new()
		dn_lb.text = _level_data.get("display_name", _level_data.get("name", ""))
		dn_lb.position = Vector2(10, bar_h + 4)
		dn_lb.size = Vector2(size.x - 20, 30)
		dn_lb.add_theme_font_size_override("font_size", 16)
		dn_lb.add_theme_color_override("font_color", Color(0.9, 0.92, 0.95))
		add_child(dn_lb)

		var desc = _level_data.get("description", "")
		if desc != "":
			var d_lb = Label.new()
			d_lb.text = desc
			d_lb.position = Vector2(10, bar_h + 38)
			d_lb.size = Vector2(size.x - 20, 60)
			d_lb.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
			d_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			add_child(d_lb)
	else:
		_display_name_edit = LineEdit.new()
		_display_name_edit.placeholder_text = "Display Name"
		_display_name_edit.text = _level_data.get("display_name", "")
		_display_name_edit.position = Vector2(10, bar_h + 4)
		_display_name_edit.size = Vector2(size.x - 20, 30)
		add_child(_display_name_edit)

		_desc_edit = TextEdit.new()
		_desc_edit.placeholder_text = "Description"
		_desc_edit.text = _level_data.get("description", "")
		_desc_edit.position = Vector2(10, bar_h + 38)
		_desc_edit.size = Vector2(size.x - 20, 60)
		add_child(_desc_edit)

	var left_x = 10
	var left_w = int(size.x * 0.35)
	var right_x = left_x + left_w + 10
	var right_w = int(size.x * 0.65) - 20

	var map_label = Label.new()
	map_label.text = "Maps:"
	map_label.position = Vector2(left_x, bar_h + 106)
	map_label.add_theme_font_size_override("font_size", 16)
	map_label.add_theme_color_override("font_color", Color(0.9, 0.92, 0.95))
	add_child(map_label)

	if not _read_only:
		var map_btn_bar = HBoxContainer.new()
		map_btn_bar.position = Vector2(left_x + 60, bar_h + 104)
		map_btn_bar.size = Vector2(left_w - 60, 28)
		add_child(map_btn_bar)

		var btn_add = Button.new()
		btn_add.text = "+"
		btn_add.size = Vector2(30, 26)
		btn_add.pressed.connect(_on_add_map)
		map_btn_bar.add_child(btn_add)

		var btn_remove = Button.new()
		btn_remove.text = "-"
		btn_remove.size = Vector2(30, 26)
		btn_remove.pressed.connect(_on_remove_map)
		map_btn_bar.add_child(btn_remove)

		var btn_up = Button.new()
		btn_up.text = "^"
		btn_up.size = Vector2(30, 26)
		btn_up.pressed.connect(_on_map_move_up)
		map_btn_bar.add_child(btn_up)

		var btn_down = Button.new()
		btn_down.text = "v"
		btn_down.size = Vector2(30, 26)
		btn_down.pressed.connect(_on_map_move_down)
		map_btn_bar.add_child(btn_down)

	var scroll = ScrollContainer.new()
	scroll.position = Vector2(left_x, bar_h + 134)
	scroll.size = Vector2(left_w, size.y - bar_h - 144)
	add_child(scroll)

	_map_list_container = VBoxContainer.new()
	_map_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_map_list_container)

	for i in _level_data["maps"].size():
		_build_map_entry(i)

	var right_scroll = ScrollContainer.new()
	right_scroll.position = Vector2(right_x, bar_h + 104)
	right_scroll.size = Vector2(right_w, size.y - bar_h - 114)
	add_child(right_scroll)

	_property_container = VBoxContainer.new()
	_property_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.add_child(_property_container)

	if _selected_map_idx >= 0 and _selected_map_idx < _level_data["maps"].size():
		_build_map_properties(_selected_map_idx)

func _build_map_entry(idx: int) -> void:
	var map_data = _level_data["maps"][idx]
	var is_selected = idx == _selected_map_idx

	var entry = HBoxContainer.new()
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var btn = Button.new()
	var map_label = ""
	if map_data.get("type") == "predefined":
		map_label = str(map_data.get("map_id", "?"))
	else:
		map_label = "[proc] " + str(map_data.get("play_mode", "?"))

	var pm = "A" if map_data.get("play_mode") == "adventure" else "D"
	btn.text = "%d. [%s][%s] %s" % [idx + 1, pm, "P" if map_data.get("type") == "predefined" else "R", map_label]
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.flat = true
	btn.add_theme_color_override("font_color", Color(0.9, 0.92, 1.0) if is_selected else Color(0.7, 0.72, 0.8))
	btn.add_theme_stylebox_override("normal", _make_bg(is_selected))
	btn.pressed.connect(_on_map_click.bind(idx))
	entry.add_child(btn)
	_map_list_container.add_child(entry)

func _make_bg(selected: bool) -> StyleBoxFlat:
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.25, 0.28, 0.35) if selected else Color(0.15, 0.16, 0.2)
	return bg

func _build_map_properties(idx: int) -> void:
	var map_data = _level_data["maps"][idx]

	var title = Label.new()
	title.text = "Map %d Properties" % (idx + 1)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.9, 0.92, 0.95))
	_property_container.add_child(title)

	if _read_only:
		var ti = Label.new()
		ti.text = "Type: " + map_data.get("type", "?")
		ti.add_theme_color_override("font_color", Color(0.8, 0.82, 0.9))
		_property_container.add_child(ti)
		var mi = Label.new()
		mi.text = "Mode: " + map_data.get("play_mode", "?")
		mi.add_theme_color_override("font_color", Color(0.8, 0.82, 0.9))
		_property_container.add_child(mi)
		if map_data.get("type") == "predefined":
			var pi = Label.new()
			pi.text = "Map: " + map_data.get("map_id", "?")
			pi.add_theme_color_override("font_color", Color(0.8, 0.82, 0.9))
			_property_container.add_child(pi)
	else:
		var type_hbox = HBoxContainer.new()
		var type_label = Label.new()
		type_label.text = "Type: "
		type_label.add_theme_color_override("font_color", Color(0.8, 0.82, 0.9))
		type_hbox.add_child(type_label)
		var type_opt = OptionButton.new()
		type_opt.add_item("Predefined", 0)
		type_opt.add_item("Procedural", 1)
		type_opt.selected = 1 if map_data.get("type") == "procedural" else 0
		type_opt.id_pressed.connect(func(id):
			map_data["type"] = "predefined" if id == 0 else "procedural"
			_rebuild_all())
		type_hbox.add_child(type_opt)
		_property_container.add_child(type_hbox)

		var mode_hbox = HBoxContainer.new()
		var mode_label = Label.new()
		mode_label.text = "Mode: "
		mode_label.add_theme_color_override("font_color", Color(0.8, 0.82, 0.9))
		mode_hbox.add_child(mode_label)
		var mode_opt = OptionButton.new()
		mode_opt.add_item("Adventure", 0)
		mode_opt.add_item("Duel", 1)
		mode_opt.selected = 1 if map_data.get("play_mode") == "duel" else 0
		mode_opt.id_pressed.connect(func(id):
			map_data["play_mode"] = "adventure" if id == 0 else "duel"
			_rebuild_all())
		mode_hbox.add_child(mode_opt)
		_property_container.add_child(mode_hbox)

		if map_data.get("type") == "predefined":
			_build_predefined_props(map_data)
		else:
			_build_procedural_props(map_data)

	_property_container.add_child(HSeparator.new())

func _build_predefined_props(map_data: Dictionary) -> void:
	var map_hbox = HBoxContainer.new()
	var map_label = Label.new()
	map_label.text = "Map: "
	map_label.add_theme_color_override("font_color", Color(0.8, 0.82, 0.9))
	map_hbox.add_child(map_label)
	var map_opt = OptionButton.new()
	var current_map = str(map_data.get("map_id", ""))
	var sel_idx = 0
	for i in _available_maps.size():
		map_opt.add_item(_available_maps[i], i)
		if _available_maps[i] == current_map:
			sel_idx = i
	map_opt.selected = sel_idx
	map_opt.id_pressed.connect(func(id):
		map_data["map_id"] = _available_maps[id]
		_rebuild_all())
	map_hbox.add_child(map_opt)
	_property_container.add_child(map_hbox)

func _build_procedural_props(map_data: Dictionary) -> void:
	var params = map_data.get("generator_params", {})
	if params.is_empty():
		params = {
			"width": 25, "height": 13,
			"floor_texture_pool": ["elem220"],
			"obstacle_pool": ["elem212"],
			"interactive_pool": ["elem225", "elem226"],
			"monster_pool": ["Slime"],
			"monster_count_min": 3,
			"monster_count_max": 6,
			"seed": null,
		}
		map_data["generator_params"] = params

	_property_container.add_child(_build_int_field("Width", params, "width", 10, 100))
	_property_container.add_child(_build_int_field("Height", params, "height", 10, 100))
	_property_container.add_child(_build_int_field("Monster Min", params, "monster_count_min", 0, 50))
	_property_container.add_child(_build_int_field("Monster Max", params, "monster_count_max", 0, 50))

	_property_container.add_child(_build_text_array_field("Floor Textures", params, "floor_texture_pool"))
	_property_container.add_child(_build_text_array_field("Obstacles", params, "obstacle_pool"))
	_property_container.add_child(_build_text_array_field("Interactive", params, "interactive_pool"))
	_property_container.add_child(_build_text_array_field("Monsters", params, "monster_pool"))

func _build_int_field(label: String, dict: Dictionary, key: String, min_v: int, max_v: int) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	var lb = Label.new()
	lb.text = label + ": "
	lb.add_theme_color_override("font_color", Color(0.8, 0.82, 0.9))
	hbox.add_child(lb)
	var spin = SpinBox.new()
	spin.min_value = min_v
	spin.max_value = max_v
	spin.value = dict.get(key, min_v)
	spin.value_changed.connect(func(v): dict[key] = int(v))
	hbox.add_child(spin)
	return hbox

func _build_text_array_field(label: String, dict: Dictionary, key: String) -> VBoxContainer:
	var vbox = VBoxContainer.new()
	var header = HBoxContainer.new()
	var lb = Label.new()
	lb.text = label + ": "
	lb.add_theme_color_override("font_color", Color(0.8, 0.82, 0.9))
	header.add_child(lb)

	var items = dict.get(key, [])
	var items_str = ",".join(items)
	var edit = LineEdit.new()
	edit.text = items_str
	edit.placeholder_text = "comma separated"
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text_changed.connect(func(t):
		var arr = []
		for s in t.split(","):
			var stripped = s.strip_edges()
			if stripped != "":
				arr.append(stripped)
		dict[key] = arr)
	header.add_child(edit)
	vbox.add_child(header)
	return vbox

func _draw() -> void:
	var win = get_viewport_rect().size
	draw_rect(Rect2(0, 0, win.x, win.y), Color(0.1, 0.1, 0.15))
