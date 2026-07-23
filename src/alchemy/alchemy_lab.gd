extends Control

const DATA = preload("res://src/alchemy/alchemy_data.gd")
const GENERATOR = preload("res://src/alchemy/recipe_generator.gd")
const ITEM_LOADER = preload("res://src/item_editor/item_data.gd")
const RARITY_ORDER = ["common", "uncommon", "rare", "epic", "legendary"]
const RARITY_NAMES = { "common": "普通", "uncommon": "优秀", "rare": "稀有", "epic": "史诗", "legendary": "传说" }
const RARITY_COLORS = { "common": Color(0.8,0.8,0.8), "uncommon": Color(0.3,0.8,0.3), "rare": Color(0.3,0.5,1.0), "epic": Color(0.8,0.3,1.0), "legendary": Color(1.0,0.6,0.0) }

var _materials_inventory: Array = []
var _recipes: Array = []
var _brew_level: int = 1

var _mortar_ingredient: Dictionary = {}
var _grind_count: int = 0
var _max_grind: int = 0

var _cauldron_ingredients: Array = []
var _cauldron_solvent: String = "water"

var _pestle_angle: float = 0.0
var _pestle_dragging: bool = false
var _pestle_last_angle: float = 0.0
var _pestle_full_rotations: float = 0.0

var _font: Font = null
var _item_frames: Dictionary = {}
var _tex_mortar: Texture2D = null
var _tex_pestle: Texture2D = null
var _tex_cauldron: Texture2D = null

var _brewing: bool = false
var _last_result: Dictionary = {}

const MORTAR_CENTER = Vector2(290, 260)
const MORTAR_RADIUS = 70.0
const PESTLE_RADIUS = 40.0
const CAULDRON_CENTER = Vector2(530, 260)
const CAULDRON_RADIUS = 60.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	_font = ThemeDB.fallback_font
	_init_textures()
	_init_inventory()
	_build_ui()

func _init_textures() -> void:
	_tex_mortar = RM.get_texture("res://assets/img/ui/alchemy/mortar.png")
	_tex_pestle = RM.get_texture("res://assets/img/ui/alchemy/pestle.png")
	_tex_cauldron = RM.get_texture("res://assets/img/ui/alchemy/cauldron.png")

func _init_inventory() -> void:
	var material_ids = ["red_herb", "blue_herb", "slime_goo", "bat_wing", "fire_flower", "ice_crystal"]
	for id in material_ids:
		var item = ITEM_LOADER.load_item(id)
		if not item.is_empty():
			_materials_inventory.append({ "data": item, "count": 10 })

func _build_ui() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.06)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bg)

	_build_header()
	_build_left_panel()
	_build_right_panel()
	_build_bottom_bar()

func _build_header() -> void:
	var header = ColorRect.new()
	header.color = Color(0.08, 0.08, 0.12)
	header.size = Vector2(800, 48)
	add_child(header)

	var title = Label.new()
	title.text = "炼 金 实 验 室"
	title.position = Vector2(300, 8)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	add_child(title)

	var back_btn = Button.new()
	back_btn.text = "  ← 返回 "
	back_btn.position = Vector2(710, 10)
	back_btn.custom_minimum_size = Vector2(80, 30)
	back_btn.pressed.connect(_on_back)
	add_child(back_btn)

	var lvl_label = Label.new()
	lvl_label.text = "炼药等级: " + str(_brew_level)
	lvl_label.position = Vector2(580, 10)
	lvl_label.add_theme_font_size_override("font_size", 16)
	lvl_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
	add_child(lvl_label)

func _build_left_panel() -> void:
	var panel = ColorRect.new()
	panel.color = Color(0.07, 0.07, 0.1)
	panel.position = Vector2(8, 54)
	panel.size = Vector2(140, 440)
	add_child(panel)

	var title = Label.new()
	title.text = "材料"
	title.position = Vector2(8, 56)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	add_child(title)

	var y = 80
	for entry in _materials_inventory:
		var d = entry.get("data", {})
		var count = entry.get("count", 0)
		var cn = d.get("chs_name", d.get("name", "?"))
		var rl = DATA.get_material_rarity(d)

		var c = Color(1,1,1)
		match rl:
			1: c = Color(0.8,0.8,0.8)
			2: c = Color(0.3,0.8,0.3)
			3: c = Color(0.3,0.5,1.0)
			4: c = Color(0.8,0.3,1.0)
			5: c = Color(1.0,0.6,0.0)

		var lbl = Label.new()
		lbl.text = cn + " x" + str(count)
		lbl.position = Vector2(12, y)
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", c)
		lbl.mouse_filter = MOUSE_FILTER_STOP
		lbl.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var data_copy = entry.duplicate(true)
		lbl.gui_input.connect(func(ev): _on_material_click(ev, data_copy, lbl))
		add_child(lbl)
		y += 22

func _build_right_panel() -> void:
	var panel = ColorRect.new()
	panel.color = Color(0.07, 0.07, 0.10)
	panel.position = Vector2(640, 54)
	panel.size = Vector2(152, 440)
	add_child(panel)

	var title = Label.new()
	title.text = "溶剂"
	title.position = Vector2(644, 56)
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.5, 0.7, 0.9))
	add_child(title)

	var solvents = DATA.list_solvents()
	var y = 80
	for sid in solvents:
		var sd = DATA.get_solvent(sid)
		var sn = sd.get("chs_name", sid)
		var btn = Button.new()
		btn.text = sn
		btn.position = Vector2(648, y)
		btn.custom_minimum_size = Vector2(136, 30)
		btn.toggle_mode = true
		btn.button_pressed = (sid == _cauldron_solvent)
		var sid_copy = sid
		btn.pressed.connect(func(): _on_solvent_select(sid_copy, btn))
		add_child(btn)
		y += 36

	var cauldron_label = Label.new()
	cauldron_label.text = "坩埚配料"
	cauldron_label.position = Vector2(644, y + 10)
	cauldron_label.add_theme_font_size_override("font_size", 13)
	cauldron_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.5))
	add_child(cauldron_label)

func _build_bottom_bar() -> void:
	var bar = ColorRect.new()
	bar.color = Color(0.08, 0.08, 0.12)
	bar.position = Vector2(0, 500)
	bar.size = Vector2(800, 100)
	add_child(bar)

	var brew_btn = Button.new()
	brew_btn.text = "⚗ 开始炼药"
	brew_btn.position = Vector2(340, 510)
	brew_btn.custom_minimum_size = Vector2(120, 40)
	brew_btn.add_theme_font_size_override("font_size", 18)
	brew_btn.pressed.connect(_on_brew)
	add_child(brew_btn)

	var recipe_btn = Button.new()
	recipe_btn.text = "📖 配方书"
	recipe_btn.position = Vector2(30, 510)
	recipe_btn.custom_minimum_size = Vector2(100, 32)
	recipe_btn.pressed.connect(_show_recipe_book)
	add_child(recipe_btn)

	var clear_btn = Button.new()
	clear_btn.text = "清空坩埚"
	clear_btn.position = Vector2(200, 510)
	clear_btn.custom_minimum_size = Vector2(100, 32)
	clear_btn.pressed.connect(_clear_cauldron)
	add_child(clear_btn)

	var test_btn = Button.new()
	test_btn.text = "生成示例配方"
	test_btn.position = Vector2(600, 510)
	test_btn.custom_minimum_size = Vector2(130, 28)
	test_btn.add_theme_font_size_override("font_size", 11)
	test_btn.pressed.connect(_generate_sample_recipe)
	add_child(test_btn)

	var status_text = "状态: 就绪 | 颗粒度: 0 | 浓度: 0"
	if _last_result.has("params"):
		var p = _last_result["params"]
		status_text = "状态: " + ("成功" if _last_result.get("success", false) else "失败") + " | 颗粒度: " + str(snapped(p.get("granularity", 0), 0.1)) + " | 浓度: " + str(snapped(p.get("concentration", 0), 0.1))

	var status_label = Label.new()
	status_label.text = status_text
	status_label.position = Vector2(30, 560)
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	status_label.name = "_status_label"
	add_child(status_label)

func _draw() -> void:
	_draw_mortar()
	_draw_pestle()
	_draw_cauldron()
	_draw_grind_info()

func _draw_mortar() -> void:
	var pos = MORTAR_CENTER - Vector2(MORTAR_RADIUS, MORTAR_RADIUS)
	var size = Vector2(MORTAR_RADIUS * 2, MORTAR_RADIUS * 2)

	draw_circle(MORTAR_CENTER, MORTAR_RADIUS + 4, Color(0.3, 0.3, 0.3, 0.5))
	draw_circle(MORTAR_CENTER, MORTAR_RADIUS, Color(0.15, 0.12, 0.1))

	if not _mortar_ingredient.is_empty():
		var col = _mortar_ingredient.get("color", [0.5, 0.5, 0.5])
		var fill = Color(col[0], col[1], col[2], 0.3)
		draw_circle(MORTAR_CENTER, MORTAR_RADIUS * 0.7, fill)
		var cn = _mortar_ingredient.get("chs_name", "")
		if _font != null:
			draw_string(_font, MORTAR_CENTER + Vector2(-30, 4), cn, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1,1,1,0.7))

func _draw_pestle() -> void:
	if _mortar_ingredient.is_empty():
		return
	var angle_rad = deg_to_rad(_pestle_angle)
	var pestle_x = MORTAR_CENTER.x + PESTLE_RADIUS * cos(angle_rad)
	var pestle_y = MORTAR_CENTER.y + PESTLE_RADIUS * sin(angle_rad)

	var handle_start = MORTAR_CENTER + Vector2(20, -80)
	var handle_end = Vector2(pestle_x, pestle_y)
	draw_line(handle_start, handle_end, Color(0.5, 0.35, 0.2), 4.0)

	var tip = Vector2(pestle_x, pestle_y)
	draw_circle(tip, 8, Color(0.4, 0.3, 0.2))
	draw_circle(tip, 4, Color(0.5, 0.4, 0.3))

	var hint = "拖拽绕圈研磨"
	if _grind_count > 0:
		hint = "已研磨: " + str(_grind_count) + " 次"
	if _font != null:
		draw_string(_font, handle_start + Vector2(-50, -10), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.7, 0.7, 0.5))

func _draw_grind_info() -> void:
	if _mortar_ingredient.is_empty():
		return
	if _max_grind <= 0:
		return
	var bar_x = MORTAR_CENTER.x - 40
	var bar_y = MORTAR_CENTER.y + MORTAR_RADIUS + 16
	var bar_w = 80
	var bar_h = 8

	draw_rect(Rect2(bar_x - 1, bar_y - 1, bar_w + 2, bar_h + 2), Color(0.2, 0.2, 0.2, 0.8))
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.1, 0.1, 0.1))

	var ratio = float(_grind_count) / float(_max_grind) if _max_grind > 0 else 0.0
	ratio = clampf(ratio, 0.0, 1.0)
	var bar_color = Color(0.3, 0.8, 0.3).lerp(Color(1.0, 0.6, 0.0), ratio)
	if ratio > 0:
		draw_rect(Rect2(bar_x, bar_y, bar_w * ratio, bar_h), bar_color)

	var lvl_labels = ["", "粗粉", "中粉", "细粉", "微粉", "超微", "纳米"]
	var lvl = mini(_grind_count, lvl_labels.size() - 1)
	var lvl_str = lvl_labels[lvl] if lvl >= 0 else ""
	if _font != null:
		draw_string(_font, Vector2(bar_x, bar_y + bar_h + 12), lvl_str + " (" + str(_grind_count) + "/" + str(_max_grind) + ")", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.7, 0.7, 0.7))

func _draw_cauldron() -> void:
	var pos = CAULDRON_CENTER - Vector2(CAULDRON_RADIUS, CAULDRON_RADIUS * 0.8)

	draw_circle(CAULDRON_CENTER, CAULDRON_RADIUS + 4, Color(0.25, 0.25, 0.25, 0.5))
	draw_circle(CAULDRON_CENTER, CAULDRON_RADIUS, Color(0.1, 0.08, 0.12))

	if _cauldron_ingredients.size() > 0:
		var col = Color(0.3, 0.6, 0.4, 0.3)
		draw_circle(CAULDRON_CENTER, CAULDRON_RADIUS * 0.7, col)
		var names = ""
		var max_show = 3
		for i in range(mini(_cauldron_ingredients.size(), max_show)):
			var d = _cauldron_ingredients[i].get("data", {})
			if i > 0: names += ", "
			names += d.get("chs_name", "?")
		if _cauldron_ingredients.size() > max_show:
			names += "..."
		if _font != null:
			draw_string(_font, CAULDRON_CENTER + Vector2(-40, 4), names, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1,1,1,0.7))

var _drag_material_data: Dictionary = {}
var _drag_start_pos: Vector2

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mpos = event.position
		if _in_mortar(mpos) and not _mortar_ingredient.is_empty():
			_pestle_dragging = true
			_pestle_last_angle = _angle_from_center(mpos)
			_pestle_full_rotations = _grind_count
			get_viewport().set_input_as_handled()

	if event is InputEventMouseMotion and _pestle_dragging:
		var mpos = event.position
		var current_angle = _angle_from_center(mpos)
		var delta = _normalize_angle(current_angle - _pestle_last_angle)

		_pestle_angle += rad_to_deg(delta)

		var new_rotations = _pestle_angle / 360.0
		var completed = int(new_rotations)
		if completed > _grind_count:
			_do_grind(completed - _grind_count)

		_pestle_last_angle = current_angle
		queue_redraw()
		get_viewport().set_input_as_handled()

	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_pestle_dragging = false
		get_viewport().set_input_as_handled()

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var mpos = event.position
		if _in_mortar(mpos) and not _mortar_ingredient.is_empty():
			var d = _mortar_ingredient.duplicate(true)
			d["grind"] = _grind_count
			_cauldron_ingredients.append({ "data": d, "grind": _grind_count })
			_mortar_ingredient = {}
			_grind_count = 0
			_max_grind = 0
			_pestle_angle = 0.0
			queue_redraw()
			_update_status()
			get_viewport().set_input_as_handled()

func _in_mortar(pos: Vector2) -> bool:
	return pos.distance_to(MORTAR_CENTER) < MORTAR_RADIUS

func _in_cauldron(pos: Vector2) -> bool:
	return pos.distance_to(CAULDRON_CENTER) < CAULDRON_RADIUS

func _angle_from_center(pos: Vector2) -> float:
	return atan2(pos.y - MORTAR_CENTER.y, pos.x - MORTAR_CENTER.x)

func _normalize_angle(a: float) -> float:
	while a > PI: a -= 2.0 * PI
	while a < -PI: a += 2.0 * PI
	return a

func _do_grind(count: int) -> void:
	if _mortar_ingredient.is_empty():
		return
	var alch = _mortar_ingredient.get("alchemy", {})
	var max_g = alch.get("max_grind", 0)
	if max_g <= 0:
		return
	var before = _grind_count
	_grind_count = mini(_grind_count + count, max_g)

	queue_redraw()
	_update_status()

func _on_material_click(ev: InputEvent, entry: Dictionary, label: Control) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var data = entry.get("data", {})
		var alch = data.get("alchemy", {})
		if not alch.get("grindable", false):
			_cauldron_ingredients.append({ "data": data.duplicate(true), "grind": 0 })
			_update_status()
			return

		_mortar_ingredient = data.duplicate(true)
		_grind_count = 0
		_max_grind = alch.get("max_grind", 0)
		_pestle_angle = 0.0
		queue_redraw()

func _on_solvent_select(sid: String, btn: Button) -> void:
	for c in get_children():
		if c is Button and c.toggle_mode:
			if c != btn:
				c.button_pressed = false
	_cauldron_solvent = sid
	_update_status()

func _on_brew() -> void:
	if _cauldron_ingredients.is_empty():
		return

	var grinds = {}
	for entry in _cauldron_ingredients:
		var d = entry.get("data", {})
		var g = entry.get("grind", 0)
		grinds[d.get("id", "")] = g

	var result = DATA.brew(_cauldron_ingredients, _cauldron_solvent, grinds, _recipes, _brew_level)
	_last_result = result

	if result.get("success", false):
		var recipe = result.get("recipe", {})
		var output_item = recipe.get("output_item", {})
		if result.get("discovered", false) and not recipe.is_empty():
			var dup = false
			for r in _recipes:
				if r.get("id", "") == recipe.get("id", ""):
					dup = true; break
			if not dup:
				_recipes.append(recipe)
		if not output_item.is_empty():
			var disc = " (新配方!)" if result.get("discovered", false) else ""
			_show_brew_result(true, output_item.get("chs_name", "药剂") + disc)
			var score = GENERATOR.estimate_rarity_score(recipe)
			_brew_level += maxi(1, score / 10)
	else:
		var severity = result.get("fail_severity", 1)
		_show_brew_result(false, "失败 (严重度: " + str(severity) + ")")
		if severity >= 3:
			_brew_level = maxi(1, _brew_level - 1)

	_clear_cauldron()
	_update_status()

func _show_brew_result(success: bool, msg: String) -> void:
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = MOUSE_FILTER_STOP
	overlay.name = "_brew_overlay"
	add_child(overlay)

	var panel = ColorRect.new()
	panel.color = Color(0.1, 0.1, 0.15)
	panel.size = Vector2(300, 180)
	panel.position = Vector2(250, 180)
	overlay.add_child(panel)

	var title = Label.new()
	title.text = "炼药结果"
	title.position = Vector2(30, 20)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.3) if success else Color(1, 0.4, 0.4))
	panel.add_child(title)

	var result_label = Label.new()
	result_label.text = msg
	result_label.position = Vector2(30, 60)
	result_label.add_theme_font_size_override("font_size", 16)
	panel.add_child(result_label)

	if success:
		var is_new = msg.contains("新配方")
		var stats = Label.new()
		stats.text = "新配方已记录到配方书中!" if is_new else "配方已记录到配方书中!"
		stats.position = Vector2(30, 100)
		stats.add_theme_font_size_override("font_size", 12)
		stats.add_theme_color_override("font_color", Color(0.5, 1, 0.5))
		panel.add_child(stats)
	else:
		var near = _last_result.get("near_match", "")
		if near != "":
			var near_lbl = Label.new()
			near_lbl.text = "与配方接近但未完全匹配..."
			near_lbl.position = Vector2(30, 100)
			near_lbl.add_theme_font_size_override("font_size", 12)
			near_lbl.add_theme_color_override("font_color", Color(0.8, 0.6, 0.3))
			panel.add_child(near_lbl)

	var ok_btn = Button.new()
	ok_btn.text = "确定"
	ok_btn.position = Vector2(100, 140)
	ok_btn.custom_minimum_size = Vector2(100, 30)
	ok_btn.pressed.connect(func():
		overlay.queue_free()
	)
	panel.add_child(ok_btn)

func _clear_cauldron() -> void:
	_cauldron_ingredients = []
	_mortar_ingredient = {}
	_grind_count = 0
	_max_grind = 0
	_pestle_angle = 0.0
	queue_redraw()

func _update_status() -> void:
	var sl = get_node_or_null("_status_label")
	if sl != null:
		var grinds = {}
		for entry in _cauldron_ingredients:
			var d = entry.get("data", {})
			grinds[d.get("id", "")] = entry.get("grind", 0)
		var p = DATA.calculate_params(_cauldron_ingredients, _cauldron_solvent, grinds)
		sl.text = "状态: 就绪 | 颗粒度: " + str(snapped(p.get("granularity", 0), 0.1)) + " | 浓度: " + str(snapped(p.get("concentration", 0), 0.1))
		if _grind_count > 0:
			sl.text += " | 研磨中: " + str(_grind_count)

func _generate_sample_recipe() -> void:
	var existing_ids = []
	for r in _recipes:
		if r.has("id"):
			existing_ids.append(r["id"])
	var qualities = ["common", "uncommon", "rare"]
	var q = qualities[randi() % qualities.size()]
	var recipe = GENERATOR.generate_recipe(q, existing_ids)
	_recipes.append(recipe)

	var msg = "获得配方: " + recipe.get("chs_name", "?") + " (" + RARITY_NAMES.get(recipe.get("rarity", "common"), "?") + ")"
	_show_toast(msg)

func _show_toast(msg: String) -> void:
	var lbl = Label.new()
	lbl.text = msg
	lbl.position = Vector2(200, 60)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	add_child(lbl)
	var tween = create_tween()
	tween.tween_method(func(v): lbl.modulate.a = v, 1.0, 0.0, 2.0).set_delay(1.5)
	tween.tween_callback(lbl.queue_free)

func _show_recipe_book() -> void:
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = MOUSE_FILTER_STOP
	overlay.name = "_recipe_overlay"
	add_child(overlay)

	var panel = ColorRect.new()
	panel.color = Color(0.08, 0.08, 0.12)
	panel.size = Vector2(500, 460)
	panel.position = Vector2(150, 50)
	overlay.add_child(panel)

	var title = Label.new()
	title.text = "配方书"
	title.position = Vector2(30, 20)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	panel.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "关闭"
	close_btn.position = Vector2(410, 20)
	close_btn.pressed.connect(overlay.queue_free)
	panel.add_child(close_btn)

	var y = 60
	if _recipes.size() == 0:
		var empty = Label.new()
		empty.text = "暂无配方。在坩埚中成功炼药后配方会自动记录。"
		empty.position = Vector2(30, y)
		empty.add_theme_font_size_override("font_size", 13)
		empty.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		panel.add_child(empty)
	else:
		for r in _recipes:
			var cn = r.get("chs_name", "未知配方")
			var rarity = r.get("rarity", "common")
			var rcol = RARITY_COLORS.get(rarity, Color(1,1,1))
			var rname = RARITY_NAMES.get(rarity, "")
			var cond = r.get("condition", {})
			var solvent = DATA.get_solvent(cond.get("solvent", ""))
			var solv_name = solvent.get("chs_name", cond.get("solvent", "?"))

			var line = cn + " [" + rname + "] 溶剂: " + solv_name
			var lbl = Label.new()
			lbl.text = line
			lbl.position = Vector2(20, y)
			lbl.add_theme_font_size_override("font_size", 13)
			lbl.add_theme_color_override("font_color", rcol)
			panel.add_child(lbl)
			y += 24

			var elem_text = "元素: "
			var ce = cond.get("element", {})
			for ek in ce:
				elem_text += ek + "≥" + str(ce[ek].get("min", 0)) + " "
			var elem_lbl = Label.new()
			elem_lbl.text = elem_text
			elem_lbl.position = Vector2(30, y)
			elem_lbl.add_theme_font_size_override("font_size", 10)
			elem_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			panel.add_child(elem_lbl)
			y += 18

func _on_back() -> void:
	var ts = Control.new()
	ts.set_script(preload("res://src/main/title_screen.gd"))
	ts.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(ts)
	queue_free()
