extends Node2D

var _ui_font: Font = null
var _tex_mask_player: Texture2D = null
var _tex_life_slice: Texture2D = null
var _tex_medal: Texture2D = null
var _tex_icon: Texture2D = null
var _skill_tex_cache: Dictionary = {}
var _tex_item_mask: Texture2D = null
var _tex_mask_cycle: Texture2D = null
var _tex_dlg_bg: Texture2D = null
var _tex_status_bar: Texture2D = null
var _tex_misc510: Texture2D = null
var _tex_game_top: Texture2D = null
var _tex_game_left: Texture2D = null
var _tex_score_bg: Texture2D = null
var _tex_btn_leave: Texture2D = null
var _digit_texes: Array = []
var _game_over_shown: bool = false

func _ready() -> void:
	_ui_font = ThemeDB.fallback_font
	_tex_mask_player = _load_tex("res://assets/img/ui/game/mask_player.png")
	_tex_life_slice = _load_tex("res://assets/img/ui/game/img_playerLife.png")
	_tex_medal = _load_tex("res://assets/img/ui/game/medal_30.png")
	_tex_item_mask = _load_tex("res://assets/img/ui/game/img_itemMask.png")
	_tex_mask_cycle = _load_tex("res://assets/img/ui/game/img_maskCycle.png")
	_tex_dlg_bg = _load_tex("res://assets/img/ui/game/dlg_pveFunc.png")
	_tex_misc510 = _load_tex("res://assets/img/ui/game/misc510.png")
	_tex_game_top = _load_tex("res://assets/img/ui/game/gameTop.png")
	_tex_game_left = _load_tex("res://assets/img/ui/game/gameLeft.png")
	_tex_score_bg = _load_tex("res://assets/img/ui/bg/bg_game.png")
	_tex_btn_leave = _load_tex("res://assets/img/ui/common/btn_leave_0_3.png")
	for i in range(10):
		_digit_texes.append(_load_tex("res://assets/img/ui/number/itemNum_0_" + str(i) + ".png"))

func _get_skill_tex(name: String) -> Texture2D:
	if _skill_tex_cache.has(name):
		return _skill_tex_cache[name]
	var tex = _load_tex("res://assets/img/ui/game/" + name + ".png")
	_skill_tex_cache[name] = tex
	return tex

func _load_tex(path: String) -> Texture2D:
	return RM.get_texture(path)

func _update_icon() -> void:
	var me = Game.me
	if me == null or me.icon_img == "":
		_tex_icon = null
		return
	var path = "res://assets/img/ui/game/" + me.icon_img + ".png"
	_tex_icon = _load_tex(path)

func _draw() -> void:
	draw_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Game.current_level != null and Game.me != null:
			var btn = Rect2(732, 545, 52, 47)
			if btn.has_point(event.position):
				Game._return_to_title()
				get_viewport().set_input_as_handled()

func draw_ui() -> void:
	var cl = Game.current_level
	var me = Game.me
	if Game.game_complete:
		_draw_victory_screen()
		return
	if cl == null or me == null:
		return
	_draw_game_top()
	_draw_game_left()
	_draw_left_panel(me)
	if G.DISPLAY_NPC_BLOOD:
		_draw_right_panel(cl)
	_draw_skill_bar(me)
	_draw_level_complete(cl)
	_draw_game_over(me)

func _draw_game_top() -> void:
	if _tex_game_top != null:
		draw_texture(_tex_game_top, Vector2(0, 0))

func _draw_game_left() -> void:
	if _tex_game_left != null:
		draw_texture(_tex_game_left, Vector2(0, 27))

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
	if _ui_font != null and me != null:
		draw_string(_ui_font, Vector2(4, 158), "Gold: " + str(me.gold), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 0.84, 0.0))

func _draw_right_panel(cl) -> void:
	var npcs = cl.npcs
	if npcs.size() == 0:
		return
	var panel_x = 650
	var start_y = 80
	var icon_size = 28
	var row_h = icon_size + 6
	var hp_font_size = 10
	var i = 0
	while i < npcs.size():
		var npc = npcs[i]
		if npc.blood <= 0:
			i += 1
			continue
		var y = start_y + i * row_h
		var row_right = panel_x + 120
		# Face texture icon at top-right of row
		var icon_x = row_right - icon_size
		if npc.face_texture != null:
			draw_texture_rect(npc.face_texture, Rect2(icon_x, y, icon_size, icon_size), false)
		else:
			draw_rect(Rect2(icon_x, y, icon_size, icon_size), Color(0.3, 0.3, 0.3))
			draw_rect(Rect2(icon_x, y, icon_size, icon_size), Color(1, 1, 1, 0.3), false, 1.0)
		# HP text (remain_blood / blood) at top-left of row
		if _ui_font != null:
			draw_string(_ui_font, Vector2(panel_x, y + hp_font_size), str(npc.remain_blood), HORIZONTAL_ALIGNMENT_LEFT, 50, hp_font_size, Color(0, 1, 1))
			draw_string(_ui_font, Vector2(panel_x, y + hp_font_size + 10), "/ " + str(npc.blood), HORIZONTAL_ALIGNMENT_LEFT, 50, hp_font_size - 2, Color(0.6, 0.6, 0.6))
		# HP bar below the row
		var bar_w = 120.0
		var bar_h = 4.0
		var bx = panel_x
		var by = y + icon_size
		draw_rect(Rect2(bx - 1, by - 1, bar_w + 2, bar_h + 2), Color(0, 0, 0, 0.4))
		draw_rect(Rect2(bx, by, bar_w, bar_h), Color(0.1, 0.1, 0.1, 0.8))
		var ratio = clampf(float(npc.remain_blood) / float(npc.blood), 0.0, 1.0)
		if ratio > 0.0:
			draw_rect(Rect2(bx, by, bar_w * ratio, bar_h), Color(1.0, 0.2, 0.2))
		i += 1

func _draw_skill_bar(me) -> void:
	var bar_x = 0
	var bar_y = 540
	if _tex_status_bar == null:
		_tex_status_bar = _load_tex("res://assets/img/ui/game/statusBar.png")
	if _tex_status_bar != null:
		draw_texture(_tex_status_bar, Vector2(bar_x, bar_y))
	if _tex_misc510 != null:
		draw_texture(_tex_misc510, Vector2(556, bar_y))
	if _tex_dlg_bg != null:
		draw_texture(_tex_dlg_bg, Vector2(619, 537))
	if _tex_btn_leave != null:
		draw_texture(_tex_btn_leave, Vector2(732, 545))
	var names = me.skill_names
	if names.size() == 0:
		return
	var icon_ox = [164, 217, 270, 323, 376, 429, 484]
	var icon_oy = -8
	var mask_ox = [179, 232, 285, 338, 391, 444, 497]
	var mask_oy = 5
	var num_tens = [[198,42],[251,42],[304,42],[357,42],[410,42],[463,42],[516,42]]
	var num_ones = [[208,42],[261,42],[314,42],[367,42],[420,42],[473,42],[526,42]]
	var current_time = Time.get_ticks_msec()
	var dev = Game.dev_mode
	for i in min(names.size(), 7):
		var tex = _get_skill_tex(names[i])
		if tex != null:
			draw_texture_rect(tex, Rect2(bar_x + icon_ox[i], bar_y + icon_oy, 80, 80), false)
		var remains = int(me.skill_remains[i])
		var init_time = int(me.skill_init_times[i])
		var masked = (not dev and current_time < init_time) or remains == 0
		if masked and _tex_item_mask != null:
			draw_texture_rect(_tex_item_mask, Rect2(bar_x + mask_ox[i], bar_y + mask_oy, 51, 49), false)
		if remains > -1:
			if _digit_texes.size() >= 10:
				var tens = remains / 10
				var ones = remains % 10
				if tens > 0 and _digit_texes[tens] != null:
					draw_texture(_digit_texes[tens], Vector2(bar_x + num_tens[i][0], bar_y + num_tens[i][1]))
				if _digit_texes[ones] != null:
					draw_texture(_digit_texes[ones], Vector2(bar_x + num_ones[i][0], bar_y + num_ones[i][1]))
			elif _ui_font != null:
				draw_string(_ui_font, Vector2(bar_x + num_ones[i][0], bar_y + num_ones[i][1]), str(remains), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1))

func _draw_game_over(me) -> void:
	if me.state != 1:  # LOSE
		_game_over_shown = false
		return
	# Check if player has any RevivalCard uses left
	var has_revive = false
	for i in me.skill_names.size():
		if me.skill_names[i] == "RevivalCard" and int(me.skill_remains[i]) > 0:
			has_revive = true
			break
	if has_revive:
		return
	if _game_over_shown:
		return
	if _ui_font == null:
		return
	_game_over_shown = true
	# Dark overlay
	draw_rect(Rect2(0, 0, 800, 600), Color(0, 0, 0, 0.6))
	var msg = "Game Over"
	var ms = 28
	var mw = _ui_font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, ms).x
	draw_string(_ui_font, Vector2((800 - mw) * 0.5, 240), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, ms, Color(1, 0.3, 0.3))
	var inst = "Press R to Restart  |  Press T for Title"
	var is_ = 14
	var iw = _ui_font.get_string_size(inst, HORIZONTAL_ALIGNMENT_LEFT, -1, is_).x
	draw_string(_ui_font, Vector2((800 - iw) * 0.5, 300), inst, HORIZONTAL_ALIGNMENT_LEFT, -1, is_, Color(1, 1, 1))
	if _ui_font != null:
		draw_string(_ui_font, Vector2((800 - iw) * 0.5, 330), "(RevivalCard can revive in battle)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.6, 0.6, 0.6))

func _draw_level_complete(cl) -> void:
	if not cl.finish_flag:
		return
	if _ui_font == null:
		return
	draw_rect(Rect2(0, 0, 800, 600), Color(0, 0, 0, 0.5))
	var msg = "Level Complete!"
	var ms = 26
	var mw = _ui_font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, ms).x
	draw_string(_ui_font, Vector2((800 - mw) * 0.5, 280), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, ms, Color(0.3, 1, 0.3))

func _draw_victory_screen() -> void:
	if _ui_font == null:
		return
	draw_rect(Rect2(0, 0, 800, 600), Color(0, 0, 0, 0.7))
	var title = "Victory!"
	var ts = 36
	var tw = _ui_font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, ts).x
	draw_string(_ui_font, Vector2((800 - tw) * 0.5, 210), title, HORIZONTAL_ALIGNMENT_LEFT, -1, ts, Color(1, 0.9, 0.2))
	var sub = "All maps cleared!"
	var ss = 18
	var sw = _ui_font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ss).x
	draw_string(_ui_font, Vector2((800 - sw) * 0.5, 260), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ss, Color(1, 1, 1))
	var inst = "Press R to Restart  |  Press T for Title"
	var is_ = 14
	var iw = _ui_font.get_string_size(inst, HORIZONTAL_ALIGNMENT_LEFT, -1, is_).x
	draw_string(_ui_font, Vector2((800 - iw) * 0.5, 320), inst, HORIZONTAL_ALIGNMENT_LEFT, -1, is_, Color(1, 1, 1))
