extends Control

func _ready() -> void:
	var btn_select = Button.new()
	btn_select.text = "Start Game"
	btn_select.position = Vector2(280, 220)
	btn_select.size = Vector2(240, 44)
	btn_select.add_theme_font_size_override("font_size", 18)
	btn_select.pressed.connect(_on_select)
	add_child(btn_select)

	var btn_char = Button.new()
	btn_char.text = "Character Editor"
	btn_char.position = Vector2(280, 275)
	btn_char.size = Vector2(240, 44)
	btn_char.add_theme_font_size_override("font_size", 18)
	btn_char.pressed.connect(_on_char_editor)
	add_child(btn_char)

	var btn_map = Button.new()
	btn_map.text = "Map Editor"
	btn_map.position = Vector2(280, 400)
	btn_map.size = Vector2(240, 50)
	btn_map.add_theme_font_size_override("font_size", 20)
	btn_map.pressed.connect(_on_map_editor)
	add_child(btn_map)

func _on_select() -> void:
	var sel = load("res://src/player_editor/character_select.gd").new()
	Game.add_child(sel)
	queue_free()

func _on_char_editor() -> void:
	var list = load("res://src/player_editor/character_list.gd").new()
	Game.add_child(list)
	queue_free()

func _on_map_editor() -> void:
	var editor = load("res://src/editor/map_editor.gd").new()
	get_tree().root.add_child(editor)
	queue_free()
