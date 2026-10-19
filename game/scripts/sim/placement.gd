class_name Placement extends RefCounted

enum Result { OK, UNKNOWN_TYPE, NOT_PLACEABLE, LOCKED, OUT_OF_BOUNDS, BLOCKED, UNAFFORDABLE, NOT_UPGRADABLE, LIMIT_REACHED }

static func upgrade_target(data: GameData, type_id: String) -> String:
	for target: String in data.building_ids():
		if data.get_building(target).get("upgrade_from", "") == type_id:
			return target
	return ""

static func check(state: GameState, type_id: String, origin: Vector2i) -> int:
	if not state.data.building_ids().has(type_id):
		return Result.UNKNOWN_TYPE
		
	if type_id == "command_center":
		return Result.NOT_PLACEABLE
		
	var b_data := state.data.get_building(type_id)
	if b_data.has("upgrade_from"):
		return Result.NOT_PLACEABLE
		
	var unlock_day := int(b_data.get("unlock_day", 0))
	if unlock_day > state.clock.day:
		return Result.LOCKED
	var max_count: int = int(b_data.get("max_count", 0))
	if max_count > 0 and state.buildings.count_of(type_id) >= max_count:
		return Result.LIMIT_REACHED
		
	var sz: Array = b_data.get("size", [1, 1])
	var size := Vector2i(int(sz[0]), int(sz[1]))
	
	for t in Grid.rect_tiles(origin, size):
		if not Grid.in_bounds(t, state.map.size()):
			return Result.OUT_OF_BOUNDS
			
	if not state.map.is_free(origin, size):
		return Result.BLOCKED
		
	var cost: Dictionary = b_data.get("cost", {})
	if not state.resources.can_afford(cost):
		return Result.UNAFFORDABLE
		
	return Result.OK

static func is_placeable_type(data: GameData, type_id: String) -> bool:
	if not data.building_ids().has(type_id):
		return false
	if type_id == "command_center":
		return false
	var b_data := data.get_building(type_id)
	if b_data.has("upgrade_from"):
		return false
	return true

static func line_tiles(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	var dx: int = b.x - a.x
	var dy: int = b.y - a.y
	
	if absi(dx) >= absi(dy):
		var step: int = 1 if dx >= 0 else -1
		for i in range(absi(dx) + 1):
			tiles.append(Vector2i(a.x + i * step, a.y))
	else:
		var step: int = 1 if dy >= 0 else -1
		for i in range(absi(dy) + 1):
			tiles.append(Vector2i(a.x, a.y + i * step))
			
	return tiles

static func result_text(r: int) -> String:
	match r:
		Result.OK:
			return "OK"
		Result.UNKNOWN_TYPE:
			return "Unknown building"
		Result.NOT_PLACEABLE:
			return "Can't place"
		Result.LOCKED:
			return "Locked"
		Result.OUT_OF_BOUNDS:
			return "Out of bounds"
		Result.BLOCKED:
			return "Blocked"
		Result.UNAFFORDABLE:
			return "Not enough resources"
		Result.NOT_UPGRADABLE:
			return "Can't upgrade"
		Result.LIMIT_REACHED:
			return "Only one Field Lab"
		_:
			return "Unknown"
