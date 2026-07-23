extends Control

const DATA = preload("res://src/alchemy/alchemy_data.gd")
const GENERATOR = preload("res://src/alchemy/recipe_generator.gd")
const ITEM_LOADER = preload("res://src/item_editor/item_data.gd")
const RARITY_ORDER = ["common", "uncommon", "rare", "epic", "legendary"]
const RARITY_NAMES = { "common": "普通", "uncommon": "优秀", "rare": "稀有", "epic": "史诗", "legendary": "传说" }
const RARITY_COLORS = { "common": Color(0.8,0.8,0.8), "uncommon": Color(0.3,0.8,0.3), "rare": Color(0.3,0.5,1.0), "epic": Color(0.8,0.3,1.0), "legendary": Color(1.0,0.6,0.0) }

# --- texture paths (swap these to use PNG textures instead of primitives) ---
const MORTAR_TEX_PATH = "res://assets/img/ui/alchemy/mortar.png"
const PESTLE_TEX_PATH = "res://assets/img/ui/alchemy/pestle.png"
const CAULDRON_TEX_PATH = "res://assets/img/ui/alchemy/cauldron.png"
const SOLVENT_TEX_PATH = "res://assets/img/ui/alchemy/solvent_tube.png"

# --- layout geometry ---
const MORTAR_CENTER = Vector2(290, 260)
const MORTAR_RADIUS = 70.0
const PESTLE_RADIUS = 40.0
const CAULDRON_CENTER = Vector2(530, 330)
const CAULDRON_WIDTH = 110.0
const CAULDRON_HEIGHT = 100.0

const SOLVENT_TUBE_W = 34
const SOLVENT_TUBE_H = 64
const SOLVENT_GAP = 10
const SOLVENT_X = 654
const SOLVENT_TOP_Y = 80

# --- state ---
var _materials_inventory: Array = []
var _recipes: Array = []
var _brew_level: int = 1

var _mortar_ingredient: Dictionary = {}
var _grind_count: int = 0
var _max_grind: int = 0

var _cauldron_ingredients: Array = []
var _cauldron_solvents: Array = []   # [{ "id": "water", "amount": 1.0 }, ...]

var _pestle_angle: float = 0.0
var _pestle_dragging: bool = false
var _pestle_last_angle: float = 0.0
var _pestle_full_rotations: float = 0.0

var _font: Font = null
var _item_frames: Dictionary = {}
var _tex_mortar: Texture2D = null
var _tex_pestle: Texture2D = null
var _tex_cauldron: Texture2D = null
var _tex_solvent_tube: Texture2D = null

var _brewing: bool = false
var _last_result: Dictionary = {}

# --- drag state ---
var _is_dragging: bool = false
var _drag_data: Dictionary = {}

# --- heat / bellows state ---
var _heat_level: float = 0.5
var _bellows_animating: bool = false
var _bellows_pump: float = 0.0    # 0 = closed, 1 = fully open (animates)
var _heat_decay_timer: float = 0.0

# --- pour animation state ---
var _pour_progress: float = 0.0
var _pouring: bool = false
var _pour_from: Vector2 = Vector2()
var _pour_to: Vector2 = Vector2()
var _pour_color: Color = Color(1, 1, 1)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	_font = ThemeDB.fallback_font
	_init_textures()
	_init_inventory()
	_build_ui()
	queue_redraw()

func _process(delta: float) -> void:
	# heat decays slowly over time
	if _heat_level > 0.0 and not _bellows_animating:
		_heat_level = maxf(_heat_level - delta * 0.04, 0.0)

	# throttle redraw for flame flicker (~15 fps)
	if int(Time.get_ticks_msec() * 0.015) != int((Time.get_ticks_msec() - delta * 1000.0) * 0.015):
		queue_redraw()

func _init_textures() -> void:
	_tex_mortar = RM.get_texture(MORTAR_TEX_PATH)
	_tex_pestle = RM.get_texture(PESTLE_TEX_PATH)
	_tex_cauldron = RM.get_texture(CAULDRON_TEX_PATH)
	_tex_solvent_tube = RM.get_texture(SOLVENT_TEX_PATH)

func _init_inventory() -> void:
	var material_ids = ["red_herb", "blue_herb", "slime_goo", "bat_wing", "fire_flower", "ice_crystal"]
	for id in material_ids:
		var item = ITEM_LOADER.load_item(id)
		if not item.is_empty():
			_materials_inventory.append({ "data": item, "count": 10 })

func _build_ui() -> void:
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
	panel.color = Color.TRANSPARENT
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
		lbl.mouse_filter = MOUSE_FILTER_PASS
		lbl.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var data_copy = entry.duplicate(true)
		lbl.gui_input.connect(func(ev): _on_material_click(ev, data_copy, lbl))
		add_child(lbl)
		y += 22

func _build_right_panel() -> void:
	var panel = ColorRect.new()
	panel.color = Color.TRANSPARENT
	panel.position = Vector2(640, 54)
	panel.size = Vector2(152, 440)
	add_child(panel)

	var title = Label.new()
	title.text = "溶剂"
	title.position = Vector2(644, 56)
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.5, 0.7, 0.9))
	add_child(title)

	# invisible click areas for each solvent tube (drawn in _draw)
	var solvents = DATA.list_solvents()
	var i = 0
	for sid in solvents:
		var btn_area = ColorRect.new()
		btn_area.color = Color.TRANSPARENT
		btn_area.mouse_filter = MOUSE_FILTER_STOP
		btn_area.position = Vector2(SOLVENT_X, SOLVENT_TOP_Y + i * (SOLVENT_TUBE_H + SOLVENT_GAP))
		btn_area.size = Vector2(SOLVENT_TUBE_W, SOLVENT_TUBE_H)
		btn_area.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		var sid_copy = sid
		btn_area.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_start_pour(sid_copy)
		)
		add_child(btn_area)
		i += 1

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

	var status_text = "状态: 就绪"
	if _last_result.has("params"):
		var p = _last_result["params"]
		status_text = "状态: " + ("成功" if _last_result.get("success", false) else "失败")

	var status_label = Label.new()
	status_label.text = status_text
	status_label.position = Vector2(30, 560)
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	status_label.name = "_status_label"
	add_child(status_label)

func _draw() -> void:
	draw_rect(Rect2(Vector2(), size), Color(0.04, 0.04, 0.06))
	# panel backgrounds (must be drawn here so _draw_solvent_tubes renders on top)
	draw_rect(Rect2(8, 54, 140, 440), Color(0.07, 0.07, 0.1))
	draw_rect(Rect2(640, 54, 152, 440), Color(0.07, 0.07, 0.10))
	_draw_mortar()
	_draw_pestle()
	_draw_cauldron()
	_draw_heat_control()
	_draw_grind_bar()
	_draw_solvent_tubes()
	_draw_pour_effect()
	if _is_dragging:
		_draw_drag_item()

func _draw_mortar() -> void:
	# outer rim (visible light gray)
	draw_circle(MORTAR_CENTER, MORTAR_RADIUS + 4, Color(0.55, 0.55, 0.55, 0.8))
	draw_circle(MORTAR_CENTER, MORTAR_RADIUS, Color(0.45, 0.42, 0.38))
	# inner bowl (darker but still visible)
	draw_circle(MORTAR_CENTER, MORTAR_RADIUS * 0.75, Color(0.3, 0.28, 0.24))

	if not _mortar_ingredient.is_empty():
		var col = _mortar_ingredient.get("color", [0.5, 0.5, 0.5])
		var fill = Color(col[0], col[1], col[2], 0.5)
		draw_circle(MORTAR_CENTER, MORTAR_RADIUS * 0.55, fill)
		var cn = _mortar_ingredient.get("chs_name", "")
		if _font != null:
			draw_string(_font, MORTAR_CENTER + Vector2(-40, 5), cn, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.9))

	# label below mortar
	if _font != null:
		draw_string(_font, MORTAR_CENTER + Vector2(-20, MORTAR_RADIUS + 50), "【研钵】", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.6, 0.6, 0.6))

func _draw_pestle() -> void:
	var angle_rad = deg_to_rad(_pestle_angle)
	var tip_x = MORTAR_CENTER.x + PESTLE_RADIUS * cos(angle_rad)
	var tip_y = MORTAR_CENTER.y + PESTLE_RADIUS * sin(angle_rad)

	# handle (from above mortar to the angled tip)
	var handle_top = MORTAR_CENTER + Vector2(0, -MORTAR_RADIUS - 36)
	var handle_bottom = Vector2(tip_x, tip_y) + Vector2(0, -10)
	draw_line(handle_top, handle_bottom, Color(0.7, 0.55, 0.35), 6.0)
	# handle highlight
	draw_line(handle_top + Vector2(-1, -1), handle_bottom + Vector2(-1, -1), Color(0.9, 0.75, 0.55), 2.0)

	# pestle head (bulbous tip)
	var tip = Vector2(tip_x, tip_y)
	draw_circle(tip, 10, Color(0.6, 0.45, 0.3))
	draw_circle(tip, 6, Color(0.75, 0.6, 0.42))
	draw_circle(tip, 3, Color(0.9, 0.75, 0.55))

	# hint text
	var hint = ""
	if _mortar_ingredient.is_empty():
		hint = "拖拽左侧材料到研钵或坩埚"
	elif _pestle_dragging:
		hint = "研磨中..."
	elif _grind_count > 0:
		hint = "右键放入坩埚"
	else:
		hint = "左键拖拽绕圈研磨"
	if hint != "" and _font != null:
		var hint_pos = MORTAR_CENTER + Vector2(-MORTAR_RADIUS, MORTAR_RADIUS + 68)
		draw_string(_font, hint_pos, hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.8, 0.8, 0.6))

func _draw_grind_bar() -> void:
	if _mortar_ingredient.is_empty() or _max_grind <= 0:
		return

	var bar_x = MORTAR_CENTER.x - 45
	var bar_y = MORTAR_CENTER.y + MORTAR_RADIUS + 16
	var bar_w = 90
	var bar_h = 8

	draw_rect(Rect2(bar_x - 1, bar_y - 1, bar_w + 2, bar_h + 2), Color(0.4, 0.4, 0.4, 0.8))
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.15, 0.15, 0.15))

	var ratio = float(_grind_count) / float(_max_grind) if _max_grind > 0 else 0.0
	ratio = clampf(ratio, 0.0, 1.0)
	var bar_color = Color(0.3, 0.8, 0.3).lerp(Color(1.0, 0.6, 0.0), ratio)
	if ratio > 0:
		draw_rect(Rect2(bar_x + 1, bar_y + 1, (bar_w - 2) * ratio, bar_h - 2), bar_color)

	# label
	if _font != null:
		draw_string(_font, Vector2(bar_x, bar_y + bar_h + 14), "颗粒度", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.6, 0.6, 0.6))

func _draw_cauldron() -> void:
	var cx = CAULDRON_CENTER.x
	var cy = CAULDRON_CENTER.y
	var hw = CAULDRON_WIDTH * 0.5
	var hh = CAULDRON_HEIGHT

	# use texture if available
	if _tex_cauldron != null:
		draw_texture(_tex_cauldron, Vector2(cx - hw, cy - hh * 0.5))
	else:
		# body (front view: wider at top, curved sides, flat bottom)
		var body_top = cy - hh * 0.35
		var body_bot = cy + hh * 0.5
		var body_pts = PackedVector2Array([
			Vector2(cx - hw * 0.85, body_top),
			Vector2(cx + hw * 0.85, body_top),
			Vector2(cx + hw, body_top + hh * 0.15),
			Vector2(cx + hw * 0.9, body_bot),
			Vector2(cx - hw * 0.9, body_bot),
			Vector2(cx - hw, body_top + hh * 0.15),
		])
		draw_colored_polygon(body_pts, Color(0.3, 0.28, 0.24))

		# rim (ellipse at top) — polygon approximation
		var rim_pts = PackedVector2Array()
		var rim_seg = 20
		for k in range(rim_seg + 1):
			var a = k * 2.0 * PI / rim_seg
			rim_pts.append(Vector2(cx + (hw * 0.85) * cos(a), body_top + 10.0 * sin(a)))
		draw_polygon(rim_pts, [Color(0.5, 0.5, 0.5, 0.9)])

		var inner_pts = PackedVector2Array()
		for k in range(rim_seg + 1):
			var a = k * 2.0 * PI / rim_seg
			inner_pts.append(Vector2(cx + (hw * 0.75) * cos(a), body_top + 7.0 * sin(a)))
		draw_polygon(inner_pts, [Color(0.2, 0.18, 0.16)])

		# highlight on left side
		var hl_pts = PackedVector2Array([
			Vector2(cx - hw * 0.85, body_top + 4),
			Vector2(cx - hw * 0.7, body_top + hh * 0.1),
			Vector2(cx - hw * 0.65, body_bot - 4),
			Vector2(cx - hw * 0.75, body_bot - 4),
		])
		draw_colored_polygon(hl_pts, Color(0.45, 0.42, 0.38, 0.5))

	# liquid inside (ingredients + solvents)
	var total_liquid = float(_cauldron_ingredients.size()) + _total_solvent_amount() * 0.5
	var fill_ratio = clampf(total_liquid / 6.0, 0.0, 1.0)
	if fill_ratio > 0.0:
		var liquid_top = cy - hh * 0.25 + hh * 0.5 * (1.0 - fill_ratio)
		var liquid_bot = cy + hh * 0.45
		var liquid_h = liquid_bot - liquid_top
		var w_factor = 1.0 - (liquid_h / hh) * 0.2
		var liq_pts = PackedVector2Array([
			Vector2(cx - hw * 0.7 * w_factor, liquid_top),
			Vector2(cx + hw * 0.7 * w_factor, liquid_top),
			Vector2(cx + hw * 0.75 * w_factor, liquid_bot),
			Vector2(cx - hw * 0.75 * w_factor, liquid_bot),
		])
		draw_colored_polygon(liq_pts, Color(0.2, 0.5, 0.4, 0.5))

		# powder particles instead of text
		var rng = RandomNumberGenerator.new()
		for ei in range(_cauldron_ingredients.size()):
			var d = _cauldron_ingredients[ei].get("data", {})
			var col_arr = d.get("alchemy", {}).get("color", d.get("color", [0.5, 0.5, 0.5]))
			var pcol = Color(col_arr[0], col_arr[1], col_arr[2], 0.7)
			rng.seed = hash(d.get("id", str(ei)))
			var pcount = 3 + rng.randi() % 5
			for pi in range(pcount):
				var px = cx + (rng.randf() - 0.5) * hw * 1.1 * w_factor
				var py = liquid_top + rng.randf() * (liquid_bot - liquid_top) * 0.8 + (liquid_bot - liquid_top) * 0.1
				var ps = 2.0 + rng.randf() * 3.5
				var pv = PackedVector2Array([
					Vector2(px, py - ps),
					Vector2(px + ps * 0.7, py + ps * 0.3),
					Vector2(px - ps * 0.7, py + ps * 0.3),
				])
				draw_colored_polygon(pv, pcol)

	# label
	if _font != null:
		draw_string(_font, Vector2(cx - 20, cy + hh * 0.5 + 24), "【坩埚】", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.6, 0.6, 0.6))

# ---------------------------------------------------------------------------
# heat / bellows control
# ---------------------------------------------------------------------------
func _draw_heat_control() -> void:
	var cx = CAULDRON_CENTER.x
	var fx = cx
	var fy = CAULDRON_CENTER.y + CAULDRON_HEIGHT * 0.5 + 50

	# ---- fire pit (stone ring) ----
	var pit_seg = 16
	var pit_outer = PackedVector2Array()
	var pit_inner = PackedVector2Array()
	for k in range(pit_seg + 1):
		var a = k * 2.0 * PI / pit_seg
		pit_outer.append(Vector2(fx + 44.0 * cos(a), fy + 12.0 * sin(a)))
		pit_inner.append(Vector2(fx + 40.0 * cos(a), fy + 10.0 * sin(a)))
	draw_polygon(pit_outer, [Color(0.35, 0.3, 0.25)])
	draw_polygon(pit_inner, [Color(0.2, 0.18, 0.16)])

	# ---- flames ----
	var flame_count = 5 + int(_heat_level * 8)
	var flame_h = 10.0 + _heat_level * 40.0
	var flame_w = 6.0 + _heat_level * 12.0
	var flicker = fmod(Time.get_ticks_msec() * 0.005, PI * 2.0)

	var flame_color = Color(0.3, 0.2, 0.05).lerp(Color(1.0, 0.6, 0.05), _heat_level)
	var inner_color = Color(0.6, 0.2, 0.0).lerp(Color(1.0, 0.9, 0.4), _heat_level)

	for i in range(flame_count):
		var offset_x = (float(i) / float(maxi(flame_count - 1, 1)) - 0.5) * 2.0 * (20.0 + _heat_level * 15.0)
		var var_h = flame_h * (0.7 + 0.3 * sin(flicker + i * 1.5))
		var var_w = flame_w * (0.6 + 0.4 * cos(flicker * 0.7 + i * 2.0))

		var outer = PackedVector2Array([
			Vector2(fx + offset_x - var_w * 0.5, fy - 4),
			Vector2(fx + offset_x, fy - 4 - var_h),
			Vector2(fx + offset_x + var_w * 0.5, fy - 4),
		])
		draw_colored_polygon(outer, Color(flame_color.r, flame_color.g, flame_color.b, 0.7))

		if _heat_level > 0.3:
			var inner_h = var_h * 0.5
			var inner_w = var_w * 0.4
			var inner = PackedVector2Array([
				Vector2(fx + offset_x - inner_w * 0.5, fy - 4),
				Vector2(fx + offset_x, fy - 4 - inner_h),
				Vector2(fx + offset_x + inner_w * 0.5, fy - 4),
			])
			draw_colored_polygon(inner, Color(inner_color.r, inner_color.g, inner_color.b, 0.6))

	# embers (sparks at high heat)
	if _heat_level > 0.6:
		var spark_count = int(_heat_level * 6)
		for j in range(spark_count):
			var sx = fx + sin(flicker * 2.0 + j * 3.7) * (20.0 + _heat_level * 20.0)
			var sy = fy - 4 - flame_h * 0.6 - randf() * flame_h * 0.5
			var spark_size = 1.5 + randf() * 2.0 * _heat_level
			draw_circle(Vector2(sx, sy), spark_size, Color(1.0, 0.7, 0.2, 0.5 + randf() * 0.3))

	# temperature label
	if _font != null:
		var temp_label = ""
		if _heat_level < 0.25: temp_label = "小火"
		elif _heat_level < 0.55: temp_label = "中火"
		elif _heat_level < 0.8: temp_label = "大火"
		else: temp_label = "猛火"
		draw_string(_font, Vector2(fx - 14, fy + 30), temp_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.9, 0.6, 0.3))

	# ---- bellows (left of fire pit) ----
	var bx = fx - 65
	var by = fy - 6

	# bellows body (trapezoid — wider at bottom)
	var body_top_w = 18.0
	var body_bot_w = 28.0
	var body_h = 28.0
	var body = PackedVector2Array([
		Vector2(bx - body_top_w * 0.5, by - body_h),
		Vector2(bx + body_top_w * 0.5, by - body_h),
		Vector2(bx + body_bot_w * 0.5, by - 2),
		Vector2(bx - body_bot_w * 0.5, by - 2),
	])
	draw_colored_polygon(body, Color(0.5, 0.35, 0.2))
	draw_line(Vector2(bx - body_top_w * 0.5, by - body_h), Vector2(bx + body_top_w * 0.5, by - body_h), Color(0.35, 0.25, 0.15), 2)
	# vertical ribs
	for rib in range(3):
		var rx = bx - body_bot_w * 0.5 + 4 + rib * 8
		draw_line(Vector2(rx, by - body_h + 2), Vector2(rx, by - 4), Color(0.4, 0.28, 0.16), 1)

	# nozzle (pointing right toward fire)
	var nozzle = PackedVector2Array([
		Vector2(bx + body_bot_w * 0.5, by - 8),
		Vector2(bx + body_bot_w * 0.5 + 14, by - 6),
		Vector2(bx + body_bot_w * 0.5 + 14, by - 2),
		Vector2(bx + body_bot_w * 0.5, by - 2),
	])
	draw_colored_polygon(nozzle, Color(0.4, 0.3, 0.18))

	# handle (rod + grip that pumps)
	var pump_open = lerp(0.0, 14.0, _bellows_pump)
	var handle_y = by - body_h - 6 - pump_open
	# rod
	draw_line(Vector2(bx, by - body_h), Vector2(bx, handle_y), Color(0.6, 0.45, 0.25), 3)
	# grip (horizontal bar at top of rod)
	var grip_w = 16.0
	var grip = PackedVector2Array([
		Vector2(bx - grip_w * 0.5, handle_y - 3),
		Vector2(bx + grip_w * 0.5, handle_y - 3),
		Vector2(bx + grip_w * 0.5, handle_y + 3),
		Vector2(bx - grip_w * 0.5, handle_y + 3),
	])
	draw_colored_polygon(grip, Color(0.55, 0.4, 0.22))

	# small "风箱" label
	if _font != null:
		draw_string(_font, Vector2(bx - 12, by + 16), "风箱", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.5, 0.4, 0.3))

# ---------------------------------------------------------------------------
# solvent tubes
# ---------------------------------------------------------------------------
func _draw_solvent_tubes() -> void:
	var solvents = DATA.list_solvents()
	var i = 0
	for sid in solvents:
		var sd = DATA.get_solvent(sid)
		var col_arr = sd.get("color", [0.5, 0.5, 0.9])
		var col = Color(col_arr[0], col_arr[1], col_arr[2])
		var x = SOLVENT_X
		var y = SOLVENT_TOP_Y + i * (SOLVENT_TUBE_H + SOLVENT_GAP)
		var tw = SOLVENT_TUBE_W
		var th = SOLVENT_TUBE_H

		# use texture if available
		if _tex_solvent_tube != null:
			draw_texture_rect(_tex_solvent_tube, Rect2(x, y, tw, th), false)
		else:
			# tube body (rectangle with rounded bottom)
			var body = PackedVector2Array([
				Vector2(x + 4, y),
				Vector2(x + tw - 4, y),
				Vector2(x + tw - 2, y + th - 12),
				Vector2(x + tw - 2, y + th - 4),
				Vector2(x + tw - 8, y + th - 1),
				Vector2(x + 8, y + th - 1),
				Vector2(x + 2, y + th - 4),
				Vector2(x + 2, y + th - 12),
			])
			# glass body
			draw_colored_polygon(body, Color(0.6, 0.65, 0.7, 0.25))

			# liquid fill (sinusoidal top surface)
			var fill_top = y + th * 0.2
			var fill_bot = y + th - 6
			var fill_w = tw - 8
			var fill_pts = PackedVector2Array()
			var steps = 8
			for j in range(steps + 1):
				var fx = x + 4 + fill_w * (float(j) / steps)
				var wave = -3.0 * sin(j * PI / steps)
				fill_pts.append(Vector2(fx, fill_top + wave))
			fill_pts.append(Vector2(x + tw - 4, fill_bot))
			fill_pts.append(Vector2(x + 4, fill_bot))
			draw_colored_polygon(fill_pts, Color(col.r, col.g, col.b, 0.45))

			# glass highlight (left side reflection)
			var hl = PackedVector2Array([
				Vector2(x + 5, y + 8),
				Vector2(x + 10, y + 8),
				Vector2(x + 9, fill_bot - 4),
				Vector2(x + 5, fill_bot - 4),
			])
			draw_colored_polygon(hl, Color(1, 1, 1, 0.12))

		# name below tube
		var sn = sd.get("chs_name", sid)
		if _font != null:
			draw_string(_font, Vector2(x - 4, y + th + 14), sn, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.7, 0.7, 0.7))

		# accumulated amount for this solvent
		var total_amt = 0.0
		for se in _cauldron_solvents:
			if se.get("id", "") == sid:
				total_amt += se.get("amount", 0.0)

		# highlight + amount label if any added
		if total_amt > 0.0:
			draw_rect(Rect2(x - 1, y - 1, tw + 2, th + 2), Color(col.r, col.g, col.b, 0.5), false, 1.5)
			if _font != null:
				draw_string(_font, Vector2(x + tw + 4, y + 8), "x" + str(snapped(total_amt, 0.1)), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.8, 0.8, 0.6))

		i += 1

# ---------------------------------------------------------------------------
# pour effect
# ---------------------------------------------------------------------------
func _draw_pour_effect() -> void:
	if not _pouring:
		return
	var p = _pour_progress
	if p <= 0.0 or p >= 1.0:
		return

	# arc from tube to cauldron
	var mid = _pour_from.lerp(_pour_to, 0.5) + Vector2(0, -60)
	var steps = 12
	var prev = _pour_from
	for i in range(1, steps + 1):
		var t = float(i) / steps
		var pt = _bezier_quad(_pour_from, mid, _pour_to, t)
		var width = 2.0 + 4.0 * (1.0 - t) * p
		draw_line(prev, pt, Color(_pour_color.r, _pour_color.g, _pour_color.b, 0.6 * (1.0 - t * 0.3)), width)
		prev = pt

	# droplet at pour_to
	var drop_size = 3.0 + 4.0 * (1.0 - p)
	draw_circle(_pour_to, drop_size, Color(_pour_color.r, _pour_color.g, _pour_color.b, 0.7 * p))

func _bezier_quad(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var u = 1.0 - t
	return u * u * p0 + 2.0 * u * t * p1 + t * t * p2

func _start_pour(sid: String) -> void:
	if _pouring:
		return
	var solvents = DATA.list_solvents()
	var i = solvents.find(sid)
	if i < 0:
		return

	# accumulate solvent amount
	var found = false
	for se in _cauldron_solvents:
		if se.get("id", "") == sid:
			se["amount"] = se.get("amount", 0.0) + 0.3
			found = true
			break
	if not found:
		_cauldron_solvents.append({ "id": sid, "amount": 0.3 })

	_pour_color = Color(0.7, 0.7, 1.0)
	var sd = DATA.get_solvent(sid)
	if sd.has("color"):
		var c = sd["color"]
		_pour_color = Color(c[0], c[1], c[2])

	var tube_x = SOLVENT_X + SOLVENT_TUBE_W * 0.5
	var tube_y = SOLVENT_TOP_Y + i * (SOLVENT_TUBE_H + SOLVENT_GAP) + SOLVENT_TUBE_H * 0.5
	_pour_from = Vector2(tube_x, tube_y)
	_pour_to = Vector2(CAULDRON_CENTER.x, CAULDRON_CENTER.y - CAULDRON_HEIGHT * 0.2)

	_pour_progress = 0.0
	_pouring = true

	var tween = create_tween()
	tween.tween_method(func(v): _pour_progress = v; queue_redraw(), 0.0, 1.0, 0.5).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func():
		_pouring = false
		_pour_progress = 0.0
		_update_status()
	)
	queue_redraw()

# ---------------------------------------------------------------------------
# drag-and-drop
# ---------------------------------------------------------------------------
func _draw_drag_item() -> void:
	if _is_dragging and _drag_data.has("data"):
		var d = _drag_data["data"]
		var cn = d.get("chs_name", d.get("name", "?"))
		var col_arr = d.get("alchemy", {}).get("color", [0.5, 0.5, 0.5])
		var col = Color(col_arr[0], col_arr[1], col_arr[2], 0.7)
		var pos = get_local_mouse_position() - Vector2(30, 15)

		# background pill
		draw_rect(Rect2(pos.x - 2, pos.y - 2, 64, 18), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(pos.x - 2, pos.y - 2, 64, 18), col, false, 1.5)

		if _font != null:
			draw_string(_font, pos + Vector2(0, 13), cn, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.85))

func _total_solvent_amount() -> float:
	var total = 0.0
	for se in _cauldron_solvents:
		total += se.get("amount", 0.0)
	return total

func _bellows_rect() -> Rect2:
	var fx = CAULDRON_CENTER.x
	var fy = CAULDRON_CENTER.y + CAULDRON_HEIGHT * 0.5 + 50
	var bx = fx - 65
	return Rect2(bx - 16, fy - 50, 50, 60)

func _pump_bellows() -> void:
	if _bellows_animating:
		return
	_bellows_animating = true
	_bellows_pump = 0.0

	var tween = create_tween()
	tween.tween_property(self, "_bellows_pump", 1.0, 0.12)
	tween.tween_property(self, "_bellows_pump", 0.0, 0.12)
	tween.tween_callback(func():
		_bellows_animating = false
		_heat_level = minf(_heat_level + 0.12, 1.0)
		queue_redraw()
	)
	_heat_level = minf(_heat_level + 0.02, 1.0)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	# --- drag mode ---
	if _is_dragging:
		if event is InputEventMouseMotion:
			queue_redraw()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var mpos = event.position
			_drop_item(mpos)
			get_viewport().set_input_as_handled()
		return

	# --- bellows pump / cool ---
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mpos = event.position
		if _bellows_rect().has_point(mpos):
			_pump_bellows()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var mpos = event.position
		if _bellows_rect().has_point(mpos):
			_heat_level = maxf(_heat_level - 0.15, 0.0)
			queue_redraw()
			get_viewport().set_input_as_handled()
			return

	# --- pestle grinding ---
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

		var total_rotations = _pestle_angle / 360.0
		var completed = int(total_rotations)
		var new_grinds = completed - _pestle_full_rotations
		if new_grinds > 0:
			_do_grind(new_grinds)
			_pestle_full_rotations = completed

		_pestle_last_angle = current_angle
		queue_redraw()
		get_viewport().set_input_as_handled()

	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_pestle_dragging = false
		get_viewport().set_input_as_handled()

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var mpos = event.position
		if _in_mortar(mpos) and not _mortar_ingredient.is_empty():
			_move_mortar_to_cauldron()
			get_viewport().set_input_as_handled()

func _in_mortar(pos: Vector2) -> bool:
	return pos.distance_to(MORTAR_CENTER) < MORTAR_RADIUS

func _in_cauldron(pos: Vector2) -> bool:
	var cx = CAULDRON_CENTER.x
	var cy = CAULDRON_CENTER.y
	var hw = CAULDRON_WIDTH * 0.5
	var hh = CAULDRON_HEIGHT
	return abs(pos.x - cx) < hw and pos.y > cy - hh * 0.3 and pos.y < cy + hh * 0.5

func _drop_item(mpos: Vector2) -> void:
	var data = _drag_data.get("data", {})
	if data.is_empty():
		_is_dragging = false
		queue_redraw()
		return

	var alch = data.get("alchemy", {})
	if _in_mortar(mpos) and alch.get("grindable", false):
		_mortar_ingredient = data.duplicate(true)
		_grind_count = 0
		_max_grind = alch.get("max_grind", 0)
		_pestle_angle = 0.0
		_pestle_full_rotations = 0
	elif _in_cauldron(mpos):
		_cauldron_ingredients.append({ "data": data.duplicate(true), "grind": 0 })
	else:
		# dropped outside valid area - cancel
		pass

	_is_dragging = false
	queue_redraw()
	_update_status()

func _move_mortar_to_cauldron() -> void:
	if _mortar_ingredient.is_empty():
		return
	var d = _mortar_ingredient.duplicate(true)
	_cauldron_ingredients.append({ "data": d, "grind": _grind_count })
	_mortar_ingredient = {}
	_grind_count = 0
	_max_grind = 0
	_pestle_angle = 0.0
	_pestle_full_rotations = 0
	queue_redraw()
	_update_status()

func _angle_from_center(pos: Vector2) -> float:
	return atan2(pos.y - MORTAR_CENTER.y, pos.x - MORTAR_CENTER.x)

func _normalize_angle(a: float) -> float:
	while a > PI: a -= 2.0 * PI
	while a < -PI: a += 2.0 * PI
	return a

func _do_grind(count: int) -> void:
	if _mortar_ingredient.is_empty() or count <= 0:
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
		# start drag
		_is_dragging = true
		_drag_data = entry.duplicate(true)
		queue_redraw()

func _on_solvent_select(sid: String) -> void:
	# same as _start_pour but without animation
	var found = false
	for se in _cauldron_solvents:
		if se.get("id", "") == sid:
			se["amount"] = se.get("amount", 0.0) + 1.0
			found = true
			break
	if not found:
		_cauldron_solvents.append({ "id": sid, "amount": 1.0 })
	_update_status()
	queue_redraw()

func _on_brew() -> void:
	if _cauldron_ingredients.is_empty():
		return

	var grinds = {}
	for entry in _cauldron_ingredients:
		var d = entry.get("data", {})
		var g = entry.get("grind", 0)
		grinds[d.get("id", "")] = g

	var result = DATA.brew(_cauldron_ingredients, _cauldron_solvents, grinds, _recipes, _brew_level, _heat_level)
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
	_cauldron_solvents = []
	_mortar_ingredient = {}
	_grind_count = 0
	_max_grind = 0
	_pestle_angle = 0.0
	_pestle_full_rotations = 0
	queue_redraw()

func _update_status() -> void:
	var sl = get_node_or_null("_status_label")
	if sl != null:
		var parts = ["状态: 就绪"]
		if _mortar_ingredient.size() > 0 and _grind_count > 0:
			parts.append("研磨中")
		if _cauldron_ingredients.size() > 0:
			parts.append("配料: " + str(_cauldron_ingredients.size()) + " 种")
		if _cauldron_solvents.size() > 0:
			var solv_parts = []
			for se in _cauldron_solvents:
				var sd = DATA.get_solvent(se.get("id", ""))
				solv_parts.append(sd.get("chs_name", se.get("id", "")) + " x" + str(snapped(se.get("amount", 0), 0.1)))
			parts.append("溶剂: " + ", ".join(solv_parts))
		sl.text = " | ".join(parts)

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

			var lbl = Label.new()
			lbl.text = cn + "  [" + rname + "]"
			lbl.position = Vector2(20, y)
			lbl.add_theme_font_size_override("font_size", 13)
			lbl.add_theme_color_override("font_color", rcol)
			panel.add_child(lbl)
			y += 22

			# grind level (from granularity)
			var g_cond = cond.get("granularity", {})
			var g_max = g_cond.get("max", 999)
			var g_min = g_cond.get("min", 0)
			var grind_desc = ""
			if g_max <= 2: grind_desc = "轻度研磨"
			elif g_max <= 4: grind_desc = "中度研磨"
			elif g_max <= 6: grind_desc = "深度研磨"
			else: grind_desc = "超细研磨"
			if g_min > 0:
				grind_desc = grind_desc + "（不低于" + str(g_min) + "）"

			# heat level
			var h_cond = cond.get("heat", {})
			var h_avg = (h_cond.get("min", 0.0) + h_cond.get("max", 1.0)) * 0.5
			var heat_desc = ""
			if h_avg < 0.25: heat_desc = "小火"
			elif h_avg < 0.55: heat_desc = "中火"
			elif h_avg < 0.8: heat_desc = "大火"
			else: heat_desc = "猛火"

			# solvents
			var solv_cond = cond.get("solvent", {})
			var solv_parts = []
			if solv_cond is Dictionary:
				for sid in solv_cond:
					var sd = DATA.get_solvent(sid)
					var sn = sd.get("chs_name", sid)
					var amt = solv_cond[sid].get("min_amount", 0.1) if solv_cond[sid] is Dictionary else 0.1
					solv_parts.append(sn + " x" + str(amt))
			elif solv_cond is String:
				var sd = DATA.get_solvent(solv_cond)
				solv_parts.append(sd.get("chs_name", solv_cond) + " x1.0")
			var solv_line = "溶剂: " + ", ".join(solv_parts)

			var info = grind_desc + " | 火候: " + heat_desc + " | " + solv_line
			var info_lbl = Label.new()
			info_lbl.text = info
			info_lbl.position = Vector2(28, y)
			info_lbl.add_theme_font_size_override("font_size", 10)
			info_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.6))
			panel.add_child(info_lbl)
			y += 20

func _on_back() -> void:
	var ts = Control.new()
	ts.set_script(preload("res://src/main/title_screen.gd"))
	ts.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(ts)
	queue_free()
