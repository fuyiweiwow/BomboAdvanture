extends RefCounted

const CRITICAL_SCRIPTS := [
	"res://src/main/title_screen.gd",
	"res://src/main/world_map.gd",
	"res://src/alchemy/combat_sandbox.gd",
	"res://src/city/city_scene.gd",
	"res://src/city/adventure_guild_scene.gd",
	"res://src/editor/map_editor.gd",
]

func run() -> Array[String]:
	var failures: Array[String] = []
	for path in CRITICAL_SCRIPTS:
		var script = load(path)
		if script == null or not script.can_instantiate():
			failures.append("cannot load critical script: " + path)
			continue
		var instance = script.new()
		if instance == null:
			failures.append("cannot instantiate critical script: " + path)
		elif instance is Node:
			instance.free()
	return failures
