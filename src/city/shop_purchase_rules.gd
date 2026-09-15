# Shop purchases currently target the persistent inventory model only. Run
# upgrades, keys and consumable effects need their own persistence design.
class_name ShopPurchaseRules
extends RefCounted


static func is_supported(item: Dictionary) -> bool:
	return (
		str(item.get("id", "")).strip_edges() != ""
		and str(item.get("type", "")) == "material"
		and int(item.get("buy_price", 0)) > 0
	)


static func plan(profile: Dictionary, item: Dictionary) -> Dictionary:
	if not is_supported(item):
		return {}
	var price := int(item.get("buy_price", 0))
	var gold := int(profile.get("gold", 0))
	if gold < price:
		return {}
	var raw_items = profile.get("items", {})
	var items: Dictionary = raw_items.duplicate(true) if raw_items is Dictionary else {}
	var item_id := str(item["id"])
	items[item_id] = int(items.get(item_id, 0)) + 1
	return {"gold": gold - price, "items": items}
