extends Control

const ITEM_LOADER = preload("res://src/item_editor/item_data.gd")
const MAP_GENERATOR = preload("res://src/game/level/map_generator.gd")

var _level = null
var _hero = null
var _config_open: bool = true
var _paused: bool = true
var _active_npcs: Array = []
var _all_monsters: Array = []

# hero config
var _hp_sb: SpinBox
var _bomb_sb: SpinBox
var _power_sb: SpinBox
var _speed_sb: SpinBox
var _defense_sb: SpinBox

# spawn UI
var _monster_option: OptionButton
var _spawn_count_sb: SpinBox
var _spawn_x_sb: SpinBox
var _spawn_y_sb: SpinBox

# item UI
var _item_option: OptionButton
var _potion_option: OptionButton

# random map UI
var _map_width_sb: SpinBox
var _map_height_sb: SpinBox
var _map_seed_sb: SpinBox
var _map_density_sb: SpinBox
var _map_floor_opt: OptionButton
var _map_wall_opt: OptionButton
var _map_breakable_opt: OptionButton
var _pool_monster_opt: OptionButton
var _pool_count_sb: SpinBox
var _pool_list: VBoxContainer
var _monster_pool: Array = []           # [{id, chs_name, max}]
var _available_floors: Array = []
var _available_walls: Array = []
var _available_breakables: Array = []

# input state
var _bomb_old: int = 0
var _skills_old: Array = [false, false, false, false, false, false, false]
var _last_back: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	_load_monsters()
	_load_map_resources()
	_init_sandbox()
	_build_config_ui()

func _load_monsters() -> void:
	_all_monsters = _load_npc_list()
	_all_materials = ITEM_LOADER.list_items()

func _load_npc_list() -> Array:
	var dir = DirAccess.open(G.GAME_ROOT + "npc/")
	if dir == null: return []
	var result = []
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			var j = Utils.load_json(G.GAME_ROOT + "npc/" + fname)
			if j != null and (j.has("name") or j.has("id")):
				j["id"] = fname.trim_suffix(".json")
				result.append(j)
		fname = dir.get_next()
	dir.list_dir_end()
	result.sort_custom(func(a, b): return str(a.get("id", "")) < str(b.get("id", "")))
	return result

func _load_map_resources() -> void:
	_available_floors = _discover_floors()
	var obstacles = _discover_obstacles()
	_available_walls = obstacles["walls"]
	_available_breakables = obstacles["breakables"]

func _discover_floors() -> Array:
	var result: Array = []
	var dir = DirAccess.open(G.RES_IMG_ROOT + "mapElem/exploration/")
	if dir == null:
		return ["elem220"]
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with(".png") and not fname.ends_with(".import"):
			var base = fname.trim_suffix(".png")
			if not base.contains("_stand") and not base.contains("_die") and not base.contains("_trigger") and not result.has(base):
				result.append(base)
		fname = dir.get_next()
	dir.list_dir_end()
	result.sort()
	if result.is_empty():
		result = ["elem220"]
	return result

func _discover_obstacles() -> Dictionary:
	var walls: Array = []
	var breakables: Array = []
	var dir = DirAccess.open(G.FRAME_ROOT + "obstacle/exploration/")
	if dir == null:
		return {"walls": ["elem212"], "breakables": ["elem225", "elem226", "elem227"]}
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			var name = fname.trim_suffix(".json")
			var j = Utils.load_json(G.FRAME_ROOT + "obstacle/exploration/" + fname)
			if j != null:
				if bool(j.get("BREAKABLE", false)):
					breakables.append(name)
				else:
					walls.append(name)
		fname = dir.get_next()
	dir.list_dir_end()
	walls.sort()
	breakables.sort()
	if walls.is_empty():
		walls = ["elem212"]
	if breakables.is_empty():
		breakables = ["elem225", "elem226", "elem227"]
	return {"walls": walls, "breakables": breakables}

func _init_sandbox() -> void:
	var hero_name = Game.cfg_json.get("your_hero", "hero1")
	var color = C.CHARACTER_RED
	_hero = Hero.new(hero_name, Vector2i(1, 1), color)
	_hero.gold = 0
	_level = Level.new("Sandbox", "sandbox_arena", _hero, 500)
	Game.me = _hero
	Game.current_level = _level
	Game.sandbox_mode = true
	_paused = true
	_config_open = true
	_update_hero_stat_ui()
	_active_npcs = []

var _all_materials: Array = []

func _build_config_ui() -> void:
	var panel = ColorRect.new()
	panel.color = Color(0.06, 0.06, 0.10, 0.92)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = MOUSE_FILTER_STOP
	panel.name = "_config_panel"
	add_child(panel)

	var title = Label.new()
	title.text = "⚙ 战斗沙盒配置  [Tab: 切换]"
	title.position = Vector2(12, 6)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	panel.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "关闭配置 (Tab)"
	close_btn.position = Vector2(640, 6)
	close_btn.custom_minimum_size = Vector2(120, 28)
	close_btn.pressed.connect(_toggle_config)
	panel.add_child(close_btn)

	var back_btn = Button.new()
	back_btn.text = "← 返回"
	back_btn.position = Vector2(740, 6)
	back_btn.pressed.connect(_on_back)
	panel.add_child(back_btn)

	var y = 42
	_build_hero_section(panel, y)
	y += 38
	_build_spawn_section(panel, y)
	y += 100
	_build_item_section(panel, y)
	y += 80
	_build_action_buttons(panel, y)
	y += 80
	_build_status_display(panel, y)
	_build_random_map_section(panel, y + 34)

func _build_hero_section(panel: Control, y: int) -> void:
	var sep = ColorRect.new()
	sep.color = Color(0.2, 0.2, 0.3, 0.5)
	sep.position = Vector2(8, y)
	sep.size = Vector2(784, 1)
	panel.add_child(sep)
	y += 4

	var hl = Label.new()
	hl.text = "英雄属性"
	hl.position = Vector2(12, y)
	hl.add_theme_font_size_override("font_size", 13)
	hl.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	panel.add_child(hl)

	var x = 100
	var fields = [
		{ "label": "HP:", "min": 1, "max": 9999, "step": 1, "default": 100, "ref": "_hp_sb" },
		{ "label": "炸弹:", "min": 1, "max": 20, "step": 1, "default": 5, "ref": "_bomb_sb" },
		{ "label": "威力:", "min": 1, "max": 20, "step": 1, "default": 3, "ref": "_power_sb" },
		{ "label": "速度:", "min": 0.1, "max": 5.0, "step": 0.1, "default": 1.0, "ref": "_speed_sb" },
		{ "label": "防御:", "min": 0, "max": 100, "step": 1, "default": 0, "ref": "_defense_sb" }
	]
	for f in fields:
		var lbl = Label.new()
		lbl.text = f["label"]
		lbl.position = Vector2(x, y)
		lbl.add_theme_font_size_override("font_size", 11)
		panel.add_child(lbl)
		var sb = SpinBox.new()
		sb.min_value = f["min"]
		sb.max_value = f["max"]
		sb.step = f["step"]
		sb.value = f["default"]
		sb.position = Vector2(x + 40, y - 2)
		sb.custom_minimum_size = Vector2(60, 22)
		sb.add_theme_font_size_override("font_size", 10)
		panel.add_child(sb)
		set(f["ref"], sb)
		x += 120

	var apply_btn = Button.new()
	apply_btn.text = "应用属性"
	apply_btn.position = Vector2(x + 10, y - 2)
	apply_btn.custom_minimum_size = Vector2(80, 24)
	apply_btn.add_theme_font_size_override("font_size", 11)
	apply_btn.pressed.connect(_apply_hero_stats)
	panel.add_child(apply_btn)

func _build_spawn_section(panel: Control, y: int) -> void:
	var sep = ColorRect.new()
	sep.color = Color(0.2, 0.2, 0.3, 0.5)
	sep.position = Vector2(8, y)
	sep.size = Vector2(784, 1)
	panel.add_child(sep)
	y += 4

	var sl = Label.new()
	sl.text = "刷怪"
	sl.position = Vector2(12, y)
	sl.add_theme_font_size_override("font_size", 13)
	sl.add_theme_color_override("font_color", Color(0.9, 0.6, 0.6))
	panel.add_child(sl)

	var ml = Label.new()
	ml.text = "怪物:"
	ml.position = Vector2(80, y)
	ml.add_theme_font_size_override("font_size", 11)
	panel.add_child(ml)

	_monster_option = OptionButton.new()
	_monster_option.position = Vector2(120, y - 2)
	_monster_option.custom_minimum_size = Vector2(140, 22)
	for m in _all_monsters:
		_monster_option.add_item(m.get("chs_name", m.get("id", "?")), _all_monsters.find(m))
	panel.add_child(_monster_option)

	var nl = Label.new()
	nl.text = "数量:"
	nl.position = Vector2(280, y)
	nl.add_theme_font_size_override("font_size", 11)
	panel.add_child(nl)
	_spawn_count_sb = SpinBox.new()
	_spawn_count_sb.min_value = 1
	_spawn_count_sb.max_value = 20
	_spawn_count_sb.value = 1
	_spawn_count_sb.position = Vector2(320, y - 2)
	_spawn_count_sb.custom_minimum_size = Vector2(50, 22)
	panel.add_child(_spawn_count_sb)

	var xl = Label.new()
	xl.text = "x:"
	xl.position = Vector2(390, y)
	xl.add_theme_font_size_override("font_size", 11)
	panel.add_child(xl)
	_spawn_x_sb = SpinBox.new()
	_spawn_x_sb.min_value = 1
	_spawn_x_sb.max_value = 19
	_spawn_x_sb.value = 10
	_spawn_x_sb.position = Vector2(410, y - 2)
	_spawn_x_sb.custom_minimum_size = Vector2(50, 22)
	panel.add_child(_spawn_x_sb)

	var yl = Label.new()
	yl.text = "y:"
	yl.position = Vector2(470, y)
	yl.add_theme_font_size_override("font_size", 11)
	panel.add_child(yl)
	_spawn_y_sb = SpinBox.new()
	_spawn_y_sb.min_value = 1
	_spawn_y_sb.max_value = 13
	_spawn_y_sb.value = 7
	_spawn_y_sb.position = Vector2(490, y - 2)
	_spawn_y_sb.custom_minimum_size = Vector2(50, 22)
	panel.add_child(_spawn_y_sb)

	var spawn_btn = Button.new()
	spawn_btn.text = "放置"
	spawn_btn.position = Vector2(560, y - 2)
	spawn_btn.custom_minimum_size = Vector2(60, 24)
	spawn_btn.pressed.connect(_spawn_npcs)
	panel.add_child(spawn_btn)

	var clear_btn = Button.new()
	clear_btn.text = "清除敌人"
	clear_btn.position = Vector2(630, y - 2)
	clear_btn.custom_minimum_size = Vector2(80, 24)
	clear_btn.pressed.connect(_clear_npcs)
	panel.add_child(clear_btn)

func _build_item_section(panel: Control, y: int) -> void:
	var sep = ColorRect.new()
	sep.color = Color(0.2, 0.2, 0.3, 0.5)
	sep.position = Vector2(8, y)
	sep.size = Vector2(784, 1)
	panel.add_child(sep)
	y += 4

	var il = Label.new()
	il.text = "道具"
	il.position = Vector2(12, y)
	il.add_theme_font_size_override("font_size", 13)
	il.add_theme_color_override("font_color", Color(0.6, 0.6, 0.9))
	panel.add_child(il)

	_item_option = OptionButton.new()
	_item_option.position = Vector2(80, y - 2)
	_item_option.custom_minimum_size = Vector2(130, 22)
	for item in _all_materials:
		var cn = item.get("chs_name", item.get("name", "?"))
		_item_option.add_item(cn, _all_materials.find(item))
	panel.add_child(_item_option)

	var give_btn = Button.new()
	give_btn.text = "给予道具"
	give_btn.position = Vector2(220, y - 2)
	give_btn.custom_minimum_size = Vector2(80, 24)
	give_btn.pressed.connect(_give_item)
	panel.add_child(give_btn)

	var pl = Label.new()
	pl.text = "炼药成品:"
	pl.position = Vector2(330, y)
	pl.add_theme_font_size_override("font_size", 11)
	panel.add_child(pl)

	_potion_option = OptionButton.new()
	_potion_option.position = Vector2(400, y - 2)
	_potion_option.custom_minimum_size = Vector2(130, 22)
	var potion_ids = ["hp_potion_small", "phantom_cloak"]
	for pid in potion_ids:
		var item = ITEM_LOADER.load_item(pid)
		if not item.is_empty():
			_potion_option.add_item(item.get("chs_name", pid))
		else:
			_potion_option.add_item(pid)
	panel.add_child(_potion_option)

	var test_potion_btn = Button.new()
	test_potion_btn.text = "测试药水"
	test_potion_btn.position = Vector2(540, y - 2)
	test_potion_btn.custom_minimum_size = Vector2(80, 24)
	test_potion_btn.pressed.connect(_give_potion)
	panel.add_child(test_potion_btn)

func _build_action_buttons(panel: Control, y: int) -> void:
	var sep = ColorRect.new()
	sep.color = Color(0.2, 0.2, 0.3, 0.5)
	sep.position = Vector2(8, y)
	sep.size = Vector2(784, 1)
	panel.add_child(sep)
	y += 4

	var actions = [
		{ "text": "重置沙盒", "cb": "_reset_sandbox", "x": 12, "color": Color(1, 0.6, 0.3) },
		{ "text": "满炸弹", "cb": "_fill_bombs", "x": 100, "color": null },
		{ "text": "满血", "cb": "_fill_hp", "x": 180, "color": Color(0.3, 1, 0.3) },
		{ "text": "放置可炸方块", "cb": "_place_breakables", "x": 260, "color": null },
		{ "text": "清除方块", "cb": "_clear_breakables", "x": 370, "color": null },
		{ "text": "切换暂停", "cb": "_toggle_pause", "x": 470, "color": Color(0.6, 0.6, 1) },
	]
	for a in actions:
		var btn = Button.new()
		btn.text = a["text"]
		btn.position = Vector2(a["x"], y - 2)
		btn.custom_minimum_size = Vector2(80, 24)
		btn.add_theme_font_size_override("font_size", 10)
		if a["color"] != null:
			btn.add_theme_color_override("font_color", a["color"])
		btn.pressed.connect(Callable(self, a["cb"]))
		panel.add_child(btn)

func _build_status_display(panel: Control, y: int) -> void:
	var sep = ColorRect.new()
	sep.color = Color(0.2, 0.2, 0.3, 0.5)
	sep.position = Vector2(8, y)
	sep.size = Vector2(784, 1)
	panel.add_child(sep)
	y += 4

	var status_text = "状态: "
	if _level and _hero:
		status_text += "HP: %d/%d | 炸弹: %d/%d | 威力: %d | 速度: %.1f | 敌人: %d" % [
			_hero.remain_blood, _hero.blood,
			_hero.remain_bombs, _hero.bomb,
			_hero.power, _hero.speed * 1000.0 / G.GAME_SQUARE,
			_level.npcs.size()
		]
	var sl = Label.new()
	sl.text = status_text
	sl.position = Vector2(12, y)
	sl.add_theme_font_size_override("font_size", 11)
	sl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	panel.add_child(sl)

	var hint = Label.new()
	hint.text = "方向键移动 | Space放炸弹 | 1-7技能 | Tab配置 | Esc暂停"
	hint.position = Vector2(500, y)
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	panel.add_child(hint)

	# Update status periodically via a timer
	var timer = get_node_or_null("_status_timer")
	if timer == null:
		timer = Timer.new()
		timer.name = "_status_timer"
		timer.wait_time = 0.5
		timer.timeout.connect(func():
			_build_status_display(panel, y)
		)
		add_child(timer)
		timer.start()

func _build_random_map_section(panel: Control, y: int) -> void:
	var sep = ColorRect.new()
	sep.color = Color(0.2, 0.2, 0.3, 0.5)
	sep.position = Vector2(8, y)
	sep.size = Vector2(784, 1)
	panel.add_child(sep)

	var rl = Label.new()
	rl.text = "随机地图生成"
	rl.position = Vector2(12, y + 4)
	rl.add_theme_font_size_override("font_size", 13)
	rl.add_theme_color_override("font_color", Color(1.0, 0.7, 0.4))
	panel.add_child(rl)

	# row 1: size / seed / density
	_map_width_sb = _make_spinbox(panel, "宽", Vector2(12, y + 22), Vector2(40, y + 20), 5, 50, 1, 21)
	_map_height_sb = _make_spinbox(panel, "高", Vector2(92, y + 22), Vector2(120, y + 20), 5, 50, 1, 15)
	_map_seed_sb = _make_spinbox(panel, "种子(0=随机)", Vector2(170, y + 22), Vector2(258, y + 20), 0, 999999999, 1, 0)
	_map_density_sb = _make_spinbox(panel, "可炸密度", Vector2(344, y + 22), Vector2(406, y + 20), 0.0, 0.8, 0.05, 0.25)

	# row 2: floor / wall / breakable resources
	_make_label(panel, "地板", Vector2(12, y + 50))
	_map_floor_opt = OptionButton.new()
	_map_floor_opt.position = Vector2(48, y + 48)
	_map_floor_opt.custom_minimum_size = Vector2(84, 22)
	for f in _available_floors:
		_map_floor_opt.add_item(str(f))
	_select_option(_map_floor_opt, "elem220", _available_floors)
	panel.add_child(_map_floor_opt)

	_make_label(panel, "墙体", Vector2(140, y + 50))
	_map_wall_opt = OptionButton.new()
	_map_wall_opt.position = Vector2(176, y + 48)
	_map_wall_opt.custom_minimum_size = Vector2(84, 22)
	for w in _available_walls:
		_map_wall_opt.add_item(str(w))
	_select_option(_map_wall_opt, "elem212", _available_walls)
	panel.add_child(_map_wall_opt)

	_make_label(panel, "可破坏", Vector2(268, y + 50))
	_map_breakable_opt = OptionButton.new()
	_map_breakable_opt.position = Vector2(318, y + 48)
	_map_breakable_opt.custom_minimum_size = Vector2(150, 22)
	_map_breakable_opt.add_item("随机混合(225/226/227)")
	for b in _available_breakables:
		_map_breakable_opt.add_item(str(b))
	_map_breakable_opt.selected = 0
	panel.add_child(_map_breakable_opt)

	# row 3: monster pool controls
	_make_label(panel, "怪物池", Vector2(12, y + 78))
	_pool_monster_opt = OptionButton.new()
	_pool_monster_opt.position = Vector2(70, y + 76)
	_pool_monster_opt.custom_minimum_size = Vector2(170, 22)
	for m in _all_monsters:
		_pool_monster_opt.add_item(str(m.get("chs_name", m.get("id", "?"))))
	panel.add_child(_pool_monster_opt)

	_make_label(panel, "最大", Vector2(250, y + 78))
	_pool_count_sb = SpinBox.new()
	_pool_count_sb.min_value = 1
	_pool_count_sb.max_value = 50
	_pool_count_sb.value = 3
	_pool_count_sb.position = Vector2(282, y + 76)
	_pool_count_sb.custom_minimum_size = Vector2(48, 22)
	panel.add_child(_pool_count_sb)

	var add_btn = Button.new()
	add_btn.text = "加入"
	add_btn.position = Vector2(336, y + 76)
	add_btn.custom_minimum_size = Vector2(52, 24)
	add_btn.pressed.connect(_add_to_pool)
	panel.add_child(add_btn)

	var clear_btn = Button.new()
	clear_btn.text = "清空"
	clear_btn.position = Vector2(394, y + 76)
	clear_btn.custom_minimum_size = Vector2(52, 24)
	clear_btn.pressed.connect(_clear_pool)
	panel.add_child(clear_btn)

	# row 4: pool list
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(12, y + 104)
	scroll.size = Vector2(760, 60)
	panel.add_child(scroll)
	_pool_list = VBoxContainer.new()
	_pool_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pool_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_pool_list)
	_refresh_pool_list()

	# row 5: generate / reroll
	var gen_btn = Button.new()
	gen_btn.text = "生成随机地图"
	gen_btn.position = Vector2(12, y + 170)
	gen_btn.custom_minimum_size = Vector2(130, 26)
	gen_btn.add_theme_color_override("font_color", Color(1, 0.8, 0.4))
	gen_btn.pressed.connect(_generate_random_map)
	panel.add_child(gen_btn)

	var reroll_btn = Button.new()
	reroll_btn.text = "重掷种子"
	reroll_btn.position = Vector2(150, y + 170)
	reroll_btn.custom_minimum_size = Vector2(80, 26)
	reroll_btn.pressed.connect(_reroll_seed)
	panel.add_child(reroll_btn)

func _make_label(panel: Control, text: String, pos: Vector2) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.position = pos
	lbl.add_theme_font_size_override("font_size", 11)
	panel.add_child(lbl)

func _make_spinbox(panel: Control, label: String, label_pos: Vector2, sb_pos: Vector2, min_v: float, max_v: float, step: float, default_v: float) -> SpinBox:
	_make_label(panel, label, label_pos)
	var sb = SpinBox.new()
	sb.min_value = min_v
	sb.max_value = max_v
	sb.step = step
	sb.value = default_v
	sb.position = sb_pos
	sb.custom_minimum_size = Vector2(46, 22)
	sb.add_theme_font_size_override("font_size", 10)
	panel.add_child(sb)
	return sb

func _select_option(opt: OptionButton, name: String, list: Array) -> void:
	for i in range(list.size()):
		if str(list[i]) == name:
			opt.selected = i
			return
	opt.selected = 0

func _add_to_pool() -> void:
	var idx = _pool_monster_opt.selected
	if idx < 0 or idx >= _all_monsters.size():
		return
	var m = _all_monsters[idx]
	var id = str(m.get("id", ""))
	var max_count = int(_pool_count_sb.value)
	for spec in _monster_pool:
		if str(spec.get("id", "")) == id:
			spec["max"] = max_count
			_refresh_pool_list()
			return
	_monster_pool.append({"id": id, "chs_name": str(m.get("chs_name", id)), "max": max_count})
	_refresh_pool_list()

func _remove_from_pool(id: String) -> void:
	for i in range(_monster_pool.size() - 1, -1, -1):
		if str(_monster_pool[i].get("id", "")) == id:
			_monster_pool.remove_at(i)
	_refresh_pool_list()

func _clear_pool() -> void:
	_monster_pool.clear()
	_refresh_pool_list()

func _refresh_pool_list() -> void:
	if _pool_list == null:
		return
	for c in _pool_list.get_children():
		c.queue_free()
	for spec in _monster_pool:
		var row = HBoxContainer.new()
		var lbl = Label.new()
		lbl.text = "%s  x%d" % [str(spec.get("chs_name", spec.get("id", "?"))), int(spec.get("max", 0))]
		lbl.custom_minimum_size = Vector2(240, 18)
		lbl.add_theme_font_size_override("font_size", 11)
		row.add_child(lbl)
		var rm = Button.new()
		rm.text = "移除"
		rm.custom_minimum_size = Vector2(48, 18)
		var rid = str(spec.get("id", ""))
		rm.pressed.connect(func(): _remove_from_pool(rid))
		row.add_child(rm)
		_pool_list.add_child(row)

func _collect_generator_params() -> Dictionary:
	var width = clampi(int(_map_width_sb.value), 5, 50)
	var height = clampi(int(_map_height_sb.value), 5, 50)
	if width % 2 == 0:
		width += 1
	if height % 2 == 0:
		height += 1

	var seed_val = int(_map_seed_sb.value)
	if seed_val == 0:
		var rng = RandomNumberGenerator.new()
		rng.randomize()
		seed_val = rng.randi_range(1, 999999999)

	var floor_name = "elem220"
	if _map_floor_opt.selected >= 0 and _map_floor_opt.selected < _available_floors.size():
		floor_name = str(_available_floors[_map_floor_opt.selected])
	var wall_name = "elem212"
	if _map_wall_opt.selected >= 0 and _map_wall_opt.selected < _available_walls.size():
		wall_name = str(_available_walls[_map_wall_opt.selected])

	var interactive_pool: Array
	if _map_breakable_opt.selected <= 0:
		interactive_pool = ["elem225", "elem226", "elem227"]
	else:
		var bi = _map_breakable_opt.selected - 1
		interactive_pool = [str(_available_breakables[bi])] if bi < _available_breakables.size() else ["elem225"]

	var monster_pool: Array = []
	for spec in _monster_pool:
		monster_pool.append({"name": str(spec.get("id", "")), "max": int(spec.get("max", 0))})

	return {
		"width": width,
		"height": height,
		"seed": seed_val,
		"breakable_density": float(_map_density_sb.value),
		"floor_texture_pool": [floor_name],
		"obstacle_pool": [wall_name],
		"interactive_pool": interactive_pool,
		"monster_pool": monster_pool,
		"begin": [1, 1],
	}

func _reroll_seed() -> void:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	_map_seed_sb.value = rng.randi_range(1, 999999999)

func _generate_random_map() -> void:
	if _hero == null:
		return
	var params = _collect_generator_params()
	var generated = MAP_GENERATOR.generate(params)
	if generated.is_empty():
		_show_toast("地图生成失败")
		return
	_hero.state = _hero.NORMAL
	_level = Level.new("Sandbox", "sandbox_generated", _hero, 500, generated)
	Game.me = _hero
	Game.current_level = _level
	_active_npcs.clear()
	_show_toast("已生成 %dx%d 随机地图 (seed=%d)" % [int(params["width"]), int(params["height"]), int(params["seed"])])
	queue_redraw()

func _toggle_config() -> void:
	_config_open = not _config_open
	var panel = get_node_or_null("_config_panel")
	if panel:
		panel.visible = _config_open
	if not _config_open:
		_paused = false
		release_focus()

func _toggle_pause() -> void:
	_paused = not _paused

func _process(_delta: float) -> void:
	if _level == null:
		return

	if Input.is_key_pressed(KEY_TAB) and not _last_back:
		_toggle_config()
		_last_back = true
	elif not Input.is_key_pressed(KEY_TAB):
		_last_back = false

	if _paused or _config_open:
		queue_redraw()
		return

	_handle_game_input()
	_level.update()
	queue_redraw()

func _handle_game_input() -> void:
	if _hero == null or _hero.state != _hero.NORMAL:
		return
	if Input.is_key_pressed(KEY_SPACE):
		if _bomb_old == 0:
			_hero.set_bomb()
		_bomb_old += 1
	else:
		_bomb_old = 0

	var orient_keys = { KEY_RIGHT: "R", KEY_UP: "U", KEY_LEFT: "L", KEY_DOWN: "D" }
	var found = false
	for kc in orient_keys.keys():
		if Input.is_key_pressed(kc):
			_hero.set_motion(orient_keys[kc])
			found = true
			break
	if not found:
		_hero.set_motion("")

	for i in range(7):
		var kc = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7][i]
		if Input.is_key_pressed(kc):
			if not _skills_old[i]:
				if Game.dev_mode:
					_hero.dev_use_skill(i)
				else:
					_hero.use_skill(i)
			_skills_old[i] = true
		else:
			_skills_old[i] = false

func _draw() -> void:
	if _level != null and _level.has_method("draw_world"):
		_level.draw_world(self)
	# Draw a thin border around the config panel area when visible
	if _config_open:
		draw_rect(Rect2(0, 0, 800, 36), Color(0.1, 0.12, 0.16), true)
		draw_string(ThemeDB.fallback_font, Vector2(12, 28), "战斗沙盒 | Tab: 开关配置, Esc: 暂停/继续, 方向键: 移动, Space: 炸弹", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.5, 0.5, 0.5))

func _apply_hero_stats() -> void:
	if _hero == null: return
	_hero.blood = int(_hp_sb.value)
	_hero.remain_blood = min(_hero.remain_blood, _hero.blood)
	_hero.bomb = int(_bomb_sb.value)
	_hero.power = int(_power_sb.value)
	_hero.speed = float(_speed_sb.value) * G.GAME_SQUARE / 1000.0
	_hero.base_speed = _hero.speed
	_hero.defense = int(_defense_sb.value)
	_hero.base_defense = _hero.defense
	_hero.gold = 999
	_update_status_label()

func _update_hero_stat_ui() -> void:
	if _hero == null: return
	if _hp_sb: _hp_sb.value = _hero.blood
	if _bomb_sb: _bomb_sb.value = _hero.bomb
	if _power_sb: _power_sb.value = _hero.power
	if _speed_sb: _speed_sb.value = _hero.speed * 1000.0 / G.GAME_SQUARE
	if _defense_sb: _defense_sb.value = _hero.defense

func _spawn_npcs() -> void:
	if _level == null: return
	var idx = _monster_option.selected
	if idx < 0 or idx >= _all_monsters.size(): return
	var npc_data = _all_monsters[idx]
	var npc_name = str(npc_data.get("id", ""))
	var count = int(_spawn_count_sb.value)
	var base_x = int(_spawn_x_sb.value)
	var base_y = int(_spawn_y_sb.value)
	for i in range(count):
		var sx = clampi(base_x + (i % 5), 1, 19)
		var sy = clampi(base_y + (i / 5), 1, 13)
		var npc = Npc.new(npc_name, Vector2i(sx, sy))
		_level.npcs.append(npc)
		_active_npcs.append(npc)
	_update_status_label()

func _clear_npcs() -> void:
	if _level == null: return
	for n in _level.npcs.duplicate():
		n.remain_blood = 0
	_level.npcs.clear()
	_active_npcs.clear()
	_update_status_label()

func _give_item() -> void:
	if _hero == null: return
	var idx = _item_option.selected
	if idx < 0 or idx >= _all_materials.size(): return
	var item_data = _all_materials[idx]
	var item_id = str(item_data.get("id", ""))
	_hero.items[item_id] = _hero.items.get(item_id, 0) + 5
	_show_toast("给予 " + item_data.get("chs_name", item_id) + " x5")

func _give_potion() -> void:
	if _hero == null: return
	var potion_ids = ["hp_potion_small", "phantom_cloak"]
	var idx = _potion_option.selected
	if idx < 0 or idx >= potion_ids.size(): return
	var pid = potion_ids[idx]
	var item = ITEM_LOADER.load_item(pid)
	if item.is_empty():
		_show_toast("药水数据未找到")
		return
	var ei = item.get("effects", {})
	for ek in ei:
		_hero._apply_item_effect(item)
		_show_toast("使用 " + item.get("chs_name", pid) + ": " + str(ei))
		_update_status_label()
		return
	_show_toast("药水无效果")

func _fill_bombs() -> void:
	if _hero == null: return
	_hero.remain_bombs = _hero.bomb
	_update_status_label()

func _fill_hp() -> void:
	if _hero == null: return
	_hero.remain_blood = _hero.blood
	_hero.state = _hero.NORMAL
	_update_status_label()

func _place_breakables() -> void:
	if _level == null: return
	var obs = ObstacleLoader.get_obstacle("exploration", "elem213")
	if obs == null: return
	for x in range(2, 19, 2):
		for y in range(2, 13, 2):
			var key = Vector2i(x, y)
			if _level.obstacle_instances.has(key):
				continue
			ObstacleInstance.new(x, y, _level.obstacle_instances, obs)
	_level.obstacle_instances_need_to_update = true
	_show_toast("放置可炸方块")

func _clear_breakables() -> void:
	if _level == null: return
	for key in _level.obstacle_instances.keys():
		var oi = _level.obstacle_instances[key]
		if oi.obstacle.get("name", "") == "elem213":
			_level.obstacle_instances.erase(key)
	_level.obstacle_instances_need_to_update = true
	_show_toast("清除可炸方块")

func _reset_sandbox() -> void:
	if _level != null:
		_level.npcs.clear()
	_active_npcs.clear()
	_hero = null
	_level = null
	Game.me = null
	_init_sandbox()
	_show_toast("沙盒已重置")

func _update_status_label() -> void:
	var panel = get_node_or_null("_config_panel")
	if panel:
		for c in panel.get_children():
			if c is Label and c.position.y > 280 and c.position.y < 320:
				if _level and _hero:
					c.text = "状态: HP: %d/%d | 炸弹: %d/%d | 威力: %d | 速度: %.1f | 敌人: %d" % [
						_hero.remain_blood, _hero.blood,
						_hero.remain_bombs, _hero.bomb,
						_hero.power, _hero.speed * 1000.0 / G.GAME_SQUARE,
						_level.npcs.size()
					]

func _show_toast(msg: String) -> void:
	var existing = get_node_or_null("_toast")
	if existing: existing.queue_free()
	var lbl = Label.new()
	lbl.name = "_toast"
	lbl.text = msg
	lbl.position = Vector2(280, 40)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	add_child(lbl)
	var tween = create_tween()
	tween.tween_method(func(v): lbl.modulate.a = v, 1.0, 0.0, 2.0).set_delay(1.0)
	tween.tween_callback(lbl.queue_free)

func _on_back() -> void:
	Game.me = null
	Game.current_level = null
	Game.sandbox_mode = false
	_paused = true
	var ts = Control.new()
	ts.set_script(preload("res://src/main/title_screen.gd"))
	ts.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(ts)
	queue_free()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if Game.me == _hero:
			Game.me = null
		if Game.current_level == _level:
			Game.current_level = null
			Game.sandbox_mode = false
