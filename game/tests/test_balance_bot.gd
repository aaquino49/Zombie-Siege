extends TestCase

func _assert_rows_and_csv(rows: Array) -> void:
	var lines: PackedStringArray = BalanceBot.to_csv(rows).split("\n", false)
	assert_eq(lines[0], ",".join(BalanceBot.COLUMNS))
	assert_eq(lines.size(), rows.size() + 1)
	for index: int in range(rows.size()):
		var row: Dictionary = rows[index]
		assert_eq(row.keys(), BalanceBot.COLUMNS, "Ordered row schema")
		var fields: PackedStringArray = lines[index + 1].split(",")
		assert_eq(fields.size(), BalanceBot.COLUMNS.size())
		for column_index: int in range(BalanceBot.COLUMNS.size()):
			var column: String = BalanceBot.COLUMNS[column_index]
			assert_has(row, column)
			assert_eq(fields[column_index], "%.2f" % float(row[column]) if column in ["morale_mean", "research_progress", "research_banked"] else str(row[column]))
		assert_true(row["end"] in ["dawn", "loss"])
		assert_true(float(row["cc_min_hp_pct"]) <= float(row["cc_hp_pct"]), "Night minimum includes row HP")
		assert_true(float(row["cc_min_hp_pct"]) >= 0.0)
		assert_true(float(row["cc_min_hp_pct"]) <= 100.0)

func test_column_order() -> void:
	var expected: Array[String] = ["seed", "strategy", "night", "cc_hp_pct", "survivors",
		"beds", "food", "wood", "scrap", "ammo", "kills", "lost", "buildings_destroyed",
		"buildings", "radio_tower", "end", "dusk_ammo", "dusk_wood", "dusk_scrap",
		"guards", "turrets", "cc_min_hp_pct", "scav_sent", "scav_hurt", "scav_lost",
		"morale_mean", "morale_min", "morale_refusing", "morale_left", "research_done",
		"research_active", "research_progress", "research_banked", "researchers", "cc_damage", "day_researchers"]
	assert_eq(BalanceBot.COLUMNS, expected)
	assert_eq(BalanceBot.to_csv([]), ",".join(expected) + "\n")

func test_job_plan_examples() -> void:
	assert_eq(BalanceBot.job_plan(1, 4, 0, 30, 0, false, 0),
		{"guards": 1, "builders": 1, "crafters": 0, "farmers": 0, "gatherers": 2})
	assert_eq(BalanceBot.job_plan(2, 4, 0, 30, 0, true, 0),
		{"guards": 1, "builders": 1, "crafters": 1, "farmers": 0, "gatherers": 1})
	assert_eq(BalanceBot.job_plan(12, 10, 0, 0, 1, true, 3, 100, 2),
		{"guards": 3, "builders": 2, "crafters": 1, "farmers": 2, "gatherers": 2})

func test_job_plan_thresholds_and_slot_exhaustion() -> void:
	for day: int in [1, 3, 4, 7, 8, 11, 12, 20]:
		assert_eq(BalanceBot.job_plan(day, 10, 1000, 1000, 2, true, 0)["guards"], 1)
	assert_eq(BalanceBot.job_plan(12, 0, 0, 0, 1, true, 3),
		{"guards": 0, "builders": 0, "crafters": 0, "farmers": 0, "gatherers": 0})
	assert_eq(BalanceBot.job_plan(12, 2, 0, 0, 1, true, 3),
		{"guards": 0, "builders": 1, "crafters": 1, "farmers": 0, "gatherers": 0})
	assert_eq(BalanceBot.job_plan(12, 6, 0, 0, 2, true, 3),
		{"guards": 1, "builders": 1, "crafters": 1, "farmers": 2, "gatherers": 1})
	assert_eq(BalanceBot.job_plan(4, 10, 120, 40, 2, true, 0),
		{"guards": 1, "builders": 1, "crafters": 0, "farmers": 0, "gatherers": 8})
	assert_eq(BalanceBot.job_plan(4, 10, 119, 39, 2, true, 0),
		{"guards": 1, "builders": 1, "crafters": 1, "farmers": 4, "gatherers": 3})

func test_jobs_alternate_and_preserve_unchanged_work() -> void:
	var state := GameState.new(GameData.load_default(), 1337)
	# Fixed synthetic population makes allocation independent of starting balance.
	for person: Survivor in state.survivors.all():
		state.survivors.remove(person.uid)
	for index: int in range(10):
		state.survivors.add(str(index), "blue", state.map.command_center_origin() - Vector2i.ONE)
	for day: int in [1, 8]:
		state.clock.day = day
		BalanceBot._jobs(state)
		var gather_index: int = 0
		for person: Survivor in state.survivors.all():
			if person.job == Survivor.Job.GATHERER:
				var kind: String = "scrap" if (gather_index + int(day >= 8)) % 2 == 1 else "wood"
				assert_eq(person.gather_kind, kind)
				gather_index += 1
			person.work_acc = 7.0
		BalanceBot._jobs(state)
		for person: Survivor in state.survivors.all():
			assert_eq(person.work_acc, 7.0, "An unchanged job must not reset work")

func test_sensible_determinism_and_first_dawn() -> void:
	var observed: Array[Dictionary] = []
	var inspect: Callable = func(state: GameState, memo: Dictionary) -> void:
		var guards: int = 0
		var gatherers: int = 0
		for person: Survivor in state.survivors.all():
			if person.job == Survivor.Job.GUARD:
				guards += 1
			if person.job == Survivor.Job.GATHERER:
				gatherers += 1
		var placed: int = 0
		for tile: Vector2i in memo["ring"]:
			if state.buildings.get_at(tile) != null:
				placed += 1
		observed.append({"guards": guards, "gatherers": gatherers,
			"placed": placed, "blueprints": state.buildings.blueprints().size()})
	var first: Dictionary = BalanceBot.run(1337, "sensible", 2, 0.25, inspect)
	var second: Dictionary = BalanceBot.run(1337, "sensible", 2)
	assert_eq(first["rows"], second["rows"], "Same seed produces identical rows, including night metrics")
	assert_eq(BalanceBot.to_csv(first["rows"]), BalanceBot.to_csv(second["rows"]))
	assert_eq(first["min_cc_hp_pct"], second["min_cc_hp_pct"])
	_assert_rows_and_csv(first["rows"])
	assert_false(observed.is_empty(), "First dawn callback was inspected")
	if not observed.is_empty():
		assert_gt(observed[0]["guards"], 0, "At least one guard at first dawn")
		assert_gt(observed[0]["gatherers"], 0, "At least one gatherer at first dawn")
		assert_gt(observed[0]["placed"], 0, "Ring construction started by first dawn")
	for observation: Dictionary in observed:
		assert_lt(observation["blueprints"], 3, "At most two open blueprints")
	for row: Dictionary in first["rows"]:
		assert_true(float(first["min_cc_hp_pct"]) <= float(row["cc_min_hp_pct"]))

func test_decide_never_exceeds_two_blueprints() -> void:
	var state := GameState.new(GameData.load_default(), 1337)
	var memo: Dictionary = {}
	var state_ref: WeakRef = weakref(state)
	state.buildings.building_added.connect(func(_building: Building) -> void:
		var current: GameState = state_ref.get_ref() as GameState
		assert_lt(current.buildings.blueprints().size(), 3, "Cap checked at every placement"))
	state.resources.add("wood", 10000)
	state.resources.add("scrap", 10000)
	for day: int in range(1, 13):
		state.clock.day = day
		BalanceBot._decide(state, memo)
		for blueprint: Building in state.buildings.blueprints():
			state.buildings.finish(blueprint.uid)
		BalanceBot._decide(state, memo)

func test_none_loss_row() -> void:
	var result: Dictionary = BalanceBot.run(1337, "none", 8)
	assert_eq(result["outcome"], "lost_cc", "The none strategy still loses the command center early")
	var rows: Array = result["rows"]
	_assert_rows_and_csv(rows)
	if String(result["outcome"]).begins_with("lost"):
		assert_false(rows.is_empty(), "A loss always writes a final row")
		if not rows.is_empty():
			assert_eq(rows[-1]["end"], "loss")
			assert_eq(rows[-1]["night"], 4, "The none strategy retains its established early-loss night")
			assert_eq(rows[-1]["cc_hp_pct"], result["cc_hp_pct"])
	for row: Dictionary in rows:
		assert_eq(row.day_researchers, 0, "No researchers work under the none strategy")
	for index: int in range(rows.size()):
		if index == rows.size() - 1 and String(result["outcome"]).begins_with("lost"):
			continue
		assert_eq(rows[index]["end"], "dawn")

func _fog_test_state(fog_chance: float) -> GameState:
	var state := GameState.new(GameData.load_default(), 1337)
	state.clock.day = 5
	state.data.weather_config()["fog"]["chance"] = fog_chance
	return state

func test_forced_fog_forecast_assigns_an_extra_guard() -> void:
	var clear_state: GameState = _fog_test_state(0.0)
	var fog_state: GameState = _fog_test_state(1.0)
	clear_state.clock.elapsed = float(clear_state.data.balance("day_length")) - 5.0
	fog_state.clock.elapsed = float(fog_state.data.balance("day_length")) - 5.0
	BalanceBot._jobs(clear_state)
	BalanceBot._jobs(fog_state)
	var clear_guards: int = 0
	var fog_guards: int = 0
	for person: Survivor in clear_state.survivors.all():
		if person.job == Survivor.Job.GUARD:
			clear_guards += 1
	for person: Survivor in fog_state.survivors.all():
		if person.job == Survivor.Job.GUARD:
			fog_guards += 1
	assert_eq(WaveSpawner.forecast(fog_state.data, 5, fog_state.difficulty_multipliers, fog_state.map_seed)["fog"], true)
	assert_eq(fog_guards, clear_guards + 1, "Fog forecast posts one extra guard when a survivor is free")

func test_fog_forecast_limits_turret_and_watchtower_placement_range() -> void:
	for type_id: String in ["turret", "watchtower"]:
		var state: GameState = _fog_test_state(1.0)
		state.resources.add("wood", 1000)
		state.resources.add("scrap", 1000)
		var memo: Dictionary = {}
		BalanceBot._plan_ring(state, memo)
		assert_eq(BalanceBot._place_inside(state, memo, type_id), Placement.Result.OK,
			"Fog-day %s placement remains available near the Command Center" % type_id)
		var placed: Building = state.buildings.all_of_type(type_id)[0]
		assert_true(BalanceBot._within_fog_approach_range(state, type_id, placed.origin),
			"Fog-day %s stays inside its reduced defense range" % type_id)
		var expected_range: float = 5.0 if type_id == "turret" else 6.5
		var actual_range: float = float(state.data.get_building(type_id).get("range_tiles", state.data.balance("guard_range_tiles")))
		if type_id == "watchtower":
			actual_range *= float(state.data.get_building(type_id)["guard_range_mult"])
		actual_range += float(state.data.weather_config()["fog"]["range_delta_tiles"])
		assert_almost_eq(actual_range, expected_range, 0.001, "Fog reduces the configured %s range" % type_id)

func test_second_farm_placed_when_food_balance_negative_with_full_farms() -> void:
	var state := GameState.new(GameData.load_default(), 1337)
	var memo: Dictionary = {}
	BalanceBot._plan_ring(state, memo)
	state.resources.add("wood", 1000)
	state.resources.add("scrap", 1000)
	state.clock.day = 2

	# Place and complete first farm
	assert_eq(BalanceBot._place_inside(state, memo, "farm"), Placement.Result.OK)
	var first_farm: Building = state.buildings.all_of_type("farm")[0]
	state.buildings.finish(first_farm.uid)
	assert_eq(BalanceBot._complete_count(state, "farm"), 1)

	# Set up 10 survivors (projected food: 1*2*8 - 10 = +6 >= 0).
	for s: Survivor in state.survivors.all():
		state.survivors.remove(s.uid)
	for i: int in range(10):
		state.survivors.add("S%d" % i, "blue", state.map.command_center_origin() - Vector2i.ONE)
	state.resources.take("food", state.resources.get_amount("food"))
	state.resources.add("food", 100)
	BalanceBot._decide(state, memo)
	assert_eq(state.buildings.count_of("farm"), 1, "No second farm when food balance >= 0")

	for bp: Building in state.buildings.blueprints():
		state.buildings.finish(bp.uid)

	# Add survivors up to 17 (projected food: 16 - 17 = -1 < 0).
	for i: int in range(10, 17):
		state.survivors.add("S%d" % i, "blue", state.map.command_center_origin() - Vector2i.ONE)
	assert_eq(state.survivors.count(), 17)

	# If farms are not staffed (0 farmers), second farm must not be placed.
	# High food (100) causes job_plan to assign 0 farmers.
	state.resources.take("food", state.resources.get_amount("food"))
	state.resources.add("food", 100)
	BalanceBot._decide(state, memo)
	assert_eq(state.buildings.count_of("farm"), 1, "No second farm when farms are unstaffed")

	for bp: Building in state.buildings.blueprints():
		state.buildings.finish(bp.uid)

	# Low food causes job_plan to assign 2 farmers (every complete farm staffed).
	# Now projected food < 0 AND complete farms staffed -> place second farm.
	state.resources.take("food", state.resources.get_amount("food"))
	state.resources.add("food", 10)
	BalanceBot._decide(state, memo)
	assert_eq(state.buildings.count_of("farm"), 2, "Second farm placed when food balance < 0 with full farms")

	# While second farm blueprint is open, do not place another farm.
	var count_before: int = state.buildings.count_of("farm")
	BalanceBot._decide(state, memo)
	assert_eq(state.buildings.count_of("farm"), count_before, "Only one farm blueprint open at a time")

func test_second_builder_at_blueprint_cap() -> void:
	# At blueprint cap (open_blueprints = 2) with survivors >= 7, builders should be 2.
	var plan_cap := BalanceBot.job_plan(8, 10, 1000, 1000, 0, false, 2)
	assert_eq(plan_cap["builders"], 2, "Second builder assigned at blueprint cap of 2")

	var plan_7 := BalanceBot.job_plan(8, 7, 1000, 1000, 0, false, 2)
	assert_eq(plan_7["builders"], 2, "Second builder assigned at 7 survivors")

	# Below blueprint cap (open_blueprints = 1): only 1 builder.
	var plan_single := BalanceBot.job_plan(8, 10, 1000, 1000, 0, false, 1)
	assert_eq(plan_single["builders"], 1, "Only 1 builder below blueprint cap")

	# With fewer than 7 survivors: only 1 builder even at blueprint cap.
	var plan_few := BalanceBot.job_plan(8, 6, 1000, 1000, 0, false, 2)
	assert_eq(plan_few["builders"], 1, "Only 1 builder when survivors < 7")

func test_jobs_assign_second_builder_at_actual_blueprint_cap() -> void:
	var state := GameState.new(GameData.load_default(), 1337)
	var memo: Dictionary = {}
	state.clock.day = 8
	for person: Survivor in state.survivors.all():
		state.survivors.remove(person.uid)
	for index: int in range(10):
		state.survivors.add(str(index), "blue", state.map.command_center_origin() - Vector2i.ONE)
	state.resources.add("wood", 1000)
	state.resources.add("scrap", 1000)
	state.resources.add("food", 1000)
	state.resources.add("ammo", 1000)
	BalanceBot._plan_ring(state, memo)
	assert_eq(BalanceBot._place_inside(state, memo, "workshop"), Placement.Result.OK)
	assert_eq(BalanceBot._place_inside(state, memo, "farm"), Placement.Result.OK)
	assert_eq(state.buildings.blueprints().size(), 2, "Two actual non-wall blueprints are open")
	BalanceBot._jobs(state)
	var builders: int = 0
	for person: Survivor in state.survivors.all():
		if person.job == Survivor.Job.BUILDER:
			builders += 1
	assert_eq(builders, 2, "The bot must apply the second-builder rule at its actual blueprint cap")

func test_second_builder_counts_turret_radio_blueprints_and_badly_damaged_buildings() -> void:
	var state := GameState.new(GameData.load_default(), 1337)
	var memo: Dictionary = {}
	state.clock.day = 8
	for person: Survivor in state.survivors.all():
		state.survivors.remove(person.uid)
	for index: int in range(10):
		state.survivors.add(str(index), "blue", state.map.command_center_origin() - Vector2i.ONE)
	state.resources.add("wood", 1000)
	state.resources.add("scrap", 1000)
	BalanceBot._plan_ring(state, memo)
	assert_eq(BalanceBot._place_inside(state, memo, "turret"), Placement.Result.OK)
	assert_eq(BalanceBot._place_inside(state, memo, "radio_tower"), Placement.Result.OK)
	BalanceBot._jobs(state)
	var builders: int = 0
	for person: Survivor in state.survivors.all():
		if person.job == Survivor.Job.BUILDER:
			builders += 1
	assert_eq(builders, 2, "Turret and radio tower blueprints count as builder work")

	var damaged_state := GameState.new(GameData.load_default(), 1337)
	var damaged_memo: Dictionary = {}
	damaged_state.clock.day = 8
	for person: Survivor in damaged_state.survivors.all():
		damaged_state.survivors.remove(person.uid)
	for index: int in range(10):
		damaged_state.survivors.add(str(index), "blue", damaged_state.map.command_center_origin() - Vector2i.ONE)
	damaged_state.resources.add("wood", 1000)
	damaged_state.resources.add("scrap", 1000)
	BalanceBot._plan_ring(damaged_state, damaged_memo)
	assert_eq(BalanceBot._place_inside(damaged_state, damaged_memo, "turret"), Placement.Result.OK)
	assert_eq(BalanceBot._place_inside(damaged_state, damaged_memo, "shelter"), Placement.Result.OK)
	assert_eq(BalanceBot._place_inside(damaged_state, damaged_memo, "watchtower"), Placement.Result.OK)
	var damaged: Building = damaged_state.buildings.all_of_type("watchtower")[0]
	damaged_state.buildings.finish(damaged.uid)
	damaged.hp = damaged.max_hp / 2 - 1
	BalanceBot._jobs(damaged_state)
	var damaged_builders: int = 0
	for person: Survivor in damaged_state.survivors.all():
		if person.job == Survivor.Job.BUILDER:
			damaged_builders += 1
	assert_eq(damaged_builders, 2, "A building below half HP counts as builder work")

func test_guard_count_scales_with_survivors() -> void:
	# With no tower posts, the cap is one; completed posts add one slot apiece.
	assert_eq(BalanceBot.job_plan(12, 12, 1000, 1000, 0, false, 0)["guards"], 1)
	assert_eq(BalanceBot.job_plan(12, 12, 1000, 1000, 0, false, 0, 100, 2)["guards"], 3)
	assert_eq(BalanceBot.job_plan(12, 28, 1000, 1000, 0, false, 0, 100, 2)["guards"], 3)
	assert_eq(BalanceBot.job_plan(12, 28, 1000, 1000, 0, false, 0, 100, 6)["guards"], 7)
	assert_eq(BalanceBot.job_plan(1, 20, 1000, 1000, 0, false, 0)["guards"], 1,
		"At least one guard from night 1, before posts exist")

	# When wood is below 20, at least one gatherer is filled first.
	var wood_plan := BalanceBot.job_plan(12, 10, 1000, 1000, 2, true, 0, 10)
	assert_gt(wood_plan["gatherers"], 0, "At least one gatherer filled first when wood < 20")

func test_crafter_target_day_19_above_old_threshold() -> void:
	# Old threshold: 40 + 20 * 19 = 420.
	# With ammo = 450, old rule would assign 0 crafters (450 >= 420).
	# New rule target: 40 + 20 * 19 + 60 * 3 = 600, so 450 < 600 assigns 1 crafter.
	var plan_crafting := BalanceBot.job_plan(19, 10, 450, 1000, 0, true, 0)
	assert_eq(plan_crafting["crafters"], 1, "Crafter assigned on day 19 above old 420 target")

	# When above the new target (600), crafters should be 0.
	var plan_capped := BalanceBot.job_plan(19, 10, 650, 1000, 0, true, 0)
	assert_eq(plan_capped["crafters"], 0, "Crafter stops once above new target")

func test_crafter_spends_scrap_above_reserve_until_two_x_target() -> void:
	var target: int = 40 + 20 * 10
	var above_target: Dictionary = BalanceBot.job_plan(10, 10, target + 10, 1000,
		0, true, 0, 100, 0, 151, 150)
	assert_eq(above_target["crafters"], 1, "Spare scrap keeps crafting above the ammo target")
	var at_reserve: Dictionary = BalanceBot.job_plan(10, 10, target + 10, 1000,
		0, true, 0, 100, 0, 150, 150)
	assert_eq(at_reserve["crafters"], 0, "Crafter preserves the scrap reserve")
	var at_cap: Dictionary = BalanceBot.job_plan(10, 10, target * 2, 1000,
		0, true, 0, 100, 0, 1000, 150)
	assert_eq(at_cap["crafters"], 0, "Crafter stops at twice the target")

func test_destroyed_farm_rebuild_preempts_unstarted_lower_priority_blueprint() -> void:
	var state := GameState.new(GameData.load_default(), 1337)
	var memo: Dictionary = {}
	BalanceBot._plan_ring(state, memo)
	state.clock.day = 9
	memo["max_complete_farms"] = 1
	state.resources.add("wood", 5000)
	state.resources.add("scrap", 5000)
	assert_eq(BalanceBot._place_inside(state, memo, "farm"), Placement.Result.OK)
	var farm: Building = state.buildings.all_of_type("farm")[0]
	state.buildings.finish(farm.uid)
	assert_eq(BalanceBot._place_inside(state, memo, "radio_tower"), Placement.Result.OK)
	assert_eq(BalanceBot._place_inside(state, memo, "turret"), Placement.Result.OK)
	state.buildings.remove(farm.uid) # Model a farm destroyed during the prior night.
	assert_eq(state.buildings.blueprints().size(), 2)
	BalanceBot._decide(state, memo)
	assert_eq(state.buildings.count_of("farm"), 1, "Farm recovery takes a blueprint slot")
	assert_eq(state.buildings.blueprints().filter(func(b: Building) -> bool: return b.type_id == "farm").size(), 1)
