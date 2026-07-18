extends Node2D

var _ui_font: Font = null
var _tex_mask_player: Texture2D = null
var _tex_life_slice: Texture2D = null
var _tex_medal: Texture2D = null
var _tex_icon: Texture2D = null

func _ready() -> void:
	_ui_font = ThemeDB.fallback_font
	_tex_mask_player = _load_tex("res://assets/img/ui/game/mask_player.png")
	_tex_life_slice = _load_tex("res://assets/img/ui/game/img_playerLife.png")
	_tex_medal = _load_tex("res://assets/img/ui/game/medal_30.png")

func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _update_icon() -> void:
	var me = Game.me
	if me == null or me.icon_img == "":
		_tex_icon = null
		return
	var path = "res://assets/img/ui/game/" + me.icon_img + ".png"
	_tex_icon = _load_tex(path)

func _draw() -> void:
	draw_ui()

func draw_ui() -> void:
	var cl = Game.current_level
	var me = Game.me
	if cl == null or me == null:
		return
	_draw_left_panel(me)
	if G.DISPLAY_NPC_BLOOD:
		_draw_right_panel(cl)

func _draw_left_panel(me) -> void:
	_update_icon()
	if _tex_icon != null:
		draw_texture(_tex_icon, Vector2(0, 78))
	if _tex_mask_player != null:
		draw_texture(_tex_mask_player, Vector2(0, 120))
	if _ui_font != null:
		draw_string(_ui_font, Vector2(4, 135), str(me.remain_blood), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0, 1, 1))
	if _tex_life_slice != null and me.blood > 0:
		var ratio = clampf(float(me.remain_blood) / float(me.blood), 0.0, 1.0)
		var max_slices = 90
		var n = ceili(ratio * max_slices)
		var i = 0
		while i < n:
			draw_texture(_tex_life_slice, Vector2(float(i), 136.0))
			i += 1
	if _tex_medal != null:
		draw_texture(_tex_medal, Vector2(0, 142))

func _draw_right_panel(cl) -> void:
	var npcs = cl.npcs
	if npcs.size() == 0:
		return
	var panel_x = 560
	var start_y = 80
	var bar_w = 130.0
	var bar_h = 6.0
	var i = 0
	while i < npcs.size():
		var npc = npcs[i]
		if npc.blood <= 0:
			i += 1
			continue
		var y = start_y + i * 22
		if _ui_font != null:
			draw_string(_ui_font, Vector2(panel_x, y + 10), npc.chs_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1))
		var bx = panel_x + 70
		var by = y + 2
		draw_rect(Rect2(bx - 1, by - 1, bar_w + 2, bar_h + 2), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(bx, by, bar_w, bar_h), Color(0.1, 0.1, 0.1, 0.85))
		var ratio = clampf(float(npc.remain_blood) / float(npc.blood), 0.0, 1.0)
		if ratio > 0.0:
			draw_rect(Rect2(bx, by, bar_w * ratio, bar_h), Color(1.0, 0.2, 0.2))
		i += 1
