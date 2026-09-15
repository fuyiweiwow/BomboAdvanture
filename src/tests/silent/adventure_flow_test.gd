extends RefCounted

const MissionService = preload("res://src/adventure/mission_service.gd")
const RogueItemRules = preload("res://src/adventure/rogue_item_rules.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	var mission := {
		"id": "forest_cleanup",
		"objective": {"type": "defeat", "target": 3},
		"rewards": {"gold": 25, "items": {"red_herb": 2}},
	}
	var session := MissionService.accept(mission)
	if session.get("status") != "active":
		failures.append("valid mission was not accepted")

	var run_stats := {"bomb": 1, "remain_bombs": 1, "power": 1, "speed": 1.0}
	run_stats = RogueItemRules.apply(run_stats, {"id": "bomb_up", "lifecycle": "run", "effects": {"bomb": 1}})
	if run_stats.get("bomb") != 2 or run_stats.get("remain_bombs") != 2:
		failures.append("bomb upgrade was not applied to run stats")

	MissionService.add_progress(session, 3)
	var settlement := MissionService.settle(session)
	if settlement.get("gold") != 25 or settlement.get("items", {}).get("red_herb") != 2:
		failures.append("mission rewards were not settled")
	if not MissionService.settle(session).is_empty():
		failures.append("mission was settled more than once")
	if settlement.has("run_stats"):
		failures.append("run-only stats leaked into permanent settlement")
	var original := {"bomb": 1, "remain_bombs": 1, "power": 1, "speed": 1.0}
	var upgraded := RogueItemRules.apply(original, {"lifecycle": "run", "effects": {"power": 2, "speed": 0.3}})
	if upgraded["power"] != 3 or not is_equal_approx(upgraded["speed"], 1.3):
		failures.append("power or speed upgrade was not applied")
	if original["power"] != 1 or original["speed"] != 1.0:
		failures.append("item rules mutated input stats")
	var ignored := RogueItemRules.apply(original, {"lifecycle": "persistent", "effects": {"power": 9}})
	if ignored != original:
		failures.append("persistent item was applied as a run upgrade")
	var safe_rewards := MissionService.accept({"id": "safe", "objective": {"type": "defeat", "target": 1}, "rewards": []})
	if safe_rewards.is_empty() or not safe_rewards.get("rewards", {}).get("items", {}).is_empty():
		failures.append("malformed rewards were not normalized")
	if not MissionService.accept({"id": "unknown", "objective": {"type": "dance", "target": 1}}).is_empty():
		failures.append("unsupported objective type was accepted")
	if MissionService.add_progress({"status": "active", "target": 0}, 1, "defeat"):
		failures.append("malformed session accepted progress")

	var invalid := MissionService.accept({"id": "", "objective": {"target": 0}})
	if not invalid.is_empty():
		failures.append("invalid mission was accepted")
	return failures
