extends Control

var _hero_list: Array = []
var _card_nodes: Array = []
var _scroll_offset: int = 0

const VISIBLE_COUNT = 5
const CARD_H = 90
const CARD_W = 680
const CARD_X = 60
const CARD_Y_START = 110
const CARD_GAP = 8
const ICON_W = 64

var _btn_up: Button
var _btn_down: Button
var _scroll_container: Node

func _ready() -> void:
	_update_size()
	get_viewport().size_changed.connect(_update_size)
	_hero_list = HeroData.list_heroes()
	_build_back_button()
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

	var btn_new = Button.new()
	btn_new.text = "+ New"
	btn_new.position = Vector2(660, 20)
	btn_new.size = Vector2(80, 30)
	btn_new.add_theme_font_size_override("font_size", 15)
	btn_new.pressed.connect(_on_new_character)
	add_child(btn_new)

func _build_scroll_buttons() -> void:
	_btn_up = Button.new()
	_btn_up.text = "^"
	_btn_up.position = Vector2(380, 88)
	_btn_up.size = Vector2(40, 20)
	_btn_up.add_theme_font_size_override("font_size", 16)
	_btn_up.pressed.connect(_on_scroll_up)
	_btn_up.visible = false
	add_child(_btn_up)

	var down_y = CARD_Y_START + VISIBLE_COUNT * (CARD_H + CARD_GAP)
	_btn_down = Button.new()
	_btn_down.text = "v"
	_btn_down.position = Vector2(380, down_y)
	_btn_down.size = Vector2(40, 20)
	_btn_down.add_theme_font_size_override("font_size", 16)
	_btn_down.pressed.connect(_on_scroll_down)
	_btn_down.visible = false
	add_child(_btn_down)

func _build_cards() -> void:
	_clear_cards()
	var start = _scroll_offset
	var end = mini(start + VISIBLE_COUNT, _hero_list.size())
	for i in range(start, end):
		var hero = _hero_list[i]
		var card = _make_card(hero, i, CARD_Y_START + (i - start) * (CARD_H + CARD_GAP))
		_card_nodes.append(card)
		_scroll_container.add_child(card)

	_btn_up.visible = _scroll_offset > 0
	_btn_down.visible = _scroll_offset + VISIBLE_COUNT < _hero_list.size()

func _clear_cards() -> void:
	for c in _card_nodes:
		_scroll_container.remove_child(c)
		c.queue_free()
	_card_nodes.clear()

func _make_card(hero: Dictionary, idx: int, y_pos: int) -> Control:
	var card = Control.new()
	card.position = Vector2(CARD_X, y_pos)
	card.size = Vector2(CARD_W, CARD_H)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(_on_card_click.bind(idx, card))
	card.mouse_entered.connect(func(): _on_card_hover(card, true))
	card.mouse_exited.connect(func(): _on_card_hover(card, false))

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

	var icon_rect = ColorRect.new()
	icon_rect.position = Vector2(10, 10)
	icon_rect.size = Vector2(ICON_W, CARD_H - 20)
	icon_rect.color = _get_hero_color(idx)
	icon_rect.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(icon_rect)

	if icon != "" and ResourceLoader.exists(icon_path):
		var tex = TextureRect.new()
		tex.texture = load(icon_path)
		tex.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.position = Vector2(10, 10)
		tex.size = Vector2(ICON_W, CARD_H - 20)
		tex.mouse_filter = Control.MOUSE_FILTER_PASS
		card.add_child(tex)

	var first = Label.new()
	first.text = name_str.left(1).to_upper()
	first.position = Vector2(10, 10)
	first.size = Vector2(ICON_W, CARD_H - 20)
	first.add_theme_font_size_override("font_size", 26)
	first.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	first.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	first.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	first.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(first)

	var name_lb = Label.new()
	name_lb.text = name_str
	name_lb.position = Vector2(ICON_W + 24, 14)
	name_lb.size = Vector2(350, 28)
	name_lb.add_theme_font_size_override("font_size", 20)
	name_lb.add_theme_color_override("font_color", Color(0.9, 0.92, 0.95))
	name_lb.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(name_lb)

	if hero.get("_src", "origin") == "custom":
		var tag = Label.new()
		tag.text = "[custom]"
		tag.position = Vector2(ICON_W + 24 + name_lb.get_minimum_size().x + 8, 16)
		tag.size = Vector2(70, 22)
		tag.add_theme_font_size_override("font_size", 12)
		tag.add_theme_color_override("font_color", Color(0.3, 1, 0.3))
		tag.mouse_filter = Control.MOUSE_FILTER_PASS
		card.add_child(tag)

	var blood = str(hero.get("blood", 0))
	var speed = str(hero.get("speed", 0.0))
	var bomb = str(hero.get("bomb", 0))

	var stat_lb = Label.new()
	stat_lb.text = "HP: %s   Bomb: %s   Speed: %s" % [blood, bomb, speed]
	stat_lb.position = Vector2(ICON_W + 24, 46)
	stat_lb.size = Vector2(380, 22)
	stat_lb.add_theme_font_size_override("font_size", 14)
	stat_lb.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	stat_lb.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(stat_lb)

	return card

func _get_hero_color(idx: int) -> Color:
	var palette = [
		Color(0.25, 0.3, 0.45), Color(0.35, 0.25, 0.4), Color(0.3, 0.4, 0.3),
		Color(0.4, 0.3, 0.25), Color(0.3, 0.35, 0.4), Color(0.4, 0.25, 0.3),
		Color(0.25, 0.35, 0.4), Color(0.35, 0.3, 0.35), Color(0.3, 0.35, 0.3),
		Color(0.35, 0.3, 0.4), Color(0.3, 0.4, 0.35),
	]
	return palette[idx % palette.size()]

func _on_card_click(event: InputEvent, idx: int, _card: Control) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_hero_selected(idx)

func _on_card_hover(card: Control, hovered: bool) -> void:
	var border = card.get_meta("border") if card.has_meta("border") else null
	if border != null:
		border.color = Color(0.5, 0.55, 0.65) if hovered else Color(0.3, 0.32, 0.38)

func _on_scroll_up() -> void:
	if _scroll_offset > 0:
		_scroll_offset -= 1
		_build_cards()

func _on_scroll_down() -> void:
	if _scroll_offset + VISIBLE_COUNT < _hero_list.size():
		_scroll_offset += 1
		_build_cards()

func _on_hero_selected(idx: int) -> void:
	var hero = _hero_list[idx]
	var editor = load("res://src/player_editor/character_editor.gd").new(hero)
	editor.set_meta("list_ref", self)
	var p = get_parent()
	p.add_child(editor)
	p.remove_child(self)

func _on_new_character() -> void:
	var template = {
		"name": "NewHero",
		"character": "Character10301",
		"icon_img": "",
		"use_custom_textures": false,
		"decorations": {
			"disable_foot_and_leg": false, "bomb_skin": "bomb1",
			"cap": null, "hair": null, "eye": null, "ear": null, "mouth": null,
			"cladorn": null, "fpack": null, "npack": null, "thadorn": null, "footprint": null,
			"head_effect": null, "body_effect": null
		},
		"blood": 4500, "speed": 5.83333, "bomb": 7, "restore": 700,
		"power": 3, "damage": 3500, "defense": 0, "skills": []
	}
	var editor = load("res://src/player_editor/character_editor.gd").new(template)
	editor.set_meta("list_ref", self)
	var p = get_parent()
	p.add_child(editor)
	p.remove_child(self)

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
	var title = "Character Editor"
	var ts = 28
	var tw = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, ts).x
	draw_string(font, Vector2((win.x - tw) * 0.5, 50), title, HORIZONTAL_ALIGNMENT_LEFT, -1, ts, Color(0.8, 0.9, 1.0))

	var custom_count = 0
	for h in _hero_list:
		if h.get("_src", "origin") == "custom":
			custom_count += 1
	var sub = "%d characters  |  %d customized" % [_hero_list.size(), custom_count]
	var ss = 15
	draw_string(font, Vector2((win.x - font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ss).x) * 0.5, 75), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ss, Color(0.6, 0.6, 0.6))

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
