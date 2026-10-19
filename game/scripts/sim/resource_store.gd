class_name ResourceStore extends RefCounted

const KINDS: Array[String] = ["food", "wood", "scrap", "ammo"]

signal changed(kind: String, amount: int)

var _amounts: Dictionary = {}

func _init(data: GameData, difficulty: Dictionary = {}) -> void:
	for kind: String in KINDS:
		_amounts[kind] = 0
	
	if data:
		var multiplier: float = float(difficulty.get("start_resource_mult", 1.0))
		_amounts["food"] = roundi(float(data.balance("start_food", 0)) * multiplier)
		_amounts["wood"] = roundi(float(data.balance("start_wood", 0)) * multiplier)
		_amounts["scrap"] = roundi(float(data.balance("start_scrap", 0)) * multiplier)
		_amounts["ammo"] = roundi(float(data.balance("start_ammo", 0)) * multiplier)

func get_amount(kind: String) -> int:
	if not _amounts.has(kind):
		push_error("Unknown resource kind: " + kind)
		return 0
	return _amounts[kind]

func add(kind: String, n: int) -> void:
	if n < 0:
		push_error("Cannot add negative amount: " + str(n))
		return
	if not _amounts.has(kind):
		push_error("Unknown resource kind: " + kind)
		return
	if n > 0:
		_amounts[kind] += n
		changed.emit(kind, _amounts[kind])

func take(kind: String, n: int) -> int:
	if n < 0:
		push_error("Cannot take negative amount: " + str(n))
		return 0
	if not _amounts.has(kind):
		push_error("Unknown resource kind: " + kind)
		return 0
	
	if n == 0:
		return 0
		
	var actual: int = mini(n, _amounts[kind])
	if actual > 0:
		_amounts[kind] -= actual
		changed.emit(kind, _amounts[kind])
	return actual

func can_afford(cost: Dictionary) -> bool:
	for kind: String in cost.keys():
		var amount: int = int(cost[kind])
		if not _amounts.has(kind):
			push_error("Unknown resource kind: " + kind)
			if amount > 0:
				return false
			continue
		if _amounts[kind] < amount:
			return false
	return true

func spend(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for kind: String in cost.keys():
		var amount: int = int(cost[kind])
		if amount > 0:
			_amounts[kind] -= amount
			changed.emit(kind, _amounts[kind])
	return true

func refund(cost: Dictionary, fraction: float) -> void:
	for kind: String in cost.keys():
		if not _amounts.has(kind):
			push_error("Unknown resource kind: " + kind)
			continue
		var amount: int = int(cost[kind])
		if amount > 0:
			var return_amount: int = floori(amount * fraction)
			if return_amount > 0:
				_amounts[kind] += return_amount
				changed.emit(kind, _amounts[kind])
