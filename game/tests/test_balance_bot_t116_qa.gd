extends TestCase

func _state(population: int = 17) -> GameState:
	var state := GameState.new(GameData.load_default(), 1337)
	state.clock.day = 9
	for person: Survivor in state.survivors.all():
		state.survivors.remove(person.uid)
	for index: int in range(population):
		state.survivors.add(str(index), "blue", state.map.command_center_origin() - Vector2i.ONE)
	state.resources.add("wood", 5000)
	state.resources.add("scrap", 5000)
	state.resources.take("food", state.resources.get_amount("food"))
	return state

func _job_count(state: GameState, job: int) -> int:
	var count: int = 0
	for person: Survivor in state.survivors.all():
		if person.job == job:
			count += 1
	return count

func test_second_farm_counts_first_farm_blueprint_before_radio() -> void:
	var state: GameState = _state()
	var memo: Dictionary = {}
	BalanceBot._plan_ring(state, memo)
	assert_eq(BalanceBot._place_inside(state, memo, "farm"), Placement.Result.OK)
	# One planned farm supports only 16 of these 17 survivors. The brief
	# requires the second-farm rule to count blueprints, not only completions.
	assert_eq(BalanceBot._complete_count(state, "farm"), 0)
	BalanceBot._decide(state, memo)
	assert_eq(state.buildings.count_of("farm"), 2,
		"Insufficient planned food capacity must place the second farm before lower-priority work")

func test_second_builder_counts_damage_with_only_one_blueprint() -> void:
	var state: GameState = _state(10)
	state.clock.day = 8
	var memo: Dictionary = {}
	BalanceBot._plan_ring(state, memo)
	assert_eq(BalanceBot._place_inside(state, memo, "watchtower"), Placement.Result.OK)
	var tower: Building = state.buildings.all_of_type("watchtower")[0]
	state.buildings.finish(tower.uid)
	assert_eq(BalanceBot._place_inside(state, memo, "turret"), Placement.Result.OK)
	tower.hp = tower.max_hp / 2
	BalanceBot._jobs(state)
	assert_eq(_job_count(state, Survivor.Job.BUILDER), 1, "Exactly half HP is outside the damage rule")
	tower.hp -= 1
	BalanceBot._jobs(state)
	assert_eq(_job_count(state, Survivor.Job.BUILDER), 2, "One blueprint plus a below-half-HP building qualifies")

func test_jobs_guard_cap_counts_completed_watchtower_posts() -> void:
	var state: GameState = _state(28)
	state.clock.day = 12
	var memo: Dictionary = {}
	BalanceBot._plan_ring(state, memo)
	for index: int in range(3):
		assert_eq(BalanceBot._place_inside(state, memo, "watchtower"), Placement.Result.OK)
		var tower: Building = state.buildings.all_of_type("watchtower")[-1]
		if index < 2:
			state.buildings.finish(tower.uid)
	BalanceBot._jobs(state)
	assert_eq(_job_count(state, Survivor.Job.GUARD), 3, "Two completed one-worker posts plus one; blueprint excluded")
	state.buildings.remove(state.buildings.all_of_type("watchtower")[0].uid)
	BalanceBot._jobs(state)
	assert_eq(_job_count(state, Survivor.Job.GUARD), 2, "Losing a completed tower reduces the guard cap")

func test_jobs_crafter_uses_next_building_scrap_reserve() -> void:
	var state: GameState = _state(10)
	state.clock.day = 10
	var memo: Dictionary = {}
	BalanceBot._plan_ring(state, memo)
	assert_eq(BalanceBot._place_inside(state, memo, "workshop"), Placement.Result.OK)
	state.buildings.finish(state.buildings.all_of_type("workshop")[0].uid)
	state.resources.take("ammo", state.resources.get_amount("ammo"))
	state.resources.add("ammo", 250)
	state.resources.take("scrap", state.resources.get_amount("scrap"))
	var reserve: int = 100 + int(state.data.get_building("radio_tower")["cost"]["scrap"])
	state.resources.add("scrap", reserve + 1)
	BalanceBot._jobs(state)
	assert_eq(_job_count(state, Survivor.Job.CRAFTER), 1, "Spend surplus scrap above the 240 ammo target")
	state.resources.take("scrap", 1)
	BalanceBot._jobs(state)
	assert_eq(_job_count(state, Survivor.Job.CRAFTER), 0, "Preserve the planned radio tower cost plus 100 scrap")
	state.resources.add("scrap", 1000)
	state.resources.add("ammo", 230)
	BalanceBot._jobs(state)
	assert_eq(_job_count(state, Survivor.Job.CRAFTER), 0, "Stop at twice the ammo target")
