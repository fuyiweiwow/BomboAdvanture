extends RefCounted

const MissionService = preload("res://src/adventure/mission_service.gd")
const RogueItemRules = preload("res://src/adventure/rogue_item_rules.gd")
const ProfileRepository = preload("res://src/adventure/adventure_profile_repository.gd")
const GeneratorConfig = preload("res://src/adventure/adventure_generator_config.gd")
const SettlementService = preload("res://src/adventure/adventure_settlement_service.gd")

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
	if str(session.get("claim_id", "")).is_empty():
		failures.append("accepted mission has no persistent claim id")
	if session.duplicate(true).get("claim_id") != session.get("claim_id"):
		failures.append("copied mission changed its claim id")

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
	var generator_params := GeneratorConfig.build(
		{"width": 21, "monsters": [{"name": "recipe_slime", "max": 4}]},
		{"count": 3, "monster_pool": ["mission_bat"]}
	)
	if generator_params.get("count") != 3:
		failures.append("mission zone count did not override recipe")
	if generator_params.get("monster_pool") != ["mission_bat"]:
		failures.append("mission monster pool did not override recipe")
	var recipe_params := GeneratorConfig.build(
		{"monsters": [{"name": "recipe_slime", "max": 4}]}, {}
	)
	if not recipe_params.get("monster_pool", [])[0] is Dictionary:
		failures.append("recipe monster specs were converted to strings")
	var safe_generator := GeneratorConfig.build({}, {"breakable": "bad"})
	if not safe_generator.get("breakable") is Array:
		failures.append("malformed breakable pool was not normalized")
	var profile_path := "user://silent_adventure_profile.json"
	if FileAccess.file_exists(profile_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(profile_path))
	var repository := ProfileRepository.new(profile_path)
	var stale_repository := ProfileRepository.new(profile_path)
	if not repository.claim("claim-1", {"gold": 10, "items": {"red_herb": 2}}):
		failures.append("first reward claim failed")
	var reloaded_repository := ProfileRepository.new(profile_path)
	if reloaded_repository.claim("claim-1", {"gold": 10, "items": {"red_herb": 2}}):
		failures.append("duplicate reward claim succeeded")
	if stale_repository.claim("claim-1", {"gold": 10}):
		failures.append("stale repository approved a duplicate claim")
	var profile := reloaded_repository.snapshot()
	if profile.get("gold") != 10 or profile.get("items", {}).get("red_herb") != 2:
		failures.append("persistent reward totals are incorrect")
	if not reloaded_repository.save_balances(4, {"red_herb": 1}):
		failures.append("updated player balances were not saved")
	var saved_profile := ProfileRepository.new(profile_path).snapshot()
	if saved_profile.get("gold") != 4 or saved_profile.get("items", {}).get("red_herb") != 1:
		failures.append("saved player balances did not survive reload")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(profile_path))

	var settlement_path := "user://silent_adventure_settlement.json"
	if FileAccess.file_exists(settlement_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settlement_path))
	var settlement_repository := ProfileRepository.new(settlement_path)
	var completed_run := MissionService.accept(mission)
	MissionService.add_progress(completed_run, 3, "defeat")
	var completed_result := SettlementService.complete(completed_run, settlement_repository)
	if completed_result.get("status") != "claimed" or completed_result.get("gold") != 25:
		failures.append("completed adventure was not claimed")
	if not SettlementService.complete(completed_run.duplicate(true), settlement_repository).is_empty():
		failures.append("copied completed adventure was claimed twice")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settlement_path))
	return failures
