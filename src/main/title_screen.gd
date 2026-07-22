extends Control

var _btn_select: Button
var _btn_char: Button
var _btn_map: Button
var _btn_level: Button

func _ready() -> void:
	_btn_select = Button.new()
	_btn_select.text = "Start Game"
	_btn_select.size = Vector2(240, 44)
	_btn_select.add_theme_font_size_override("font_size", 18)
	_btn_select.pressed.connect(_on_select)
	add_child(_btn_select)

	_btn_char = Button.new()
	_btn_char.text = "Character Editor"
	_btn_char.size = Vector2(240, 44)
	_btn_char.add_theme_font_size_override("font_size", 18)
	_btn_char.pressed.connect(_on_char_editor)
	add_child(_btn_char)

	_btn_level = Button.new()
	_btn_level.text = "Level Editor"
	_btn_level.size = Vector2(240, 44)
	_btn_level.add_theme_font_size_override("font_size", 18)
	_btn_level.pressed.connect(_on_level_editor)
	add_child(_btn_level)

	_btn_map = Button.new()
	_btn_map.text = "Map Editor"
	_btn_map.size = Vector2(240, 50)
	_btn_map.add_theme_font_size_override("font_size", 20)
	_btn_map.pressed.connect(_on_map_editor)
	add_child(_btn_map)

	_reposition()
	get_viewport().size_changed.connect(_reposition)

func _reposition() -> void:
	var win = get_viewport_rect().size
	var cx = win.x * 0.5
	var cy = win.y * 0.5
	_btn_select.position = Vector2(cx - 120, cy - 60)
	_btn_char.position = Vector2(cx - 120, cy - 10)
	_btn_level.position = Vector2(cx - 120, cy + 40)
	_btn_map.position = Vector2(cx - 120, cy + 100)

func _draw() -> void:
	var win = get_viewport_rect().size
	draw_rect(Rect2(0, 0, win.x, win.y), Color(0.1, 0.1, 0.15))
	var title = "QQTPVE"
	var font = ThemeDB.fallback_font
	if font != null:
		var ts = 36
		var tw = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, ts).x
		draw_string(font, Vector2((win.x - tw) * 0.5, win.y * 0.5 - 100), title, HORIZONTAL_ALIGNMENT_LEFT, -1, ts, Color(0.8, 0.9, 1.0))

func _on_select() -> void:
	var sel = load("res://src/player_editor/character_select.gd").new()
	Game.add_child(sel)
	queue_free()

func _on_char_editor() -> void:
	var list = load("res://src/player_editor/character_list.gd").new()
	Game.add_child(list)
	queue_free()

func _on_level_editor() -> void:
	var list = load("res://src/level_editor/level_list.gd").new()
	Game.add_child(list)
	queue_free()

func _on_map_editor() -> void:
	var editor = load("res://src/editor/map_editor.gd").new()
	get_tree().root.add_child(editor)
	queue_free()
