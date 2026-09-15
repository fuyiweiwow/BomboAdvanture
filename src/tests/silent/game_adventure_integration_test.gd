extends RefCounted

const LevelScript = preload("res://src/game/level/level.gd")
const ProfileRepository = preload("res://src/adventure/adventure_profile_repository.gd")


class FakeHero:
	extends RefCounted
	var gold: int = 0
	var items: Dictionary = {}
	func set_motion(_direction: String = "") -> void: pass
	func set_bomb() -> void: pass
	func use_skill(_index: int) -> void: pass
	func dev_use_skill(_index: int) -> void: pass


class FakeLevel:
	extends RefCounted
	var finish_flag := false
	var update_count := 0
	func update() -> void: update_count += 1


class FakeEnemy:
	extends RefCounted
	var remain_blood: int
	func _init(blood: int) -> void: remain_blood = blood


class RejectingRepository:
	extends RefCounted
	var attempts := 0
	func claim(_claim_id: String, _rewards: Dictionary) -> bool:
		attempts += 1
		return false
	func snapshot() -> Dictionary:
		return {"gold": 0, "items": {}, "claimed": []}


func run() -> Array[String]:
	var failures: Array[String] = []
	var original_me = Game.me
	var original_level = Game.current_level
	var original_session: Dictionary = Game.active_mission
	var original_result: Dictionary = Game.last_mission_result
	var original_repository = Game._adventure_profile_repository

	var profile_path := "user://silent_game_adventure_profile.json"
	_delete_profile_files(profile_path)
	var repository := ProfileRepository.new(profile_path)
	repository.save_balances(7, {"old_loot": 1})
	Game._adventure_profile_repository = repository
	var hero := FakeHero.new()
	hero.gold = 7
	hero.items = {"old_loot": 1}
	Game.me = hero
	var mission := {
		"id": "silent_game_flow",
		"objective": {"type": "defeat", "target": 2},
		"rewards": {"gold": 5, "items": {"red_herb": 2}},
		"generator": {},
	}
	if not Game.start_adventure_mission(mission, false):
		failures.append("Game did not accept a headless adventure mission")

	# Loot picked up during the run is permanent and must be merged into the
	# same durable settlement as the fixed mission reward.
	hero.gold = 10
	hero.items["run_loot"] = 2
	var enemies: Array = [FakeEnemy.new(0), FakeEnemy.new(0), FakeEnemy.new(1)]
	LevelScript.retire_defeated_npcs(enemies, Callable(Game, "record_mission_progress"))
	if enemies.size() != 1 or int(Game.active_mission.get("progress", 0)) != 2:
		failures.append("NPC death removal did not advance Game mission progress")
	Game.current_level = FakeLevel.new()
	Game.frame_step()
	var persisted := ProfileRepository.new(profile_path).snapshot()
	if persisted.get("gold") != 15:
		failures.append("run gold and mission gold were not merged")
	if persisted.get("items", {}).get("run_loot") != 2 \
	or persisted.get("items", {}).get("red_herb") != 2:
		failures.append("run items and mission items were not merged")
	if not Game.active_mission.is_empty() or Game.current_level != null:
		failures.append("successful adventure did not clear the run and return")
	if Game.last_mission_result.get("status") != "claimed":
		failures.append("successful adventure did not expose a settlement result")

	var rejecting := RejectingRepository.new()
	Game._adventure_profile_repository = rejecting
	Game.me = FakeHero.new()
	Game.current_level = FakeLevel.new()
	Game.start_adventure_mission(mission, false)
	Game.record_mission_progress("defeat", 2)
	var failed_level = Game.current_level
	Game.frame_step()
	Game.frame_step()
	if Game.active_mission.is_empty() or Game.current_level != failed_level:
		failures.append("failed settlement discarded the active run")
	if rejecting.attempts != 1:
		failures.append("failed settlement retried without backoff")

	Game.me = original_me
	Game.current_level = original_level
	Game.active_mission = original_session
	Game.last_mission_result = original_result
	Game._adventure_profile_repository = original_repository
	_delete_profile_files(profile_path)
	return failures


func _delete_profile_files(path: String) -> void:
	for suffix in ["", ".bak"]:
		var absolute := ProjectSettings.globalize_path(path + suffix)
		if FileAccess.file_exists(absolute):
			DirAccess.remove_absolute(absolute)
