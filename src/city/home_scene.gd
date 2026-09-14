# res://src/city/home_scene.gd
# The player's home (overlay). Placeholder for now: shows player state and lets
# the hero rest (restore HP). Will grow into the home/hub for the garden system.
extends Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.12, 0.07, 0.05)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = MOUSE_FILTER_STOP
	add_child(bg)

	var title = Label.new()
	title.text = "主角的房子"
	title.position = Vector2(24, 20)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.5))
	add_child(title)

	var desc = Label.new()
	desc.text = "你的家。休息可以恢复状态，未来可接入家园/种植系统。"
	desc.position = Vector2(24, 64)
	desc.add_theme_font_size_override("font_size", 14)
	add_child(desc)

	var rest_btn = Button.new()
	rest_btn.text = "休息（恢复满血）"
	rest_btn.position = Vector2(24, 120)
	rest_btn.custom_minimum_size = Vector2(200, 48)
	rest_btn.pressed.connect(_rest)
	add_child(rest_btn)

	var close_btn = Button.new()
	close_btn.text = "关闭"
	close_btn.position = Vector2(24, 190)
	close_btn.custom_minimum_size = Vector2(200, 40)
	close_btn.pressed.connect(queue_free)
	add_child(close_btn)


func _rest() -> void:
	if Game != null and Game.me != null:
		Game.me.remain_blood = Game.me.blood
		Game.me.state = Game.me.NORMAL
		_toast("已休息，状态恢复满")
	else:
		_toast("当前无角色")


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
