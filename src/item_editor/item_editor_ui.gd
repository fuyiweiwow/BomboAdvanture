class_name ItemEditorUI
extends RefCounted

var _editor

func _init(editor):
	_editor = editor

func clear_container(c: Node) -> void:
	for ch in c.get_children():
		c.remove_child(ch)
		ch.queue_free()

func build_basic_tab(vb: VBoxContainer) -> void:
	clear_container(vb)
	var m = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 8)
	m.add_theme_constant_override("margin_top", 4)
	m.add_theme_constant_override("margin_right", 8)
	var inner = VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 4)

	var le_id = LineEdit.new()
	le_id.text = str(_editor._item.get("id", ""))
	le_id.placeholder_text = "unique_id"
	le_id.add_theme_font_size_override("font_size", 14)
	le_id.text_changed.connect(func(t): _editor._item["id"] = t; _editor._dirty = true)
	_add_field(inner, "ID", le_id)

	var le_name = LineEdit.new()
	le_name.text = str(_editor._item.get("name", ""))
	le_name.placeholder_text = "English name"
	le_name.add_theme_font_size_override("font_size", 14)
	le_name.text_changed.connect(func(t): _editor._item["name"] = t; _editor._dirty = true)
	_add_field(inner, "Name", le_name)

	var le_chs = LineEdit.new()
	le_chs.text = str(_editor._item.get("chs_name", ""))
	le_chs.placeholder_text = "中文名"
	le_chs.add_theme_font_size_override("font_size", 14)
	le_chs.text_changed.connect(func(t): _editor._item["chs_name"] = t; _editor._dirty = true)
	_add_field(inner, "中文名", le_chs)

	var te_desc = TextEdit.new()
	te_desc.text = str(_editor._item.get("description", ""))
	te_desc.custom_minimum_size = Vector2(0, 60)
	te_desc.add_theme_font_size_override("font_size", 13)
	te_desc.text_changed.connect(func(): _editor._item["description"] = te_desc.text; _editor._dirty = true)
	_add_field(inner, "Description", te_desc)

	var type_hb = HBoxContainer.new()
	type_hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var type_lb = Label.new()
	type_lb.text = "Type:"
	type_lb.custom_minimum_size = Vector2(100, 24)
	type_lb.add_theme_font_size_override("font_size", 14)
	type_lb.add_theme_color_override("font_color", Color(0.85, 0.87, 0.9))
	type_hb.add_child(type_lb)
	var type_opt = OptionButton.new()
	type_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for t in ItemData.TYPES:
		type_opt.add_item(ItemData.type_label(t), ItemData.TYPES.find(t))
	var cur_type = _editor._item.get("type", "material")
	type_opt.select(ItemData.TYPES.find(cur_type))
	type_opt.item_selected.connect(func(idx):
		_editor._item["type"] = ItemData.TYPES[idx]; _editor._dirty = true
		_editor._update_effects_tab())
	type_hb.add_child(type_opt)
	inner.add_child(type_hb)

	var rarity_hb = HBoxContainer.new()
	rarity_hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rarity_lb = Label.new()
	rarity_lb.text = "Rarity:"
	rarity_lb.custom_minimum_size = Vector2(100, 24)
	rarity_lb.add_theme_font_size_override("font_size", 14)
	rarity_lb.add_theme_color_override("font_color", Color(0.85, 0.87, 0.9))
	rarity_hb.add_child(rarity_lb)
	var rarity_opt = OptionButton.new()
	rarity_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for r in ItemData.RARITIES:
		rarity_opt.add_item(ItemData.rarity_label(r), ItemData.RARITIES.find(r))
	var cur_rarity = _editor._item.get("rarity", "common")
	rarity_opt.select(ItemData.RARITIES.find(cur_rarity))
	rarity_opt.item_selected.connect(func(idx):
		_editor._item["rarity"] = ItemData.RARITIES[idx]; _editor._dirty = true)
	rarity_hb.add_child(rarity_opt)
	inner.add_child(rarity_hb)

	var frame_hb = HBoxContainer.new()
	frame_hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var frame_lb = Label.new()
	frame_lb.text = "Frame:"
	frame_lb.custom_minimum_size = Vector2(100, 24)
	frame_lb.add_theme_font_size_override("font_size", 14)
	frame_lb.add_theme_color_override("font_color", Color(0.85, 0.87, 0.9))
	frame_hb.add_child(frame_lb)
	var frame_btn = Button.new()
	frame_btn.text = str(_editor._item.get("frame", "item1"))
	frame_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame_btn.add_theme_font_size_override("font_size", 14)
	frame_btn.pressed.connect(_editor._on_pick_frame.bind(frame_btn))
	frame_hb.add_child(frame_btn)
	inner.add_child(frame_hb)

	m.add_child(inner)
	vb.add_child(m)

func build_pricing_tab(vb: VBoxContainer) -> void:
	clear_container(vb)
	var m = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 8)
	m.add_theme_constant_override("margin_top", 4)
	m.add_theme_constant_override("margin_right", 8)
	var inner = VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 4)

	var sb_buy = SpinBox.new()
	sb_buy.min_value = 0; sb_buy.max_value = 999999; sb_buy.step = 1
	sb_buy.value = float(_editor._item.get("buy_price", 0))
	sb_buy.add_theme_font_size_override("font_size", 14)
	sb_buy.value_changed.connect(func(v): _editor._item["buy_price"] = int(v); _editor._dirty = true)
	_add_field(inner, "Buy Price", sb_buy)

	var sb_sell = SpinBox.new()
	sb_sell.min_value = 0; sb_sell.max_value = 999999; sb_sell.step = 1
	sb_sell.value = float(_editor._item.get("sell_price", 0))
	sb_sell.add_theme_font_size_override("font_size", 14)
	sb_sell.value_changed.connect(func(v): _editor._item["sell_price"] = int(v); _editor._dirty = true)
	_add_field(inner, "Sell Price", sb_sell)

	var stack_hb = HBoxContainer.new()
	stack_hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var stack_lb = Label.new()
	stack_lb.text = "Stackable:"
	stack_lb.custom_minimum_size = Vector2(100, 24)
	stack_lb.add_theme_font_size_override("font_size", 14)
	stack_lb.add_theme_color_override("font_color", Color(0.85, 0.87, 0.9))
	stack_hb.add_child(stack_lb)
	var stack_cb = CheckBox.new()
	stack_cb.button_pressed = _editor._item.get("stackable", true)
	stack_cb.toggled.connect(func(v): _editor._item["stackable"] = v; _editor._dirty = true)
	stack_hb.add_child(stack_cb)
	inner.add_child(stack_hb)

	var sb_max = SpinBox.new()
	sb_max.min_value = 1; sb_max.max_value = 999; sb_max.step = 1
	sb_max.value = float(_editor._item.get("max_stack", 99))
	sb_max.add_theme_font_size_override("font_size", 14)
	sb_max.value_changed.connect(func(v): _editor._item["max_stack"] = int(v); _editor._dirty = true)
	_add_field(inner, "Max Stack", sb_max)

	m.add_child(inner)
	vb.add_child(m)

func build_effects_tab(vb: VBoxContainer) -> void:
	clear_container(vb)
	var m = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 8)
	m.add_theme_constant_override("margin_top", 4)
	m.add_theme_constant_override("margin_right", 8)
	var inner = VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 4)

	var item_type = _editor._item.get("type", "material")
	var fields = ItemData.effects_for_type(item_type)
	if fields.is_empty():
		var lb = Label.new()
		lb.text = "No effects for this item type."
		lb.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
		lb.add_theme_font_size_override("font_size", 13)
		inner.add_child(lb)
	else:
		var effects = _editor._item.get("effects", {})
		for key in fields:
			var val = effects.get(key, ItemData.EFFECT_DEFAULTS.get(key, 0))
			var is_string = val is String
			if is_string:
				var le = LineEdit.new()
				le.text = str(val)
				le.add_theme_font_size_override("font_size", 14)
				le.text_changed.connect(func(t):
					_editor._item["effects"] = _editor._item.get("effects", {})
					_editor._item["effects"][key] = t
					_editor._dirty = true)
				_add_field(inner, key.capitalize(), le)
			else:
				var sb = SpinBox.new()
				sb.min_value = -99999; sb.max_value = 99999; sb.step = 0.1 if "speed" in key else 1
				sb.value = float(val)
				sb.add_theme_font_size_override("font_size", 14)
				sb.value_changed.connect(func(v):
					_editor._item["effects"] = _editor._item.get("effects", {})
					_editor._item["effects"][key] = v if "speed" in key else int(v)
					_editor._dirty = true)
				_add_field(inner, key.capitalize().replace("_", " "), sb)

	m.add_child(inner)
	vb.add_child(m)

func _add_field(container: Node, label: String, input: Control, label_w: int = 100) -> void:
	var hb = HBoxContainer.new()
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lb = Label.new()
	lb.text = label + ":"
	lb.custom_minimum_size = Vector2(label_w, 24)
	lb.add_theme_font_size_override("font_size", 14)
	lb.add_theme_color_override("font_color", Color(0.85, 0.87, 0.9))
	hb.add_child(lb)
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(input)
	container.add_child(hb)

func add_tab(name: String, tc: TabContainer) -> VBoxContainer:
	var sc = ScrollContainer.new()
	sc.name = name
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var vb = VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 6)
	sc.add_child(vb)
	tc.add_child(sc)
	return vb
