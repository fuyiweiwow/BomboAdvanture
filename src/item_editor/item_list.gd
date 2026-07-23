extends Control

var _items: Array = []
var _card_nodes: Array = []
var _scroll_offset: int = 0

const VISIBLE_COUNT = 6
const CARD_H = 64
const CARD_GAP = 6

var _btn_up: Button
var _btn_down: Button
var _scroll_container: Node
var _card_w: int = 680
var _card_x: int = 60

func _ready() -> void:
	_update_size()
	get_viewport().size_changed.connect(_update_size)
	_items = ItemData.list_items()
	_build_buttons()
	_scroll_container = Node.new()
	add_child(_scroll_container)
	_rebuild_cards()

func _update_size() -> void:
	var win = get_viewport_rect().size
	size = win; position = Vector2.ZERO
	_card_w = mini(680, int(win.x) - 80)
	_card_x = maxi(20, (int(win.x) - _card_w) / 2)
	_rebuild_cards()
	_reposition_scroll_buttons()

var _btn_back: Button
var _btn_new: Button

func _build_buttons() -> void:
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
	_btn_new.position = Vector2(get_viewport_rect().size.x - 100, 20)
	_btn_new.add_theme_font_size_override("font_size", 15)
	_btn_new.pressed.connect(_on_new_item)
	add_child(_btn_new)

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

func _reposition_scroll_buttons() -> void:
	if _btn_up == null: return
	var ax = _card_x + _card_w / 2 - 20
	_btn_up.position = Vector2(ax, 120 - 22)
	_btn_down.position = Vector2(ax, 120 + VISIBLE_COUNT * (CARD_H + CARD_GAP))

func _rebuild_cards() -> void:
	_clear_cards()
	var start = _scroll_offset
	var end = mini(start + VISIBLE_COUNT, _items.size())
	for i in range(start, end):
		var item = _items[i]
		var card = _make_card(item, i, 120 + (i - start) * (CARD_H + CARD_GAP))
		_card_nodes.append(card)
		_scroll_container.add_child(card)
	if _btn_up != null: _btn_up.visible = _scroll_offset > 0
	if _btn_down != null: _btn_down.visible = _scroll_offset + VISIBLE_COUNT < _items.size()

func _clear_cards() -> void:
	for c in _card_nodes:
		_scroll_container.remove_child(c); c.queue_free()
	_card_nodes.clear()

func _make_card(item: Dictionary, idx: int, y_pos: int) -> Control:
	var card = Control.new()
	card.position = Vector2(_card_x, y_pos)
	card.size = Vector2(_card_w, CARD_H)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_item_selected(idx))
	card.mouse_entered.connect(func():
		var border = card.get_meta("border") if card.has_meta("border") else null
		if border: border.color = Color(0.5, 0.55, 0.65))
	card.mouse_exited.connect(func():
		var border = card.get_meta("border") if card.has_meta("border") else null
		if border: border.color = Color(0.3, 0.32, 0.38))

	var border = ColorRect.new()
	border.color = Color(0.3, 0.32, 0.38)
	border.position = Vector2.ZERO; border.size = Vector2(_card_w, CARD_H)
	border.mouse_filter = Control.MOUSE_FILTER_PASS
	card.set_meta("border", border); card.add_child(border)

	var inner = ColorRect.new()
	inner.color = Color(0.17, 0.18, 0.22)
	inner.position = Vector2(1, 1); inner.size = Vector2(_card_w - 2, CARD_H - 2)
	inner.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(inner)

	var item_id = str(item.get("id", "?"))
	var item_name = str(item.get("name", ""))
	var item_chs = str(item.get("chs_name", ""))
	var item_type = str(item.get("type", "?"))
	var item_rarity = str(item.get("rarity", "common"))

	var icon = ColorRect.new()
	icon.position = Vector2(8, 8); icon.size = Vector2(44, CARD_H - 16)
	icon.color = ItemData.rarity_color(item_rarity)
	icon.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(icon)

	var fl = Label.new()
	fl.text = item_id.left(1).to_upper()
	fl.position = Vector2(8, 8); fl.size = Vector2(44, CARD_H - 16)
	fl.add_theme_font_size_override("font_size", 20)
	fl.add_theme_color_override("font_color", Color(1, 1, 1, 0.3))
	fl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fl.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(fl)

	var lw = _card_w - 70
	var nl = Label.new()
	nl.text = "%s  (%s)" % [item_name, item_chs] if item_chs else item_name
	nl.position = Vector2(60, 8); nl.size = Vector2(mini(300, lw), 22)
	nl.add_theme_font_size_override("font_size", 16)
	nl.add_theme_color_override("font_color", Color(0.9, 0.92, 0.95))
	nl.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(nl)

	var tl = Label.new()
	var tlabel = ItemData.type_label(item_type)
	var rlabel = ItemData.rarity_label(item_rarity)
	var rcol = ItemData.rarity_color(item_rarity)
	tl.text = "%s  |  %s" % [tlabel, rlabel]
	tl.position = Vector2(60, 34); tl.size = Vector2(mini(350, lw), 20)
	tl.add_theme_font_size_override("font_size", 13)
	tl.add_theme_color_override("font_color", rcol)
	tl.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(tl)

	return card

func _on_item_selected(idx: int) -> void:
	var item = _items[idx]
	var editor = load("res://src/item_editor/item_editor.gd").new(item)
	editor.set_meta("list_ref", self)
	var p = get_parent()
	p.add_child(editor); p.remove_child(self)

func _on_new_item() -> void:
	var editor = load("res://src/item_editor/item_editor.gd").new(ItemData.new_template())
	editor.set_meta("list_ref", self)
	var p = get_parent()
	p.add_child(editor); p.remove_child(self)

func _on_scroll_up() -> void:
	if _scroll_offset > 0: _scroll_offset -= 1; _rebuild_cards()

func _on_scroll_down() -> void:
	if _scroll_offset + VISIBLE_COUNT < _items.size(): _scroll_offset += 1; _rebuild_cards()

func _on_back() -> void:
	var ts = Control.new()
	ts.set_script(preload("res://src/main/title_screen.gd"))
	ts.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(ts); queue_free()

func _draw() -> void:
	var win = get_viewport_rect().size
	draw_rect(Rect2(0, 0, win.x, win.y), Color(0.1, 0.1, 0.15))
	var font = ThemeDB.fallback_font
	if font == null: return
	var title = "Item Editor"
	var ts = 28
	var tw = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, ts).x
	draw_string(font, Vector2((win.x - tw) * 0.5, 50), title, HORIZONTAL_ALIGNMENT_LEFT, -1, ts, Color(0.8, 0.9, 1.0))
	var sub = "%d items" % _items.size()
	var ss = 15
	draw_string(font, Vector2((win.x - font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ss).x) * 0.5, 75), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ss, Color(0.6, 0.6, 0.6))

func _unhandled_input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: _on_scroll_up(); get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: _on_scroll_down(); get_viewport().set_input_as_handled()
