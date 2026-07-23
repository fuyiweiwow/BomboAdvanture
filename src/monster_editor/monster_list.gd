extends Control

var _monster_list: Array = []
var _card_nodes: Array = []
var _scroll_offset: int = 0

const VISIBLE_COUNT = 5
const CARD_H = 80
const CARD_W = 680
const CARD_X = 60
const CARD_Y_START = 110
const CARD_GAP = 8
const ICON_W = 50

var _btn_up: Button
var _btn_down: Button
var _scroll_container: Node
var _card_w: int = 680
var _card_x: int = 60

func _ready() -> void:
	_update_size()
	get_viewport().size_changed.connect(_update_size)
	_monster_list = MonsterData.list_monsters()
	_build_back_button()
	_build_scroll_buttons()
	_scroll_container = Node.new()
	add_child(_scroll_container)
	_rebuild_cards()

func _update_size() -> void:
	var win = get_viewport_rect().size
	size = win
	position = Vector2(0, 0)
	_card_w = mini(680, int(win.x) - 80)
	_card_x = maxi(20, (int(win.x) - _card_w) / 2)
	_reposition_buttons(win.x)
	_reposition_scroll_buttons()
	_rebuild_cards()

var _btn_back: Button
var _btn_new: Button

func _build_back_button() -> void:
	_btn_back = Button.new()
	_btn_back.text = "< Back"
	_btn_back.size = Vector2(100, 30)
	_btn_back.position = Vector2(20, 20)
	_btn_back.add_theme_font_size_override("font_size", 16)
	_btn_back.pressed.connect(_on_back)
	add_child(_btn_back)

	_btn_new = Button.new()
	_btn_new.text = "+ New"
	_btn_new.size = Vector2(80, 30)
	_btn_new.position = Vector2(120, 20)
	_btn_new.add_theme_font_size_override("font_size", 15)
	_btn_new.pressed.connect(_on_new_monster)
	add_child(_btn_new)

func _reposition_buttons(win_w: float) -> void:
	if _btn_back != null:
		_btn_back.position = Vector2(20, 20)
	if _btn_new != null:
		_btn_new.position = Vector2(win_w - 100, 20)

func _build_scroll_buttons() -> void:
	_btn_up = Button.new()
	_btn_up.text = "^"
	_btn_up.size = Vector2(40, 20)
	_btn_up.add_theme_font_size_override("font_size", 16)
	_btn_up.pressed.connect(_on_scroll_up)
	_btn_up.visible = false
	add_child(_btn_up)

	_btn_down = Button.new()
	_btn_down.text = "v"
	_btn_down.size = Vector2(40, 20)
	_btn_down.add_theme_font_size_override("font_size", 16)
	_btn_down.pressed.connect(_on_scroll_down)
	_btn_down.visible = false
	add_child(_btn_down)
	_reposition_scroll_buttons()

func _reposition_scroll_buttons() -> void:
	if _btn_up == null:
		return
	var arrow_x = _card_x + _card_w / 2 - 20
	_btn_up.position = Vector2(arrow_x, CARD_Y_START - 22)
	var down_y = CARD_Y_START + VISIBLE_COUNT * (CARD_H + CARD_GAP)
	_btn_down.position = Vector2(arrow_x, down_y)

func _rebuild_cards() -> void:
	_clear_cards()
	var start = _scroll_offset
	var end = mini(start + VISIBLE_COUNT, _monster_list.size())
	for i in range(start, end):
		var monster = _monster_list[i]
		var card = _make_card(monster, i, CARD_Y_START + (i - start) * (CARD_H + CARD_GAP))
		_card_nodes.append(card)
		_scroll_container.add_child(card)

	if _btn_up != null:
		_btn_up.visible = _scroll_offset > 0
	if _btn_down != null:
		_btn_down.visible = _scroll_offset + VISIBLE_COUNT < _monster_list.size()

func _clear_cards() -> void:
	for c in _card_nodes:
		_scroll_container.remove_child(c)
		c.queue_free()
	_card_nodes.clear()

func _make_card(monster: Dictionary, idx: int, y_pos: int) -> Control:
	var card = Control.new()
	card.position = Vector2(_card_x, y_pos)
	card.size = Vector2(_card_w, CARD_H)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(_on_card_click.bind(idx, card))
	card.mouse_entered.connect(func(): _on_card_hover(card, true))
	card.mouse_exited.connect(func(): _on_card_hover(card, false))

	var border = ColorRect.new()
	border.color = Color(0.3, 0.32, 0.38)
	border.position = Vector2(0, 0)
	border.size = Vector2(_card_w, CARD_H)
	border.mouse_filter = Control.MOUSE_FILTER_PASS
	card.set_meta("border", border)
	card.add_child(border)

	var inner = ColorRect.new()
	inner.color = Color(0.17, 0.18, 0.22)
	inner.position = Vector2(1, 1)
	inner.size = Vector2(_card_w - 2, CARD_H - 2)
	inner.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(inner)

	var name_str = str(monster.get("name", "?"))
	var chs = str(monster.get("chs_name", ""))
	var char_frame = str(monster.get("character", ""))

	var icon_rect = ColorRect.new()
	icon_rect.position = Vector2(10, 10)
	icon_rect.size = Vector2(ICON_W, CARD_H - 20)
	icon_rect.color = _get_card_color(idx)
	icon_rect.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(icon_rect)

	var first = Label.new()
	first.text = name_str.left(1).to_upper()
	first.position = Vector2(10, 10)
	first.size = Vector2(ICON_W, CARD_H - 20)
	first.add_theme_font_size_override("font_size", 22)
	first.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	first.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	first.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	first.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(first)

	var label_w = _card_w - ICON_W - 34
	var name_lb = Label.new()
	name_lb.text = name_str + ("  (" + chs + ")" if chs != "" else "")
	name_lb.position = Vector2(ICON_W + 24, 10)
	name_lb.size = Vector2(mini(350, label_w), 24)
	name_lb.add_theme_font_size_override("font_size", 18)
	name_lb.add_theme_color_override("font_color", Color(0.9, 0.92, 0.95))
	name_lb.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(name_lb)

	var blood = str(monster.get("blood", 0))
	var speed = str(monster.get("speed", 0.0))
	var contact = str(monster.get("contact", 0))
	var boss = " [BOSS]" if monster.get("boss_mode", false) else ""

	var stat_lb = Label.new()
	stat_lb.text = "HP: %s  Contact: %s  Speed: %s  Frame: %s%s" % [blood, contact, speed, char_frame, boss]
	stat_lb.position = Vector2(ICON_W + 24, 40)
	stat_lb.size = Vector2(mini(450, label_w), 22)
	stat_lb.add_theme_font_size_override("font_size", 13)
	stat_lb.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	stat_lb.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(stat_lb)

	return card

func _get_card_color(idx: int) -> Color:
	var palette = [
		Color(0.4, 0.2, 0.2), Color(0.3, 0.2, 0.35), Color(0.2, 0.3, 0.35),
		Color(0.35, 0.25, 0.2), Color(0.3, 0.3, 0.25), Color(0.35, 0.2, 0.25),
	]
	return palette[idx % palette.size()]

func _on_card_click(event: InputEvent, idx: int, _card: Control) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_monster_selected(idx)

func _on_card_hover(card: Control, hovered: bool) -> void:
	var border = card.get_meta("border") if card.has_meta("border") else null
	if border != null:
		border.color = Color(0.5, 0.55, 0.65) if hovered else Color(0.3, 0.32, 0.38)

func _on_scroll_up() -> void:
	if _scroll_offset > 0:
		_scroll_offset -= 1
		_rebuild_cards()

func _on_scroll_down() -> void:
	if _scroll_offset + VISIBLE_COUNT < _monster_list.size():
		_scroll_offset += 1
		_rebuild_cards()

func _on_monster_selected(idx: int) -> void:
	var monster = _monster_list[idx]
	var editor = load("res://src/monster_editor/monster_editor.gd").new(monster)
	editor.set_meta("list_ref", self)
	var p = get_parent()
	p.add_child(editor)
	p.remove_child(self)

func _on_new_monster() -> void:
	var template = {
		"name": "NewMonster",
		"chs_name": "",
		"character": "CharacterBlank",
		"blood": 5000, "speed": 0, "contact": 500, "defense": 0, "resent_dist": 8,
		"boss_mode": false, "self_damage_blood": 0,
		"bomb_skin": "bomb1", "skills": [],
		"decorations": {}, "colors": {},
	}
	var editor = load("res://src/monster_editor/monster_editor.gd").new(template)
	editor.set_meta("list_ref", self)
	var p = get_parent()
	p.add_child(editor)
	p.remove_child(self)

func _on_back() -> void:
	var ts = Control.new()
	ts.set_script(preload("res://src/main/title_screen.gd"))
	ts.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(ts)
	queue_free()

func _draw() -> void:
	var win = get_viewport_rect().size
	draw_rect(Rect2(0, 0, win.x, win.y), Color(0.1, 0.1, 0.15))
	var font = ThemeDB.fallback_font
	if font == null:
		return
	var title = "Monster Editor"
	var ts = 28
	var tw = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, ts).x
	draw_string(font, Vector2((win.x - tw) * 0.5, 50), title, HORIZONTAL_ALIGNMENT_LEFT, -1, ts, Color(0.8, 0.9, 1.0))
	var sub = "%d monsters" % _monster_list.size()
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
