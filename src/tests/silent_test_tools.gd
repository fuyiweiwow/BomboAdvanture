class_name SilentTestTools
extends RefCounted

## Advances the live SceneTree without a window or player input. The optional
## callback receives a zero-based frame index after each frame is processed.
static func advance_frames(frame_count: int, frame_callback: Callable = Callable()) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	for frame in range(maxi(frame_count, 0)):
		await tree.process_frame
		if frame_callback.is_valid():
			frame_callback.call(frame)

## Runs synchronous or frame-yielding test code behind a cooperative deadline.
## A timed-out coroutine is ignored by the runner; tests must not keep mutating
## shared state after their requested frame waits complete.
static func run_with_timeout(test_callable: Callable, timeout_msec: int) -> Dictionary:
	var state := {"completed": false, "result": null}
	_complete_when_ready(test_callable, state)
	if state["completed"]:
		return {"timed_out": false, "result": state["result"]}
	if timeout_msec <= 0:
		return {"timed_out": true, "result": null}

	var deadline := Time.get_ticks_msec() + timeout_msec
	var tree := Engine.get_main_loop() as SceneTree
	while not state["completed"] and Time.get_ticks_msec() < deadline:
		await tree.process_frame
	return {"timed_out": not state["completed"], "result": state["result"]}

static func _complete_when_ready(test_callable: Callable, state: Dictionary) -> void:
	state["result"] = await test_callable.call()
	state["completed"] = true
