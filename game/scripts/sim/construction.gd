class_name Construction extends RefCounted

static func refund_fraction(data: GameData, b: Building) -> float:
	if b.progress <= 0.0:
		return data.balance("refund_before_build", 1.0)
	return data.balance("refund_after_build", 0.5)

static func repair_cost(data: GameData, b: Building) -> int:
	if not b.is_damaged():
		return 0
	var b_data := data.get_building(b.type_id)
	var wood_cost: int = 0
	if b_data.has("cost") and b_data.cost.has("wood"):
		wood_cost = int(b_data.cost.wood)
	var frac := float(data.balance("repair_cost_fraction", 0.25))
	return ceili(wood_cost * frac * (b.max_hp - b.hp) / float(b.max_hp))
