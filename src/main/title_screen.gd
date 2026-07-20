extends Control

var _btn_normal: Button
var _btn_dev: Button
var _btn_editor: Button

func _ready() -> void:
	_btn_normal = Button.new()
	_btn_normal.text = "Normal Mode"
	_btn_normal.position = Vector2(280, 240)
	_btn_normal.size = Vector2(240, 44)
	_btn_normal.add_theme_font_size_override("font_size", 18)
	_btn_normal.pressed.connect(_on_normal)
	add_child(_btn_normal)

	_btn_dev = Button.new()
	_btn_dev.text = "Developer Mode"
	_btn_dev.position = Vector2(280, 295)
	_btn_dev.size = Vector2(240, 44)
	_btn_dev.add_theme_font_size_override("font_size", 18)
	_btn_dev.pressed.connect(_on_dev)
	add_child(_btn_dev)

	_btn_editor = Button.new()
	_btn_editor.text = "Character Editor"
	_btn_editor.position = Vector2(280, 350)
	_btn_editor.size = Vector2(240, 44)
	_btn_editor.add_theme_font_size_override("font_size", 18)
	_btn_editor.pressed.connect(_on_editor)
	add_child(_btn_editor)

func _draw() -> void:
	var win = get_viewport_rect().size
	draw_rect(Rect2(0, 0, win.x, win.y), Color(0.1, 0.1, 0.15))
	var title = "QQTPVE"
	var font = ThemeDB.fallback_font
	if font != null:
		var ts = 36
		var tw = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, ts).x
		draw_string(font, Vector2((win.x - tw) * 0.5, 180), title, HORIZONTAL_ALIGNMENT_LEFT, -1, ts, Color(0.8, 0.9, 1.0))

func _on_normal() -> void:
	Game.start_game(false)
	queue_free()

func _on_dev() -> void:
	Game.start_game(true)
	queue_free()

func _on_editor() -> void:
	var list = load("res://src/player_editor/character_list.gd").new()
	Game.add_child(list)
	queue_free()
