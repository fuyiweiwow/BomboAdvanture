extends Control

var _btn_normal: Button
var _btn_dev: Button
var _btn_editor: Button

func _ready() -> void:
	_btn_normal = Button.new()
	_btn_normal.text = "Normal Mode"
	_btn_normal.position = Vector2(280, 260)
	_btn_normal.size = Vector2(240, 50)
	_btn_normal.add_theme_font_size_override("font_size", 20)
	_btn_normal.pressed.connect(_on_normal)
	add_child(_btn_normal)

	_btn_dev = Button.new()
	_btn_dev.text = "Developer Mode"
	_btn_dev.position = Vector2(280, 330)
	_btn_dev.size = Vector2(240, 50)
	_btn_dev.add_theme_font_size_override("font_size", 20)
	_btn_dev.pressed.connect(_on_dev)
	add_child(_btn_dev)

	_btn_editor = Button.new()
	_btn_editor.text = "Map Editor"
	_btn_editor.position = Vector2(280, 400)
	_btn_editor.size = Vector2(240, 50)
	_btn_editor.add_theme_font_size_override("font_size", 20)
	_btn_editor.pressed.connect(_on_editor)
	add_child(_btn_editor)

func _on_normal() -> void:
	Game.start_game(false)
	queue_free()

func _on_dev() -> void:
	Game.start_game(true)
	queue_free()

func _on_editor() -> void:
	var editor = load("res://src/editor/map_editor.gd").new()
	get_tree().root.add_child(editor)
	queue_free()
