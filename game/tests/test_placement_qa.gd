extends TestCase
## Acceptance regressions for exact costs, atomic rejection and placement ordering.

func _snapshot(state: GameState) -> Dictionary:
	var amounts: Dictionary = {}
	for kind: String in ResourceStore.KINDS:
		amounts[kind] = state.resources.get_amount(kind)
	var occupants: Array[int] = []
	var types: Array[String] = []
	for x: int in range(state.map.size()):
		for y: int in range(state.map.size()):
			var tile: Vector2i = Vector2i(x, y)
			occupants.append(state.map.occupant_at(tile))
			types.append(state.map.building_at(tile))
	return {"resources": amounts, "occupants": occupants,
		"types": types, "buildings": state.buildings.all()}

func test_failed_placement_is_atomic_and_first_failure_wins() -> void:
	var cases: Array[Dictionary] = [
		{"type": "castle", "position": "outside", "result": Placement.Result.UNKNOWN_TYPE},
		{"type": "command_center", "position": "outside", "result": Placement.Result.NOT_PLACEABLE},
		{"type": "reinforced_wall", "position": "outside", "result": Placement.Result.NOT_PLACEABLE},
		{"type": "storage", "position": "outside", "result": Placement.Result.LOCKED},
		{"type": "shelter", "position": "corner", "result": Placement.Result.OUT_OF_BOUNDS},
		{"type": "wooden_wall", "position": "cc", "result": Placement.Result.BLOCKED},
		{"type": "wooden_wall", "position": "free", "result": Placement.Result.UNAFFORDABLE}
	]
	for entry: Dictionary in cases:
		var state: GameState = GameState.new(GameData.load_default(), 1337)
		state.resources.take("wood", state.resources.get_amount("wood"))
		var origin: Vector2i = state.map.command_center_origin()
		match entry["position"]:
			"outside": origin = Vector2i(-1, -1)
			"corner": origin = Vector2i(state.map.size() - 1, state.map.size() - 1)
			"free": origin += Vector2i(3, 0)
		var before: Dictionary = _snapshot(state)
		var signals: Array[int] = [0]
		state.resources.changed.connect(func(_kind: String, _amount: int) -> void: signals[0] += 1)
		state.map.changed.connect(func() -> void: signals[0] += 1)
		state.buildings.building_added.connect(func(_b: Building) -> void: signals[0] += 1)
		assert_eq(Placement.check(state, entry["type"], origin), entry["result"], str(entry))
		assert_eq(_snapshot(state), before, "check is read-only")
		assert_eq(state.try_place(entry["type"], origin), entry["result"], str(entry))
		assert_eq(_snapshot(state), before, "Rejected placement changes no resources, map or instances")
		assert_eq(signals[0], 0, "Rejected placement emits no mutation signals")

func test_multi_resource_cost_success_and_shortfall() -> void:
	var data: GameData = GameData.load_default()
	var state: GameState = GameState.new(data, 1337)
	state.clock.advance(data.balance("day_length") + data.balance("night_min_length"))
	var origin: Vector2i = state.map.command_center_origin() + Vector2i(3, 0)
	var cost: Dictionary = data.get_building("watchtower")["cost"]
	var scrap_cost: int = int(cost["scrap"])
	assert_gt(scrap_cost, 0, "Fixture exercises a positive scrap cost")
	state.resources.take("scrap", state.resources.get_amount("scrap"))
	state.resources.add("scrap", scrap_cost - 1)
	var before: Dictionary = _snapshot(state)
	assert_eq(state.try_place("watchtower", origin), Placement.Result.UNAFFORDABLE)
	assert_eq(_snapshot(state), before, "Sufficient wood but insufficient scrap must spend nothing")
	state.resources.add("scrap", 1)
	var amounts: Dictionary = _snapshot(state)["resources"]
	var added: Array[Building] = []
	state.buildings.building_added.connect(func(b: Building) -> void: added.append(b))
	assert_eq(state.try_place("watchtower", origin), Placement.Result.OK)
	for kind: String in ResourceStore.KINDS:
		assert_eq(state.resources.get_amount(kind), int(amounts[kind]) - int(cost.get(kind, 0)),
			"Deduct only the data-defined cost for " + kind)
	var building: Building = state.buildings.get_at(origin)
	assert_not_null(building)
	if building == null:
		return
	assert_eq(added, [building], "One signal with the stored instance")
	assert_false(building.complete, "New placements are blueprints")
	assert_eq(building.progress, 0.0)
	assert_eq(building.hp, int(data.get_building("watchtower")["hp"]))
	assert_eq(building.max_hp, building.hp)
	assert_eq(state.map.building_at(origin), "watchtower")
	assert_eq(state.buildings.get_by_uid(building.uid), building)

func test_command_center_footprint_helpers_and_removal() -> void:
	var state: GameState = GameState.new(GameData.load_default(), 1337)
	var cc: Building = state.buildings.get_at(state.map.command_center_origin())
	assert_not_null(cc)
	if cc == null:
		return
	assert_eq(cc.uid, 1)
	var size_data: Array = state.data.get_building("command_center")["size"]
	assert_eq(cc.size, Vector2i(int(size_data[0]), int(size_data[1])))
	assert_eq(cc.tiles(), Grid.rect_tiles(cc.origin, cc.size))
	assert_eq(cc.center_world(), (Vector2(cc.origin) + Vector2(cc.size) / 2.0) * Grid.TILE)
	assert_true(cc.complete)
	assert_eq(cc.hp, int(state.data.get_building("command_center")["hp"]))
	for tile: Vector2i in cc.tiles():
		assert_true(cc.contains(tile))
		assert_eq(state.buildings.get_at(tile), cc)
	assert_false(cc.contains(cc.origin - Vector2i(1, 0)))
	assert_false(cc.contains(cc.origin + cc.size))
	state.buildings.remove(cc.uid)
	assert_eq(state.buildings.get_by_uid(cc.uid), null)
	assert_eq(state.buildings.all().size(), 0)
	for tile: Vector2i in cc.tiles():
		assert_eq(state.buildings.get_at(tile), null)
		assert_eq(state.map.occupant_at(tile), WorldMap.Occupant.NONE)
		assert_eq(state.map.building_at(tile), "")

func test_rocks_and_scrap_block_placement() -> void:
	var state: GameState = GameState.new(GameData.load_default(), 1337)
	for occupant: int in [WorldMap.Occupant.ROCK, WorldMap.Occupant.SCRAP]:
		var found: bool = false
		for x: int in range(state.map.size()):
			for y: int in range(state.map.size()):
				var tile: Vector2i = Vector2i(x, y)
				if state.map.occupant_at(tile) == occupant:
					assert_eq(Placement.check(state, "wooden_wall", tile), Placement.Result.BLOCKED)
					found = true
					break
			if found:
				break
		assert_true(found, "Generated map contains occupant " + str(occupant))

func test_line_tiles_full_sequence_and_horizontal_tie() -> void:
	assert_eq(Placement.line_tiles(Vector2i(0, 0), Vector2i(4, 1)),
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)])
	assert_eq(Placement.line_tiles(Vector2i(0, 0), Vector2i(1, -3)),
		[Vector2i(0, 0), Vector2i(0, -1), Vector2i(0, -2), Vector2i(0, -3)])
	assert_eq(Placement.line_tiles(Vector2i(3, 4), Vector2i(1, 2)),
		[Vector2i(3, 4), Vector2i(2, 4), Vector2i(1, 4)])
	assert_eq(Placement.line_tiles(Vector2i(3, 4), Vector2i(4, 7)),
		[Vector2i(3, 4), Vector2i(3, 5), Vector2i(3, 6), Vector2i(3, 7)])
