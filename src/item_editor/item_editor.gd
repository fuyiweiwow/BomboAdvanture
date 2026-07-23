extends Control

var _item: Dictionary = {}
var _dirty: bool = false
var _list_ref = null
var _ui: ItemEditorUI
var _preview_bg: ColorRect

var _btn_back: Button
var _btn_save: Button
var _btn_delete: Button
var _btn_new: Button

var _tab_basic: VBoxContainer
var _tab_pricing: VBoxContainer
var _tab_effects: VBoxContainer
var _tc: TabContainer
var _preview_label: RichTextLabel

func _init(item: Dictionary):
	_item = item.duplicate(true)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_list_ref = get_meta("list_ref") if has_meta("list_ref") else null
	_ui = ItemEditorUI.new(self)
	_build_layout()

func _build_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var vb = VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 10)
	margin.add_child(vb)

	var bar = HBoxContainer.new()
	bar.custom_minimum_size = Vector2(0, 40)
	bar.add_theme_constant_override("separation", 8)
	vb.add_child(bar)

	_btn_back = Button.new()
	_btn_back.text = "< Back"
	_btn_back.pressed.connect(_on_back)
	bar.add_child(_btn_back)

	_btn_save = Button.new()
	_btn_save.text = "Save"
	_btn_save.pressed.connect(_on_save)
	bar.add_child(_btn_save)

	_btn_delete = Button.new()
	_btn_delete.text = "Delete"
	_btn_delete.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	_btn_delete.pressed.connect(_on_delete)
	bar.add_child(_btn_delete)

	bar.add_spacer(false)

	var title = Label.new()
	title.text = str(_item.get("name", "")) + "  (" + str(_item.get("id", "new")) + ")"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.9, 0.92, 0.95))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_meta("_title", title)
	bar.add_child(title)

	_btn_new = Button.new()
	_btn_new.text = "+ New"
	_btn_new.pressed.connect(_on_new_item)
	bar.add_child(_btn_new)

	var hb_body = HBoxContainer.new()
	hb_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(hb_body)

	var left = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hb_body.add_child(left)

	_tc = TabContainer.new()
	_tc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(_tc)

	_tab_basic = _ui.add_tab("Basic", _tc)
	_tab_pricing = _ui.add_tab("Pricing", _tc)
	_tab_effects = _ui.add_tab("Effects", _tc)

	var right_margin = MarginContainer.new()
	right_margin.custom_minimum_size = Vector2(240, 0)
	right_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_margin.add_theme_constant_override("margin_left", 10)
	right_margin.add_theme_constant_override("margin_top", 4)
	right_margin.add_theme_constant_override("margin_right", 4)
	right_margin.add_theme_constant_override("margin_bottom", 4)
	hb_body.add_child(right_margin)

	var right = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 4)
	right_margin.add_child(right)

	var plb = Label.new()
	plb.text = "Preview"
	plb.add_theme_font_size_override("font_size", 16)
	plb.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	right.add_child(plb)

	var preview_scroll = ScrollContainer.new()
	preview_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(preview_scroll)

	_preview_label = RichTextLabel.new()
	_preview_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_label.fit_content = true
	_preview_label.scroll_active = false
	preview_scroll.add_child(_preview_label)

	_refresh_preview()

	_ui.build_basic_tab(_tab_basic)
	_ui.build_pricing_tab(_tab_pricing)
	_ui.build_effects_tab(_tab_effects)

func _refresh_preview() -> void:
	if _preview_label == null: return
	var item = _item
	var lines = []
	var id = str(item.get("id", "?"))
	var name = str(item.get("name", ""))
	var chs = str(item.get("chs_name", ""))
	var type = str(item.get("type", "?"))
	var rarity = str(item.get("rarity", "common"))
	var desc = str(item.get("description", ""))
	var frame = str(item.get("frame", "?"))
	var buy = int(item.get("buy_price", 0))
	var sell = int(item.get("sell_price", 0))
	var stackable = item.get("stackable", true)
	var max_stack = int(item.get("max_stack", 99))

	var rcol = ItemData.rarity_color(rarity)
	var rlabel = ItemData.rarity_label(rarity)
	var tlabel = ItemData.type_label(type)

	lines.append("[b]%s[/b]" % name)
	if chs: lines.append("  %s" % chs)
	lines.append("")
	lines.append("ID: %s" % id)
	lines.append("Type: %s" % tlabel)
	lines.append("Rarity: [color=#%s]%s[/color]" % [rcol.to_html(false), rlabel])
	lines.append("Frame: %s" % frame)
	lines.append("")
	lines.append("Buy: %d  Sell: %d" % [buy, sell])
	lines.append("Stack: %s  (max %d)" % ["yes" if stackable else "no", max_stack])

	if desc:
		lines.append("")
		lines.append(desc)

	var effects = item.get("effects", {})
	if effects and not effects.is_empty():
		lines.append("")
		lines.append("--- Effects ---")
		for k in effects:
			var v = effects[k]
			if v is String and v != "":
				lines.append("  %s: %s" % [k.capitalize().replace("_", " "), v])
			elif v is float or v is int:
				if v != 0:
					lines.append("  %s: %+d" % [k.capitalize().replace("_", " "), v])

	_preview_label.text = "\n".join(lines)

func _update_title() -> void:
	for c in get_children():
		var title = c.get_node_or_null("")
		break
	var bar = _btn_back.get_parent() if _btn_back != null else null
	if bar != null:
		for c in bar.get_children():
			if c is Label and c.has_meta("_title"):
				c.text = str(_item.get("name", "")) + "  (" + str(_item.get("id", "new")) + ")"

func _update_effects_tab() -> void:
	_ui.build_effects_tab(_tab_effects)
	_refresh_preview()

func _on_pick_frame(btn: Button) -> void:
	var frames = ItemData.list_frames()
	var menu = PopupMenu.new()
	for f in frames:
		menu.add_item(f)
	menu.id_pressed.connect(func(id):
		_item["frame"] = frames[id]; btn.text = frames[id]; _dirty = true)
	_add_child(menu); menu.position = get_viewport().get_mouse_position(); menu.popup()

func _on_save() -> void:
	var id = str(_item.get("id", "")).strip_edges()
	if id == "":
		_show_notice("ID cannot be empty!", Color(1, 0.3, 0.3)); return
	var name = str(_item.get("name", "")).strip_edges()
	if name == "":
		_show_notice("Name cannot be empty!", Color(1, 0.3, 0.3)); return
	if ItemData.save_item(_item):
		_dirty = false; _show_notice("Saved!", Color(0.3, 1, 0.3))
		await get_tree().create_timer(0.5).timeout; _do_quit()
		var p = get_parent()
		if p != null:
			p.add_child(load("res://src/item_editor/item_list.gd").new())
	else:
		_show_notice("Save failed!", Color(1, 0.3, 0.3))

func _on_delete() -> void:
	var id = str(_item.get("id", ""))
	if id == "": return
	var dlg = ConfirmationDialog.new()
	dlg.dialog_text = "Delete item '%s'?" % id
	dlg.ok_button_text = "Delete"; dlg.cancel_button_text = "Cancel"
	dlg.confirmed.connect(func():
		ItemData.delete_item(id); _do_quit()
		var p = get_parent()
		if p != null:
			p.add_child(load("res://src/item_editor/item_list.gd").new()))
	_add_child(dlg); dlg.popup_centered()

func _on_new_item() -> void:
	for c in get_children(): c.queue_free()
	_item = ItemData.new_template()
	_dirty = true; _build_layout()

func _show_notice(msg: String, color: Color) -> void:
	var n = Label.new()
	n.text = msg; n.position = Vector2(300, 48); n.size = Vector2(200, 24)
	n.add_theme_font_size_override("font_size", 16)
	n.add_theme_color_override("font_color", color)
	add_child(n)
	await get_tree().create_timer(1.5).timeout
	if is_inside_tree(): n.queue_free()

func _on_back() -> void:
	if _dirty:
		var dlg = ConfirmationDialog.new()
		dlg.dialog_text = "Unsaved changes will be lost. Continue?"
		dlg.ok_button_text = "Discard"; dlg.cancel_button_text = "Cancel"
		dlg.confirmed.connect(_do_quit); add_child(dlg); dlg.popup_centered()
	else:
		_do_quit()

func _do_quit() -> void:
	if _list_ref != null and is_instance_valid(_list_ref):
		get_parent().add_child(_list_ref)
	queue_free()

func _add_child(n: Node) -> void:
	add_child(n)

func _draw() -> void:
	var win = get_viewport_rect().size
	draw_rect(Rect2(0, 0, win.x, win.y), Color(0.08, 0.08, 0.12))

func _exit_tree() -> void:
	pass
