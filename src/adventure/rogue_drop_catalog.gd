class_name RogueDropCatalog
extends RefCounted

const RogueDropPool = preload("res://src/adventure/rogue_drop_pool.gd")
const DEFAULT_PATH := "res://assets/adventure/rogue_drop_pool.json"

## Loads author-editable drop data only when both the chance and weighted
## entries are valid. Runtime callers receive an empty dictionary on bad data.
static func load_config(path: String = DEFAULT_PATH) -> Dictionary:
	var config := JsonStore.read_dictionary(path)
	if config.is_empty():
		return {}
	var chance := float(config.get("chance", -1.0))
	var entries = config.get("entries", [])
	if not is_finite(chance) or chance < 0.0 or chance > 1.0:
		return {}
	if not entries is Array or not RogueDropPool.validate(entries).is_empty():
		return {}
	for entry in entries:
		if not ItemData.item_exists(str(entry["item_id"])):
			return {}
	return {
		"chance": chance,
		"entries": (entries as Array).duplicate(true),
	}
