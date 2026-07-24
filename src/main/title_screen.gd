extends Control

var _btn_select: Button
var _btn_char: Button
var _btn_map: Button
var _btn_level: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	_build()

func _build() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.035, 0.055, 0.075)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bg)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel = VBoxContainer.new()
	panel.custom_minimum_size = Vector2(320, 0)
	panel.add_theme_constant_override("separation", 6)
	center.add_child(panel)

	var title = Label.new()
	title.text = "BOMBO ADVENTURE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.80, 0.26))
	panel.add_child(title)

	panel.add_child(_spacer(4))
	panel.add_child(_make_menu_button("Start Game", _on_select))
	panel.add_child(_make_menu_button("Character Editor", _on_char_editor))
	panel.add_child(_make_menu_button("Monster Editor", _on_monster_editor))
	panel.add_child(_make_menu_button("Item Editor", _on_item_editor))
	panel.add_child(_spacer(4))
	panel.add_child(_make_menu_button("Alchemy Lab", _on_alchemy))
	panel.add_child(_make_menu_button("Recipe Editor", _on_recipe_editor))
	panel.add_child(_make_menu_button("Alchemy Test", _on_alchemy_test))
	panel.add_child(_make_menu_button("Combat Sandbox", _on_combat_sandbox))
	panel.add_child(_make_menu_button("Tournament", _on_tournament))
	panel.add_child(_spacer(4))
	panel.add_child(_make_menu_button("Level Editor", _on_level_editor))
	panel.add_child(_make_menu_button("Map Editor", _on_map_editor))

func _make_menu_button(text: String, fn: Callable) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(280, 34)
	button.size_flags_horizontal = SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(fn)
	return button

func _spacer(height: float) -> Control:
	var spacer = Control.new()
	spacer.custom_minimum_size.y = height
	return spacer

func _on_select() -> void:
	var world_map = load("res://src/main/world_map.gd").new()
	_add_screen(world_map)
	queue_free()

func _on_char_editor() -> void:
	var list = load("res://src/player_editor/character_list.gd").new()
	_add_screen(list)
	queue_free()

func _on_level_editor() -> void:
	var list = load("res://src/level_editor/level_list.gd").new()
	_add_screen(list)
	queue_free()

func _on_monster_editor() -> void:
	var list = load("res://src/monster_editor/monster_list.gd").new()
	_add_screen(list)
	queue_free()

func _on_item_editor() -> void:
	var list = load("res://src/item_editor/item_list.gd").new()
	_add_screen(list)
	queue_free()

func _on_map_editor() -> void:
	var editor = load("res://src/editor/map_editor.gd").new()
	_add_screen(editor)
	queue_free()

func _on_alchemy() -> void:
	var lab = load("res://src/alchemy/alchemy_lab.gd").new()
	_add_screen(lab)
	queue_free()

func _on_recipe_editor() -> void:
	var editor = load("res://src/alchemy/recipe_editor/recipe_editor.gd").new()
	_add_screen(editor)
	queue_free()

func _on_alchemy_test() -> void:
	var test = load("res://src/alchemy/alchemy_test.gd").new()
	_add_screen(test)
	queue_free()

func _on_combat_sandbox() -> void:
	var sb = load("res://src/alchemy/combat_sandbox.gd").new()
	_add_screen(sb)
	queue_free()

func _on_tournament() -> void:
	var t = load("res://src/tournament/tournament.gd").new()
	_add_screen(t)
	queue_free()

func _add_screen(node: Node) -> void:
	if node is Control:
		(node as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(node)
