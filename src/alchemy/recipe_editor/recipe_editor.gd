extends Control

const EVAL = preload("res://src/alchemy/recipe_evaluator.gd")
const DATA = preload("res://src/alchemy/recipe_data.gd")
const GENERATOR = preload("res://src/alchemy/recipe_generator.gd")
const RARITY_NAMES = { "common": "普通", "uncommon": "优秀", "rare": "稀有", "epic": "史诗", "legendary": "传说" }
const RARITY_COLORS = { "common": Color(0.8,0.8,0.8), "uncommon": Color(0.3,0.8,0.3), "rare": Color(0.3,0.5,1.0), "epic": Color(0.8,0.3,1.0), "legendary": Color(1.0,0.6,0.0) }
const SOLVENTS = ["water", "oil", "venom"]
const ELEMENTS = ["fire", "water", "ice", "earth", "air", "dark", "poison", "light"]
const EFFECT_TYPES = ["hp", "power", "speed", "defense", "bomb_up", "max_hp", "regen", "fire_resist", "poison_resist", "ice_resist"]

var _recipes: Array = []
var _selected_index: int = -1
var _current_recipe: Dictionary = {}
var _dirty: bool = false

var _list_container: VBoxContainer
var _id_edit: LineEdit
var _name_edit: LineEdit
var _chs_name_edit: LineEdit
var _rarity_option: OptionButton
var _output_id_edit: LineEdit
var _output_name_edit: LineEdit

var _solvent_option: OptionButton
var _granularity_min: SpinBox
var _granularity_max: SpinBox
var _concentration_min: SpinBox
var _concentration_max: SpinBox
var _element_containers: Dictionary = {}

var _effect_edit: TextEdit
var _eval_label: Label
var _flags_label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	_init_textures()
	_load_recipe_list()
	_build_ui()

func _init_textures() -> void:
	pass

func _load_recipe_list() -> void:
	_recipes = DATA.list_recipes()
	if _recipes.is_empty():
		var temp = DATA.new_template()
		temp["id"] = "example_healing"
		temp["name"] = "Healing Potion"
		temp["chs_name"] = "治疗药剂"
		_recipes.append(temp)

func _build_ui() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.035, 0.04, 0.055)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bg)

	_build_header()
	_build_list_panel()
	_build_editor_panel()
	_show_recipe(-1)

func _build_header() -> void:
	var hb = ColorRect.new()
	hb.color = Color(0.08, 0.08, 0.12)
	hb.size = Vector2(800, 42)
	add_child(hb)

	var title = Label.new()
	title.text = "配方编辑器"
	title.position = Vector2(16, 6)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	add_child(title)

	var back_btn = Button.new()
	back_btn.text = " ← 返回 "
	back_btn.position = Vector2(710, 8)
	back_btn.custom_minimum_size = Vector2(80, 28)
	back_btn.pressed.connect(_on_back)
	add_child(back_btn)

	var new_btn = Button.new()
	new_btn.text = "新建配方"
	new_btn.position = Vector2(160, 8)
	new_btn.pressed.connect(_on_new)
	add_child(new_btn)

	var gen_btn = Button.new()
	gen_btn.text = "随机生成"
	gen_btn.position = Vector2(250, 8)
	gen_btn.pressed.connect(_on_generate)
	add_child(gen_btn)

	var clean_btn = Button.new()
	clean_btn.text = "清空文件"
	clean_btn.position = Vector2(600, 8)
	clean_btn.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	clean_btn.pressed.connect(_on_cleanup)
	add_child(clean_btn)

func _build_list_panel() -> void:
	var panel = ColorRect.new()
	panel.color = Color(0.06, 0.06, 0.09)
	panel.position = Vector2(4, 46)
	panel.size = Vector2(160, 508)
	add_child(panel)

	var lbl = Label.new()
	lbl.text = "配方列表 (" + str(_recipes.size()) + ")"
	lbl.position = Vector2(8, 50)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.5, 0.7, 0.9))
	add_child(lbl)

	var scroll = ScrollContainer.new()
	scroll.position = Vector2(4, 68)
	scroll.size = Vector2(160, 482)
	add_child(scroll)

	_list_container = VBoxContainer.new()
	_list_container.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(_list_container)
	_refresh_list()

func _refresh_list() -> void:
	for c in _list_container.get_children():
		c.queue_free()

	for i in range(_recipes.size()):
		var r = _recipes[i]
		var cn = r.get("chs_name", r.get("name", "?"))
		var rarity = r.get("rarity", "common")
		var col = RARITY_COLORS.get(rarity, Color(1,1,1))

		var btn = Button.new()
		btn.text = cn
		btn.custom_minimum_size = Vector2(150, 26)
		btn.add_theme_color_override("font_color", col)
		btn.add_theme_font_size_override("font_size", 11)
		var idx = i
		btn.pressed.connect(func(): _select_recipe(idx))
		_list_container.add_child(btn)

func _build_editor_panel() -> void:
	var panel = ColorRect.new()
	panel.color = Color(0.055, 0.06, 0.085)
	panel.position = Vector2(168, 46)
	panel.size = Vector2(628, 508)
	add_child(panel)

	var y_offset = 54

	var id_lbl = Label.new()
	id_lbl.text = "ID:"
	id_lbl.position = Vector2(176, y_offset)
	id_lbl.add_theme_font_size_override("font_size", 12)
	add_child(id_lbl)
	_id_edit = LineEdit.new()
	_id_edit.placeholder_text = "recipe_xxx"
	_id_edit.position = Vector2(210, y_offset - 3)
	_id_edit.custom_minimum_size = Vector2(200, 22)
	_id_edit.text_changed.connect(func(t): _mark_dirty())
	add_child(_id_edit)

	var rarity_lbl = Label.new()
	rarity_lbl.text = "品质:"
	rarity_lbl.position = Vector2(440, y_offset)
	rarity_lbl.add_theme_font_size_override("font_size", 12)
	add_child(rarity_lbl)
	_rarity_option = OptionButton.new()
	_rarity_option.position = Vector2(480, y_offset - 3)
	_rarity_option.custom_minimum_size = Vector2(100, 22)
	for rn in ["common", "uncommon", "rare", "epic", "legendary"]:
		_rarity_option.add_item(RARITY_NAMES.get(rn, rn))
	_rarity_option.item_selected.connect(func(idx): _mark_dirty())
	add_child(_rarity_option)

	y_offset += 28
	var name_lbl = Label.new()
	name_lbl.text = "英文名:"
	name_lbl.position = Vector2(176, y_offset)
	name_lbl.add_theme_font_size_override("font_size", 12)
	add_child(name_lbl)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Potion Name"
	_name_edit.position = Vector2(230, y_offset - 3)
	_name_edit.custom_minimum_size = Vector2(180, 22)
	_name_edit.text_changed.connect(func(t): _mark_dirty())
	add_child(_name_edit)

	_chs_name_edit = LineEdit.new()
	_chs_name_edit.placeholder_text = "中文名"
	_chs_name_edit.position = Vector2(420, y_offset - 3)
	_chs_name_edit.custom_minimum_size = Vector2(140, 22)
	_chs_name_edit.text_changed.connect(func(t): _mark_dirty())
	add_child(_chs_name_edit)

	y_offset += 28
	var oid_lbl = Label.new()
	oid_lbl.text = "产出药剂ID:"
	oid_lbl.position = Vector2(176, y_offset)
	oid_lbl.add_theme_font_size_override("font_size", 12)
	add_child(oid_lbl)
	_output_id_edit = LineEdit.new()
	_output_id_edit.placeholder_text = "potion_id"
	_output_id_edit.position = Vector2(260, y_offset - 3)
	_output_id_edit.custom_minimum_size = Vector2(150, 22)
	_output_id_edit.text_changed.connect(func(t): _mark_dirty())
	add_child(_output_id_edit)

	var onm_lbl = Label.new()
	onm_lbl.text = "药剂名:"
	onm_lbl.position = Vector2(430, y_offset)
	onm_lbl.add_theme_font_size_override("font_size", 12)
	add_child(onm_lbl)
	_output_name_edit = LineEdit.new()
	_output_name_edit.placeholder_text = "Potion Name"
	_output_name_edit.position = Vector2(490, y_offset - 3)
	_output_name_edit.custom_minimum_size = Vector2(120, 22)
	_output_name_edit.text_changed.connect(func(t): _mark_dirty())
	add_child(_output_name_edit)

	y_offset += 36
	var sep1 = ColorRect.new()
	sep1.color = Color(0.2, 0.2, 0.3, 0.5)
	sep1.position = Vector2(176, y_offset)
	sep1.size = Vector2(600, 1)
	add_child(sep1)
	y_offset += 8

	var cond_title = Label.new()
	cond_title.text = "=== 配方条件 ==="
	cond_title.position = Vector2(176, y_offset)
	cond_title.add_theme_font_size_override("font_size", 14)
	cond_title.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	add_child(cond_title)
	y_offset += 24

	var sol_lbl = Label.new()
	sol_lbl.text = "溶剂:"
	sol_lbl.position = Vector2(176, y_offset)
	sol_lbl.add_theme_font_size_override("font_size", 12)
	add_child(sol_lbl)
	_solvent_option = OptionButton.new()
	_solvent_option.position = Vector2(220, y_offset - 3)
	_solvent_option.custom_minimum_size = Vector2(100, 22)
	for s in SOLVENTS:
		_solvent_option.add_item(s)
	_solvent_option.item_selected.connect(func(idx): _mark_dirty())
	add_child(_solvent_option)

	var grn_lbl = Label.new()
	grn_lbl.text = "颗粒度:"
	grn_lbl.position = Vector2(340, y_offset)
	grn_lbl.add_theme_font_size_override("font_size", 12)
	add_child(grn_lbl)
	_granularity_min = SpinBox.new()
	_granularity_min.min_value = 0
	_granularity_min.max_value = 8
	_granularity_min.step = 0.5
	_granularity_min.position = Vector2(400, y_offset - 3)
	_granularity_min.custom_minimum_size = Vector2(60, 22)
	_granularity_min.value_changed.connect(func(v): _mark_dirty())
	add_child(_granularity_min)
	var tilde = Label.new()
	tilde.text = "~"
	tilde.position = Vector2(462, y_offset)
	add_child(tilde)
	_granularity_max = SpinBox.new()
	_granularity_max.min_value = 0
	_granularity_max.max_value = 8
	_granularity_max.step = 0.5
	_granularity_max.value = 3
	_granularity_max.position = Vector2(478, y_offset - 3)
	_granularity_max.custom_minimum_size = Vector2(60, 22)
	_granularity_max.value_changed.connect(func(v): _mark_dirty())
	add_child(_granularity_max)

	y_offset += 28
	var conc_lbl = Label.new()
	conc_lbl.text = "浓度:"
	conc_lbl.position = Vector2(176, y_offset)
	conc_lbl.add_theme_font_size_override("font_size", 12)
	add_child(conc_lbl)
	_concentration_min = SpinBox.new()
	_concentration_min.min_value = 0
	_concentration_min.max_value = 10
	_concentration_min.step = 0.1
	_concentration_min.position = Vector2(220, y_offset - 3)
	_concentration_min.custom_minimum_size = Vector2(70, 22)
	_concentration_min.value_changed.connect(func(v): _mark_dirty())
	add_child(_concentration_min)
	var tilde2 = Label.new()
	tilde2.text = "~"
	tilde2.position = Vector2(292, y_offset)
	add_child(tilde2)
	_concentration_max = SpinBox.new()
	_concentration_max.min_value = 0
	_concentration_max.max_value = 10
	_concentration_max.step = 0.1
	_concentration_max.value = 2.0
	_concentration_max.position = Vector2(308, y_offset - 3)
	_concentration_max.custom_minimum_size = Vector2(70, 22)
	_concentration_max.value_changed.connect(func(v): _mark_dirty())
	add_child(_concentration_max)

	y_offset += 28
	var elem_title = Label.new()
	elem_title.text = "元素阈值:"
	elem_title.position = Vector2(176, y_offset)
	elem_title.add_theme_font_size_override("font_size", 12)
	add_child(elem_title)

	var add_elem_btn = Button.new()
	add_elem_btn.text = "+添加元素"
	add_elem_btn.position = Vector2(320, y_offset - 3)
	add_elem_btn.custom_minimum_size = Vector2(90, 22)
	add_elem_btn.add_theme_font_size_override("font_size", 11)
	add_elem_btn.pressed.connect(_on_add_element)
	add_child(add_elem_btn)

	_element_container = VBoxContainer.new()
	_element_container.position = Vector2(176, y_offset + 24)
	_element_container.size = Vector2(400, 200)
	add_child(_element_container)

	var sep2 = ColorRect.new()
	sep2.color = Color(0.2, 0.2, 0.3, 0.5)
	sep2.position = Vector2(176, 420)
	sep2.size = Vector2(600, 1)
	add_child(sep2)

	var out_title = Label.new()
	out_title.text = "=== 产出药剂效果 ==="
	out_title.position = Vector2(176, 426)
	out_title.add_theme_font_size_override("font_size", 14)
	out_title.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	add_child(out_title)

	_effect_edit = TextEdit.new()
	_effect_edit.position = Vector2(176, 448)
	_effect_edit.size = Vector2(400, 60)
	_effect_edit.placeholder_text = '{"hp": 5, "power": 2, "duration": 30}'
	_effect_edit.text_changed.connect(func(): _mark_dirty())
	add_child(_effect_edit)

	var eval_btn = Button.new()
	eval_btn.text = "评估配方"
	eval_btn.position = Vector2(600, 448)
	eval_btn.custom_minimum_size = Vector2(80, 26)
	eval_btn.pressed.connect(_on_evaluate)
	add_child(eval_btn)

	var fix_btn = Button.new()
	fix_btn.text = "自动修正"
	fix_btn.position = Vector2(600, 480)
	fix_btn.custom_minimum_size = Vector2(80, 26)
	fix_btn.pressed.connect(_on_auto_fix)
	add_child(fix_btn)

	_eval_label = Label.new()
	_eval_label.position = Vector2(176, 512)
	_eval_label.add_theme_font_size_override("font_size", 11)
	add_child(_eval_label)

	_flags_label = Label.new()
	_flags_label.position = Vector2(176, 530)
	_flags_label.add_theme_font_size_override("font_size", 12)
	add_child(_flags_label)

	var save_btn = Button.new()
	save_btn.text = "保存"
	save_btn.position = Vector2(620, 520)
	save_btn.custom_minimum_size = Vector2(70, 28)
	save_btn.pressed.connect(_on_save)
	add_child(save_btn)

var _element_container: VBoxContainer

func _refresh_element_ui(elements: Dictionary) -> void:
	for c in _element_container.get_children():
		c.queue_free()

	var i = 0
	for ek in ELEMENTS:
		var ev = elements.get(ek, {})
		var min_val = ev.get("min", 0.0) if ev is Dictionary else float(ev)
		var row = HBoxContainer.new()
		row.size_flags_horizontal = SIZE_EXPAND_FILL

		var chk = CheckBox.new()
		chk.text = ek
		chk.button_pressed = elements.has(ek)
		chk.toggled.connect(func(tog):
			if tog:
				var cd = _build_cond_dict()
				cd[ek] = { "min": 0.1 }
				_refresh_element_ui(cd)
			else:
				_remove_element(ek)
			_mark_dirty()
		)
		row.add_child(chk)

		var min_lbl = Label.new()
		min_lbl.text = "min:"
		row.add_child(min_lbl)
		var sb = SpinBox.new()
		sb.min_value = 0.0
		sb.max_value = 1.0
		sb.step = 0.05
		sb.value = min_val
		sb.custom_minimum_size = Vector2(70, 22)
		sb.value_changed.connect(func(v):
			var cd = _build_cond_dict()
			if not cd.has(ek): cd[ek] = {}
			cd[ek]["min"] = v
			_mark_dirty()
		)
		row.add_child(sb)

		if chk.button_pressed:
			_element_containers[ek] = sb

		_element_container.add_child(row)
		i += 1

func _build_cond_dict() -> Dictionary:
	var result = {}
	for ek in ELEMENTS:
		if _element_containers.has(ek):
			result[ek] = { "min": _element_containers[ek].value }
	for r in _element_container.get_children():
		if r is HBoxContainer:
			var chk = r.get_child(0) if r.get_child_count() > 0 else null
			if chk is CheckBox and chk.button_pressed:
				if not result.has(chk.text):
					result[chk.text] = { "min": 0.1 }
	return result

func _remove_element(ek: String) -> void:
	_element_containers.erase(ek)

func _select_recipe(idx: int) -> void:
	if _dirty and _selected_index >= 0:
		_save_current_to_list()
	_selected_index = idx
	if idx >= 0 and idx < _recipes.size():
		_show_recipe(idx)
	else:
		_show_recipe(-1)

func _show_recipe(idx: int) -> void:
	if idx < 0 or idx >= _recipes.size():
		_id_edit.text = ""
		_name_edit.text = ""
		_chs_name_edit.text = ""
		_rarity_option.select(0)
		_output_id_edit.text = ""
		_output_name_edit.text = ""
		_solvent_option.select(0)
		_granularity_min.value = 0
		_granularity_max.value = 3
		_concentration_min.value = 0
		_concentration_max.value = 2.0
		_effect_edit.text = "{}"
		_refresh_element_ui({})
		_eval_label.text = ""
		_flags_label.text = ""
		_dirty = false
		return

	var r = _recipes[idx]
	_current_recipe = r.duplicate(true)
	_id_edit.text = str(r.get("id", ""))
	_name_edit.text = str(r.get("name", ""))
	_chs_name_edit.text = str(r.get("chs_name", ""))

	var rar_idx = 0
	for i in range(_rarity_option.item_count):
		if _rarity_option.get_item_text(i) == RARITY_NAMES.get(r.get("rarity", "common"), ""):
			rar_idx = i; break
	_rarity_option.select(rar_idx)

	_output_id_edit.text = str(r.get("output_item_id", ""))
	var output_item = r.get("output_item", {})
	_output_name_edit.text = str(output_item.get("chs_name", output_item.get("name", "")))

	var cond = r.get("condition", {})

	var sol_idx = 0
	for i in range(_solvent_option.item_count):
		if _solvent_option.get_item_text(i) == cond.get("solvent", "water"):
			sol_idx = i; break
	_solvent_option.select(sol_idx)

	var gran = cond.get("granularity", {})
	if gran is Dictionary:
		_granularity_min.value = gran.get("min", 0)
		_granularity_max.value = gran.get("max", 3)
	else:
		_granularity_min.value = 0
		_granularity_max.value = 3

	var conc = cond.get("concentration", {})
	if conc is Dictionary:
		_concentration_min.value = conc.get("min", 0)
		_concentration_max.value = conc.get("max", 2.0)
	else:
		_concentration_min.value = 0
		_concentration_max.value = 2.0

	_refresh_element_ui(cond.get("element", {}))

	var fx = output_item.get("effects", {})
	_effect_edit.text = JSON.new().stringify(fx, "\t")

	_dirty = false
	_eval_label.text = ""
	_flags_label.text = ""

func _save_current_to_list() -> void:
	if _selected_index < 0 or _selected_index >= _recipes.size():
		return
	var r = _build_recipe_from_ui()
	if not r.is_empty():
		_recipes[_selected_index] = r

func _build_recipe_from_ui() -> Dictionary:
	var id_text = _id_edit.text.strip_edges()
	if id_text == "":
		return {}

	var rarity_keys = ["common", "uncommon", "rare", "epic", "legendary"]
	var rar_idx = maxi(0, _rarity_option.selected)
	var rarity = rarity_keys[rar_idx] if rar_idx < rarity_keys.size() else "common"

	var condition = {
		"solvent": SOLVENTS[maxi(0, _solvent_option.selected)],
		"granularity": { "min": _granularity_min.value, "max": _granularity_max.value },
		"concentration": { "min": _concentration_min.value, "max": _concentration_max.value },
		"element": _build_cond_dict()
	}

	var effects = {}
	var fx_text = _effect_edit.text.strip_edges()
	if fx_text != "":
		var parse = JSON.new()
		var err = parse.parse(fx_text)
		if err == OK and parse.data is Dictionary:
			effects = parse.data

	var output_item = {
		"id": _output_id_edit.text.strip_edges(),
		"name": _name_edit.text.strip_edges(),
		"chs_name": _chs_name_edit.text.strip_edges(),
		"type": "potion",
		"rarity": rarity,
		"description": "通过炼金术制作的药剂",
		"frame": "item3",
		"color": GENERATOR._quality_color(rarity),
		"effects": effects,
		"buy_price": 30,
		"sell_price": 15,
		"stackable": true,
		"max_stack": 10
	}

	return {
		"id": id_text,
		"name": _name_edit.text.strip_edges(),
		"chs_name": _chs_name_edit.text.strip_edges(),
		"type": "recipe",
		"rarity": rarity,
		"description": "",
		"frame": "item2",
		"color": GENERATOR._quality_color(rarity),
		"output_item_id": _output_id_edit.text.strip_edges(),
		"output_item": output_item,
		"condition": condition
	}

func _mark_dirty() -> void:
	_dirty = true

func _on_add_element() -> void:
	var menu = PopupMenu.new()
	var idx = 0
	for ek in ELEMENTS:
		menu.add_item(ek, idx)
		idx += 1
	menu.position = get_global_mouse_position()
	menu.id_pressed.connect(func(id):
		var ek = ELEMENTS[id]
		var cd = _build_cond_dict()
		if not cd.has(ek):
			cd[ek] = { "min": 0.1 }
			_refresh_element_ui(cd)
			_mark_dirty()
	)
	add_child(menu)
	menu.popup()

func _on_evaluate() -> void:
	var r = _build_recipe_from_ui()
	if r.is_empty():
		_eval_label.text = "请先填写配方ID"
		return

	var result = EVAL.evaluate(r)
	var score = result.get("total_score", 0)
	_eval_label.text = "评分: " + str(score) + "/100"
	var color = Color(0.3, 1, 0.3) if score >= 60 else (Color(1, 0.8, 0.2) if score >= 30 else Color(1, 0.3, 0.3))
	_eval_label.add_theme_color_override("font_color", color)

	var flags = result.get("flags", [])
	if flags.size() > 0:
		var txt = ""
		for f in flags:
			txt += "[" + f + "] "
		_flags_label.text = txt
	else:
		_flags_label.text = "配方合理"

	var warnings = result.get("warnings", [])
	if warnings.size() > 0:
		_flags_label.text += "\n" + "\n".join(warnings)

func _on_auto_fix() -> void:
	var r = _build_recipe_from_ui()
	if r.is_empty():
		return
	var fixed = EVAL.auto_fix(r)
	if fixed.get("id", "") == r.get("id", "") and _recipes_deep_eq(fixed, r):
		_eval_label.text = "配方已合理，无需修正"
		return

	if _selected_index >= 0:
		_recipes[_selected_index] = fixed
	_show_recipe(_selected_index)
	_eval_label.text = "已自动修正配方参数"

	var eval2 = EVAL.evaluate(fixed)
	_eval_label.text += " | 新评分: " + str(eval2.get("total_score", 0)) + "/100"

	_show_toast("配方已修正")

func _recipes_deep_eq(a: Dictionary, b: Dictionary) -> bool:
	return JSON.new().stringify(a) == JSON.new().stringify(b)

func _on_save() -> void:
	var r = _build_recipe_from_ui()
	if r.is_empty():
		_show_toast("ID 不能为空")
		return

	if _selected_index >= 0:
		_recipes[_selected_index] = r

	if DATA.save_recipe(r):
		_dirty = false
		_show_toast("已保存: " + r.get("chs_name", r.get("name", "")))
		_refresh_list()
	else:
		_show_toast("保存失败!")

func _on_new() -> void:
	var existing_ids = []
	for r in _recipes:
		if r.has("id"):
			existing_ids.append(r["id"])
	var new_r = GENERATOR.generate_recipe("common", existing_ids)
	_recipes.append(new_r)
	_select_recipe(_recipes.size() - 1)
	_refresh_list()

func _on_generate() -> void:
	var existing_ids = []
	for r in _recipes:
		if r.has("id"):
			existing_ids.append(r["id"])
	var qualities = ["common", "uncommon", "rare", "epic"]
	var q = qualities[randi() % qualities.size()]
	var new_r = GENERATOR.generate_recipe(q, existing_ids)
	_recipes.append(new_r)
	_select_recipe(_recipes.size() - 1)
	_refresh_list()
	_show_toast("已生成: " + str(new_r.get("chs_name", "")))

func _on_cleanup() -> void:
	var confirm = ColorRect.new()
	confirm.color = Color(0, 0, 0, 0.6)
	confirm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirm.mouse_filter = MOUSE_FILTER_STOP
	add_child(confirm)

	var panel = ColorRect.new()
	panel.color = Color(0.1, 0.1, 0.15)
	panel.size = Vector2(320, 140)
	panel.position = Vector2(240, 220)
	confirm.add_child(panel)

	var lbl = Label.new()
	lbl.text = "确定要删除所有配方文件?"
	lbl.position = Vector2(30, 20)
	lbl.add_theme_font_size_override("font_size", 14)
	panel.add_child(lbl)

	var ok_btn = Button.new()
	ok_btn.text = "确认删除"
	ok_btn.position = Vector2(50, 80)
	ok_btn.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	ok_btn.pressed.connect(func():
		for r in _recipes:
			var rid = r.get("id", "")
			if rid != "": DATA.delete_recipe(rid)
		_recipes.clear()
		_refresh_list()
		_show_recipe(-1)
		confirm.queue_free()
		_show_toast("已清空所有配方")
	)
	panel.add_child(ok_btn)

	var cancel_btn = Button.new()
	cancel_btn.text = "取消"
	cancel_btn.position = Vector2(170, 80)
	cancel_btn.pressed.connect(confirm.queue_free)
	panel.add_child(cancel_btn)

func _show_toast(msg: String) -> void:
	var lbl = Label.new()
	lbl.text = msg
	lbl.position = Vector2(250, 80)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	add_child(lbl)
	var tween = create_tween()
	tween.tween_method(func(v): lbl.modulate.a = v, 1.0, 0.0, 2.0).set_delay(1.2)
	tween.tween_callback(lbl.queue_free)

func _on_back() -> void:
	if _dirty and _selected_index >= 0 and _selected_index < _recipes.size():
		_save_current_to_list()
	var ts = Control.new()
	ts.set_script(preload("res://src/main/title_screen.gd"))
	ts.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(ts)
	queue_free()
