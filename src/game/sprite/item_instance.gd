# res://src/game/sprite/item_instance.gd
# Port of game/sprite/item_instance.py
class_name ItemInstance
extends Updatable

const DEAD = -2
const DYING = -1
const NORMAL = 0

var item_instances_dict: Dictionary = {}
var item: Dictionary = {}
var state: int = NORMAL
var item_timer: int = 0
var item_frame_idx: int = 0
var cx: int = 0
var cy: int = 0

func _init(nx: int, ny: int, item_instances_dict_: Dictionary, item_: Dictionary):
	super._init(nx, ny)
	item_instances_dict = item_instances_dict_
	item = item_
	state = NORMAL
	item_timer = 0
	item_frame_idx = 0
	cx = 0
	cy = 0
	setup()
	update()

func setup() -> void:
	item_instances_dict[Vector2i(x, y)] = self

func update() -> void:
	if state == DEAD:
		return
	var current_time = Time.get_ticks_msec()
	if state == NORMAL:
		throw()
		update_frame(current_time)
		if_hide()
	if state == DYING:
		update_frame(current_time)

func update_frame(current_time: int) -> void:
	var category = get_category()
	if current_time - item_timer > int(item["INTERVAL"]):
		var lEN = item[category].size()
		if lEN == 0:
			frame_loop()
			return
		if item_frame_idx + 1 == lEN:
			frame_loop()
		item_frame_idx = (item_frame_idx + 1) % lEN
		cx = item[category][item_frame_idx].cx
		cy = item[category][item_frame_idx].cy
		item_timer = current_time

func get_category() -> String:
	if state == DYING:
		return "DIE"
	return "STAND"

func frame_loop() -> void:
	if state == DYING:
		switch_state(DEAD)
		uninstall()

func switch_state(new_state: int) -> void:
	state = new_state
	item_frame_idx = -1
	if new_state == DYING:
		item["INTERVAL"] = 100

func if_hide() -> bool:
	if Game.current_level.obstacle_instances.has(Vector2i(x, y)):
		blank_img()
		return true
	return false

func player_get(_p) -> void:
	if state == DYING or state == DEAD:
		return
	var next_state = DYING if item.has("DIE") else DEAD
	switch_state(next_state)

func set_restoration(to_x: int, to_y: int) -> void:
	item_instances_dict.erase(Vector2i(x, y))
	x = to_x
	y = to_y
	item_instances_dict[Vector2i(to_x, to_y)] = self

func uninstall() -> void:
	item_instances_dict.erase(Vector2i(x, y))

func draw(ci: CanvasItem) -> void:
	if state == DEAD:
		return
	if hidden:
		return
	var category = get_category()
	if not item.has(category) or item[category].size() == 0:
		return
	var idx = item_frame_idx if item_frame_idx >= 0 else 0
	var fr: Frame = item[category][idx]
	fr.draw(ci, x_pos, y_pos)
