extends Control

const DATA = preload("res://src/alchemy/alchemy_data.gd")
const EVAL = preload("res://src/alchemy/recipe_evaluator.gd")
const RECIPE_DATA = preload("res://src/alchemy/recipe_data.gd")
const ITEM_LOADER = preload("res://src/item_editor/item_data.gd")
const RARITY_NAMES = { "common": "普通", "uncommon": "优秀", "rare": "稀有", "epic": "史诗", "legendary": "传说" }
const RARITY_COLORS = { "common": Color(0.8,0.8,0.8), "uncommon": Color(0.3,0.8,0.3), "rare": Color(0.3,0.5,1.0), "epic": Color(0.8,0.3,1.0), "legendary": Color(1.0,0.6,0.0) }

var _recipes: Array = []
var _test_results: Dictionary = {}
var _all_materials: Array = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	_all_materials = EVAL.get_all_materials()
	_recipes = RECIPE_DATA.list_recipes()
	if _recipes.is_empty():
		for i in range(6):
			var existing_ids = []
			for r in _recipes:
				if r.has("id"): existing_ids.append(r["id"])
			var gen = preload("res://src/alchemy/recipe_generator.gd")
			var q = ["common", "uncommon", "rare"][i % 3]
			_recipes.append(gen.generate_recipe(q, existing_ids))
	_build_ui()
	_show_metrics()

func _build_ui() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.035, 0.04, 0.055)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bg)

	_build_header()
	_build_metrics_panel()
	_build_recipe_test_panel()

func _build_header() -> void:
	var hb = ColorRect.new()
	hb.color = Color(0.08, 0.08, 0.12)
	hb.size = Vector2(800, 42)
	add_child(hb)

	var title = Label.new()
	title.text = "炼药玩法测试"
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

	var reset_btn = Button.new()
	reset_btn.text = "重置统计"
	reset_btn.position = Vector2(160, 8)
	reset_btn.pressed.connect(func():
		_test_results.clear()
		_build_recipe_test_panel()
		_show_metrics()
		_show_toast("统计已重置")
	)
	add_child(reset_btn)

	var batch_btn = Button.new()
	batch_btn.text = "批量测试全部"
	batch_btn.position = Vector2(260, 8)
	batch_btn.pressed.connect(_on_batch_test)
	add_child(batch_btn)

func _build_metrics_panel() -> void:
	var panel = ColorRect.new()
	panel.color = Color(0.05, 0.055, 0.08)
	panel.position = Vector2(4, 46)
	panel.size = Vector2(200, 508)
	add_child(panel)

	var mt = Label.new()
	mt.text = "测 试 概 览"
	mt.position = Vector2(10, 50)
	mt.add_theme_font_size_override("font_size", 14)
	mt.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	add_child(mt)

	_metrics_labels = []
	var y = 76
	var metric_names = [
		"配方总数", "已测试", "通过", "失败",
		"通过率", "平均评分", "评价≥60", "评价<30"
	]
	for i in range(metric_names.size()):
		var nm = Label.new()
		nm.text = metric_names[i] + ":"
		nm.position = Vector2(10, y)
		nm.add_theme_font_size_override("font_size", 11)
		nm.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		add_child(nm)

		var vl = Label.new()
		vl.text = "0"
		vl.position = Vector2(120, y)
		vl.add_theme_font_size_override("font_size", 11)
		vl.name = "_m" + str(i)
		add_child(vl)
		_metrics_labels.append(vl)
		y += 22

var _metrics_labels: Array = []

func _show_metrics() -> void:
	if _metrics_labels.size() < 8:
		return

	_metrics_labels[0].text = str(_recipes.size())

	var tested = 0
	var passed = 0
	var failed = 0
	var total_score = 0
	var score_count = 0
	var score_ge_60 = 0
	var score_lt_30 = 0

	for rid in _test_results:
		var tr = _test_results[rid]
		tested += 1
		if tr.get("success", false):
			passed += 1
		else:
			failed += 1
		var s = tr.get("score", 0)
		total_score += s
		score_count += 1
		if s >= 60: score_ge_60 += 1
		if s < 30: score_lt_30 += 1

	_metrics_labels[1].text = str(tested)
	_metrics_labels[2].text = str(passed)
	_metrics_labels[3].text = str(failed)
	_metrics_labels[4].text = str(snapped(float(passed) / maxf(tested, 1) * 100, 1)) + "%"
	_metrics_labels[5].text = str(int(total_score / maxf(score_count, 1)))
	_metrics_labels[6].text = str(score_ge_60)
	_metrics_labels[7].text = str(score_lt_30)

	var color_map = [
		Color(0.6,0.6,0.6), Color(0.6,0.6,0.6), Color(0.3,1,0.3), Color(1,0.3,0.3),
		Color(0.3,1,0.3) if passed > 0 else Color(0.6,0.6,0.6),
		Color(0.3,1,0.3) if score_count > 0 and total_score/score_count >= 60 else Color(1,0.8,0.2),
		Color(0.3,1,0.3), Color(1,0.8,0.2)
	]
	for i in range(mini(_metrics_labels.size(), color_map.size())):
		_metrics_labels[i].add_theme_color_override("font_color", color_map[i])

func _build_recipe_test_panel() -> void:
	var existing = get_node_or_null("_test_scroll")
	if existing:
		existing.queue_free()

	var panel = ColorRect.new()
	panel.color = Color(0.05, 0.05, 0.075)
	panel.position = Vector2(208, 46)
	panel.size = Vector2(588, 508)
	add_child(panel)

	var title = Label.new()
	title.text = "配方测试列表"
	title.position = Vector2(214, 50)
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.5, 0.7, 0.9))
	add_child(title)
	title.name = "_test_title"

	var scroll = ScrollContainer.new()
	scroll.position = Vector2(208, 68)
	scroll.size = Vector2(588, 482)
	scroll.name = "_test_scroll"
	add_child(scroll)

	var container = VBoxContainer.new()
	container.size_flags_horizontal = SIZE_EXPAND_FILL
	container.add_theme_constant_override("separation", 2)
	scroll.add_child(container)

	var y = 0
	for r in _recipes:
		var rid = str(r.get("id", ""))
		var cn = r.get("chs_name", r.get("name", "?"))
		var rarity = r.get("rarity", "common")
		var rcol = RARITY_COLORS.get(rarity, Color(1,1,1))
		var rname = RARITY_NAMES.get(rarity, "")

		var eval_result = EVAL.evaluate(r)
		var score = eval_result.get("total_score", 0)
		var flags = eval_result.get("flags", [])

		var card = ColorRect.new()
		card.color = Color(0.07, 0.07, 0.1)
		card.custom_minimum_size = Vector2(570, 32)
		container.add_child(card)

		var nml = Label.new()
		nml.text = cn + " [" + rname + "]"
		nml.position = Vector2(4, 4)
		nml.add_theme_font_size_override("font_size", 12)
		nml.add_theme_color_override("font_color", rcol)
		card.add_child(nml)

		var tr = _test_results.get(rid, {})
		var test_status = tr.get("success", null)
		var status_char = ""
		var status_color = Color(0.5, 0.5, 0.5)
		if test_status == true:
			status_char = "✓"
			status_color = Color(0.3, 1, 0.3)
		elif test_status == false:
			status_char = "✗"
			status_color = Color(1, 0.3, 0.3)

		var sl = Label.new()
		sl.text = status_char + " 评分:" + str(score)
		sl.position = Vector2(260, 4)
		sl.add_theme_font_size_override("font_size", 11)
		sl.add_theme_color_override("font_color", status_color)
		card.add_child(sl)

		var fl = ""
		for f in flags:
			fl += "[" + f + "] "
		if fl != "":
			var fll = Label.new()
			fll.text = fl
			fll.position = Vector2(380, 4)
			fll.add_theme_font_size_override("font_size", 10)
			fll.add_theme_color_override("font_color", Color(1, 0.6, 0) if "逆天" in fl else Color(1, 0.8, 0.2))
			card.add_child(fll)

		var test_btn = Button.new()
		test_btn.text = "测试"
		test_btn.position = Vector2(500, 2)
		test_btn.custom_minimum_size = Vector2(50, 26)
		test_btn.add_theme_font_size_override("font_size", 10)
		var rid_copy = rid
		test_btn.pressed.connect(func(): _test_recipe(rid_copy))
		card.add_child(test_btn)

		var eval_btn2 = Button.new()
		eval_btn2.text = "评估"
		eval_btn2.position = Vector2(500, 28)
		eval_btn2.custom_minimum_size = Vector2(50, 18)
		eval_btn2.add_theme_font_size_override("font_size", 8)
		var rid2 = rid
		eval_btn2.pressed.connect(func(): _show_eval_detail(rid2))
		card.add_child(eval_btn2)

		card.size = Vector2(570, 48)
		y += 50

func _test_recipe(recipe_id: String) -> void:
	var recipe = null
	for r in _recipes:
		if r.get("id", "") == recipe_id:
			recipe = r; break
	if recipe == null:
		return

	var eval_result = EVAL.evaluate(recipe)
	var score = eval_result.get("total_score", 0)

	var materials = _pick_materials_for_recipe(recipe)
	if materials.is_empty():
		_test_results[recipe_id] = { "success": false, "score": score, "reason": "无匹配材料" }
		_show_toast("无法找到匹配材料")
		return

	var grinds = {}
	var total_grind = 0
	for entry in materials:
		var d = entry.get("data", {})
		var did = d.get("id", "")
		var alch = d.get("alchemy", {})
		var max_g = alch.get("max_grind", 0)
		var target_g = 0
		var cond = recipe.get("condition", {})
		var g_range = cond.get("granularity", {})
		if g_range is Dictionary and g_range.has("max"):
			target_g = mini(int(g_range["max"]), max_g)
		grinds[did] = target_g
		total_grind += target_g

	var solvent_cond = recipe.get("condition", {}).get("solvent", { "water": { "min_amount": 0.1 } })
	var solvents_arr = []
	if solvent_cond is Dictionary:
		for sid in solvent_cond:
			var req = solvent_cond[sid]
			var amt = req.get("min_amount", 0.3) if req is Dictionary else 0.3
			solvents_arr.append({ "id": sid, "amount": amt })
	elif solvent_cond is String:
		solvents_arr.append({ "id": solvent_cond, "amount": 1.0 })
	var brew_result = DATA.brew(materials, solvents_arr, grinds, _recipes, 5)

	var success = brew_result.get("success", false)
	var reason = ""
	if not success:
		var severity = brew_result.get("fail_severity", 1)
		var near = brew_result.get("near_match", "")
		if near != "":
			reason = "接近匹配: " + str(near)
		else:
			reason = "参数不匹配"

	_test_results[recipe_id] = { "success": success, "score": score, "reason": reason }
	_build_recipe_test_panel()
	_show_metrics()

	var msg = str(recipe.get("chs_name", "")) + ": " + ("成功" if success else "失败")
	if reason != "":
		msg += " (" + reason + ")"
	_show_toast(msg)

func _pick_materials_for_recipe(recipe: Dictionary) -> Array:
	var cond = recipe.get("condition", {})
	var ce = cond.get("element", {})
	if ce.is_empty():
		return []

	var selected = []
	for ek in ce:
		var min_val = 0.0
		var ev = ce[ek]
		if ev is Dictionary: min_val = ev.get("min", 0)
		else: min_val = float(ev)

		var best_mat = null
		var best_val = 0.0
		for mat in _all_materials:
			var alch = mat.get("alchemy", {})
			var mat_elem = alch.get("element", {})
			var val = mat_elem.get(ek, 0.0)
			if val > best_val:
				best_val = val
				best_mat = mat

		if best_mat != null and best_val >= min_val * 0.5:
			var dup = false
			for s in selected:
				if s.get("data", {}).get("id", "") == best_mat.get("id", ""):
					dup = true; break
			if not dup:
				selected.append({ "data": best_mat, "count": 1 })

	return selected

func _show_eval_detail(recipe_id: String) -> void:
	var recipe = null
	for r in _recipes:
		if r.get("id", "") == recipe_id:
			recipe = r; break
	if recipe == null:
		return

	var result = EVAL.evaluate(recipe)

	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = MOUSE_FILTER_STOP
	overlay.name = "_eval_overlay"
	add_child(overlay)

	var panel = ColorRect.new()
	panel.color = Color(0.08, 0.08, 0.12)
	panel.size = Vector2(420, 360)
	panel.position = Vector2(190, 70)
	overlay.add_child(panel)

	var title = Label.new()
	title.text = recipe.get("chs_name", "") + " 评估详情"
	title.position = Vector2(20, 16)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", RARITY_COLORS.get(recipe.get("rarity", "common"), Color(1,1,1)))
	panel.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "关闭"
	close_btn.position = Vector2(340, 14)
	close_btn.pressed.connect(overlay.queue_free)
	panel.add_child(close_btn)

	var y = 50
	var total = result.get("total_score", 0)
	var color = Color(0.3, 1, 0.3) if total >= 60 else (Color(1, 0.8, 0.2) if total >= 30 else Color(1, 0.3, 0.3))

	var score_lbl = Label.new()
	score_lbl.text = "综合评分: " + str(total) + "/100"
	score_lbl.position = Vector2(20, y)
	score_lbl.add_theme_font_size_override("font_size", 14)
	score_lbl.add_theme_color_override("font_color", color)
	panel.add_child(score_lbl)
	y += 28

	var detail = result.get("detail", {})
	for dk in detail:
		var dv = detail[dk]
		var ds = dv.get("score", 0)
		var dw = dv.get("warning", "")
		var dcolor = Color(0.3, 1, 0.3) if ds >= 10 else (Color(1, 0.8, 0.2) if ds >= 5 else Color(1, 0.3, 0.3))
		var dl = Label.new()
		var dtext = dk + ": " + str(ds)
		if dw != "":
			dtext += "  ⚠" + dw
		dl.text = dtext
		dl.position = Vector2(20, y)
		dl.add_theme_font_size_override("font_size", 11)
		dl.add_theme_color_override("font_color", dcolor)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.size = Vector2(380, 40)
		panel.add_child(dl)
		y += 28

	var flags = result.get("flags", [])
	if flags.size() > 0:
		y += 4
		var fl = Label.new()
		fl.text = "标记: " + " ".join(flags)
		fl.position = Vector2(20, y)
		fl.add_theme_font_size_override("font_size", 12)
		fl.add_theme_color_override("font_color", Color(1, 0.6, 0))
		panel.add_child(fl)

func _on_batch_test() -> void:
	_show_toast("开始批量测试...")
	var pass_count = 0
	var fail_count = 0
	for r in _recipes:
		var rid = str(r.get("id", ""))
		_test_recipe(rid)
		var tr = _test_results.get(rid, {})
		if tr.get("success", false):
			pass_count += 1
		else:
			fail_count += 1
	_show_toast("批量完成: 通过 " + str(pass_count) + "/" + str(pass_count + fail_count))

func _show_toast(msg: String) -> void:
	var existing = get_node_or_null("_toast")
	if existing:
		existing.queue_free()
	var lbl = Label.new()
	lbl.name = "_toast"
	lbl.text = msg
	lbl.position = Vector2(280, 90)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	add_child(lbl)
	var tween = create_tween()
	tween.tween_method(func(v): lbl.modulate.a = v, 1.0, 0.0, 2.0).set_delay(1.5)
	tween.tween_callback(lbl.queue_free)

func _on_back() -> void:
	var ts = Control.new()
	ts.set_script(preload("res://src/main/title_screen.gd"))
	ts.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(ts)
	queue_free()
