extends Control

const MissionCatalog = preload("res://src/adventure/mission_catalog.gd")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()

func _build() -> void:
	var background := ColorRect.new()
	background.color = Color(0.055, 0.075, 0.09, 0.98)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var root := VBoxContainer.new()
	root.position = Vector2(40, 32)
	root.custom_minimum_size = Vector2(720, 520)
	root.add_theme_constant_override("separation", 12)
	add_child(root)
	var title := Label.new()
	title.text = "冒险工会"
	title.add_theme_font_size_override("font_size", 28)
	root.add_child(title)
	for mission in MissionCatalog.list_missions():
		root.add_child(_mission_card(mission))
	var close := Button.new()
	close.text = "返回城市"
	close.custom_minimum_size = Vector2(160, 40)
	close.pressed.connect(queue_free)
	root.add_child(close)

func _mission_card(mission: Dictionary) -> VBoxContainer:
	var card := VBoxContainer.new()
	var name_label := Label.new()
	name_label.text = str(mission.get("name", mission.get("id", "?")))
	name_label.add_theme_font_size_override("font_size", 18)
	card.add_child(name_label)
	var detail := Label.new()
	detail.text = "%s\n目标：击败 %d 个敌人　奖励：%d 金币" % [str(mission.get("description", "")), int(mission.get("objective", {}).get("target", 0)), int(mission.get("rewards", {}).get("gold", 0))]
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(detail)
	var accept := Button.new()
	accept.text = "接取任务"
	accept.custom_minimum_size = Vector2(160, 40)
	accept.pressed.connect(func(): _accept(mission))
	card.add_child(accept)
	return card

func _accept(mission: Dictionary) -> void:
	if Game.start_adventure_mission(mission):
		_close_city_screen()

func _close_city_screen() -> void:
	var screen: Node = self
	while screen.get_parent() != null and screen.get_parent() != get_tree().root:
		screen = screen.get_parent()
	screen.queue_free()
