extends TestCase
## T-011 acceptance checks with explicit setup and successful order assertions.

func _state() -> GameState:
	var state: GameState = GameState.new(GameData.load_default(), 1337)
	state.map.vacate(Vector2i(10, 10), Vector2i(8, 8))
	for s in state.survivors.all():
		state.set_job(s.uid, Survivor.Job.IDLE)
	return state

func test_seed_reproduces_names_tiles_and_variants() -> void:
	var a: GameState = GameState.new(GameData.load_default(), 1337)
	var b: GameState = GameState.new(GameData.load_default(), 1337)
	var first: Array[Survivor] = a.survivors.all()
	var second: Array[Survivor] = b.survivors.all()
	assert_eq(first.size(), 4)
	assert_eq(second.size(), first.size())
	for i: int in range(mini(first.size(), second.size())):
		assert_eq(first[i].name, second[i].name)
		assert_eq(first[i].tile(), second[i].tile())
		assert_eq(first[i].variant, second[i].variant)

func test_diagonals_do_not_cut_corners_and_wall_invalidates_path() -> void:
	var state: GameState = _state()
	var start: Vector2i = Vector2i(11, 11)
	var target: Vector2i = Vector2i(15, 15)
	assert_eq(state.try_place("wooden_wall", start + Vector2i.RIGHT), Placement.Result.OK)
	assert_eq(state.try_place("wooden_wall", start + Vector2i.DOWN), Placement.Result.OK)
	var path: Array[Vector2i] = state.pathfinder.find_path(start, target)
	assert_gt(path.size(), 0)
	var previous: Vector2i = start
	for tile: Vector2i in path:
		var step: Vector2i = tile - previous
		assert_true(absi(step.x) <= 1 and absi(step.y) <= 1 and step != Vector2i.ZERO)
		assert_true(state.map.is_passable(tile))
		if step.x != 0 and step.y != 0:
			assert_true(state.map.is_passable(previous + Vector2i(step.x, 0)))
			assert_true(state.map.is_passable(previous + Vector2i(0, step.y)))
		previous = tile
	if path.is_empty():
		return
	var blocked: Vector2i = path[0]
	assert_eq(state.try_place("wooden_wall", blocked), Placement.Result.OK)
	var rerouted: Array[Vector2i] = state.pathfinder.find_path(start, target)
	assert_gt(rerouted.size(), 0)
	assert_false(rerouted.has(blocked))

func test_gate_is_a_walkable_destination_and_enclosure_is_unreachable() -> void:
	var state: GameState = _state()
	var gate: Vector2i = Vector2i(12, 11)
	assert_eq(state.try_place("gate", gate), Placement.Result.OK)
	var path: Array[Vector2i] = state.pathfinder.find_path(Vector2i(11, 11), gate)
	assert_eq(path, [gate] as Array[Vector2i], "Must actually enter the gate tile")
	var target: Vector2i = Vector2i(15, 15)
	for y: int in range(-1, 2):
		for x: int in range(-1, 2):
			if x == 0 and y == 0:
				continue
			assert_eq(state.try_place("wooden_wall", target + Vector2i(x, y)), Placement.Result.OK)
	assert_true(state.map.is_passable(target), "Target itself is free")
	assert_true(state.pathfinder.find_path(Vector2i(11, 11), target).is_empty())
	assert_true(state.pathfinder.find_path(Vector2i(11, 11), target + Vector2i.RIGHT).is_empty())

func test_adjacent_path_reaches_cc_ring() -> void:
	var state: GameState = GameState.new(GameData.load_default(), 1337)
	var cc: Vector2i = state.map.command_center_origin()
	var path: Array[Vector2i] = state.pathfinder.find_path_adjacent(cc + Vector2i(-4, 0), cc, Vector2i(2, 2))
	assert_gt(path.size(), 0, "A distant free start must reach the CC ring")
	if path.is_empty():
		return
	var last: Vector2i = path.back()
	assert_true(Rect2i(cc - Vector2i.ONE, Vector2i(4, 4)).has_point(last))
	assert_false(Rect2i(cc, Vector2i(2, 2)).has_point(last))
	assert_true(state.map.is_passable(last))
	assert_true(state.pathfinder.find_path_adjacent(last, cc, Vector2i(2, 2)).is_empty())

func test_five_tile_walk_at_1x_2x_and_pause() -> void:
	for speed: int in [1, 2]:
		var state: GameState = _state()
		var survivor: Survivor = state.survivors.all()[0]
		var start: Vector2i = Vector2i(11, 11)
		var target: Vector2i = start + Vector2i(5, 0)
		survivor.pos = Grid.tile_to_world(start)
		assert_true(state.order_move(survivor.uid, target))
		state.clock.set_paused(true)
		var before: Vector2 = survivor.pos
		state.tick(1.0)
		assert_eq(survivor.pos, before)
		assert_true(survivor.is_moving(), "Pause tested on a real pending order")
		state.clock.set_speed(speed)
		if speed == 1:
			for i: int in range(28):
				state.tick(0.1)
			assert_true(survivor.is_moving())
			for i: int in range(2):
				state.tick(0.1)
		else:
			state.tick(1.75)
		assert_false(survivor.is_moving())
		assert_eq(survivor.pos, Grid.tile_to_world(target))

func test_mid_walk_wall_reroutes_and_rejected_tree_order_preserves_order() -> void:
	var state: GameState = _state()
	var survivor: Survivor = state.survivors.all()[0]
	var start: Vector2i = Vector2i(11, 11)
	var target: Vector2i = start + Vector2i(5, 0)
	survivor.pos = Grid.tile_to_world(start)
	assert_true(state.order_move(survivor.uid, target))
	state.tick(0.8)
	var blocked: Vector2i = survivor.path[0]
	assert_eq(state.try_place("wooden_wall", blocked), Placement.Result.OK)
	state.tick(0.1)
	assert_true(survivor.is_moving())
	assert_false(survivor.path.has(blocked))
	var tree: Vector2i = Vector2i(10, 10)
	state.map._occupants[tree] = WorldMap.Occupant.TREE
	state.map.changed.emit()
	var path_before: Array[Vector2i] = survivor.path.duplicate()
	var pos_before: Vector2 = survivor.pos
	assert_false(state.order_move(survivor.uid, tree))
	assert_eq(survivor.target, target)
	assert_eq(survivor.path, path_before)
	assert_eq(survivor.pos, pos_before)
	state.tick(10.0)
	assert_false(survivor.is_moving())
	assert_eq(survivor.pos, Grid.tile_to_world(target))

