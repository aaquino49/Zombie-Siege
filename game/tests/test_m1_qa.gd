extends TestCase
## M1 integration gaps: all day-1 costs, dawn placement, invalid ghosts.

func test_every_day1_type_places_on_free_grass_and_pays_its_data_cost() -> void:
	var data: GameData = GameData.load_default()
	var exercised: Array[String] = []
	for type_id: String in data.buildings_unlocked_on(1):
		if not Placement.is_placeable_type(data, type_id):
			continue
		var state: GameState = GameState.new(data, 1337)
		var definition: Dictionary = data.get_building(type_id)
		var size_data: Array = definition["size"]
		var size: Vector2i = Vector2i(int(size_data[0]), int(size_data[1]))
		var origin: Vector2i = _free_grass(state, size)
		assert_ne(origin, Vector2i(-1, -1))
		var cost: Dictionary = definition["cost"]
		var before: Dictionary = _resources(state)
		assert_eq(state.try_place(type_id, origin), Placement.Result.OK, type_id)
		for kind: String in ResourceStore.KINDS:
			assert_eq(state.resources.get_amount(kind), int(before[kind]) - int(cost.get(kind, 0)), type_id + ": " + kind)
		var building: Building = state.buildings.get_at(origin)
		assert_not_null(building, type_id)
		if building != null:
			assert_eq(building.type_id, type_id)
			assert_eq(building.size, size)
			for tile: Vector2i in building.tiles():
				assert_eq(state.map.occupant_at(tile), WorldMap.Occupant.BUILDING)
		exercised.append(type_id)
	assert_eq(exercised.size(), 4, "Wall, gate, shelter and farm must all be exercised")

func test_dawn_unlocks_bar_and_try_place_in_the_same_state() -> void:
	var state: GameState = GameState.new(GameData.load_default(), 1337)
	var bar: BuildBar = preload("res://scenes/ui/build_bar.tscn").instantiate() as BuildBar
	bar.bind(state)
	state.resources.add("wood", 100)
	var origin: Vector2i = state.map.command_center_origin()
	var types: Array[String] = ["storage", "watchtower", "workshop"]
	var positions: Array[Vector2i] = [origin + Vector2i(-2, -2), origin + Vector2i(3, 1), origin + Vector2i(2, -2)]
	var before: Dictionary = _resources(state)
	for i: int in range(types.size()):
		assert_eq(state.try_place(types[i], positions[i]), Placement.Result.LOCKED)
	assert_eq(_resources(state), before)
	var day_length: float = float(state.data.balance("day_length"))
	var night_length: float = float(state.data.balance("night_min_length"))
	state.tick(day_length)
	assert_eq(state.clock.phase, GameClock.Phase.NIGHT)
	assert_eq(bar._hbox().get_child_count(), 4)
	state.tick(night_length)
	assert_eq(state.clock.day, 2)
	assert_eq(state.clock.phase, GameClock.Phase.DAY)
	var shown: Array[String] = []
	for button: Button in bar._hbox().get_children():
		shown.append(str(button.get_meta("type_id")))
	for i: int in range(types.size()):
		assert_has(shown, types[i])
		var cost: Dictionary = state.data.get_building(types[i])["cost"]
		before = _resources(state)
		assert_eq(state.try_place(types[i], positions[i]), Placement.Result.OK, types[i])
		for kind: String in ResourceStore.KINDS:
			assert_eq(state.resources.get_amount(kind), int(before[kind]) - int(cost.get(kind, 0)), types[i])
	bar.free()

func test_red_ghost_and_no_mutation_for_all_obstacles_bounds_and_shortfall() -> void:
	var state: GameState = GameState.new(GameData.load_default(), 1337)
	var mode: BuildMode = BuildMode.new()
	mode.bind(state)
	mode.select("wooden_wall")
	var positions: Array[Vector2i] = [state.map.command_center_origin(), Vector2i(-1, 0), Vector2i(state.map.size(), 0)]
	var expected: Array[int] = [Placement.Result.BLOCKED, Placement.Result.OUT_OF_BOUNDS, Placement.Result.OUT_OF_BOUNDS]
	for occupant: int in [WorldMap.Occupant.TREE, WorldMap.Occupant.ROCK, WorldMap.Occupant.SCRAP]:
		var found: Vector2i = Vector2i(-1, -1)
		for x: int in range(state.map.size()):
			for y: int in range(state.map.size()):
				var tile: Vector2i = Vector2i(x, y)
				if state.map.occupant_at(tile) == occupant:
					found = tile
					break
			if found != Vector2i(-1, -1):
				break
		assert_ne(found, Vector2i(-1, -1))
		positions.append(found)
		expected.append(Placement.Result.BLOCKED)
	state.resources.take("wood", state.resources.get_amount("wood"))
	positions.append(_free_grass(state, Vector2i.ONE))
	expected.append(Placement.Result.UNAFFORDABLE)
	for i: int in range(positions.size()):
		var before: Dictionary = _resources(state)
		var count: int = state.buildings.all().size()
		var occupants: Dictionary = state.map._occupants.duplicate()
		mode.preview_at(positions[i])
		mode._process(0.0)
		assert_true(mode._ghost_sprites[0].visible)
		assert_eq(mode._ghost_sprites[0].modulate, Color(1, 0.35, 0.35, 0.6))
		assert_eq(mode._ghost_labels[0].text, Placement.result_text(expected[i]))
		assert_eq(mode.place_at(positions[i], false), expected[i])
		assert_eq(_resources(state), before)
		assert_eq(state.buildings.all().size(), count)
		assert_eq(state.map._occupants, occupants)
		assert_eq(mode.active_type, "wooden_wall")
	mode.free()

func _resources(state: GameState) -> Dictionary:
	var result: Dictionary = {}
	for kind: String in ResourceStore.KINDS:
		result[kind] = state.resources.get_amount(kind)
	return result

func _free_grass(state: GameState, size: Vector2i) -> Vector2i:
	for x: int in range(state.map.size()):
		for y: int in range(state.map.size()):
			var origin: Vector2i = Vector2i(x, y)
			if not state.map.is_free(origin, size):
				continue
			var grass: bool = true
			for tile: Vector2i in Grid.rect_tiles(origin, size):
				if state.map.terrain_at(tile) != WorldMap.Terrain.GRASS:
					grass = false
			if grass:
				return origin
	return Vector2i(-1, -1)
