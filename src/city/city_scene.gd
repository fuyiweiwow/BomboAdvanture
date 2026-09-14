# res://src/city/city_scene.gd
# A district (城区) screen. Data-driven: reads the district JSON and renders
# building buttons + exit buttons. Switching districts just rebuilds this scene
# from another JSON, so the city is fully incremental.
extends Control

const CityData = preload("res://src/city/city_data.gd")

var _district_id: String = "living_district"
var _district: Dictionary = {}


func _init(district_id: String = "living_district"):
	_district_id = district_id


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	for c in get_children():
		c.free()
	_district = CityData.load_district(_district_id)

	var bg = ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.11)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bg)

	var title = Label.new()
	title.text = str(_district.get("name", _district_id))
	title.position = Vector2(24, 20)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	add_child(title)

	if _district.has("desc"):
		var desc = Label.new()
		desc.text = str(_district["desc"])
		desc.position = Vector2(24, 62)
		desc.add_theme_font_size_override("font_size", 14)
		desc.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
		add_child(desc)

	# buildings
	var buildings: Array = _district.get("buildings", [])
	var bx := 24
	var by := 120
	for b in buildings:
		var btn = Button.new()
		btn.text = str(b.get("name", "?"))
		btn.position = Vector2(bx, by)
		btn.custom_minimum_size = Vector2(170, 64)
		btn.add_theme_font_size_override("font_size", 15)
		var action := str(b.get("action", ""))
		btn.pressed.connect(func(): _on_building(action))
		add_child(btn)
		bx += 190

	# exits (district switching)
	var exits: Array = _district.get("exits", [])
	var ey := by + 100
	for e in exits:
		var btn = Button.new()
		btn.text = str(e.get("label", "?"))
		btn.position = Vector2(24, ey)
		btn.custom_minimum_size = Vector2(170, 52)
		var to := str(e.get("to", ""))
		btn.pressed.connect(func(): _goto_district(to))
		add_child(btn)
		ey += 64

	# NPC list (non-interactive for now)
	var npcs: Array = _district.get("npcs", [])
	if not npcs.is_empty():
		var ny := ey + 20
		for n in npcs:
			var lbl = Label.new()
			lbl.text = "· " + str(n.get("name", "?"))
			lbl.position = Vector2(24, ny)
			lbl.add_theme_font_size_override("font_size", 13)
			add_child(lbl)
			ny += 24

	var back = Button.new()
	back.text = "← 返回标题"
	back.position = Vector2(660, 556)
	back.custom_minimum_size = Vector2(120, 32)
	back.pressed.connect(_on_back)
	add_child(back)


func _on_building(action: String) -> void:
	match action:
		"home":
			_open_home()
		"shop":
			_open_shop()
		"royal":
			_open_royal()
		_:
			_toast("建筑未实现: " + action)


func _open_home() -> void:
	var home = load("res://src/city/home_scene.gd").new()
	home.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(home)


func _open_shop() -> void:
	var shop = load("res://src/city/shop_scene.gd").new()
	shop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shop)


func _open_royal() -> void:
	var royal = load("res://src/city/royal_scene.gd").new()
	royal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(royal)


func _goto_district(to: String) -> void:
	if not CityData.district_exists(to):
		_toast("城区不存在: " + to)
		return
	_district_id = to
	_build()


func _on_back() -> void:
	var ts = Control.new()
	ts.set_script(preload("res://src/main/title_screen.gd"))
	ts.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(ts)
	queue_free()


func _toast(msg: String) -> void:
	var existing = get_node_or_null("_toast")
	if existing:
		existing.free()
	var lbl = Label.new()
	lbl.name = "_toast"
	lbl.text = msg
	lbl.position = Vector2(280, 20)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	add_child(lbl)
	var tween = create_tween()
	tween.tween_method(func(v): lbl.modulate.a = v, 1.0, 0.0, 2.0).set_delay(1.0)
	tween.tween_callback(lbl.queue_free)
