extends TestCase
## T-055: bounds, restoration, adjacent queries and automatic re-pathing.

func _state() -> GameState:
	var state: GameState = GameState.new(GameData.load_default(), 1337)
	state.map.vacate(Vector2i(10, 10), Vector2i(8, 8))
	return state

func test_out_of_bounds_ends_remain_rejected() -> void:
	var state: GameState = _state()
	var free: Vector2i = Vector2i(11, 11)
	var outside: Array[Vector2i] = [Vector2i(-1, 11), Vector2i(state.map.size(), 11), Vector2i(11, -1), Vector2i(11, state.map.size())]
	for tile: Vector2i in outside:
		assert_true(state.pathfinder.find_path(tile, free).is_empty(), "out-of-bounds start")
		assert_true(state.pathfinder.find_path(free, tile).is_empty(), "out-of-bounds target")

func test_empty_query_restores_enclosed_solid_start() -> void:
	var state: GameState = _state()
	var start: Vector2i = Vector2i(12, 12)
	state.map.occupy(start - Vector2i.ONE, Vector2i(3, 3), "wooden_wall")
	assert_true(state.pathfinder.find_path(start, Vector2i(16, 12)).is_empty(), "solid start has no exit")
	assert_true(state.pathfinder._astar.is_point_solid(start), "restore even when get_id_path is empty")
	assert_false(state.map.is_passable(start), "map occupancy remains intact")
	assert_true(state.pathfinder.find_path(Vector2i(16, 12), start).is_empty(), "solid destination remains rejected")

func test_adjacent_query_can_leave_solid_start() -> void:
	var state: GameState = _state()
	var start: Vector2i = Vector2i(11, 11)
	var origin: Vector2i = Vector2i(15, 13)
	state.map.occupy(start, Vector2i.ONE, "wooden_wall")
	state.map.occupy(origin, Vector2i(2, 2), "farm")
	var path: Array[Vector2i] = state.pathfinder.find_path_adjacent(start, origin, Vector2i(2, 2))
	assert_gt(path.size(), 0, "adjacent query must use the solid-start fix")
	if path.is_empty():
		return
	var previous: Vector2i = start
	for tile: Vector2i in path:
		var step: Vector2i = tile - previous
		assert_true(absi(step.x) <= 1 and absi(step.y) <= 1 and step != Vector2i.ZERO, "8-neighbour step excluding start")
		assert_true(state.map.is_passable(tile))
		previous = tile
	assert_true(Rect2i(origin - Vector2i.ONE, Vector2i(4, 4)).has_point(path.back()))
	assert_false(Rect2i(origin, Vector2i(2, 2)).has_point(path.back()))
	assert_true(state.pathfinder.find_path(path.back(), start).is_empty(), "query restored solid start")

func test_tick_repaths_after_farm_covers_starting_survivor() -> void:
	var state: GameState = GameState.new(GameData.load_default(), 1337)
	var survivor: Survivor = state.survivors.all()[0]
	var start: Vector2i = survivor.tile()
	var target: Vector2i = start + Vector2i(-5, 0)
	assert_true(state.map.is_passable(target))
	state.set_job(survivor.uid, Survivor.Job.IDLE)
	assert_true(state.order_move(survivor.uid, target), "order before construction")
	if survivor.path.is_empty():
		return
	var blocked_next: Vector2i = survivor.path[0]
	assert_eq(state.try_place("farm", start - Vector2i.ONE), Placement.Result.OK, "native seed layout permits farm over starting survivor")
	assert_eq(state.map.building_at(start), "farm")
	assert_false(state.map.is_passable(blocked_next), "construction blocks pending next step and triggers re-path")
	state.tick(0.1)
	assert_true(survivor.is_moving(), "tick finds an exit from solid current tile")
	assert_false(survivor.path.has(blocked_next))
	for i: int in range(100):
		state.tick(0.1)
	assert_false(survivor.is_moving())
	assert_eq(survivor.tile(), target)
	assert_eq(survivor.pos, Grid.tile_to_world(target), "automatic re-path arrives at exact centre")
	assert_eq(state.map.building_at(start), "farm", "construction remains intact")
