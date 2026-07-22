class_name ComponentColorEditor
extends RefCounted

var _editor

const COLORABLE_COMPONENTS = ["Body", "Foot", "Leg", "Cloth", "Face", "Hair", "Ear", "Cap", "Thadorn", "Npack", "Fpack"]

func _init(editor):
	_editor = editor

func _rebuild_preview() -> void:
	_editor._render_preview()

func build_ui(vb: VBoxContainer) -> void:
	var existing = _editor._hero.get("colors", {})
	var sep = HSeparator.new()
	vb.add_child(sep)

	var lb = Label.new()
	lb.text = "Component Colors:"
	lb.add_theme_font_size_override("font_size", 12)
	lb.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	vb.add_child(lb)

	var hint = Label.new()
	hint.text = "Click picker to change, X to clear (multiply blending on colored textures)"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 9)
	hint.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
	vb.add_child(hint)

	for comp in COLORABLE_COMPONENTS:
		var hb = HBoxContainer.new()
		hb.alignment = BoxContainer.ALIGNMENT_CENTER

		var lb_comp = Label.new()
		lb_comp.text = comp
		lb_comp.custom_minimum_size = Vector2(70, 20)
		lb_comp.add_theme_font_size_override("font_size", 10)
		lb_comp.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
		hb.add_child(lb_comp)

		var current = _parse_color(existing.get(comp, null))
		var picker_btn = ColorPickerButton.new()
		picker_btn.color = current if current != null else Color.WHITE
		picker_btn.custom_minimum_size = Vector2(28, 18)
		picker_btn.size = Vector2(28, 18)
		picker_btn.color_changed.connect(_on_color_changed.bind(comp))
		hb.add_child(picker_btn)

		var btn_clear = Button.new()
		btn_clear.text = "X"
		btn_clear.custom_minimum_size = Vector2(18, 18)
		btn_clear.add_theme_font_size_override("font_size", 9)
		btn_clear.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
		btn_clear.pressed.connect(_clear_color.bind(comp, picker_btn))
		hb.add_child(btn_clear)

		var status = Label.new()
		if current != null:
			status.text = "custom"
			status.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
		else:
			status.text = "global"
			status.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
		status.add_theme_font_size_override("font_size", 9)
		hb.add_child(status)

		vb.add_child(hb)

func _parse_color(val):
	if val is Array:
		if val.size() >= 4:
			return Color(val[0], val[1], val[2], val[3])
		elif val.size() >= 3:
			return Color(val[0], val[1], val[2])
	return null

func _color_to_array(c: Color) -> Array:
	return [c.r, c.g, c.b, c.a]

func _on_color_changed(c: Color, comp: String) -> void:
	if not _editor._hero.has("colors"):
		_editor._hero["colors"] = {}
	_editor._hero["colors"][comp] = _color_to_array(c)
	_editor._dirty = true
	_editor._render_preview()

func _clear_color(comp: String, picker_btn: ColorPickerButton) -> void:
	var colors = _editor._hero.get("colors", {})
	colors.erase(comp)
	_editor._hero["colors"] = colors
	picker_btn.color = Color.WHITE
	_editor._dirty = true
	_editor._render_preview()
