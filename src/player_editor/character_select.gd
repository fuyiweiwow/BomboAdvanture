extends Control

var _hero_list: Array = []
var _card_nodes: Array = []
var _selected_idx: int = -1
var _preview_instance = null

var _scroll_offset: int = 0
var _custom_start: int = 0
const VISIBLE_COUNT = 4
const CARD_H = 80
const CARD_W = 360
const CARD_X = 80
const CARD_Y_START = 120
const CARD_GAP = 6
const SEP_H = 24

var _btn_up: Button
var _btn_down: Button
var _scroll_container: Node

func _ready() -> void:
	_update_size()
	get_viewport().size_changed.connect(_update_size)
	_hero_list = HeroData.list_heroes()
	_hero_list.sort_custom(func(a, b):
		var sa = 0 if a.get("_src", "origin") == "origin" else 1
		var sb = 0 if b.get("_src", "origin") == "origin" else 1
		if sa != sb: return sa < sb
		return a["name"] < b["name"])
	_custom_start = _hero_list.size()
	for i in _hero_list.size():
		if _hero_list[i].get("_src", "origin") == "custom":
			_custom_start = i
			break
	_build_back_button()
	_build_title()
	_build_scroll_buttons()
	_scroll_container = Node.new()
	add_child(_scroll_container)
	_build_cards()
	_build_action_buttons()

	if _hero_list.size() > 0:
		_select_hero(0)

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

	var down_y = CARD_Y_START + VISIBLE_COUNT * (CARD_H + CARD_GAP)
	_btn_down = Button.new()
	_btn_down.text = "v"
	_btn_down.position = Vector2(100, 500)
	_btn_down.size = Vector2(30, 20)
	_btn_down.add_theme_font_size_override("font_size", 14)
	_btn_down.pressed.connect(_on_scroll_down)
	_btn_down.visible = false
	add_child(_btn_down)

func _build_cards() -> void:
	_clear_cards()
	var start = _scroll_offset
	var end = mini(start + VISIBLE_COUNT, _hero_list.size())
	var draw_idx = 0
	for i in range(start, end):
		var y = CARD_Y_START + draw_idx * (CARD_H + CARD_GAP)
		if i == _custom_start and _custom_start < _hero_list.size():
			var sep = _make_separator(y)
			_card_nodes.append(sep)
			_scroll_container.add_child(sep)
			draw_idx += 1
			y = CARD_Y_START + draw_idx * (CARD_H + CARD_GAP)
		var hero = _hero_list[i]
		var card = _make_card(hero, i, y)
		_card_nodes.append(card)
		_scroll_container.add_child(card)
		draw_idx += 1
	_btn_up.visible = _scroll_offset > 0
	_btn_down.visible = _scroll_offset + VISIBLE_COUNT < _hero_list.size()

func _clear_cards() -> void:
	for c in _card_nodes:
		_scroll_container.remove_child(c)
		c.queue_free()
	_card_nodes.clear()

func _on_scroll_up() -> void:
	if _scroll_offset > 0:
		_scroll_offset -= 1
		_build_cards()
		if _selected_idx >= 0:
			_highlight_selected()

func _on_scroll_down() -> void:
	if _scroll_offset + VISIBLE_COUNT < _hero_list.size():
		_scroll_offset += 1
		_build_cards()
		if _selected_idx >= 0:
			_highlight_selected()

func _make_card(hero: Dictionary, idx: int, y_pos: int) -> Control:
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

	var name_str = str(hero.get("name", "?"))
	var icon = str(hero.get("icon_img", ""))
	var icon_path = "res://assets/img/ui/game/" + icon + ".png"
	var icon_slot = ColorRect.new()
	icon_slot.position = Vector2(8, 8)
	icon_slot.size = Vector2(48, CARD_H - 16)
	icon_slot.color = _get_slot_color(idx)
	icon_slot.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(icon_slot)

	if icon != "" and ResourceLoader.exists(icon_path):
		var tex = TextureRect.new()
		tex.texture = load(icon_path)
		tex.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.position = Vector2(8, 8)
		tex.size = Vector2(48, CARD_H - 16)
		tex.mouse_filter = Control.MOUSE_FILTER_PASS
		card.add_child(tex)

	var fl = Label.new()
	fl.text = name_str.left(1).to_upper()
	fl.position = Vector2(8, 8)
	fl.size = Vector2(48, CARD_H - 16)
	fl.add_theme_font_size_override("font_size", 24)
	fl.add_theme_color_override("font_color", Color(1, 1, 1, 0.3))
	fl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fl.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(fl)

	var name_lb = Label.new()
	name_lb.text = name_str
	name_lb.position = Vector2(64, 8)
	name_lb.size = Vector2(200, 26)
	name_lb.add_theme_font_size_override("font_size", 18)
	name_lb.add_theme_color_override("font_color", Color(0.9, 0.92, 0.95))
	name_lb.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(name_lb)

	if hero.get("_src", "origin") == "custom":
		var tag = Label.new()
		tag.text = "[custom]"
		tag.position = Vector2(64 + name_lb.get_minimum_size().x + 6, 10)
		tag.size = Vector2(60, 20)
		tag.add_theme_font_size_override("font_size", 11)
		tag.add_theme_color_override("font_color", Color(0.3, 1, 0.3))
		tag.mouse_filter = Control.MOUSE_FILTER_PASS
		card.add_child(tag)

	var blood = str(hero.get("blood", 0))
	var speed = str(hero.get("speed", 0.0))
	var bomb = str(hero.get("bomb", 0))
	var stat = Label.new()
	stat.text = "HP: %s   Bomb: %s   Speed: %s" % [blood, bomb, speed]
	stat.position = Vector2(64, 36)
	stat.size = Vector2(280, 22)
	stat.add_theme_font_size_override("font_size", 13)
	stat.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	stat.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(stat)

	var char_name = str(hero.get("character", ""))
	var frame = Label.new()
	frame.text = "Frame: " + char_name
	frame.position = Vector2(64, 54)
	frame.size = Vector2(280, 18)
	frame.add_theme_font_size_override("font_size", 11)
	frame.add_theme_color_override("font_color", Color(0.45, 0.5, 0.55))
	frame.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(frame)

	return card

func _on_card_click(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_hero(idx)

func _select_hero(idx: int) -> void:
	if idx < 0 or idx >= _hero_list.size():
		return
	_selected_idx = idx
	_highlight_selected()
	_render_preview()

func _make_separator(y_pos: int) -> Control:
	var sep = Control.new()
	sep.position = Vector2(CARD_X, y_pos)
	sep.size = Vector2(CARD_W, SEP_H)
	sep.mouse_filter = Control.MOUSE_FILTER_PASS

	var line = ColorRect.new()
	line.color = Color(0.25, 0.27, 0.32)
	line.position = Vector2(0, SEP_H * 0.5 - 1)
	line.size = Vector2(CARD_W, 1)
	sep.add_child(line)

	var lb = Label.new()
	lb.text = "────  Custom Characters  ────"
	lb.position = Vector2(0, 0)
	lb.size = Vector2(CARD_W, SEP_H)
	lb.add_theme_font_size_override("font_size", 12)
	lb.add_theme_color_override("font_color", Color(0.4, 0.45, 0.5))
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sep.add_child(lb)

	return sep

func _highlight_selected() -> void:
	var start = _scroll_offset
	var end = mini(start + VISIBLE_COUNT, _hero_list.size())
	var ci = 0
	for i in range(start, end):
		if i == _custom_start and _custom_start < _hero_list.size():
			ci += 1
		if ci < _card_nodes.size():
			var card = _card_nodes[ci]
			var border = card.get_meta("border") if card.has_meta("border") else null
			if border != null:
				border.color = Color(0.6, 0.65, 0.8) if i == _selected_idx else Color(0.3, 0.32, 0.38)
		ci += 1

func _render_preview() -> void:
	if _preview_instance != null:
		_preview_instance.queue_free()
		_preview_instance = null

	if _selected_idx < 0 or _selected_idx >= _hero_list.size():
		return
	var hero = _hero_list[_selected_idx]
	var hero_name = str(hero.get("name", ""))
	if hero_name == "":
		return

	var color = C.CHARACTER_RED
	var result = CharacterGenerator.generate_from_hero(hero, color)
	if result.is_empty():
		return

	_preview_instance = CharacterPreview.new()
	_preview_instance.set_character(result)
	_preview_instance.position = Vector2(610, 220)
	_preview_instance.scale = Vector2(1.8, 1.8)
	add_child(_preview_instance)

func _build_action_buttons() -> void:
	var by = 520
	var btn_normal = Button.new()
	btn_normal.text = "Normal Mode"
	btn_normal.position = Vector2(200, by)
	btn_normal.size = Vector2(180, 44)
	btn_normal.add_theme_font_size_override("font_size", 18)
	btn_normal.pressed.connect(_on_start_normal)
	add_child(btn_normal)

	var btn_dev = Button.new()
	btn_dev.text = "Dev Mode"
	btn_dev.position = Vector2(400, by)
	btn_dev.size = Vector2(180, 44)
	btn_dev.add_theme_font_size_override("font_size", 18)
	btn_dev.pressed.connect(_on_start_dev)
	add_child(btn_dev)

func _on_start_normal() -> void:
	_start_game(false)

func _on_start_dev() -> void:
	_start_game(true)

func _start_game(dev: bool) -> void:
	if _selected_idx < 0 or _selected_idx >= _hero_list.size():
		return
	var hero = _hero_list[_selected_idx]
	var hero_name = str(hero.get("name", ""))
	if hero_name == "":
		return
	Game.selected_hero = hero_name
	Game.start_game(dev)
	queue_free()

func _on_back() -> void:
	var ts = Control.new()
	ts.set_script(preload("res://src/main/title_screen.gd"))
	Game.add_child(ts)
	queue_free()

func _draw() -> void:
	var win = get_viewport_rect().size
	draw_rect(Rect2(0, 0, win.x, win.y), Color(0.1, 0.1, 0.15))
	var font = ThemeDB.fallback_font
	if font == null:
		return
	var title = "Select Character"
	var ts = 28
	var tw = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, ts).x
	draw_string(font, Vector2((win.x - tw) * 0.5, 65), title, HORIZONTAL_ALIGNMENT_LEFT, -1, ts, Color(0.8, 0.9, 1.0))

	var px = 500
	var py = 100
	var pw = 300
	var ph = 400
	draw_rect(Rect2(px, py, pw, ph), Color(0.14, 0.15, 0.19))
	draw_rect(Rect2(px, py, pw, ph), Color(0.3, 0.32, 0.38), false, 1.5)

	if _selected_idx >= 0 and _selected_idx < _hero_list.size():
		var hero = _hero_list[_selected_idx]
		var name_str = str(hero.get("name", ""))
		var is_custom = hero.get("_src", "origin") == "custom"
		draw_string(font, Vector2(px + 20, py + 30), name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.9, 0.92, 0.95))
		if is_custom:
			draw_string(font, Vector2(px + 160, py + 30), "[custom]", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.3, 1, 0.3))

		var blood = str(hero.get("blood", 0))
		var speed = str(hero.get("speed", 0.0))
		var bomb = str(hero.get("bomb", 0))
		var power = str(hero.get("power", 0))
		var damage = str(hero.get("damage", 0))
		var lines = [
			"HP:     %s" % blood,
			"Bomb:   %s" % bomb,
			"Speed:  %s" % speed,
			"Power:  %s" % power,
			"Damage: %s" % damage,
		]
		var sy = 360
		for line in lines:
			draw_string(font, Vector2(px + 20, sy), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.6, 0.65, 0.7))
			sy += 22

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

func _get_slot_color(idx: int) -> Color:
	var palette = [
		Color(0.25, 0.3, 0.45), Color(0.35, 0.25, 0.4), Color(0.3, 0.4, 0.3),
		Color(0.4, 0.3, 0.25), Color(0.3, 0.35, 0.4), Color(0.4, 0.25, 0.3),
		Color(0.25, 0.35, 0.4), Color(0.35, 0.3, 0.35), Color(0.3, 0.35, 0.3),
		Color(0.35, 0.3, 0.4), Color(0.3, 0.4, 0.35),
	]
	return palette[idx % palette.size()]
