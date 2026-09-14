# res://src/city/shop_scene.gd
# Shop overlay: buy items (buy_price > 0) with gold. Selling from inventory
# is a future extension. Uses Game.me; if no hero exists the city entry ensures
# one is created.
extends Control

const ItemData = preload("res://src/item_editor/item_data.gd")

var _gold_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	for c in get_children():
		c.free()

	var bg = ColorRect.new()
	bg.color = Color(0.11, 0.09, 0.05)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = MOUSE_FILTER_STOP
	add_child(bg)

	var title = Label.new()
	title.text = "商店"
	title.position = Vector2(24, 20)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	add_child(title)

	_gold_label = Label.new()
	_gold_label.position = Vector2(24, 62)
	_gold_label.add_theme_font_size_override("font_size", 16)
	add_child(_gold_label)
	_update_gold()

	var items = _buyable_items()
	var y := 104
	for item in items:
		var name_label = Label.new()
		name_label.text = "%s　%dG" % [str(item.get("chs_name", item.get("name", "?"))), int(item.get("buy_price", 0))]
		name_label.position = Vector2(24, y)
		name_label.custom_minimum_size = Vector2(300, 28)
		name_label.add_theme_font_size_override("font_size", 14)
		add_child(name_label)
		var buy_btn = Button.new()
		buy_btn.text = "买"
		buy_btn.position = Vector2(340, y)
		buy_btn.custom_minimum_size = Vector2(56, 28)
		var item_id := str(item.get("id", ""))
		buy_btn.pressed.connect(func(): _buy(item_id))
		add_child(buy_btn)
		y += 34

	var close = Button.new()
	close.text = "关闭"
	close.position = Vector2(660, 556)
	close.custom_minimum_size = Vector2(100, 32)
	close.pressed.connect(queue_free)
	add_child(close)


func _buyable_items() -> Array:
	var result: Array = []
	for item in ItemData.list_items():
		if int(item.get("buy_price", 0)) > 0:
			result.append(item)
	return result


func _buy(item_id: String) -> void:
	var hero = Game.me
	if hero == null:
		_toast("当前无角色")
		return
	var item = ItemData.load_item(item_id)
	if item.is_empty():
		return
	var price := int(item.get("buy_price", 0))
	if int(hero.gold) < price:
		_toast("金币不足")
		return
	hero.gold = int(hero.gold) - price
	hero._apply_item_effect(item)
	_update_gold()
	_toast("购买 " + str(item.get("chs_name", item_id)))


func _update_gold() -> void:
	if _gold_label == null:
		return
	var hero = Game.me
	var g := 0
	if hero != null:
		g = int(hero.gold)
	_gold_label.text = "金币: %d" % g


func _toast(msg: String) -> void:
	var existing = get_node_or_null("_toast")
	if existing:
		existing.free()
	var lbl = Label.new()
	lbl.name = "_toast"
	lbl.text = msg
	lbl.position = Vector2(280, 20)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	add_child(lbl)
	var tween = create_tween()
	tween.tween_method(func(v): lbl.modulate.a = v, 1.0, 0.0, 2.0).set_delay(1.0)
	tween.tween_callback(lbl.queue_free)
