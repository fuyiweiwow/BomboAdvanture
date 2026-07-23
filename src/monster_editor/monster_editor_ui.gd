class_name MonsterEditorUI
extends RefCounted

var _editor

const COLOR_COMPS = ["Body", "Foot", "Leg", "Cloth", "Face", "Hair", "Cap", "Ear", "Mouth", "Cladorn", "Fpack", "Npack", "Thadorn", "Fhadorn"]

func _init(editor):
	_editor = editor

func clear_container(c: Node) -> void:
	for ch in c.get_children():
		c.remove_child(ch)
		ch.queue_free()

func add_tab(name: String, tab_container: TabContainer) -> VBoxContainer:
	var sc = ScrollContainer.new()
	sc.name = name
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var vb = VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 6)
	sc.add_child(vb)
	tab_container.add_child(sc)
	return vb

func add_field(vb: VBoxContainer, label: String, input: Control, label_w: int = 120) -> void:
	var hb = HBoxContainer.new()
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lb = Label.new()
	lb.text = label + ":"
	lb.custom_minimum_size = Vector2(label_w, 24)
	lb.add_theme_font_size_override("font_size", 15)
	lb.add_theme_color_override("font_color", Color(0.85, 0.87, 0.9))
	hb.add_child(lb)
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(input)
	vb.add_child(hb)

func build_basic_tab(vb: VBoxContainer) -> void:
	clear_container(vb)
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 8)
	var inner = VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 4)

	var le_name = LineEdit.new()
	le_name.text = str(_editor._monster.get("name", ""))
	le_name.add_theme_font_size_override("font_size", 14)
	le_name.text_changed.connect(func(t): _editor._monster["name"] = t; _editor._dirty = true)
	add_field(inner, "Name", le_name, 110)

	var le_chs = LineEdit.new()
	le_chs.text = str(_editor._monster.get("chs_name", ""))
	le_chs.add_theme_font_size_override("font_size", 14)
	le_chs.text_changed.connect(func(t): _editor._monster["chs_name"] = t; _editor._dirty = true)
	add_field(inner, "Display Name", le_chs, 110)

	var fields = [
		["Blood", "blood", 0, 999999, 1],
		["Speed", "speed", 1, 999.999, 0.01],
		["Contact", "contact", 0, 999999, 1],
		["Defense", "defense", 0, 999999, 1],
		["Resent Dist", "resent_dist", 0, 999999, 1],
		["Self Dmg Blood", "self_damage_blood", 0, 999999, 1],
	]
	for f in fields:
		var sb = SpinBox.new()
		sb.min_value = 0
		sb.max_value = f[3]
		sb.step = f[4]
		sb.value = float(_editor._monster.get(f[1], 0))
		sb.add_theme_font_size_override("font_size", 14)
		if f[2] == 1:
			sb.value_changed.connect(_editor._on_float_changed.bind(f[1]))
		else:
			sb.value_changed.connect(_editor._on_int_changed.bind(f[1]))
		add_field(inner, f[0], sb, 110)

	var boss_hb = HBoxContainer.new()
	boss_hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var boss_lb = Label.new()
	boss_lb.text = "Boss Mode:"
	boss_lb.custom_minimum_size = Vector2(110, 24)
	boss_lb.add_theme_font_size_override("font_size", 15)
	boss_lb.add_theme_color_override("font_color", Color(0.85, 0.87, 0.9))
	boss_hb.add_child(boss_lb)
	var boss_cb = CheckBox.new()
	boss_cb.button_pressed = _editor._monster.get("boss_mode", false)
	boss_cb.toggled.connect(func(v): _editor._monster["boss_mode"] = v; _editor._dirty = true)
	boss_hb.add_child(boss_cb)
	inner.add_child(boss_hb)

	_editor._btn_bomb = Button.new()
	var current_bomb = _editor._monster.get("bomb_skin", null)
	_editor._btn_bomb.text = str(current_bomb) if current_bomb != null else "None"
	_editor._btn_bomb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_editor._btn_bomb.add_theme_font_size_override("font_size", 13)
	_editor._btn_bomb.pressed.connect(_editor._on_pick_bomb_skin)
	add_field(inner, "Bomb Skin", _editor._btn_bomb, 110)

	margin.add_child(inner)
	vb.add_child(margin)

func build_character_tab(vb: VBoxContainer) -> void:
	clear_container(vb)
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 8)
	var inner = VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 6)

	_editor._btn_char_frame = Button.new()
	var current = str(_editor._monster.get("character", "CharacterBlank"))
	_editor._btn_char_frame.text = current
	_editor._btn_char_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_editor._btn_char_frame.add_theme_font_size_override("font_size", 14)
	_editor._btn_char_frame.pressed.connect(_editor._on_pick_character)
	add_field(inner, "Character Frame", _editor._btn_char_frame)

	inner.add_child(HSeparator.new())

	var color_lb = Label.new()
	color_lb.text = "Component Colors"
	color_lb.add_theme_font_size_override("font_size", 13)
	color_lb.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	inner.add_child(color_lb)

	var existing_colors = _editor._monster.get("colors", {})
	for comp in COLOR_COMPS:
		var hb = HBoxContainer.new()
		hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var lb = Label.new()
		lb.text = comp
		lb.custom_minimum_size = Vector2(80, 22)
		lb.add_theme_font_size_override("font_size", 12)
		lb.add_theme_color_override("font_color", Color(0.75, 0.8, 0.85))
		hb.add_child(lb)

		var current_color = null
		if existing_colors.has(comp):
			var val = existing_colors[comp]
			if val is Array:
				current_color = Color(val[0], val[1], val[2], val[3]) if val.size() >= 4 else Color(val[0], val[1], val[2])

		var picker = ColorPickerButton.new()
		picker.color = current_color if current_color != null else Color.WHITE
		picker.custom_minimum_size = Vector2(28, 18)
		picker.color_changed.connect(_editor._on_color_changed.bind(comp, picker))
		hb.add_child(picker)

		var clear_btn = Button.new()
		clear_btn.text = "X"
		clear_btn.custom_minimum_size = Vector2(18, 18)
		clear_btn.add_theme_font_size_override("font_size", 9)
		clear_btn.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
		clear_btn.pressed.connect(_editor._on_color_clear.bind(comp, picker))
		hb.add_child(clear_btn)

		var st = Label.new()
		st.text = "custom" if current_color != null else "default"
		st.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4) if current_color != null else Color(0.5, 0.55, 0.6))
		st.add_theme_font_size_override("font_size", 9)
		hb.add_child(st)

		inner.add_child(hb)

	margin.add_child(inner)
	vb.add_child(margin)

func build_skills_tab(vb: VBoxContainer) -> void:
	clear_container(vb)
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	var inner = VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 4)

	var skills = _editor._monster.get("skills", [])
	for i in skills.size():
		var s = skills[i]
		var hb = HBoxContainer.new()
		hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var lb_s = Label.new()
		lb_s.text = "%d: %s" % [i + 1, str(s.get("name", ""))]
		lb_s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lb_s.add_theme_font_size_override("font_size", 14)
		lb_s.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
		hb.add_child(lb_s)
		var btn_edit = Button.new()
		btn_edit.text = "Edit"
		btn_edit.custom_minimum_size = Vector2(50, 24)
		btn_edit.add_theme_font_size_override("font_size", 13)
		btn_edit.pressed.connect(_editor._on_edit_skill.bind(i))
		hb.add_child(btn_edit)
		var btn_del = Button.new()
		btn_del.text = "X"
		btn_del.custom_minimum_size = Vector2(28, 24)
		btn_del.add_theme_font_size_override("font_size", 13)
		btn_del.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
		btn_del.pressed.connect(_editor._on_delete_skill.bind(i))
		hb.add_child(btn_del)
		inner.add_child(hb)

	inner.add_child(HSeparator.new())
	var btn_add = Button.new()
	btn_add.text = "+ Add Skill"
	btn_add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_add.add_theme_font_size_override("font_size", 14)
	btn_add.pressed.connect(_editor._on_add_skill)
	inner.add_child(btn_add)

	margin.add_child(inner)
	vb.add_child(margin)

func show_skill_dialog(title: String, defaults: Dictionary, on_confirm: Callable) -> void:
	var dlg = AcceptDialog.new()
	dlg.title = title
	dlg.dialog_text = ""
	var vb = VBoxContainer.new()
	vb.size = Vector2(300, 200)
	var fields = {}
	for pair in [["Name", "name"], ["Init (ms)", "init"], ["Interval (ms)", "interval"], ["Max Uses", "max"]]:
		var hb = HBoxContainer.new()
		var lb = Label.new()
		lb.text = pair[0] + ":"
		lb.size = Vector2(100, 24)
		hb.add_child(lb)
		var key = pair[1]
		if key == "name":
			var le = LineEdit.new()
			le.text = str(defaults.get(key, ""))
			le.size = Vector2(180, 24)
			hb.add_child(le)
			fields[key] = le
		else:
			var sb = SpinBox.new()
			sb.min_value = 0
			sb.max_value = 99999
			sb.step = 1
			sb.value = int(defaults.get(key, 0))
			sb.size = Vector2(180, 24)
			hb.add_child(sb)
			fields[key] = sb
		vb.add_child(hb)
	dlg.add_child(vb)
	dlg.confirmed.connect(func():
		var data = {"name": fields["name"].text, "init": int(fields["init"].value), "interval": int(fields["interval"].value), "max": int(fields["max"].value)}
		on_confirm.call(data))
	_editor._add_child(dlg)
	dlg.popup_centered()

func build_drops_tab(vb: VBoxContainer) -> void:
	clear_container(vb)
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	var inner = VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 6)

	var gifts_lb = Label.new()
	gifts_lb.text = "Drops / Gifts"
	gifts_lb.add_theme_font_size_override("font_size", 14)
	gifts_lb.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	inner.add_child(gifts_lb)

	var gifts = _editor._monster.get("gifts", [])
	if gifts is Array and gifts.size() > 0:
		for i in gifts.size():
			var g = gifts[i]
			var ghb = HBoxContainer.new()
			ghb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			ghb.custom_minimum_size = Vector2(0, 28)

			var item_id = str(g.get("id", ""))
			var item_name = item_id
			var all_items = ItemData.list_items()
			for ai in all_items:
				if str(ai.get("id", "")) == item_id:
					item_name = str(ai.get("name", item_id))
					break

			var gl = Label.new()
			var weight = int(g.get("weight", 10))
			var min_c = int(g.get("min", 1))
			var max_c = int(g.get("max", 1))
			var qty = "%d" % min_c if min_c == max_c else "%d-%d" % [min_c, max_c]
			gl.text = "%s  x%s  (weight: %d)" % [item_name, qty, weight]
			gl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			gl.add_theme_font_size_override("font_size", 13)
			gl.add_theme_color_override("font_color", Color(0.75, 0.8, 0.85))
			ghb.add_child(gl)

			var btn_edit = Button.new()
			btn_edit.text = "E"
			btn_edit.custom_minimum_size = Vector2(24, 24)
			btn_edit.add_theme_font_size_override("font_size", 11)
			btn_edit.pressed.connect(_editor._on_edit_gift.bind(i))
			ghb.add_child(btn_edit)

			var btn_del = Button.new()
			btn_del.text = "X"
			btn_del.custom_minimum_size = Vector2(24, 24)
			btn_del.add_theme_font_size_override("font_size", 11)
			btn_del.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
			btn_del.pressed.connect(_editor._on_delete_gift.bind(i))
			ghb.add_child(btn_del)

			inner.add_child(ghb)
	else:
		var empty_lb = Label.new()
		empty_lb.text = "No drops configured."
		empty_lb.add_theme_font_size_override("font_size", 12)
		empty_lb.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
		inner.add_child(empty_lb)

	inner.add_child(HSeparator.new())
	var btn_add = Button.new()
	btn_add.text = "+ Add Drop"
	btn_add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_add.add_theme_font_size_override("font_size", 14)
	btn_add.pressed.connect(_editor._on_add_gift)
	inner.add_child(btn_add)

	inner.add_child(HSeparator.new())

	var death_lb = Label.new()
	death_lb.text = "Death Event"
	death_lb.add_theme_font_size_override("font_size", 12)
	death_lb.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	inner.add_child(death_lb)

	var death_le = LineEdit.new()
	death_le.text = str(_editor._monster.get("death", ""))
	death_le.add_theme_font_size_override("font_size", 14)
	death_le.text_changed.connect(func(t): _editor._monster["death"] = t; _editor._dirty = true)
	inner.add_child(death_le)

	margin.add_child(inner)
	vb.add_child(margin)

func show_gift_dialog(title: String, defaults: Dictionary, on_confirm: Callable) -> void:
	var all_items = ItemData.list_items()
	var dlg = AcceptDialog.new()
	dlg.title = title; dlg.dialog_text = ""
	var vb = VBoxContainer.new()
	vb.size = Vector2(350, 220)

	var item_hb = HBoxContainer.new()
	var item_lb = Label.new()
	item_lb.text = "Item:"
	item_lb.size = Vector2(60, 24)
	item_hb.add_child(item_lb)

	var item_btn = Button.new()
	item_btn.text = str(defaults.get("id", "(select)"))
	item_btn.size = Vector2(270, 24)
	item_btn.add_theme_font_size_override("font_size", 13)
	item_btn.pressed.connect(func():
		var pm = PopupMenu.new()
		for ai in all_items:
			pm.add_item(str(ai.get("id", "?")) + "  (" + str(ai.get("name", "")) + ")")
		pm.id_pressed.connect(func(iid):
			var selected = all_items[iid]
			defaults["id"] = str(selected.get("id", ""))
			item_btn.text = defaults["id"])
		_editor._add_child(pm)
		pm.position = get_viewport().get_mouse_position(); pm.popup())
	item_hb.add_child(item_btn)
	vb.add_child(item_hb)

	var fields = {}
	for pair in [["Weight", "weight", 1, 9999], ["Min Qty", "min", 1, 999], ["Max Qty", "max", 1, 999]]:
		var hb = HBoxContainer.new()
		var lb = Label.new()
		lb.text = pair[0] + ":"; lb.size = Vector2(80, 24)
		hb.add_child(lb)
		var sb = SpinBox.new()
		sb.min_value = pair[2]; sb.max_value = pair[3]; sb.step = 1
		sb.value = float(defaults.get(pair[1], pair[2]))
		sb.size = Vector2(250, 24)
		hb.add_child(sb)
		fields[pair[1]] = sb
		vb.add_child(hb)

	dlg.add_child(vb)
	dlg.confirmed.connect(func():
		var data = {
			"id": str(defaults.get("id", "")),
			"weight": int(fields["weight"].value),
			"min": int(fields["min"].value),
			"max": int(fields["max"].value),
		}
		on_confirm.call(data))
	_editor._add_child(dlg); dlg.popup_centered()
