extends RefCounted

const SilentTestTools = preload("res://src/tests/silent_test_tools.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	var state := {"frames": 0}
	await SilentTestTools.advance_frames(3, func(_frame: int) -> void: state["frames"] += 1)
	if state["frames"] != 3:
		failures.append("advance_frames should invoke its callback once per simulated frame")

	var completed: Dictionary = await SilentTestTools.run_with_timeout(func() -> Array[String]: return [], 1000)
	if completed.get("timed_out", true) or completed.get("result") != []:
		failures.append("run_with_timeout should return a completed suite result")

	var timed_out: Dictionary = await SilentTestTools.run_with_timeout(_finish_after_frames.bind(2), 0)
	if not timed_out.get("timed_out", false):
		failures.append("run_with_timeout should report a suite that exceeds its deadline")
	# Let the deliberately timed-out fixture finish so it cannot leak into later suites.
	await SilentTestTools.advance_frames(3)
	return failures

func _finish_after_frames(frame_count: int) -> Array[String]:
	await SilentTestTools.advance_frames(frame_count)
	return []
