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

	var invalid := MissionService.accept({"id": "", "objective": {"target": 0}})
	if not invalid.is_empty():
		failures.append("invalid mission was accepted")
	return failures
