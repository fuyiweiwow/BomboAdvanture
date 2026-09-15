extends RefCounted

const MissionCatalog = preload("res://src/adventure/mission_catalog.gd")
const CityData = preload("res://src/city/city_data.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	var missions := MissionCatalog.list_missions()
	if missions.is_empty():
		failures.append("adventure guild has no missions")
	elif str(missions[0].get("id", "")) == "":
		failures.append("catalog returned mission without id")
	if not MissionCatalog.get_mission("../config").is_empty():
		failures.append("mission catalog allowed path traversal")
	var living := CityData.load_district("living_district")
	var has_guild := false
	for building in living.get("buildings", []):
		has_guild = has_guild or str(building.get("action", "")) == "guild"
	if not has_guild:
		failures.append("living district has no guild entrance")
	return failures
