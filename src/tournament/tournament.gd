extends Control

enum State { PREP, QUALIFY, BRACKET, BATTLE, SHOP, VICTORY }

const ROUND_NAMES = ["资格赛", "32强", "16强", "8强", "半决赛", "决赛"]
const MAX_PARTICIPANTS = 8
const STARTING_GOLD = 300
const SENZU_BEAN_COST = 150
const MAX_SENZU = 3
const TITLE = "天下第一武道会"

var _state: int = State.PREP

var _player_hp: int = 5
var _player_bomb: int = 3
var _player_power: int = 2
var _player_speed: float = 1.0
var _player_defense: int = 0
var _gold: int = STARTING_GOLD
var _senzu_beans: int = 0

var _bracket: Array = []          # bracket[round][slot] = {"player":bool, "name":String, "won":bool}
var _current_round: int = 0
var _total_rounds: int = 0
var _round_opponents: Array = []  # _round_opponents[round] = Dictionary of opponent data

var _all_monsters: Array = []
var _level = null
var _hero = null
var _battle_started: bool = false
var _battle_timer: float = 0.0

var _bomb_old: int = 0
var _skills_old: Array = [false, false, false, false, false, false, false]
var _font: Font

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	_font = ThemeDB.fallback_font
	_load_monsters()
	_show_prep()

func _load_monsters() -> void:
	var dir = DirAccess.open(G.GAME_ROOT + "npc/")
	if dir == null: return
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			var j = Utils.load_json(G.GAME_ROOT + "npc/" + fname)
			if j != null and j.has("id"):
				_all_monsters.append(j)
		fname = dir.get_next()
	dir.list_dir_end()

# ─── STATE TRANSITIONS ───────────────────────────────────

func _show_prep() -> void:
	_state = State.PREP
	_clear_all()
	_build_prep_ui()

func _start_qualify() -> void:
	_state = State.QUALIFY
	_clear_all()
	_init_bracket()
	_hero = _create_hero()
	_level = Level.new("Tournament", "tournament_qualify", _hero, 500)
	Game.me = _hero
	Game.current_level = null
	_spawn_qualify_npcs()
	_battle_started = false
	_battle_timer = 1.0

func _show_bracket() -> void:
	_state = State.BRACKET
	_clear_all()
	_build_bracket_ui()

func _start_battle() -> void:
	_state = State.BATTLE
	_clear_all()
	if _hero == null:
		_hero = _create_hero()
	_hero.state = _hero.NORMAL
	var opp = _current_opponent()
	if opp.is_empty():
		_show_victory()
		return
	_level = Level.new("Tournament", "tournament_battle", _hero, 500)
	Game.me = _hero
	Game.current_level = null
	var npc_name = str(opp.get("id", ""))
	if npc_name != "":
		var npc = Npc.new(npc_name, Vector2i(13, 6))
		_level.npcs.append(npc)
	_battle_started = false
	_battle_timer = 2.0

func _show_shop() -> void:
	_state = State.SHOP
	_clear_all()
	_build_shop_ui()

func _show_victory() -> void:
	_state = State.VICTORY
	_clear_all()
	_build_victory_ui()

# ─── BRACKET ─────────────────────────────────────────────

func _init_bracket() -> void:
	_total_rounds = int(log(MAX_PARTICIPANTS) / log(2))
	_bracket = []
	for r in range(_total_rounds):
		var slots = MAX_PARTICIPANTS / int(pow(2, r))
		var round_arr = []
		for m in range(slots):
			round_arr.append({ "player": false, "name": "???", "won": false })
		_bracket.append(round_arr)
		_bracket[r][0]["player"] = true
		_bracket[r][0]["name"] = "你"

	var pool = _all_monsters.duplicate()
	pool.shuffle()
	# Fill round 0 slot names from pool
	for i in range(1, _bracket[0].size()):
		var opp = pool[i % pool.size()].duplicate()
		_bracket[0][i]["name"] = opp.get("chs_name", opp.get("id", "?"))

	# Build one opponent per bracket round
	_round_opponents = []
	for r in range(_total_rounds):
		var opp = pool[r % pool.size()].duplicate()
		_apply_round_scaling(opp, r)
		_round_opponents.append(opp)

	_current_round = 0

func _apply_round_scaling(opp: Dictionary, seed_idx: int) -> void:
	var extra = (seed_idx + 1) * 30
	opp["blood"] = int(opp.get("blood", 50)) + extra
	opp["speed"] = float(opp.get("speed", 0.5)) + seed_idx * 0.08
	opp["contact"] = int(opp.get("contact", 10)) + extra / 3

func _current_opponent() -> Dictionary:
	if _current_round < _round_opponents.size():
		return _round_opponents[_current_round]
	return {}

func _advance_bracket() -> void:
	if _current_round >= _bracket.size():
		_show_victory()
		return
	_bracket[_current_round][0]["won"] = true
	if _current_round >= _total_rounds - 1:
		_show_victory()
		return
	_current_round += 1
	# Auto-complete previous round slots so bracket display looks right
	for i in range(_bracket[_current_round - 1].size()):
		if not _bracket[_current_round - 1][i].get("player", false):
			_bracket[_current_round - 1][i]["won"] = true
	# Set next round opponent name in bracket
	var opp = _current_opponent()
	if not opp.is_empty() and _bracket[_current_round].size() > 1:
		_bracket[_current_round][1]["name"] = opp.get("chs_name", opp.get("id", "?"))
	_show_shop()

# ─── QUALIFY ─────────────────────────────────────────────

func _spawn_qualify_npcs() -> void:
	if _level == null: return
	var pool = _all_monsters.duplicate()
	pool.shuffle()
	var count = mini(3, pool.size())
	for i in range(count):
		var sx = 5 + i * 4
		var sy = 6 + (i % 2) * 3
		var npc = Npc.new(str(pool[i].get("id", "")), Vector2i(sx, sy))
		_level.npcs.append(npc)

# ─── PREP UI ─────────────────────────────────────────────

func _build_prep_ui() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.035, 0.04, 0.055)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bg)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel = VBoxContainer.new()
	panel.custom_minimum_size = Vector2(380, 420)
	panel.add_theme_constant_override("separation", 10)
	center.add_child(panel)

	var title = Label.new()
	title.text = TITLE + " — 准备"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.3))
	panel.add_child(title)
	panel.add_child(_spacer(4))

	var gold_lbl = Label.new()
	gold_lbl.text = "金币: " + str(_gold)
	gold_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_lbl.add_theme_font_size_override("font_size", 16)
	gold_lbl.add_theme_color_override("font_color", Color(1, 0.84, 0))
	gold_lbl.name = "_gold_label"
	panel.add_child(gold_lbl)

	var stats = [
		{ "label": "生命 (HP)", "key": "hp", "min": 1, "max": 10, "cost": 50, "start": _player_hp },
		{ "label": "炸弹数", "key": "bomb", "min": 1, "max": 10, "cost": 40, "start": _player_bomb },
		{ "label": "威力", "key": "power", "min": 1, "max": 8, "cost": 60, "start": _player_power },
		{ "label": "速度", "key": "speed", "min": 0.5, "max": 3.0, "cost": 70, "start": _player_speed },
		{ "label": "防御", "key": "defense", "min": 0, "max": 5, "cost": 30, "start": _player_defense },
	]
	for s in stats:
		var row = HBoxContainer.new()
		row.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 8)
		var lbl = Label.new()
		lbl.text = s["label"]
		lbl.custom_minimum_size = Vector2(80, 30)
		lbl.add_theme_font_size_override("font_size", 14)
		row.add_child(lbl)
		var minus = Button.new()
		minus.text = "-"
		minus.custom_minimum_size = Vector2(30, 30)
		row.add_child(minus)
		var vl = Label.new()
		vl.text = str(s["start"])
		vl.custom_minimum_size = Vector2(40, 30)
		vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vl.add_theme_font_size_override("font_size", 14)
		vl.name = s["key"] + "_val"
		row.add_child(vl)
		var plus = Button.new()
		plus.text = "+"
		plus.custom_minimum_size = Vector2(30, 30)
		row.add_child(plus)
		var cost_lbl = Label.new()
		cost_lbl.text = "(" + str(s["cost"]) + "g)"
		cost_lbl.add_theme_font_size_override("font_size", 11)
		cost_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		row.add_child(cost_lbl)
		panel.add_child(row)
		var skey = s["key"]
		minus.pressed.connect(func(): _adjust_stat(skey, -1, s))
		plus.pressed.connect(func(): _adjust_stat(skey, 1, s))

	panel.add_child(_spacer(8))
	var start_btn = Button.new()
	start_btn.text = "开始武道会!"
	start_btn.custom_minimum_size = Vector2(280, 46)
	start_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	start_btn.add_theme_font_size_override("font_size", 20)
	start_btn.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	start_btn.pressed.connect(_start_qualify)
	panel.add_child(start_btn)
	var back_btn = Button.new()
	back_btn.text = "返回"
	back_btn.custom_minimum_size = Vector2(280, 36)
	back_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	back_btn.pressed.connect(_on_back)
	panel.add_child(back_btn)

func _adjust_stat(key: String, dir: int, s: Dictionary) -> void:
	var cost = s["cost"]
	match key:
		"hp":
			var new_val = _player_hp + dir
			if dir > 0 and _gold >= cost and new_val <= s["max"]:
				_player_hp = new_val; _gold -= cost
			elif dir < 0 and new_val >= s["min"]:
				_player_hp = new_val; _gold += cost
		"bomb":
			var new_val = _player_bomb + dir
			if dir > 0 and _gold >= cost and new_val <= s["max"]:
				_player_bomb = new_val; _gold -= cost
			elif dir < 0 and new_val >= s["min"]:
				_player_bomb = new_val; _gold += cost
		"power":
			var new_val = _player_power + dir
			if dir > 0 and _gold >= cost and new_val <= s["max"]:
				_player_power = new_val; _gold -= cost
			elif dir < 0 and new_val >= s["min"]:
				_player_power = new_val; _gold += cost
		"speed":
			var new_val = _player_speed + dir * 0.5
			if dir > 0 and _gold >= cost and new_val <= s["max"]:
				_player_speed = new_val; _gold -= cost
			elif dir < 0 and new_val >= s["min"]:
				_player_speed = new_val; _gold += cost
		"defense":
			var new_val = _player_defense + dir
			if dir > 0 and _gold >= cost and new_val <= s["max"]:
				_player_defense = new_val; _gold -= cost
			elif dir < 0 and new_val >= s["min"]:
				_player_defense = new_val; _gold += cost
	for c in get_children():
		if c is CenterContainer:
			var panel = c.get_child(0) if c.get_child_count() > 0 else null
			if panel:
				for cc in panel.get_children():
					if cc is Label and cc.name == "_gold_label":
						cc.text = "金币: " + str(_gold)
					if cc is HBoxContainer:
						for ccc in cc.get_children():
							if ccc is Label:
								match ccc.name:
									"hp_val": ccc.text = str(_player_hp)
									"bomb_val": ccc.text = str(_player_bomb)
									"power_val": ccc.text = str(_player_power)
									"speed_val": ccc.text = str(_player_speed)
									"defense_val": ccc.text = str(_player_defense)

# ─── BRACKET UI ──────────────────────────────────────────

func _build_bracket_ui() -> void:
	var rn = ROUND_NAMES[min(_current_round + 1, ROUND_NAMES.size() - 1)]
	var title = Label.new()
	title.text = TITLE + " — " + rn
	title.position = Vector2(160, 10)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1, 0.82, 0.3))
	add_child(title)

	var status = Label.new()
	status.text = ROUND_NAMES[min(_current_round + 1, ROUND_NAMES.size() - 1)] + " — 准备战斗"
	status.position = Vector2(160, 40)
	status.add_theme_font_size_override("font_size", 12)
	status.add_theme_color_override("font_color", Color(0.6, 0.8, 1))
	add_child(status)

	var next_btn = Button.new()
	next_btn.text = "进入战斗!"
	next_btn.position = Vector2(340, 530)
	next_btn.custom_minimum_size = Vector2(120, 36)
	next_btn.add_theme_font_size_override("font_size", 16)
	next_btn.pressed.connect(_start_battle)
	add_child(next_btn)

	var back_btn = Button.new()
	back_btn.text = "← 返回主菜单"
	back_btn.position = Vector2(10, 10)
	back_btn.pressed.connect(_on_back)
	add_child(back_btn)

	var opp = _current_opponent()
	if not opp.is_empty():
		var opp_name = opp.get("chs_name", opp.get("id", "?"))
		var opp_hp = opp.get("blood", 0)
		var info = Label.new()
		info.text = "本场对手: " + opp_name + " | HP: " + str(opp_hp)
		info.position = Vector2(160, 60)
		info.add_theme_font_size_override("font_size", 13)
		info.add_theme_color_override("font_color", Color(0.8, 0.6, 0.6))
		add_child(info)

	var tip = Label.new()
	tip.text = "按 Enter/空格 快速进入战斗"
	tip.position = Vector2(340, 565)
	tip.add_theme_font_size_override("font_size", 10)
	tip.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	add_child(tip)

func _draw_bracket() -> void:
	if _state != State.BRACKET: return
	if _bracket.size() == 0: return
	var ox = 40
	var oy = 90
	var slot_h = 24
	var round_w = 160
	var avail_h = 450.0
	for r in range(_bracket.size()):
		var slots = _bracket[r].size()
		var x = ox + r * round_w
		var spacing = avail_h / slots
		var base_y = oy + spacing / 2 - slot_h / 2
		for s in range(slots):
			var y = base_y + s * spacing
			var entry = _bracket[r][s]
			var is_player = entry.get("player", false)
			var name = entry.get("name", "???")
			var won = entry.get("won", false)
			var is_current = (r == _current_round and is_player)
			var rect_color = Color(0.15, 0.15, 0.2)
			if is_player: rect_color = Color(0.15, 0.3, 0.4)
			if is_current: rect_color = Color(0.3, 0.5, 0.2)
			if won: rect_color = Color(0.2, 0.35, 0.2)
			draw_rect(Rect2(x, y, 140, slot_h), rect_color)
			draw_rect(Rect2(x, y, 140, slot_h), Color(0.3, 0.3, 0.4, 0.5), false, 1)
			var name_color = Color(1, 0.85, 0.3) if is_player else Color(0.8, 0.8, 0.8)
			if won: name_color = Color(0.3, 1, 0.3)
			if _font:
				draw_string(_font, Vector2(x + 6, y + 16), name, HORIZONTAL_ALIGNMENT_LEFT, 130, 11, name_color)
			if won and _font:
				draw_string(_font, Vector2(x + 122, y + 16), "✓", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.3, 1, 0.3))
			if r < _bracket.size() - 1:
				var next_slots = _bracket[r + 1].size()
				var next_spacing = avail_h / next_slots
				var next_base_y = oy + next_spacing / 2 - slot_h / 2
				var next_s = s / 2
				if next_s < next_slots:
					var next_y = next_base_y + next_s * next_spacing
					var mid_x = x + 140
					var mid_y = y + slot_h / 2
					var next_mid_y = next_y + slot_h / 2
					draw_line(Vector2(mid_x, mid_y), Vector2(mid_x + 10, mid_y), Color(0.4, 0.4, 0.5), 1.5)
					draw_line(Vector2(mid_x + 10, mid_y), Vector2(mid_x + 10, next_mid_y), Color(0.4, 0.4, 0.5), 1.5)
					draw_line(Vector2(mid_x + 10, next_mid_y), Vector2(x + round_w, next_mid_y), Color(0.4, 0.4, 0.5), 1.5)

# ─── SHOP UI ─────────────────────────────────────────────

func _build_shop_ui() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.035, 0.04, 0.055, 0.95)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel = VBoxContainer.new()
	panel.custom_minimum_size = Vector2(360, 320)
	panel.add_theme_constant_override("separation", 12)
	center.add_child(panel)

	var title = Label.new()
	title.text = "场间商店"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1, 0.82, 0.3))
	panel.add_child(title)
	var gold_lbl = Label.new()
	gold_lbl.text = "当前金币: " + str(_gold)
	gold_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_lbl.add_theme_font_size_override("font_size", 16)
	gold_lbl.add_theme_color_override("font_color", Color(1, 0.84, 0))
	panel.add_child(gold_lbl)
	var senzu_lbl = Label.new()
	senzu_lbl.text = "仙豆: " + str(_senzu_beans) + "/" + str(MAX_SENZU)
	senzu_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	senzu_lbl.add_theme_font_size_override("font_size", 14)
	panel.add_child(senzu_lbl)
	var desc = Label.new()
	desc.text = "仙豆可以在濒死时恢复1格生命"
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	panel.add_child(desc)
	var buy_btn = Button.new()
	buy_btn.text = "购买仙豆 (%d金币)" % SENZU_BEAN_COST
	buy_btn.custom_minimum_size = Vector2(240, 40)
	buy_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	buy_btn.pressed.connect(func():
		if _gold >= SENZU_BEAN_COST and _senzu_beans < MAX_SENZU:
			_gold -= SENZU_BEAN_COST
			_senzu_beans += 1
			senzu_lbl.text = "仙豆: " + str(_senzu_beans) + "/" + str(MAX_SENZU)
			gold_lbl.text = "当前金币: " + str(_gold))
	panel.add_child(buy_btn)
	var hp_btn = Button.new()
	hp_btn.text = "恢复1格生命 (80金币)"
	hp_btn.custom_minimum_size = Vector2(240, 40)
	hp_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	hp_btn.pressed.connect(func():
		if _gold >= 80 and _hero != null and _hero.remain_blood < _player_hp:
			_gold -= 80
			_hero.remain_blood = mini(_hero.remain_blood + 1, _player_hp)
			gold_lbl.text = "当前金币: " + str(_gold))
	panel.add_child(hp_btn)
	panel.add_child(_spacer(8))
	var next_btn = Button.new()
	var rn = ROUND_NAMES[min(_current_round + 1, ROUND_NAMES.size() - 1)]
	next_btn.text = "继续 → " + rn
	next_btn.custom_minimum_size = Vector2(240, 44)
	next_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	next_btn.add_theme_font_size_override("font_size", 18)
	next_btn.pressed.connect(_show_bracket)
	panel.add_child(next_btn)

# ─── VICTORY UI ──────────────────────────────────────────

func _build_victory_ui() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.04, 0.95)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel = VBoxContainer.new()
	panel.custom_minimum_size = Vector2(400, 300)
	panel.add_theme_constant_override("separation", 14)
	center.add_child(panel)

	var title = Label.new()
	title.text = "冠军!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1, 0.82, 0.0))
	panel.add_child(title)
	var sub = Label.new()
	sub.text = "恭喜在" + TITLE + "中获得优胜!"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(0.8, 0.9, 1))
	panel.add_child(sub)
	var reward = Label.new()
	reward.text = "剩余金币: " + str(_gold) + " | 仙豆: " + str(_senzu_beans)
	reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward.add_theme_font_size_override("font_size", 14)
	reward.add_theme_color_override("font_color", Color(1, 0.84, 0))
	panel.add_child(reward)
	var again_btn = Button.new()
	again_btn.text = "再来一次"
	again_btn.custom_minimum_size = Vector2(280, 44)
	again_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	again_btn.pressed.connect(_show_prep)
	panel.add_child(again_btn)
	var back_btn = Button.new()
	back_btn.text = "返回主菜单"
	back_btn.custom_minimum_size = Vector2(280, 36)
	back_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	back_btn.pressed.connect(_on_back)
	panel.add_child(back_btn)

# ─── COMBAT ──────────────────────────────────────────────

func _create_hero() -> Hero:
	var hero_name = Game.cfg_json.get("your_hero", "hero1")
	var hero = Hero.new(hero_name, Vector2i(1, 1), C.CHARACTER_RED)
	hero.blood = _player_hp
	hero.remain_blood = _player_hp
	hero.bomb = _player_bomb
	hero.remain_bombs = _player_bomb
	hero.power = _player_power
	hero.speed = _player_speed * G.GAME_SQUARE / 1000.0
	hero.base_speed = hero.speed
	hero.defense = _player_defense
	hero.base_defense = _player_defense
	hero.gold = _gold
	return hero

func _check_qualify_end() -> void:
	if _level == null or _hero == null: return
	if _hero.state == _hero.LOSE:
		if _senzu_beans > 0:
			_senzu_beans -= 1
			_hero.remain_blood = 1
			_hero.state = _hero.NORMAL
			_show_toast("仙豆发动! 恢复1格生命")
			return
		_show_toast("资格赛失败...")
		await get_tree().create_timer(1.5).timeout
		_on_back()

func _check_battle_end() -> void:
	if _level == null or _hero == null: return
	if _hero.state == _hero.LOSE:
		if _senzu_beans > 0:
			_senzu_beans -= 1
			_hero.remain_blood = 1
			_hero.state = _hero.NORMAL
			_show_toast("仙豆发动! 恢复1格生命")
			return
		_show_toast("战败... 武道会到此结束")
		await get_tree().create_timer(1.5).timeout
		_on_back()
	elif _level.npcs.size() > 0 and _all_dead(_level.npcs):
		_gold += 30 * (_current_round + 1)
		_advance_bracket()

func _all_dead(npcs: Array) -> bool:
	for n in npcs:
		if n.remain_blood > 0: return false
	return true

func _process(delta: float) -> void:
	match _state:
		State.QUALIFY, State.BATTLE:
			_process_battle(delta)
		State.BRACKET:
			queue_redraw()

func _process_battle(delta: float) -> void:
	if _level == null or _hero == null: return
	if _battle_timer > 0:
		_battle_timer -= delta
		queue_redraw()
		return
	if not _battle_started:
		_battle_started = true
		queue_redraw()
	if _hero.state == _hero.NORMAL:
		if Input.is_key_pressed(KEY_SPACE):
			if _bomb_old == 0: _hero.set_bomb()
			_bomb_old += 1
		else:
			_bomb_old = 0
		var key_map = { KEY_RIGHT: "R", KEY_UP: "U", KEY_LEFT: "L", KEY_DOWN: "D" }
		var found = false
		for k in key_map.keys():
			if Input.is_key_pressed(k):
				_hero.set_motion(key_map[k]); found = true; break
		if not found: _hero.set_motion("")
		for i in range(7):
			var kc = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7][i]
			if Input.is_key_pressed(kc):
				if not _skills_old[i]: _hero.dev_use_skill(i)
				_skills_old[i] = true
			else:
				_skills_old[i] = false
	_level.update()
	queue_redraw()
	if _state == State.QUALIFY:
		_check_qualify_end()
	else:
		_check_battle_end()

func _draw() -> void:
	match _state:
		State.QUALIFY, State.BATTLE:
			if _level != null:
				_level.draw_world(self)
			if _battle_timer > 0 and _font:
				var ct = ceili(_battle_timer)
				draw_string(_font, Vector2(380, 280), str(ct), HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(0, 1, 0, 0.8))
			if _state == State.QUALIFY and _level and _battle_started and _font:
				if _level.npcs.size() > 0 and _all_dead(_level.npcs):
					draw_string(_font, Vector2(280, 260), "资格赛通过! 按 Tab 继续", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.3, 1, 0.3))
		State.BRACKET:
			_draw_bracket()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match _state:
			State.QUALIFY:
				if event.keycode == KEY_TAB and _level and _level.npcs.size() > 0 and _all_dead(_level.npcs):
					_show_bracket()
			State.BRACKET:
				if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
					_start_battle()

func _clear_all() -> void:
	for c in get_children():
		c.queue_free()

func _spacer(h: float) -> Control:
	var s = Control.new()
	s.custom_minimum_size.y = h
	return s

func _show_toast(msg: String) -> void:
	var lbl = Label.new()
	lbl.text = msg
	lbl.position = Vector2(300, 280)
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	add_child(lbl)
	var tween = create_tween()
	tween.tween_method(func(v): lbl.modulate.a = v, 1.0, 0.0, 2.0).set_delay(1.5)
	tween.tween_callback(lbl.queue_free)

func _on_back() -> void:
	Game.me = null
	Game.current_level = null
	var ts = Control.new()
	ts.set_script(preload("res://src/main/title_screen.gd"))
	ts.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(ts)
	queue_free()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if Game.me == _hero: Game.me = null
		if Game.current_level == _level: Game.current_level = null
