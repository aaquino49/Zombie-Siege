class_name TestCoveredSurvivorQA extends TestCase

func test_solid_ring_path_ends_on_passable_ring_and_restores_wall() -> void:
	var state: GameState = GameState.new(GameData.load_default(), 1337)
	var origin: Vector2i = state.map.command_center_origin()
	var start: Vector2i = origin + Vector2i(-1, -1)
	assert_eq(state.try_place("wooden_wall", start), Placement.Result.OK)
	var path: Array[Vector2i] = state.pathfinder.find_path_adjacent(start, origin, Vector2i(2, 2))
	assert_false(path.is_empty(), "a solid start in the ring is not an arrival")
	if path.is_empty():
		return
	assert_true(Grid.in_ring(path.back(), origin, Vector2i(2, 2)))
	for tile: Vector2i in path:
		assert_true(state.map.is_passable(tile), "every returned step is passable")
	assert_false(state.map.is_passable(start), "query leaves the wall intact")
	assert_true(state.pathfinder.find_path(path.back(), start).is_empty())

func test_eviction_resets_work_navigation_and_preserves_assignment_and_cargo() -> void:
	var state: GameState = GameState.new(GameData.load_default(), 1337)
	var worker: Survivor = state.survivors.all()[1]
	worker.job = Survivor.Job.FARMER
	worker.activity = Survivor.Activity.FARMING
	worker.work_uid = 17
	worker.work_tile = worker.tile()
	worker.job_timer = 3.0
	worker.work_acc = 0.5
	worker.gather_kind = "scrap"
	worker.carry_kind = "wood"
	worker.carry_amount = 4
	state.map.occupy(worker.tile(), Vector2i.ONE, "wooden_wall")
	state.survivors.evict_from_solid(state.map)
	assert_true(state.map.is_passable(worker.tile()))
	assert_eq(worker.pos, Grid.tile_to_world(worker.tile()), "snapped to tile centre")
	assert_true(worker.path.is_empty())
	assert_eq(worker.work_tile, Vector2i(-1, -1))
	assert_eq(worker.activity, Survivor.Activity.IDLE)
	assert_eq(worker.job_timer, 0.0)
	assert_eq(worker.job, Survivor.Job.FARMER)
	assert_eq(worker.work_uid, 17)
	assert_eq(worker.work_acc, 0.5)
	assert_eq(worker.gather_kind, "scrap")
	assert_eq(worker.carry_kind, "wood")
	assert_eq(worker.carry_amount, 4)

func test_eviction_preserves_exact_passable_gate_and_sheltered_positions() -> void:
	var state: GameState = GameState.new(GameData.load_default(), 1337)
	var workers: Array[Survivor] = state.survivors.all()
	workers[0].pos += Vector2(7, 3)
	workers[1].pos += Vector2(-5, 2)
	state.map.occupy(workers[1].tile(), Vector2i.ONE, "gate")
	workers[2].sheltered = true
	workers[2].pos = Grid.tile_to_world(state.map.command_center_origin())
	var positions: Array[Vector2] = [workers[0].pos, workers[1].pos, workers[2].pos]
	state.survivors.evict_from_solid(state.map)
	for i: int in range(positions.size()):
		assert_eq(workers[i].pos, positions[i], "eviction must preserve exact allowed positions")

func test_eviction_crosses_solid_footprint_to_nearest_tile_deterministically() -> void:
	var results: Array[Vector2i] = []
	for repetition: int in range(2):
		var state: GameState = GameState.new(GameData.load_default(), 1337)
		var worker: Survivor = state.survivors.all()[0]
		state.set_job(worker.uid, Survivor.Job.IDLE)
		var start: Vector2i = Vector2i(20, 20)
		state.map.vacate(start - Vector2i(2, 2), Vector2i(5, 5))
		state.map.occupy(start - Vector2i.ONE, Vector2i(3, 3), "farm")
		worker.pos = Grid.tile_to_world(start)
		state.tick(0.1)
		assert_true(state.map.is_passable(worker.tile()))
		assert_eq(worker.tile(), start + Vector2i(0, -2), "nearest tile with required up-first tie break")
		results.append(worker.tile())
	assert_eq(results[0], results[1])

func test_covered_assigned_farmer_resumes_work_on_passable_ring() -> void:
	var state: GameState = GameState.new(GameData.load_default(), 1337)
	for survivor: Survivor in state.survivors.all():
		state.set_job(survivor.uid, Survivor.Job.IDLE)
	var origin: Vector2i = state.map.command_center_origin() + Vector2i(0, -3)
	var farm: Building = state.buildings.add("farm", origin, true)
	var worker: Survivor = state.survivors.all()[1]
	state.set_job(worker.uid, Survivor.Job.FARMER)
	state.tick(0.1)
	assert_eq(worker.activity, Survivor.Activity.FARMING)
	assert_eq(worker.work_uid, farm.uid)
	var progress: float = worker.work_acc
	assert_eq(state.try_place("wooden_wall", worker.tile()), Placement.Result.OK)
	state.tick(0.1)
	assert_true(state.map.is_passable(worker.tile()), "covered farmer is evicted within one tick")
	assert_eq(worker.job, Survivor.Job.FARMER)
	for tick: int in range(100):
		state.tick(0.1)
	assert_true(Grid.in_ring(worker.tile(), farm.origin, farm.size))
	assert_true(state.map.is_passable(worker.tile()))
	assert_eq(worker.activity, Survivor.Activity.FARMING, "retained farm assignment must resume work after recovery")
	assert_gt(worker.work_acc, progress, "farmer must continue producing after recovery")
