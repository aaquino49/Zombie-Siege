extends TestCase

var _state: GameState
var _data: GameData
var _need: int
var _pop: int

func before_each() -> void:
	_data = GameData.load_default()
	_state = GameState.new(_data, 1337)
	_need = int(_data.balance("food_eat_per_survivor"))
	_pop = int(_data.balance("start_survivors"))
	for s: Survivor in _state.survivors.all():
		_state.set_job(s.uid, Survivor.Job.IDLE)

func _food(amount: int) -> void:
	_state.resources.take("food", _state.resources.get_amount("food"))
	_state.resources.add("food", amount)

func _cycle() -> float:
	return float(_data.balance("day_length")) + float(_data.balance("night_min_length"))

func _shelter(complete: bool = true) -> Building:
	var origin: Vector2i = _state.map.command_center_origin() + Vector2i(-4, 3)
	_state.map.vacate(origin, Vector2i(2, 2))
	return _state.buildings.add("shelter", origin, complete)

func test_everyone_eats_and_report_is_typed() -> void:
	var food: int = int(_data.balance("start_food"))
	var report: Dictionary = DawnRules.process(_state)
	assert_eq(_state.resources.get_amount("food"), food - _pop * _need)
	assert_eq(report["food_eaten"], _pop * _need)
	assert_eq(report["day"], _state.clock.day)
	for key: String in ["hungry", "left", "arrived"]:
		var names: Array = report[key]
		assert_true(names.is_typed())
		assert_eq(names.get_typed_builtin(), TYPE_STRING)
		assert_true(names.is_empty())
	for s: Survivor in _state.survivors.all():
		assert_false(s.is_hungry())

func test_short_food_uses_uid_order_and_reports_staying_hungry() -> void:
	var eaters: int = _pop / 2
	_food(eaters * _need)
	var report: Dictionary = DawnRules.process(_state)
	var hungry: Array[String] = []
	var survivors: Array[Survivor] = _state.survivors.all()
	for i: int in range(_pop):
		assert_eq(survivors[i].hungry_days, 0 if i < eaters else 1)
		if i >= eaters:
			hungry.append(survivors[i].name)
	assert_eq(report["hungry"], hungry)
	assert_eq(report["food_eaten"], eaters * _need)
	assert_eq(_state.resources.get_amount("food"), 0)

func test_hungriest_eats_first_and_recovers() -> void:
	var survivors: Array[Survivor] = _state.survivors.all()
	var hungry: Survivor = survivors.back()
	hungry.hungry_days = int(_data.balance("food_hungry_leave_days")) - 1
	_food(_need)
	DawnRules.process(_state)
	assert_eq(hungry.hungry_days, 0)
	assert_false(hungry.is_hungry())
	assert_eq(survivors[0].hungry_days, 1)
	assert_eq(_state.survivors.count(), _pop)

func test_second_unfed_dawn_removes_survivor_and_loses_cargo() -> void:
	var s: Survivor = _state.survivors.all()[0]
	s.hungry_days = int(_data.balance("food_hungry_leave_days")) - 1
	s.carry_kind = "wood"
	s.carry_amount = int(_data.balance("carry_capacity"))
	var wood: int = _state.resources.get_amount("wood")
	var removed: Array[Survivor] = []
	_state.survivors.survivor_removed.connect(func(left: Survivor) -> void: removed.append(left))
	_food(0)
	var report: Dictionary = DawnRules.process(_state)
	assert_eq(removed, [s])
	assert_eq(_state.survivors.count(), _pop - 1)
	assert_eq(_state.survivors.get_by_uid(s.uid), null)
	assert_eq(report["left"], [s.name])
	assert_false(report["hungry"].has(s.name))
	assert_eq(_state.resources.get_amount("wood"), wood)

func test_only_complete_buildings_supply_beds() -> void:
	var cc_beds: int = int(_data.get_building("command_center")["beds"])
	var shelter_beds: int = int(_data.get_building("shelter")["beds"])
	assert_eq(_state.buildings.total_beds(), cc_beds)
	var shelter: Building = _shelter(false)
	assert_eq(_state.buildings.total_beds(), cc_beds)
	assert_true(DawnRules.process(_state)["arrived"].is_empty())
	_state.buildings.finish(shelter.uid)
	assert_eq(_state.buildings.total_beds(), cc_beds + shelter_beds)
	_state.buildings.add("farm", Vector2i(5, 5), true)
	assert_eq(_state.buildings.total_beds(), cc_beds + shelter_beds)
	_state.buildings.remove(_state.buildings.all_of_type("command_center")[0].uid)
	assert_eq(_state.buildings.total_beds(), shelter_beds)

func test_newcomers_at_exact_post_meal_threshold_seeded_identity_and_tile() -> void:
	_shelter()
	_food(_pop * (_need + int(_data.balance("food_newcomers_threshold"))))
	var ring: Array[Vector2i] = _state.cc_ring_tiles()
	var used_names: Array[String] = []
	for s: Survivor in _state.survivors.all():
		used_names.append(s.name)
	var expected_rng := RandomNumberGenerator.new()
	expected_rng.seed = 1337 + 2
	var expected: int = expected_rng.randi_range(int(_data.balance("food_newcomers_min")), int(_data.balance("food_newcomers_max")))
	# Seed 1339 draws the configured maximum (2 in the shipped data).
	assert_eq(expected, int(_data.balance("food_newcomers_max")))
	var report: Dictionary = DawnRules.process(_state)
	assert_eq(report["arrived"].size(), expected)
	assert_eq(_state.survivors.count(), _pop + expected)
	var names: Array = _data.balance("survivor_names")
	var variants: Array = _data.balance("survivor_variants")
	for i: int in range(expected):
		var s: Survivor = _state.survivors.all()[_pop + i]
		var expected_name: String = ""
		for candidate: String in names:
			if not used_names.has(candidate):
				expected_name = candidate
				break
		assert_eq(s.name, expected_name)
		used_names.append(s.name)
		assert_eq(s.variant, variants[(s.uid - 1) % variants.size()])
		assert_eq(s.tile(), ring[_pop + i])
		assert_true(_state.map.is_passable(s.tile()))
		assert_eq(s.job, Survivor.Job.IDLE)
		assert_false(s.is_hungry())
		assert_eq(report["arrived"][i], s.name)

func test_cap_food_gate_and_empty_colony() -> void:
	_shelter()
	var beds: int = _state.buildings.total_beds()
	while _state.survivors.count() < beds - 1:
		_state.survivors.add("Extra %d" % _state.survivors.count(), "blue", _state.cc_ring_tiles().back())
	var pop: int = _state.survivors.count()
	var threshold: int = int(_data.balance("food_newcomers_threshold"))
	_food(pop * (_need + threshold) - 1)
	assert_true(DawnRules.process(_state)["arrived"].is_empty())
	_food(pop * (_need + threshold))
	assert_eq(DawnRules.process(_state)["arrived"].size(), 1)
	assert_eq(_state.survivors.count(), beds)
	_food(beds * (_need + threshold))
	assert_true(DawnRules.process(_state)["arrived"].is_empty())
	for s: Survivor in _state.survivors.all():
		_state.survivors.remove(s.uid)
	assert_true(DawnRules.process(_state)["arrived"].is_empty())

func test_arrivals_use_population_after_leaving() -> void:
	var leave_days: int = int(_data.balance("food_hungry_leave_days"))
	var survivors: Array[Survivor] = _state.survivors.all()
	# Three overdue survivors, with only enough food for two: one leaves.
	for i: int in range(_pop - 1):
		survivors[i].hungry_days = leave_days
	_food((_pop - 2) * _need)
	var report: Dictionary = DawnRules.process(_state)
	assert_eq(report["left"], [survivors[_pop - 2].name])
	assert_eq(_state.survivors.count(), _pop - 1)

func test_name_exhaustion_and_occupied_ring_fallback() -> void:
	var names: Array = _data.balance("survivor_names")
	var ring: Array[Vector2i] = _state.cc_ring_tiles()
	for s: Survivor in _state.survivors.all():
		_state.survivors.remove(s.uid)
	for i: int in range(names.size()):
		_state.survivors.add(names[i], "blue", ring[i % ring.size()])
	for i: int in range(names.size() / int(_data.get_building("shelter")["beds"]) + 1):
		_state.buildings.add("shelter", Vector2i(2 + i * 3, 2), true)
	var pop: int = _state.survivors.count()
	_food(pop * (_need + int(_data.balance("food_newcomers_threshold"))))
	var next_uid: int = _state.survivors.next_uid()
	var report: Dictionary = DawnRules.process(_state)
	assert_gt(report["arrived"].size(), 0)
	for i: int in range(report["arrived"].size()):
		var s: Survivor = _state.survivors.get_by_uid(next_uid + i)
		assert_eq(s.name, "Survivor %d" % s.uid)
		assert_eq(s.tile(), ring[0])

func test_clock_and_tick_process_each_dawn_once() -> void:
	var reports: Array[Dictionary] = []
	_state.dawn_processed.connect(func(report: Dictionary) -> void: reports.append(report))
	assert_true(_state.last_dawn_report.is_empty())
	_state.clock.advance(_cycle() * 2 + float(_data.balance("day_length")) / 2)
	assert_eq(reports.size(), 2)
	assert_eq(reports[0]["day"], 2)
	assert_eq(reports[1]["day"], 3)
	assert_eq(_state.last_dawn_report, reports.back())
	assert_eq(_state.resources.get_amount("food"), int(_data.balance("start_food")) - 2 * _pop * _need)
	_state.tick(_cycle() * 2)
	assert_eq(reports.size(), 4)
	assert_eq(_state.last_dawn_report["day"], 5)
	_state.clock.set_paused(true)
	_state.tick(_cycle())
	assert_eq(reports.size(), 4)

func test_seed_1337_starting_survivors_unchanged() -> void:
	var names: Array[String] = ["David", "Frank", "Grace", "Victor"]
	var origin: Vector2i = _state.map.command_center_origin()
	var jobs: Array = _data.balance("start_jobs")
	var variants: Array = _data.balance("survivor_variants")
	var original := GameState.new(_data, 1337)
	for i: int in range(_pop):
		var s: Survivor = original.survivors.all()[i]
		assert_eq(s.name, names[i])
		assert_eq(s.tile(), origin + Vector2i(i - 1, -1))
		assert_eq(s.job, Survivor.job_from_name(jobs[i]))
		assert_eq(s.variant, variants[i])
		if str(jobs[i]).begins_with("gatherer_"):
			assert_eq(s.gather_kind, str(jobs[i]).trim_prefix("gatherer_"))

func test_hungry_gatherers_move_and_harvest_at_data_speed() -> void:
	var pair: Array[Survivor] = [_state.survivors.all()[0], _state.survivors.all()[1]]
	var start: Vector2i = _state.cc_ring_tiles()[0]
	var factor: float = float(_data.balance("food_hungry_speed"))
	pair[1].hungry_days = 1
	for s: Survivor in pair:
		s.pos = Grid.tile_to_world(start)
		s.target = start + Vector2i(0, -2)
		_state.map.vacate(s.target, Vector2i.ONE)
		s.path.assign([start + Vector2i(0, -1), s.target])
	var dt: float = float(Grid.TILE) / float(_data.balance("survivor_speed")) / 2.0
	_state.survivors.tick(dt, _state.pathfinder, _state.map)
	var distance: float = pair[0].pos.distance_to(Grid.tile_to_world(start))
	assert_gt(distance, 0.0)
	assert_almost_eq(pair[1].pos.distance_to(Grid.tile_to_world(start)), distance * factor, distance * 0.1)
	var tree: Vector2i = _state.map.nodes_of(WorldMap.Occupant.TREE)[0]
	_state.map.vacate(tree + Vector2i.LEFT, Vector2i.ONE)
	for s: Survivor in pair:
		_state.set_job(s.uid, Survivor.Job.GATHERER, "wood")
		s.pos = Grid.tile_to_world(tree + Vector2i.LEFT)
		s.work_tile = tree
		s.activity = Survivor.Activity.HARVESTING
	var gather_time: float = float(_data.balance("gather_time_wood"))
	Jobs.tick(_state, gather_time * 4)
	assert_eq(pair[0].carry_amount, 4)
	assert_eq(pair[1].carry_amount, int(4 * factor))

func test_hungry_builder_and_repair_speed() -> void:
	var normal := GameState.new(_data, 1337)
	var factor: float = float(_data.balance("food_hungry_speed"))
	var buildings: Array[Building] = []
	for state: GameState in [normal, _state]:
		for s: Survivor in state.survivors.all():
			state.set_job(s.uid, Survivor.Job.IDLE)
		var origin: Vector2i = state.map.command_center_origin() + Vector2i(-3, 3)
		var b: Building = state.buildings.add("farm", origin, false)
		buildings.append(b)
		var s: Survivor = state.survivors.all()[0]
		state.set_job(s.uid, Survivor.Job.BUILDER)
		s.pos = Grid.tile_to_world(origin + Vector2i.UP)
		s.hungry_days = 1 if state == _state else 0
	var dt: float = float(_data.get_building("farm")["build_time"]) / 10
	Jobs.tick(normal, dt)
	Jobs.tick(_state, dt)
	assert_almost_eq(buildings[1].progress, buildings[0].progress * factor)
	for i: int in range(2):
		var state: GameState = normal if i == 0 else _state
		state.buildings.finish(buildings[i].uid)
		buildings[i].hp = 1
		var s: Survivor = state.survivors.all()[0]
		state.set_job(s.uid, Survivor.Job.BUILDER)
	Jobs.tick(normal, dt)
	Jobs.tick(_state, dt)
	assert_almost_eq(float(buildings[1].hp - 1), float(buildings[0].hp - 1) * factor, 1.0)

func test_hungry_farming_and_crafting_speed() -> void:
	var factor: float = float(_data.balance("food_hungry_speed"))
	for job: int in [Survivor.Job.FARMER, Survivor.Job.CRAFTER]:
		var pair: Array[Survivor] = [_state.survivors.all()[0], _state.survivors.all()[1]]
		var type_id: String = ProductionJob.building_type_for(job)
		for i: int in range(2):
			var origin: Vector2i = _state.map.command_center_origin() + Vector2i(-5 + 6 * i, 4)
			var b: Building = _state.buildings.add(type_id, origin, true)
			_state.set_job(pair[i].uid, job)
			pair[i].pos = Grid.tile_to_world(origin + Vector2i.UP)
			pair[i].work_uid = b.uid
			pair[i].activity = Survivor.Activity.FARMING if job == Survivor.Job.FARMER else Survivor.Activity.CRAFTING
			pair[i].hungry_days = i
		var dt: float = float(_data.get_building("workshop")["craft_time"]) / 4
		Jobs.tick(_state, dt)
		assert_gt(pair[0].work_acc, 0.0)
		assert_almost_eq(pair[1].work_acc, pair[0].work_acc * factor)

func test_two_consecutive_hungry_dawns_empty_the_colony() -> void:
	_food(0)
	var leave_days: int = int(_data.balance("food_hungry_leave_days"))
	for day: int in range(leave_days):
		_state.clock.advance(_cycle())
		if day < leave_days - 1:
			assert_eq(_state.survivors.count(), _pop)
			assert_eq(_state.last_dawn_report["hungry"].size(), _pop)
	assert_eq(_state.survivors.count(), 0)
	assert_eq(_state.last_dawn_report["left"].size(), _pop)
	assert_true(_state.last_dawn_report["hungry"].is_empty())
	assert_true(_state.last_dawn_report["arrived"].is_empty())

func test_dawn_refreshes_roster_membership_and_hunger_labels() -> void:
	var selection := SelectionController.new()
	selection.bind(_state)
	var roster: RosterPanel = preload("res://scenes/ui/roster_panel.tscn").instantiate()
	roster.bind(_state, selection)
	roster.toggle()
	var info: InfoPanel = preload("res://scenes/ui/info_panel.tscn").instantiate()
	info.bind(_state, selection)
	var hungry: Survivor = _state.survivors.all().back()
	selection.select_survivor(hungry.uid)
	_food((_pop / 2) * _need)
	_state.clock.advance(_cycle())
	roster.refresh()
	info.refresh()
	assert_eq(info._activity_label.text, "Idle \u00b7 Hungry")
	assert_eq((roster._vbox.get_child(_pop - 1).get_child(2) as Label).text, "Idle \u00b7 Hungry")
	_food(0)
	_state.clock.advance(_cycle())
	assert_eq(roster._vbox.get_child_count(), _state.survivors.count())
	info.refresh()
	assert_false(info.visible)
	_shelter()
	var pop: int = _state.survivors.count()
	_food(pop * (_need + int(_data.balance("food_newcomers_threshold"))))
	_state.clock.advance(_cycle())
	assert_gt(_state.last_dawn_report["arrived"].size(), 0)
	assert_eq(roster._vbox.get_child_count(), _state.survivors.count())
	info.free()
	roster.free()
	selection.free()
