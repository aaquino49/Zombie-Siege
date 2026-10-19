extends TestCase

func _state(population: int = 10, day: int = 4) -> GameState:
	var state := GameState.new(GameData.load_default(), 1337)
	state.waves.enabled = false
	state.clock.day = day
	for person: Survivor in state.survivors.all(): state.survivors.remove(person.uid)
	for index: int in range(population):
		var person: Survivor = state.survivors.add(str(index), "blue", state.map.command_center_origin() - Vector2i.ONE)
		state.set_job(person.uid, Survivor.Job.GATHERER, "wood" if index == 0 else "scrap")
	for kind: String in ["wood", "scrap", "food", "ammo"]: _stock(state, kind, 1000)
	return state

func _stock(state: GameState, kind: String, amount: int) -> void:
	state.resources.take(kind, state.resources.get_amount(kind))
	state.resources.add(kind, amount)

func _complete(state: GameState, memo: Dictionary, type_id: String) -> Building:
	assert_eq(BalanceBot._place_inside(state, memo, type_id), Placement.Result.OK)
	var building: Building = state.buildings.all_of_type(type_id)[-1]
	state.buildings.finish(building.uid)
	return building

func _count(state: GameState, job: int) -> int:
	var count: int = 0
	for person: Survivor in BalanceBotM12.roster(state):
		count += int(person.job == job)
	return count

func test_optional_spending_and_radio_reserves_use_data_costs() -> void:
	var state: GameState = _state(6, 2)
	var memo: Dictionary = {}
	BalanceBot._plan_ring(state, memo)
	var fire_cost: int = int(state.data.get_building("campfire").cost.wood)
	_stock(state, "wood", fire_cost + 29)
	assert_false(BalanceBotM12.optional_build(state, memo))
	_stock(state, "wood", fire_cost + 30)
	assert_true(BalanceBotM12.optional_build(state, memo))
	assert_eq(state.resources.get_amount("wood"), 30)
	state.buildings.finish(state.buildings.all_of_type("campfire")[0].uid)
	_stock(state, "wood", 1000)
	assert_false(BalanceBotM12.optional_build(state, memo), "Covered slots need no extra fire")
	state.clock.day = 4
	_complete(state, memo, "farm")
	_complete(state, memo, "workshop")
	var lab_cost: Dictionary = state.data.get_building("field_lab").cost
	_stock(state, "wood", int(lab_cost.wood) + 60)
	_stock(state, "scrap", int(lab_cost.scrap) + 29)
	assert_false(BalanceBotM12.optional_build(state, memo))
	_stock(state, "scrap", int(lab_cost.scrap) + 30)
	assert_true(BalanceBotM12.optional_build(state, memo))
	assert_eq(state.resources.get_amount("wood"), 60)
	assert_eq(state.resources.get_amount("scrap"), 30)
	state.buildings.remove(state.buildings.all_of_type("field_lab")[0].uid)
	state.clock.day = int(state.data.get_building("radio_tower").unlock_day)
	var radio: Dictionary = state.data.get_building("radio_tower").cost
	_stock(state, "wood", int(lab_cost.wood) + 60 + int(radio.wood))
	_stock(state, "scrap", int(lab_cost.scrap) + 30 + int(radio.scrap) - 1)
	assert_false(BalanceBotM12.optional_build(state, memo), "Full missing Radio cost is reserved")
	_stock(state, "scrap", int(lab_cost.scrap) + 30 + int(radio.scrap))
	assert_true(BalanceBotM12.optional_build(state, memo), "Destroyed Lab can rebuild from surplus")

func test_optional_unlocks_prerequisites_population_slots_and_cap() -> void:
	var state: GameState = _state(7, 1)
	var memo: Dictionary = {}
	BalanceBot._plan_ring(state, memo)
	assert_false(BalanceBotM12.optional_build(state, memo))
	state.clock.day = 2
	assert_true(BalanceBotM12.optional_build(state, memo))
	assert_eq(state.buildings.count_of("campfire"), 1)
	assert_true(BalanceBotM12.optional_build(state, memo))
	assert_eq(state.buildings.count_of("campfire"), 2, "Second fire only for uncovered slots")
	assert_false(BalanceBotM12.optional_build(state, memo), "Blueprint cap holds")
	for bp: Building in state.buildings.blueprints(): state.buildings.finish(bp.uid)
	state.clock.day = 4
	assert_false(BalanceBotM12.optional_build(state, memo), "Farm and Workshop must be complete")
	_complete(state, memo, "farm")
	_complete(state, memo, "workshop")
	for person: Survivor in state.survivors.all().slice(5): state.survivors.remove(person.uid)
	assert_false(BalanceBotM12.optional_build(state, memo), "Lab requires six living survivors")

func test_urgent_farm_and_radio_recovery_preempt_optional_buildings() -> void:
	for urgent: String in ["farm", "radio_tower"]:
		var state: GameState = _state(6, 9)
		var memo: Dictionary = {}
		BalanceBot._plan_ring(state, memo)
		if urgent == "radio_tower":
			_complete(state, memo, "farm")
			memo["radio_tower_ever_complete"] = true
		else:
			memo["max_complete_farms"] = 1
		BalanceBot._decide(state, memo)
		assert_eq(state.buildings.count_of(urgent), 1)
		assert_eq(state.buildings.count_of("campfire"), 0)
		assert_eq(state.buildings.count_of("field_lab"), 0)

func test_staffing_shortages_exclusions_and_same_job_progress() -> void:
	var state: GameState = _state()
	var memo: Dictionary = {}
	BalanceBot._plan_ring(state, memo)
	_complete(state, memo, "field_lab")
	BalanceBot._jobs(state)
	assert_eq(_count(state, Survivor.Job.RESEARCHER), 2)
	for person: Survivor in state.survivors.all():
		person.work_acc = 0.75
		person.work_uid = 987
	BalanceBot._jobs(state)
	for person: Survivor in state.survivors.all():
		assert_eq(person.work_acc, 0.75)
		assert_eq(person.work_uid, 987, "Repeated same-job choices retain slots")
	_stock(state, "ammo", BalanceBotM12.ammo_target(state.clock.day) - 1)
	BalanceBot._jobs(state)
	assert_eq(_count(state, Survivor.Job.RESEARCHER), 1)
	_stock(state, "food", 2 * state.survivors.count() - 1)
	BalanceBot._jobs(state)
	assert_eq(_count(state, Survivor.Job.RESEARCHER), 0)
	_stock(state, "food", 1000)
	_stock(state, "ammo", 1000)
	BalanceBot._jobs(state)
	assert_eq(_count(state, Survivor.Job.RESEARCHER), 2, "Staffing recovers")
	var people: Array[Survivor] = state.survivors.all()
	people[0].refusing = true
	people[1].away = true
	people[2].day_off = true
	assert_true(state.expeditions.send(people[3].uid))
	assert_eq(BalanceBotM12.roster(state).size(), 6)
	var old_jobs: Array[int] = []
	for person: Survivor in people.slice(0, 4): old_jobs.append(person.job)
	BalanceBot._jobs(state)
	assert_eq(_count(state, Survivor.Job.RESEARCHER), 1)
	for i: int in range(4): assert_eq(people[i].job, old_jobs[i], "Excluded survivors are not reassigned")
	people[4].refusing = true
	BalanceBot._jobs(state)
	assert_eq(_count(state, Survivor.Job.RESEARCHER), 0, "Below six useful workers drops researchers")

func test_guards_prefer_morale_but_protect_essential_workers() -> void:
	var state: GameState = _state()
	var people: Array[Survivor] = state.survivors.all()
	state.set_job(people[1].uid, Survivor.Job.BUILDER)
	people[1].morale = 100
	people[7].morale = 90
	people[8].morale = 90
	BalanceBot._jobs(state)
	assert_eq(people[1].job, Survivor.Job.BUILDER)
	assert_eq(people[7].job, Survivor.Job.GUARD, "High morale then uid")
	assert_ne(people[8].job, Survivor.Job.GUARD)
	assert_eq(people[0].job, Survivor.Job.GATHERER, "Keep a wood gatherer")

func test_fire_and_lab_blueprints_create_builder_demand() -> void:
	var state: GameState = _state(10, 8)
	var memo: Dictionary = {}
	BalanceBot._plan_ring(state, memo)
	BalanceBot._place_inside(state, memo, "campfire")
	BalanceBot._place_inside(state, memo, "field_lab")
	BalanceBot._jobs(state)
	assert_eq(_count(state, Survivor.Job.BUILDER), 2)

func test_feast_food_cooldown_and_day_off_safeguards() -> void:
	var state: GameState = _state()
	var memo: Dictionary = {}
	for person: Survivor in state.survivors.all():
		Morale.add_mood(state, person, "hurt", "", -35)
	_stock(state, "food", 39)
	BalanceBotM12.morale_commands(state, memo)
	assert_eq(state.last_feast_day, 0)
	assert_eq(state.resources.get_amount("food"), 39)
	assert_eq(memo.get("day_off_day"), state.clock.day)
	var off: int = 0
	for person: Survivor in state.survivors.all(): off += int(person.day_off)
	assert_eq(off, 1)
	BalanceBotM12.morale_commands(state, memo)
	var off_again: int = 0
	for person: Survivor in state.survivors.all(): off_again += int(person.day_off)
	assert_eq(off_again, 1, "At most one off per day")
	_stock(state, "food", 40)
	BalanceBotM12.morale_commands(state, memo)
	assert_eq(state.last_feast_day, state.clock.day)
	assert_eq(state.resources.get_amount("food"), 20)
	_stock(state, "food", 1000)
	BalanceBotM12.morale_commands(state, memo)
	assert_eq(state.resources.get_amount("food"), 1000, "Cooldown prevents another feast")

func test_day_off_excludes_critical_jobs_and_requires_morning_seven_workers() -> void:
	var state: GameState = _state(7)
	var people: Array[Survivor] = state.survivors.all()
	for pair: Array in [[0, Survivor.Job.GUARD], [1, Survivor.Job.BUILDER], [2, Survivor.Job.CRAFTER], [3, Survivor.Job.FARMER]]:
		state.set_job(people[int(pair[0])].uid, int(pair[1]))
		Morale.add_mood(state, people[int(pair[0])], "hurt", "", -40)
	_stock(state, "food", 0)
	BalanceBotM12.morale_commands(state, {})
	for person: Survivor in people: assert_false(person.day_off)
	Morale.add_mood(state, people[4], "hurt", "", -35)
	state.clock.elapsed = float(state.data.balance("day_length")) * float(state.data.morale_config().day_off_morning_fraction)
	BalanceBotM12.morale_commands(state, {})
	assert_false(people[4].day_off, "Morning endpoint is excluded")
	state.clock.elapsed = 0.0
	people[6].away = true
	BalanceBotM12.morale_commands(state, {})
	assert_false(people[4].day_off, "Six useful workers is insufficient")
	people[6].away = false
	BalanceBotM12.morale_commands(state, {})
	assert_true(people[4].day_off)

func test_research_fixed_legal_order_partial_bank_and_no_instant_mutations() -> void:
	var state: GameState = _state()
	state.tech.progress["camp_songs"] = 3.25
	state.tech.banked = 1.5
	BalanceBotM12.choose_research(state)
	assert_eq(state.tech.active, "camp_songs")
	assert_eq(state.tech.progress["camp_songs"], 4.75, "Only the public choose command spends existing bank")
	var snapshot: Dictionary = state.tech.capture()
	var stocks: Dictionary = {}
	for kind: String in ResourceStore.KINDS: stocks[kind] = state.resources.get_amount(kind)
	BalanceBotM12.choose_research(state)
	BalanceBot._jobs(state)
	assert_eq(state.tech.capture(), snapshot, "Decisions alone cannot produce RP")
	for kind: String in ResourceStore.KINDS:
		assert_eq(state.resources.get_amount(kind), stocks[kind], "Staffing alone cannot produce resources")
	for id: String in BalanceBotM12.RESEARCH_ORDER:
		BalanceBotM12.choose_research(state)
		assert_eq(state.tech.active, id)
		assert_true(state.tech.available(id), "Prerequisites satisfied")
		state.tech.add_points(float(state.data.tech_config().upgrades[id].cost))
	assert_eq(state.tech.done, BalanceBotM12.RESEARCH_ORDER)
	BalanceBotM12.choose_research(state)
	assert_eq(state.tech.active, "")

func test_scavenging_preserves_researchers_and_suspended_essentials() -> void:
	var state: GameState = _state(6)
	var people: Array[Survivor] = state.survivors.all()
	state.set_job(people[1].uid, Survivor.Job.RESEARCHER)
	state.set_job(people[2].uid, Survivor.Job.BUILDER)
	state.set_job(people[3].uid, Survivor.Job.CRAFTER)
	people[4].refusing = true
	people[5].day_off = true
	assert_false(BalanceBot._send_scavenger(state))
	assert_false(state.expeditions.is_running(people[1]))
	people[4].refusing = false
	assert_true(BalanceBot._send_scavenger(state))
	assert_true(state.expeditions.is_running(people[4]))

func test_measurements_empty_population_retains_tree_and_loss_has_no_leavers() -> void:
	var state: GameState = _state(0)
	state.tech.choose("spotters")
	state.tech.add_points(1.25)
	var row: Dictionary = BalanceBotM12.measurements(state, {"left_morale": ["Gone"], "cc_damage": 17}, "loss")
	for key: String in ["morale_mean", "morale_min", "morale_refusing", "morale_left", "researchers"]: assert_eq(float(row[key]), 0.0)
	assert_eq(row.research_active, "spotters")
	assert_eq(row.research_progress, 1.25)
	assert_eq(row.cc_damage, 17)
	assert_eq(BalanceBotM12.measurements(state, {"left_morale": ["Gone"]}, "dawn").morale_left, 0)

func test_measurements_count_only_real_working_unsuspended_researchers() -> void:
	var state: GameState = _state(6)
	var memo: Dictionary = {}
	BalanceBot._plan_ring(state, memo)
	var lab: Building = _complete(state, memo, "field_lab")
	var people: Array[Survivor] = state.survivors.all()
	for person: Survivor in people:
		state.set_job(person.uid, Survivor.Job.RESEARCHER)
		person.pos = Grid.tile_to_world(lab.origin - Vector2i.ONE)
		person.work_uid = lab.uid
		person.activity = Survivor.Activity.RESEARCHING
	people[1].refusing = true
	people[2].day_off = true
	people[3].away = true
	people[4].sheltered = true
	people[5].work_uid = 0
	assert_eq(BalanceBotM12.measurements(state, {}, "dawn").researchers, 1)
	state.clock.phase = GameClock.Phase.NIGHT
	assert_eq(BalanceBotM12.measurements(state, {}, "loss").researchers, 0)

func test_active_research_is_never_switched_and_staffing_obeys_food_boundaries() -> void:
	var state: GameState = _state()
	state.tech.choose("spotters")
	BalanceBotM12.choose_research(state)
	assert_eq(state.tech.active, "spotters", "Do not switch an available active research")
	var memo: Dictionary = {}
	BalanceBot._plan_ring(state, memo)
	_complete(state, memo, "field_lab")
	_stock(state, "food", 2 * state.survivors.count())
	BalanceBot._jobs(state)
	assert_eq(_count(state, Survivor.Job.RESEARCHER), 1)
	_stock(state, "food", 3 * state.survivors.count())
	BalanceBot._jobs(state)
	assert_eq(_count(state, Survivor.Job.RESEARCHER), 2)

func test_essential_staffing_survives_food_and_worker_shortages() -> void:
	var state: GameState = _state(7, 8)
	var memo: Dictionary = {}
	BalanceBot._plan_ring(state, memo)
	_complete(state, memo, "field_lab")
	_complete(state, memo, "farm")
	_complete(state, memo, "workshop")
	_stock(state, "food", 1)
	_stock(state, "ammo", 0)
	BalanceBot._jobs(state)
	assert_eq(_count(state, Survivor.Job.RESEARCHER), 0)
	assert_eq(_count(state, Survivor.Job.BUILDER), 1)
	assert_eq(_count(state, Survivor.Job.CRAFTER), 1)
	assert_eq(_count(state, Survivor.Job.FARMER), 2)
	var wood: int = 0
	for person: Survivor in BalanceBotM12.roster(state):
		wood += int(person.job == Survivor.Job.GATHERER and person.gather_kind == "wood")
	assert_gt(wood, 0)

func test_day_researchers_productive_day_and_reset_in_fixed_run() -> void:
	var inspect: Callable = func(state: GameState, memo: Dictionary) -> void:
		state.waves.enabled = false
		if state.clock.day == 2:
			state.clock.day = 4 # Lab unlock; restore day before returning to the loop.
			for index: int in range(6):
				state.survivors.add("Research fixture %d" % index, "blue", state.map.command_center_origin() - Vector2i.ONE)
			for kind: String in ["wood", "scrap", "food", "ammo"]: _stock(state, kind, 1000)
			_complete(state, memo, "field_lab")
			state.clock.day = 2
		elif state.clock.day == 3:
			assert_gt(state.tech.banked + float(state.tech.progress.get(state.tech.active, 0.0)), 0.0, "Fixture actually produced RP")
			for lab: Building in state.buildings.all_of_type("field_lab"): state.buildings.remove(lab.uid)
	var result: Dictionary = BalanceBot.run(1337, "sensible", 3, 0.25, inspect)
	assert_eq(result.rows.size(), 3)
	if result.rows.size() != 3: return
	assert_eq(result.rows[0].day_researchers, 0)
	assert_gt(result.rows[1].day_researchers, 0, "Full productive day retains its peak at dawn")
	assert_eq(result.rows[1].researchers, 0, "Original instantaneous dawn count is unchanged")
	assert_eq(result.rows[2].day_researchers, 0, "Next day cannot inherit the previous peak")

func test_day_researchers_peak_is_read_only_and_survives_dusk_and_loss() -> void:
	var state: GameState = _state(6)
	var memo: Dictionary = {}
	BalanceBot._plan_ring(state, memo)
	var lab: Building = _complete(state, memo, "field_lab")
	var people: Array[Survivor] = state.survivors.all()
	for person: Survivor in people.slice(0, 2):
		state.set_job(person.uid, Survivor.Job.RESEARCHER)
		person.pos = Grid.tile_to_world(lab.origin - Vector2i.ONE)
		person.work_uid = lab.uid
		person.activity = Survivor.Activity.RESEARCHING
	var night: Dictionary = {"dusk_ammo": 0, "dusk_wood": 0, "dusk_scrap": 0,
		"guards": 0, "turrets": 0, "cc_min_hp_pct": 100.0, "day_researchers": 0}
	var tech_before: Dictionary = state.tech.capture()
	var rng_before: int = state.rng.state
	var combat_before: int = state.combat_rng.state
	BalanceBot._sample_day_researchers(state, night)
	assert_eq(night.day_researchers, 2)
	assert_eq(state.tech.capture(), tech_before)
	assert_eq(state.rng.state, rng_before)
	assert_eq(state.combat_rng.state, combat_before)
	people[1].refusing = true
	BalanceBot._sample_day_researchers(state, night)
	assert_eq(BalanceBotM12.working_researchers(state), 1)
	assert_eq(night.day_researchers, 2, "Sample is a maximum, not the latest count")
	state.clock.phase = GameClock.Phase.NIGHT
	BalanceBot._sample_day_researchers(state, night)
	var report: Dictionary = state.night_log.summary(state)
	report["night"] = state.clock.day
	for end: String in ["dawn", "loss"]:
		var row: Dictionary = BalanceBot._row(state, "sensible", report, night, end)
		assert_eq(row.keys(), BalanceBot.COLUMNS)
		assert_eq(row.day_researchers, 2)
		assert_eq(row.researchers, 0)
		assert_eq(BalanceBot.to_csv([row]).split("\n", false)[1].split(",")[-1], "2")
