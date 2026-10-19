extends TestCase
## T-012 acceptance: blueprint lifecycle, refunds, helpers and job assignment.

var _state: GameState
var _origin: Vector2i

func before_each() -> void:
	_state = GameState.new(GameData.load_default(), 1337)
	_origin = _state.map.command_center_origin() + Vector2i(-3, 3)

func _wall() -> Building:
	assert_eq(_state.try_place("wooden_wall", _origin), Placement.Result.OK)
	return _state.buildings.get_at(_origin)

func test_placement_is_paid_occupied_zero_progress_blueprint() -> void:
	var wood: int = _state.resources.get_amount("wood")
	var b: Building = _wall()
	assert_not_null(b)
	if b == null:
		return
	assert_false(b.complete)
	assert_eq(b.progress, 0.0)
	assert_eq(b.build_time, 2.5)
	assert_eq(_state.resources.get_amount("wood"), wood - 5)
	assert_eq(_state.map.building_at(_origin), "wooden_wall")
	assert_false(_state.map.is_passable(_origin))
	var cc: Building = _state.buildings.all()[0]
	assert_true(cc.complete)
	assert_eq(cc.progress_ratio(), 1.0)

func test_default_jobs_and_optional_start_job_entries() -> void:
	var survivors: Array[Survivor] = _state.survivors.all()
	assert_eq(survivors[0].job, Survivor.Job.BUILDER)
	assert_eq(survivors[1].job, Survivor.Job.GATHERER)
	assert_eq(survivors[1].gather_kind, "wood")
	assert_eq(survivors[2].job, Survivor.Job.GATHERER)
	assert_eq(survivors[2].gather_kind, "scrap")
	assert_eq(survivors[3].job, Survivor.Job.GUARD)
	var data: GameData = GameData.load_default()
	data._balance.erase("start_jobs")
	var missing: GameState = GameState.new(data, 1337)
	for s: Survivor in missing.survivors.all():
		assert_eq(s.job, Survivor.Job.IDLE)
	data._balance["start_jobs"] = ["builder", "unknown"]
	var short_list: GameState = GameState.new(data, 1337)
	assert_eq(short_list.survivors.all()[0].job, Survivor.Job.BUILDER)
	for i in range(1, short_list.survivors.count()):
		assert_eq(short_list.survivors.all()[i].job, Survivor.Job.IDLE)

func test_finish_is_idempotent_restores_hp_and_queries_sort_by_uid() -> void:
	var b: Building = _wall()
	var other: Building = _state.buildings.add("gate", _origin + Vector2i(2, 0), false)
	assert_eq(_state.buildings.blueprints(), [b, other])
	var completed: Array[Building] = []
	_state.buildings.building_completed.connect(func(done: Building) -> void: completed.append(done))
	b.hp = 1
	_state.buildings.finish(b.uid)
	_state.buildings.finish(b.uid)
	_state.buildings.finish(99999)
	assert_eq(completed, [b])
	assert_true(b.complete)
	assert_eq(b.progress, b.build_time)
	assert_eq(b.hp, b.max_hp)
	assert_eq(_state.buildings.blueprints(), [other])
	b.hp -= 1
	assert_true(b.is_damaged())
	assert_false(other.is_damaged())
	assert_eq(_state.buildings.damaged(), [b])
	assert_eq(Construction.repair_cost(_state.data, other), 0)

func test_untouched_cancel_refunds_all_and_frees_tile() -> void:
	var wood: int = _state.resources.get_amount("wood")
	var b: Building = _wall()
	assert_eq(Construction.refund_fraction(_state.data, b), 1.0)
	assert_true(_state.cancel_building(b.uid))
	assert_eq(_state.resources.get_amount("wood"), wood)
	assert_true(_state.map.is_passable(_origin))
	assert_eq(_state.buildings.get_at(_origin), null)
	assert_false(_state.cancel_building(b.uid))

func test_worked_cancel_refunds_floor_half_and_clears_builder() -> void:
	var wood: int = _state.resources.get_amount("wood")
	var b: Building = _wall()
	var s: Survivor = _state.survivors.all()[0]
	s.pos = Grid.tile_to_world(_origin + Vector2i(0, -1))
	for i in range(10):
		_state.tick(0.1)
	assert_almost_eq(b.progress, 1.0)
	assert_eq(Construction.refund_fraction(_state.data, b), 0.5)
	assert_true(_state.cancel_building(b.uid))
	assert_eq(_state.resources.get_amount("wood"), wood - 5 + 2)
	assert_true(_state.map.is_passable(_origin))
	_state.tick(0.1)
	assert_eq(s.work_uid, 0)
	assert_eq(s.activity, Survivor.Activity.IDLE)
	assert_false(s.is_moving())

func test_complete_building_and_command_center_cannot_cancel() -> void:
	var b: Building = _wall()
	_state.buildings.finish(b.uid)
	var wood: int = _state.resources.get_amount("wood")
	var count: int = _state.buildings.all().size()
	assert_false(_state.cancel_building(b.uid))
	assert_false(_state.cancel_building(_state.buildings.all()[0].uid))
	assert_false(_state.cancel_building(99999))
	assert_eq(_state.resources.get_amount("wood"), wood)
	assert_eq(_state.buildings.all().size(), count)
	assert_eq(_state.map.building_at(_origin), "wooden_wall")

func test_set_job_clears_work_and_path_without_moving() -> void:
	var s: Survivor = _state.survivors.all()[0]
	var pos: Vector2 = s.pos
	s.path = [s.tile() + Vector2i(1, 0)]
	s.work_uid = 123
	s.work_acc = 0.75
	s.job_timer = 0.8
	s.activity = Survivor.Activity.BUILDING
	assert_false(_state.set_job(99999, Survivor.Job.BUILDER))
	assert_true(_state.set_job(s.uid, Survivor.Job.GATHERER))
	assert_eq(s.job, Survivor.Job.GATHERER)
	assert_eq(s.pos, pos)
	assert_true(s.path.is_empty())
	assert_eq(s.work_uid, 0)
	assert_eq(s.work_acc, 0.0)
	assert_eq(s.job_timer, 0.0)
	assert_eq(s.activity, Survivor.Activity.IDLE)

func test_ring_excludes_footprint_and_includes_all_eight_neighbours() -> void:
	var size: Vector2i = Vector2i(2, 2)
	for y in range(-1, 3):
		for x in range(-1, 3):
			var inside: bool = x >= 0 and x < 2 and y >= 0 and y < 2
			assert_eq(Grid.in_ring(_origin + Vector2i(x, y), _origin, size), not inside)
	assert_false(Grid.in_ring(_origin + Vector2i(3, 0), _origin, size))
	assert_false(Grid.in_ring(_origin + Vector2i(-2, 0), _origin, size))
