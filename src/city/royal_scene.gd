# res://src/city/royal_scene.gd
# The royal court (overlay). Placeholder for world-building / story NPCs.
extends Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.12, 0.08, 0.14)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = MOUSE_FILTER_STOP
	add_child(bg)

	var title = Label.new()
	title.text = "王城"
	title.position = Vector2(24, 20)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.9, 0.7, 1.0))
	add_child(title)

	var desc = Label.new()
	desc.text = "王城。衔接世界观的剧情入口（开发中）。"
	desc.position = Vector2(24, 64)
	desc.add_theme_font_size_override("font_size", 14)
	add_child(desc)

	var close = Button.new()
	close.text = "关闭"
	close.position = Vector2(24, 120)
	close.custom_minimum_size = Vector2(120, 40)
	close.pressed.connect(queue_free)
	add_child(close)
