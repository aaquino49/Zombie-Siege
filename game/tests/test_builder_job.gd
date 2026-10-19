extends TestCase
## T-012 acceptance: timing, unattended building, repairs and paused work.

var _state: GameState
var _origin: Vector2i
var _builder: Survivor

func before_each() -> void:
	_state = GameState.new(GameData.load_default(), 1337)
	for s in _state.survivors.all():
		_state.set_job(s.uid, Survivor.Job.IDLE)
	_origin = _state.map.command_center_origin() + Vector2i(-3, 3)
	_builder = _state.survivors.all()[0]
	_state.set_job(_builder.uid, Survivor.Job.BUILDER)

func _adjacent_wall() -> Building:
	assert_eq(_state.try_place("wooden_wall", _origin), Placement.Result.OK)
	_builder.pos = Grid.tile_to_world(_origin + Vector2i(0, -1))
	return _state.buildings.get_at(_origin)

func _farm() -> Building:
	assert_eq(_state.try_place("farm", _origin), Placement.Result.OK)
	var farm: Building = _state.buildings.get_at(_origin)
	_state.buildings.finish(farm.uid)
	farm.hp = farm.max_hp / 2
	_builder.pos = Grid.tile_to_world(_origin + Vector2i(0, -1))
	return farm

func _ticks(count: int) -> void:
	for i in range(count):
		_state.tick(0.1)

func test_one_adjacent_builder_completes_between_2_3_and_2_6_seconds_once() -> void:
	var b: Building = _adjacent_wall()
	var completed: Array[Building] = []
	_state.buildings.building_completed.connect(func(done: Building) -> void: completed.append(done))
	_ticks(23)
	assert_false(b.complete, "Must still be a blueprint at 2.3 seconds")
	assert_almost_eq(b.progress, 2.3)
	assert_eq(completed.size(), 0)
	_ticks(3)
	assert_true(b.complete, "Must finish by 2.6 seconds")
	assert_eq(b.hp, b.max_hp)
	assert_eq(completed, [b])
	_ticks(20)
	assert_eq(completed, [b], "Completion signal is emitted only once")

func test_two_adjacent_builders_complete_by_1_3_seconds_once() -> void:
	var b: Building = _adjacent_wall()
	var second: Survivor = _state.survivors.all()[1]
	_state.set_job(second.uid, Survivor.Job.BUILDER)
	second.pos = Grid.tile_to_world(_origin + Vector2i(1, -1))
	var completed: Array[Building] = []
	_state.buildings.building_completed.connect(func(done: Building) -> void: completed.append(done))
	_ticks(11)
	assert_false(b.complete)
	_ticks(2)
	assert_true(b.complete)
	assert_eq(b.hp, b.max_hp)
	assert_eq(completed, [b])

func test_distant_builder_walks_to_two_blueprints_without_orders() -> void:
	# Clear a reproducible corridor and add a solid obstacle to exercise routing.
	for y in range(26, 31):
		for x in range(13, 25):
			_state.map.vacate(Vector2i(x, y), Vector2i.ONE)
	_state.buildings.add("wooden_wall", Vector2i(17, 28), true)
	var first_tile: Vector2i = Vector2i(20, 28)
	var second_tile: Vector2i = Vector2i(23, 28)
	assert_eq(_state.try_place("wooden_wall", first_tile), Placement.Result.OK)
	assert_eq(_state.try_place("wooden_wall", second_tile), Placement.Result.OK)
	var first: Building = _state.buildings.get_at(first_tile)
	var second: Building = _state.buildings.get_at(second_tile)
	_builder.pos = Grid.tile_to_world(Vector2i(13, 28))
	var start: Vector2 = _builder.pos
	var completed: Array[Building] = []
	_state.buildings.building_completed.connect(func(done: Building) -> void: completed.append(done))
	_state.tick(0.1)
	assert_eq(_builder.activity, Survivor.Activity.WALKING)
	assert_eq(_builder.work_uid, first.uid)
	assert_ne(_builder.pos, start)
	assert_true(_state.map.is_passable(_builder.target))
	var saw_second_walk: bool = false
	for i in range(400):
		_state.tick(0.1)
		assert_true(_state.map.is_passable(_builder.tile()), "Never enters an impassable tile")
		for t: Vector2i in _builder.path:
			assert_true(_state.map.is_passable(t), "Path contains passable tiles only")
		if _builder.work_uid == second.uid and _builder.activity == Survivor.Activity.WALKING:
			saw_second_walk = true
		if second.complete:
			break
	assert_true(first.complete)
	assert_true(second.complete)
	assert_true(saw_second_walk)
	assert_eq(completed, [first, second])

func test_repair_farm_charges_exactly_three_wood_once_and_restores_hp() -> void:
	var farm: Building = _farm()
	assert_eq(Construction.repair_cost(_state.data, farm), 3)
	var wood: int = _state.resources.get_amount("wood")
	var charges: Array[int] = []
	_state.resources.changed.connect(func(kind: String, amount: int) -> void:
		if kind == "wood":
			charges.append(amount)
	)
	_state.tick(0.1)
	assert_eq(_builder.activity, Survivor.Activity.REPAIRING)
	assert_eq(_state.resources.get_amount("wood"), wood - 3)
	_ticks(80)
	assert_eq(farm.hp, farm.max_hp)
	assert_eq(_state.resources.get_amount("wood"), wood - 3)
	assert_eq(charges, [wood - 3])
	assert_eq(Construction.repair_cost(_state.data, farm), 0)
	assert_eq(_builder.work_uid, 0)

func test_zero_duration_command_center_repair_is_instant_and_free() -> void:
	var cc: Building = _state.buildings.get_at(_state.map.command_center_origin())
	assert_eq(_state.clock.phase, GameClock.Phase.DAY)
	assert_true(_state.buildings.blueprints().is_empty())
	assert_eq(cc.build_time, 0.0)
	cc.hp = cc.max_hp - 100
	_builder.pos = Grid.tile_to_world(_state.cc_ring_tiles()[0])
	assert_true(Grid.in_ring(_builder.tile(), cc.origin, cc.size))
	assert_eq(Construction.repair_cost(_state.data, cc), 0)
	var wood: int = _state.resources.get_amount("wood")
	_state.tick(0.1)
	assert_eq(cc.hp, cc.max_hp)
	assert_eq(_state.resources.get_amount("wood"), wood)
	assert_eq(_builder.work_uid, 0)
	assert_eq(_builder.job_timer, 0.0)
	assert_eq(_builder.activity, Survivor.Activity.IDLE)
	_ticks(4)
	assert_eq(cc.hp, cc.max_hp)
	assert_eq(_state.resources.get_amount("wood"), wood)
	assert_eq(_builder.work_uid, 0)
	assert_eq(_builder.activity, Survivor.Activity.IDLE)

func test_no_repair_starts_at_night() -> void:
	var farm: Building = _farm()
	_state.clock.phase = GameClock.Phase.NIGHT
	_state.clock.elapsed = 0.0
	var wood: int = _state.resources.get_amount("wood")
	_ticks(50)
	assert_eq(farm.hp, farm.max_hp / 2)
	assert_eq(_state.resources.get_amount("wood"), wood)
	assert_eq(_builder.activity, Survivor.Activity.SHELTERED)
	assert_eq(_builder.work_uid, 0)
	assert_true(_builder.sheltered) # Night work is interrupted by sheltering (T-056).

func test_no_repair_starts_without_wood() -> void:
	var farm: Building = _farm()
	_state.resources.take("wood", _state.resources.get_amount("wood"))
	_ticks(50)
	assert_eq(farm.hp, farm.max_hp / 2)
	assert_eq(_state.resources.get_amount("wood"), 0)
	assert_eq(_builder.activity, Survivor.Activity.IDLE)
	assert_eq(_builder.work_uid, 0)

func test_builder_without_work_and_idle_survivors_do_not_move() -> void:
	var positions: Array[Vector2] = []
	for s: Survivor in _state.survivors.all():
		positions.append(s.pos)
	_ticks(50)
	var survivors: Array[Survivor] = _state.survivors.all()
	for i in range(survivors.size()):
		assert_eq(survivors[i].pos, positions[i])
		assert_eq(survivors[i].activity, Survivor.Activity.IDLE)

func test_pause_stops_building_movement_and_clock() -> void:
	var b: Building = _adjacent_wall()
	_ticks(10)
	var progress: float = b.progress
	var second: Survivor = _state.survivors.all()[1]
	assert_true(_state.order_move(second.uid, second.tile() + Vector2i(0, -2)))
	var pos: Vector2 = second.pos
	var elapsed: float = _state.clock.elapsed
	var timer: float = _builder.job_timer
	_state.clock.set_paused(true)
	_ticks(50)
	assert_eq(b.progress, progress)
	assert_eq(second.pos, pos)
	assert_eq(_state.clock.elapsed, elapsed)
	assert_eq(_builder.job_timer, timer)

func test_pause_stops_active_repair_and_payment() -> void:
	var farm: Building = _farm()
	_state.tick(0.1)
	var hp: int = farm.hp
	var wood: int = _state.resources.get_amount("wood")
	var acc: float = _builder.work_acc
	_state.clock.set_paused(true)
	_ticks(50)
	assert_eq(farm.hp, hp)
	assert_eq(_state.resources.get_amount("wood"), wood)
	assert_eq(_builder.work_acc, acc)
