extends TestCase

var _state: GameState
var _origin: Vector2i
var _workers: Array[Survivor]

func before_each() -> void:
	_state = GameState.new(GameData.load_default(), 1337)
	_workers = _state.survivors.all()
	for s: Survivor in _workers:
		_state.set_job(s.uid, Survivor.Job.IDLE)
	_origin = _state.map.command_center_origin() + Vector2i(-3, 3)

func _assign(s: Survivor, job: int, origin: Vector2i) -> void:
	_state.set_job(s.uid, job)
	s.pos = Grid.tile_to_world(origin + Vector2i(0, -1))

func _ticks(seconds: float) -> void:
	for i: int in range(int(round(seconds * 10.0))):
		_state.tick(0.1)

func test_workshop_reserves_one_slot_while_walking() -> void:
	var b: Building = _state.buildings.add("workshop", _origin, true)
	for s: Survivor in _workers:
		_state.set_job(s.uid, Survivor.Job.CRAFTER)
	_state.tick(0.1)
	assert_eq(ProductionJob.workers_at(_state, b), int(_state.data.get_building("workshop")["workers"]))
	assert_eq(_workers[0].work_uid, b.uid)
	assert_eq(_workers[0].activity, Survivor.Activity.WALKING)
	for i: int in range(1, _workers.size()):
		assert_eq(_workers[i].work_uid, 0)
		assert_eq(_workers[i].activity, Survivor.Activity.IDLE)
	_ticks(5.0)
	assert_eq(_workers[0].activity, Survivor.Activity.CRAFTING)
	assert_true(Grid.in_ring(_workers[0].tile(), b.origin, b.size))
	assert_true(_state.map.is_passable(_workers[0].tile()))
	assert_eq(ProductionJob.workers_at(_state, b), 1)

func test_both_working_jobs_shelter_and_release_slots_at_night() -> void:
	var farm: Building = _state.buildings.add("farm", _origin, true)
	var workshop_origin: Vector2i = _origin + Vector2i(4, 0)
	var workshop: Building = _state.buildings.add("workshop", workshop_origin, true)
	_assign(_workers[0], Survivor.Job.FARMER, _origin)
	_assign(_workers[1], Survivor.Job.CRAFTER, workshop_origin)
	_state.tick(0.1)
	_workers[0].work_acc = 0.9
	_workers[1].work_acc = float(_state.data.get_building("workshop")["craft_time"]) - 0.5
	_state.clock.phase = GameClock.Phase.NIGHT
	_state.clock.elapsed = 0.0
	var food: int = _state.resources.get_amount("food")
	var ammo: int = _state.resources.get_amount("ammo")
	var scrap: int = _state.resources.get_amount("scrap")
	_ticks(20.0)
	assert_eq(_state.resources.get_amount("food"), food)
	assert_eq(_state.resources.get_amount("ammo"), ammo)
	assert_eq(_state.resources.get_amount("scrap"), scrap)
	# T-056 clears partial work and reservations when workers shelter for the night.
	for s: Survivor in [_workers[0], _workers[1]]:
		assert_almost_eq(s.work_acc, 0.0)
		assert_eq(s.activity, Survivor.Activity.SHELTERED)
		assert_eq(s.work_uid, 0)
		assert_true(s.sheltered)
	assert_eq(ProductionJob.workers_at(_state, farm), 0)
	assert_eq(ProductionJob.workers_at(_state, workshop), 0)

func test_blueprint_workshop_is_not_chosen() -> void:
	_state.buildings.add("workshop", _origin, false)
	_assign(_workers[0], Survivor.Job.CRAFTER, _origin)
	_ticks(2.0)
	assert_eq(_workers[0].work_uid, 0)
	assert_eq(_workers[0].activity, Survivor.Activity.IDLE)

func test_removing_workshop_clears_crafter_progress_and_path() -> void:
	var b: Building = _state.buildings.add("workshop", _origin, true)
	_assign(_workers[0], Survivor.Job.CRAFTER, _origin)
	_ticks(1.0)
	assert_gt(_workers[0].work_acc, 0.0)
	_state.buildings.remove(b.uid)
	_state.tick(0.1)
	assert_eq(_workers[0].work_uid, 0)
	assert_eq(_workers[0].activity, Survivor.Activity.IDLE)
	assert_true(_workers[0].path.is_empty())
	assert_almost_eq(_workers[0].work_acc, 0.0)

func test_zero_scrap_preserves_progress_then_resumes_one_cycle() -> void:
	var b: Building = _state.buildings.add("workshop", _origin, true)
	_assign(_workers[0], Survivor.Job.CRAFTER, _origin)
	_ticks(2.0)
	var progress: float = _workers[0].work_acc
	var ammo: int = _state.resources.get_amount("ammo")
	_state.resources.take("scrap", _state.resources.get_amount("scrap"))
	_ticks(15.0)
	assert_eq(_state.resources.get_amount("scrap"), 0)
	assert_eq(_state.resources.get_amount("ammo"), ammo)
	assert_eq(_workers[0].work_uid, b.uid)
	assert_eq(_workers[0].activity, Survivor.Activity.IDLE)
	assert_almost_eq(_workers[0].work_acc, progress)
	_state.resources.add("scrap", 1)
	var craft_time: float = float(_state.data.get_building("workshop")["craft_time"])
	_ticks(craft_time - progress + 0.2)
	assert_eq(_state.resources.get_amount("ammo"), ammo + int(_state.data.get_building("workshop")["ammo_per_scrap"]))
	assert_eq(_state.resources.get_amount("scrap"), 0)
	_ticks(craft_time * 2.0)
	assert_eq(_state.resources.get_amount("ammo"), ammo + int(_state.data.get_building("workshop")["ammo_per_scrap"]))
	assert_eq(_state.resources.get_amount("scrap"), 0)

func test_multiple_craft_cycles_emit_matching_deliveries() -> void:
	var b: Building = _state.buildings.add("workshop", _origin, true)
	_assign(_workers[0], Survivor.Job.CRAFTER, _origin)
	var deliveries: Array[Dictionary] = []
	_state.resource_delivered.connect(func(kind: String, amount: int, pos: Vector2) -> void:
		deliveries.append({"kind": kind, "amount": amount, "pos": pos})
	)
	var ammo: int = _state.resources.get_amount("ammo")
	var scrap: int = _state.resources.get_amount("scrap")
	var data: Dictionary = _state.data.get_building("workshop")
	_ticks(float(data["craft_time"]) * 3.0 + 0.2)
	assert_eq(_state.resources.get_amount("scrap"), scrap - 3)
	assert_eq(_state.resources.get_amount("ammo"), ammo + 3 * int(data["ammo_per_scrap"]))
	assert_eq(deliveries.size(), 3)
	for delivery: Dictionary in deliveries:
		assert_eq(delivery["kind"], "ammo")
		assert_eq(delivery["amount"], int(data["ammo_per_scrap"]))
		assert_eq(delivery["pos"], b.center_world())

func test_farmer_full_day_at_normal_frame_rate() -> void:
	_state.buildings.add("farm", _origin, true)
	_assign(_workers[0], Survivor.Job.FARMER, _origin)
	var food: int = _state.resources.get_amount("food")
	var day_length: float = float(_state.data.balance("day_length"))
	var frames: int = 0
	while _state.clock.phase == GameClock.Phase.DAY and frames < int(day_length * 60.0) + 2:
		_state.tick(1.0 / 60.0)
		frames += 1
	assert_eq(_state.clock.phase, GameClock.Phase.NIGHT)
	assert_eq(_state.resources.get_amount("food"), food + int(_state.data.get_building("farm")["food_per_farmer"]), "A farmer in the ring at dawn must produce the full daily amount at 60 fps.")

func test_food_deliveries_match_daily_yield_and_farm_position() -> void:
	var farm: Building = _state.buildings.add("farm", _origin, true)
	_assign(_workers[0], Survivor.Job.FARMER, _origin)
	var deliveries: Array[Dictionary] = []
	_state.resource_delivered.connect(func(kind: String, amount: int, pos: Vector2) -> void:
		deliveries.append({"kind": kind, "amount": amount, "pos": pos})
	)
	var day_length: float = float(_state.data.balance("day_length"))
	var ticks: int = 0
	while _state.clock.phase == GameClock.Phase.DAY and ticks < int(day_length * 10.0) + 2:
		_state.tick(0.1)
		ticks += 1
	assert_eq(deliveries.size(), int(_state.data.get_building("farm")["food_per_farmer"]))
	for delivery: Dictionary in deliveries:
		assert_eq(delivery["kind"], "food")
		assert_eq(delivery["amount"], 1)
		assert_eq(delivery["pos"], farm.center_world())

func test_farmer_actually_arrives_and_works_on_passable_ring() -> void:
	var b: Building = _state.buildings.add("farm", _origin, true)
	_state.set_job(_workers[0].uid, Survivor.Job.FARMER)
	for i: int in range(100):
		_state.tick(0.1)
		if _workers[0].activity == Survivor.Activity.FARMING:
			assert_true(Grid.in_ring(_workers[0].tile(), b.origin, b.size))
			assert_true(_state.map.is_passable(_workers[0].tile()))
	assert_eq(_workers[0].activity, Survivor.Activity.FARMING)
	assert_eq(_workers[0].work_uid, b.uid)
