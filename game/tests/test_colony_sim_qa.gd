extends TestCase
## T-016: integration coverage using real clock, jobs, movement and dawn dispatch.

const STEP: float = 0.1
const SEED: int = 1337

func _resources(state: GameState) -> Dictionary:
	var amounts: Dictionary = {}
	for kind: String in ResourceStore.KINDS:
		amounts[kind] = state.resources.get_amount(kind)
	return amounts

func _place_complete(state: GameState, type_id: String) -> Building:
	var cc: Vector2i = state.map.command_center_origin()
	for radius: int in range(2, 16):
		for y: int in range(cc.y - radius, cc.y + radius + 1):
			for x: int in range(cc.x - radius, cc.x + radius + 1):
				var origin := Vector2i(x, y)
				var occupied: bool = false
				var size_data: Array = state.data.get_building(type_id)["size"]
				var footprint := Rect2i(origin, Vector2i(int(size_data[0]), int(size_data[1])))
				for s: Survivor in state.survivors.all():
					occupied = occupied or footprint.has_point(s.tile())
				if not occupied and Placement.check(state, type_id, origin) == Placement.Result.OK:
					return state.buildings.add(type_id, origin, true)
	return null

func _run_to_day(state: GameState, target_day: int) -> void:
	var started: int = Time.get_ticks_msec()
	var ticks: int = 0
	var nights_checked: int = 0
	var cycles: int = target_day - state.clock.day
	var cycle_time: float = float(state.data.balance("day_length")) + float(state.data.balance("night_min_length"))
	var limit: int = ceili(cycle_time * cycles / STEP) + cycles + 10
	while state.clock.day < target_day and ticks < limit:
		# Inspect the last night tick BEFORE dawn releases the survivors.
		var previous_day: int = state.clock.day
		var sheltered_before_tick: bool = true
		if state.clock.phase == GameClock.Phase.NIGHT:
			# Guards (one is a default start job since T-027) hold their posts at night.
			for s: Survivor in state.survivors.all():
				sheltered_before_tick = sheltered_before_tick and (s.sheltered or s.job == Survivor.Job.GUARD)
		state.tick(STEP)
		if state.clock.day != previous_day:
			assert_true(sheltered_before_tick, "night %d: everybody sheltered on the tick before dawn" % previous_day)
			nights_checked += 1
		ticks += 1
		assert_true(state.resources.get_amount("food") >= 0, "food cannot go negative")
		for s: Survivor in state.survivors.all():
			assert_true(state.map.is_passable(s.tile()), "tick %d: %s on blocked tile %s" % [ticks, s.name, s.tile()])
	assert_eq(state.clock.day, target_day, "bounded loop reaches the requested dawn")
	assert_eq(nights_checked, cycles, "every night was inspected before dawn")
	assert_lt(Time.get_ticks_msec() - started, 10000, "multi-day integration test stays below 10 seconds")

func test_default_colony_three_days() -> void:
	var state := GameState.new(GameData.load_default(), SEED)
	var reports: Array[Dictionary] = []
	state.dawn_processed.connect(func(report: Dictionary) -> void: reports.append(report))
	var wood: int = state.resources.get_amount("wood")
	var scrap: int = state.resources.get_amount("scrap")
	_run_to_day(state, 4)
	assert_gt(state.resources.get_amount("wood"), wood)
	assert_gt(state.resources.get_amount("scrap"), scrap)
	assert_eq(state.resources.get_amount("food"), 18, "30 starting food minus 4 meals at each of 3 dawns")
	assert_eq(state.survivors.count(), 4)
	assert_eq(reports.size(), 3)
	for i: int in range(reports.size()):
		assert_eq(reports[i]["day"], i + 2)
		assert_eq(reports[i]["food_eaten"], 4)
		assert_true(reports[i]["left"].is_empty())
		assert_true(reports[i]["arrived"].is_empty(), "CC beds equal the starting population")
	for s: Survivor in state.survivors.all():
		assert_eq(s.hungry_days, 0)
	print("T-016 default day4: ", _resources(state))

func test_planned_colony_grows() -> void:
	var state := GameState.new(GameData.load_default(), SEED)
	var farm: Building = _place_complete(state, "farm")
	var shelter: Building = _place_complete(state, "shelter")
	assert_not_null(farm)
	assert_not_null(shelter)
	if farm == null or shelter == null:
		return
	assert_eq(state.buildings.total_beds(), 8)
	var original: Array[Survivor] = state.survivors.all()
	state.set_job(original[0].uid, Survivor.Job.FARMER)
	state.set_job(original[1].uid, Survivor.Job.FARMER)
	state.set_job(original[2].uid, Survivor.Job.GATHERER, "wood")
	state.set_job(original[3].uid, Survivor.Job.BUILDER)
	var reports: Array[Dictionary] = []
	var produced: Array[int] = [0]
	state.dawn_processed.connect(func(report: Dictionary) -> void: reports.append(report))
	state.resource_delivered.connect(func(kind: String, amount: int, _pos: Vector2) -> void:
		if kind == "food":
			produced[0] += amount)
	var food: int = state.resources.get_amount("food")
	_run_to_day(state, 4)
	assert_gt(state.survivors.count(), 4)
	assert_eq(reports.size(), 3)
	assert_gt(reports[0]["arrived"].size(), 0, "first dawn attracts newcomers")
	var eaten: int = 0
	var arrivals: Array[String] = []
	for report: Dictionary in reports:
		eaten += int(report["food_eaten"])
		arrivals.append_array(report["arrived"])
		assert_true(report["left"].is_empty(), "nobody leaves the planned colony")
	assert_gt(state.resources.get_amount("food") - food + eaten, 0, "the farm produced food")
	assert_eq(state.resources.get_amount("food") - food + eaten, produced[0], "food production matches actual delivery events")
	assert_eq(state.survivors.count(), original.size() + arrivals.size())
	var names: Array[String] = []
	for s: Survivor in state.survivors.all():
		assert_false(names.has(s.name), "every survivor has a unique name")
		names.append(s.name)
		assert_eq(s.hungry_days, 0)
		if not original.has(s):
			assert_eq(s.job, Survivor.Job.IDLE)
			assert_has(arrivals, s.name)
	for s: Survivor in original:
		assert_not_null(state.survivors.get_by_uid(s.uid), "every original survivor remains")
	print("T-016 planned day4: population=", state.survivors.count(), " produced=", produced[0], " resources=", _resources(state), " reports=", reports)

func test_starving_colony_loses_people() -> void:
	# Existing dawn tests use clock.advance, not full state.tick loops for starvation.
	var state := GameState.new(GameData.load_default(), SEED)
	state.resources.take("food", state.resources.get_amount("food"))
	var names: Array[String] = []
	for s: Survivor in state.survivors.all():
		names.append(s.name)
	var reports: Array[Dictionary] = []
	state.dawn_processed.connect(func(report: Dictionary) -> void: reports.append(report))
	_run_to_day(state, 2)
	assert_eq(state.survivors.count(), 4)
	assert_eq(reports[0]["hungry"], names)
	assert_true(reports[0]["left"].is_empty())
	for s: Survivor in state.survivors.all():
		assert_eq(s.hungry_days, 1)
	_run_to_day(state, 3)
	assert_eq(state.survivors.count(), 0)
	assert_eq(reports.size(), 2)
	assert_eq(reports[1]["left"], names)
	assert_true(reports[1]["arrived"].is_empty())
	assert_eq(state.resources.get_amount("food"), 0)

func test_same_seed_same_result() -> void:
	var first := GameState.new(GameData.load_default(), SEED)
	var second := GameState.new(GameData.load_default(), SEED)
	_run_to_day(first, 2)
	_run_to_day(second, 2)
	assert_eq(_resources(first), _resources(second))
	assert_eq(first.last_dawn_report, second.last_dawn_report)
	assert_eq(first.survivors.count(), second.survivors.count())
	for i: int in range(first.survivors.count()):
		var a: Survivor = first.survivors.all()[i]
		var b: Survivor = second.survivors.all()[i]
		assert_eq(a.tile(), b.tile())
		assert_eq(a.pos, b.pos, "determinism includes sub-tile positions")
		assert_eq(a.job, b.job)

func test_blueprint_over_stationary_farmer_recovers_and_shelters() -> void:
	var state := GameState.new(GameData.load_default(), SEED)
	for s: Survivor in state.survivors.all():
		state.set_job(s.uid, Survivor.Job.IDLE)
	var farm_origin: Vector2i = state.map.command_center_origin() + Vector2i(0, -3)
	assert_eq(Placement.check(state, "farm", farm_origin), Placement.Result.OK)
	var farm: Building = state.buildings.add("farm", farm_origin, true)
	var worker: Survivor = state.survivors.all()[1]
	state.set_job(worker.uid, Survivor.Job.FARMER)
	state.tick(STEP)
	assert_eq(worker.activity, Survivor.Activity.FARMING)
	assert_eq(worker.work_uid, farm.uid)
	assert_eq(state.try_place("wooden_wall", worker.tile()), Placement.Result.OK)
	state.set_job(state.survivors.all()[0].uid, Survivor.Job.BUILDER)
	for tick: int in range(100):
		state.tick(STEP)
	var recovered: bool = state.map.is_passable(worker.tile())
	state.clock.elapsed = float(state.data.balance("day_length")) - STEP
	for tick: int in range(392):
		state.tick(STEP)
	var entered_shelter: bool = worker.sheltered
	# BUG T-016: a wall placed on a stationary farmer leaves him on solid ground.
	# Pathfinder.find_path_adjacent returns [] for a blocked tile already in the
	# CC ring, so he also remains outside all night. Skip ONLY these two expected
	# behaviour assertions until the backlog fix; all setup assertions still run.
	var check_known_bug: bool = true
	if check_known_bug:
		assert_true(recovered, "covered farmer must leave the impassable tile")
		assert_true(entered_shelter, "covered farmer must reach shelter before dawn")
	print("T-016 known bug: covered farmer recovered=", recovered, " sheltered=", entered_shelter, " tile=", worker.tile())
