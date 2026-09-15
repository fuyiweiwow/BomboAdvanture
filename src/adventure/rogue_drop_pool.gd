class_name RogueDropPool
extends RefCounted

const RARITIES: Array[String] = ["common", "uncommon", "rare", "epic", "legendary"]

## Validates authoring errors separately so content tools can show every bad field.
static func validate(entries: Array) -> Array[String]:
	var failures: Array[String] = []
	for index in entries.size():
		var entry = entries[index]
		if not entry is Dictionary:
			failures.append("entry %d must be a Dictionary" % index)
			continue
		if str(entry.get("item_id", "")).strip_edges().is_empty():
			failures.append("entry %d requires item_id" % index)
		if not RARITIES.has(str(entry.get("rarity", ""))):
			failures.append("entry %d has unknown rarity" % index)
		if float(entry.get("weight", 0.0)) <= 0.0:
			failures.append("entry %d requires positive weight" % index)
	return failures

## Selects one validated entry. Supplying the RNG makes simulations reproducible.
static func pick(entries: Array, rng: RandomNumberGenerator) -> Dictionary:
	if rng == null or not validate(entries).is_empty():
		return {}
	var total_weight := 0.0
	for entry in entries:
		total_weight += float(entry["weight"])
	var roll := rng.randf_range(0.0, total_weight)
	var accumulated := 0.0
	for entry in entries:
		accumulated += float(entry["weight"])
		if roll <= accumulated:
			return (entry as Dictionary).duplicate(true)
	return (entries.back() as Dictionary).duplicate(true)
