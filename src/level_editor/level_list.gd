extends Control

var _level_list: Array = []
var _card_nodes: Array = []
var _selected_idx: int = -1

var _scroll_offset: int = 0
const VISIBLE_COUNT = 5
const CARD_H = 70
const CARD_W = 460
const CARD_X = 80
const CARD_Y_START = 120
const CARD_GAP = 6

var _btn_up: Button
var _btn_down: Button
var _scroll_container: Node

func _ready() -> void:
	_update_size()
	get_viewport().size_changed.connect(_update_size)
	_level_list = LevelData.list_levels()
	_build_back_button()
	_build_new_button()
	_build_title()
	_build_scroll_buttons()
	_scroll_container = Node.new()
	add_child(_scroll_container)
	_build_cards()

func _update_size() -> void:
	var win = get_viewport_rect().size
	size = win
	position = Vector2(0, 0)

func _build_back_button() -> void:
	var btn = Button.new()
	btn.text = "< Back"
	btn.position = Vector2(20, 20)
	btn.size = Vector2(100, 30)
	btn.add_theme_font_size_override("font_size", 16)
	btn.pressed.connect(_on_back)
	add_child(btn)

func _build_new_button() -> void:
	var btn = Button.new()
	btn.text = "+ New Level"
	btn.position = Vector2(540, 20)
	btn.size = Vector2(160, 30)
	btn.add_theme_font_size_override("font_size", 16)
	btn.pressed.connect(_on_new)
	add_child(btn)

func _build_title() -> void:
	pass

func _build_scroll_buttons() -> void:
	_btn_up = Button.new()
	_btn_up.text = "^"
	_btn_up.position = Vector2(100, 98)
	_btn_up.size = Vector2(30, 20)
	_btn_up.add_theme_font_size_override("font_size", 14)
	_btn_up.pressed.connect(_on_scroll_up)
	_btn_up.visible = false
	add_child(_btn_up)

	_btn_down = Button.new()
	_btn_down.text = "v"
	_btn_down.position = Vector2(100, CARD_Y_START + VISIBLE_COUNT * (CARD_H + CARD_GAP))
	_btn_down.size = Vector2(30, 20)
	_btn_down.add_theme_font_size_override("font_size", 14)
	_btn_down.pressed.connect(_on_scroll_down)
	_btn_down.visible = false
	add_child(_btn_down)

func _build_cards() -> void:
	_clear_cards()
	var start = _scroll_offset
	var end = mini(start + VISIBLE_COUNT, _level_list.size())
	var draw_idx = 0
	for i in range(start, end):
		var y = CARD_Y_START + draw_idx * (CARD_H + CARD_GAP)
		var level = _level_list[i]
		var card = _make_card(level, i, y)
		_card_nodes.append(card)
		_scroll_container.add_child(card)
		draw_idx += 1
	_btn_up.visible = _scroll_offset > 0
	_btn_down.visible = _scroll_offset + VISIBLE_COUNT < _level_list.size()

func _clear_cards() -> void:
	for c in _card_nodes:
		_scroll_container.remove_child(c)
		c.queue_free()
	_card_nodes.clear()

func _on_scroll_up() -> void:
	if _scroll_offset > 0:
		_scroll_offset -= 1
		_build_cards()

func _on_scroll_down() -> void:
	if _scroll_offset + VISIBLE_COUNT < _level_list.size():
		_scroll_offset += 1
		_build_cards()

func _make_card(level: Dictionary, idx: int, y_pos: int) -> Control:
	var card = Control.new()
	card.position = Vector2(CARD_X, y_pos)
	card.size = Vector2(CARD_W, CARD_H)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(_on_card_click.bind(idx))

	var border = ColorRect.new()
	border.color = Color(0.3, 0.32, 0.38)
	border.position = Vector2(0, 0)
	border.size = Vector2(CARD_W, CARD_H)
	border.mouse_filter = Control.MOUSE_FILTER_PASS
	card.set_meta("border", border)
	card.add_child(border)

	var inner = ColorRect.new()
	inner.color = Color(0.17, 0.18, 0.22)
	inner.position = Vector2(1, 1)
	inner.size = Vector2(CARD_W - 2, CARD_H - 2)
	inner.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(inner)

	var src = level.get("_src", "custom")
	var name_str = str(level.get("display_name", level.get("name", "?")))
	var map_count = level.get("maps", []).size()
	var desc = str(level.get("description", ""))

	var name_lb = Label.new()
	name_lb.text = name_str
	name_lb.position = Vector2(16, 10)
	name_lb.size = Vector2(CARD_W - 32, 26)
	name_lb.add_theme_font_size_override("font_size", 18)
	name_lb.add_theme_color_override("font_color", Color(0.9, 0.92, 0.95))
	card.add_child(name_lb)

	var tag_text = "[compat]" if src == "compat" else "[custom]"
	var tag_color = Color(0.3, 0.7, 1.0) if src == "compat" else Color(0.3, 1, 0.3)
	var tag = Label.new()
	tag.text = tag_text
	tag.position = Vector2(16 + name_lb.get_minimum_size().x + 8, 12)
	tag.size = Vector2(70, 20)
	tag.add_theme_font_size_override("font_size", 11)
	tag.add_theme_color_override("font_color", tag_color)
	card.add_child(tag)

	var info = Label.new()
	info.text = "Maps: %d" % map_count
	info.position = Vector2(16, 38)
	info.size = Vector2(200, 18)
	info.add_theme_font_size_override("font_size", 13)
	info.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	card.add_child(info)

	if desc != "":
		var desc_lb = Label.new()
		desc_lb.text = desc
		desc_lb.position = Vector2(130, 38)
		desc_lb.size = Vector2(CARD_W - 150, 18)
		desc_lb.add_theme_font_size_override("font_size", 12)
		desc_lb.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
		card.add_child(desc_lb)

	return card

func _on_card_click(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if idx >= 0 and idx < _level_list.size():
			_selected_idx = idx
			_open_editor(idx)

func _open_editor(idx: int) -> void:
	var level = _level_list[idx]
	var editor = load("res://src/level_editor/level_editor.gd").new()
	editor.set_level_name(level.get("name", ""))
	var is_compat = level.get("_src") == "compat"
	editor.set_read_only(is_compat)
	Game.add_child(editor)
	queue_free()

func _on_back() -> void:
	var ts = Control.new()
	ts.set_script(preload("res://src/main/title_screen.gd"))
	Game.add_child(ts)
	queue_free()

func _on_new() -> void:
	var editor = load("res://src/level_editor/level_editor.gd").new()
	Game.add_child(editor)
	queue_free()

func _draw() -> void:
	var win = get_viewport_rect().size
	draw_rect(Rect2(0, 0, win.x, win.y), Color(0.1, 0.1, 0.15))
	var font = ThemeDB.fallback_font
	if font == null:
		return
	var title = "Level Editor"
	var ts = 28
	var tw = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, ts).x
	draw_string(font, Vector2((win.x - tw) * 0.5, 65), title, HORIZONTAL_ALIGNMENT_LEFT, -1, ts, Color(0.8, 0.9, 1.0))

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_on_scroll_up()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_on_scroll_down()
			get_viewport().set_input_as_handled()
