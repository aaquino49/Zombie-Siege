extends TestCase

var state: GameState

func before_each() -> void:
	state = GameState.new(GameData.load_default(), 821)
	for survivor: Survivor in state.survivors.all(): state.set_job(survivor.uid, Survivor.Job.IDLE)

func test_prerequisites_switch_bank_completion_and_overflow() -> void:
	var tech: TechTree = state.tech
	assert_false(tech.choose("missing"))
	assert_false(tech.choose("oiled_turrets"))
	assert_true(tech.choose("spotters"))
	assert_true(tech.choose("spotters"), "reselect active is a no-op")
	tech.add_points(7.25)
	assert_almost_eq(float(tech.progress.spotters), 7.25)
	assert_true(tech.choose(""))
	tech.add_points(8.5)
	assert_almost_eq(tech.banked, 8.5)
	assert_true(tech.choose("better_tools"))
	assert_almost_eq(float(tech.progress.better_tools), 8.5)
	tech.add_points(11.5)
	assert_true(tech.is_done("better_tools"))
	assert_eq(tech.active, "")
	assert_almost_eq(tech.banked, 0.0)
	assert_true(tech.choose("spotters"))
	tech.add_points(12.75)
	assert_true(tech.is_done("spotters"))
	assert_true(tech.done_today.has("spotters"))
	assert_true(tech.available("oiled_turrets"))
	assert_false(tech.choose("spotters"))
	tech.add_points(-1.0)
	tech.add_points(INF)
	assert_almost_eq(tech.banked, 0.0)
	assert_true(tech.choose("camp_songs"))
	tech.add_points(23.5)
	assert_true(tech.is_done("camp_songs"))
	assert_almost_eq(tech.banked, 3.5, 0.000001, "completion overflow stays in RP bank")
	state.game_over = true
	assert_false(tech.choose("camp_songs"), "game over rejects research selection")

func test_all_prerequisites_gate_completion_and_rejections_are_atomic() -> void:
	var branches: Array[Array] = [["spotters", "oiled_turrets", "reinforced_frames"],
		["better_tools", "crop_rotation", "ammo_press"], ["camp_songs", "first_aid", "bunk_beds"]]
	for branch: Array in branches:
		var tech: TechTree = TechTree.new(state.data.tech_config())
		assert_true(tech.available(str(branch[0])))
		for tier: int in [1, 2]:
			var id: String = str(branch[tier])
			assert_false(tech.available(id))
			var old_bank: float = tech.banked
			var old_progress: Dictionary = tech.progress.duplicate(true)
			assert_false(tech.choose(id))
			assert_eq(tech.banked, old_bank)
			assert_eq(tech.progress, old_progress)
		for tier: int in range(3):
			var id: String = str(branch[tier])
			assert_true(tech.available(id))
			assert_true(tech.choose(id))
			tech.add_points(float(state.data.tech_config().upgrades[id].cost))
			assert_true(tech.is_done(id))
			assert_false(tech.choose(id), "completed research cannot be selected")
			assert_eq(tech.active, "")
			if tier < 2: assert_true(tech.available(str(branch[tier + 1])))
			if tier == 0 and branch[0] == "spotters": assert_true(state.tech.available("better_tools"), "Other branches remain independently available")

func test_live_game_over_transition_allows_keep_fighting_commands_immediately() -> void:
	state.game_over = true
	state.won = true
	state.clock.locked = true
	state.clock.set_paused(true)
	assert_false(state.tech.choose("spotters"))
	var victory: VictoryScreen = VictoryScreen.new()
	victory._state = state
	victory._keep_fighting()
	victory.free()
	assert_true(state.endless)
	assert_false(state.game_over)
	assert_true(state.tech.choose("spotters"))
	assert_true(state.tech.choose("better_tools"))
	assert_true(state.tech.choose(""))
	state.game_over = true
	assert_false(state.tech.choose(""), "pause command remains rejected during a live game over")

func test_restored_banked_rp_is_spent_on_next_production_without_restore_replay() -> void:
	var copy: TechTree = TechTree.new(state.data.tech_config())
	copy.restore({"done": [], "active": "spotters", "progress": {"spotters": 8.0}, "banked": 4.0})
	assert_eq(copy.done, [])
	assert_almost_eq(float(copy.progress.spotters), 8.0)
	assert_almost_eq(copy.banked, 4.0)
	copy.add_points(1.0)
	assert_almost_eq(float(copy.progress.spotters), 13.0)
	assert_almost_eq(copy.banked, 0.0)
	copy.restore({"done": [], "active": "spotters", "progress": {"spotters": 18.25}, "banked": 4.125})
	copy.add_points(0.5)
	assert_true(copy.is_done("spotters"))
	assert_eq(copy.active, "")
	assert_almost_eq(copy.banked, 2.875, 0.000001)
	assert_eq(copy.done_today, ["spotters"])

func test_direct_switch_keeps_two_partial_upgrades_and_pause_resumes() -> void:
	var tech: TechTree = state.tech
	tech.choose("spotters")
	tech.add_points(3.5)
	tech.choose("better_tools")
	tech.add_points(7.25)
	assert_eq(tech.active, "better_tools")
	assert_almost_eq(float(tech.progress.spotters), 3.5)
	assert_almost_eq(float(tech.progress.better_tools), 7.25)
	tech.choose("")
	tech.add_points(2.0)
	assert_almost_eq(tech.banked, 2.0)
	tech.choose("spotters")
	assert_almost_eq(float(tech.progress.spotters), 5.5)
	assert_eq(tech.banked, 0.0)

func test_researcher_walks_works_and_lab_loss_keeps_tree_state() -> void:
	state.clock.day = 3
	var lab_data: Dictionary = state.data.get_building("field_lab")
	assert_eq(int(lab_data.cost.wood), 40)
	assert_eq(int(lab_data.cost.scrap), 15)
	assert_eq(int(lab_data.hp), 150)
	assert_eq(int(lab_data.unlock_day), 3)
	assert_almost_eq(float(lab_data.build_time), 20.0)
	assert_eq(int(lab_data.workers), 2)
	var lab: Building = state.buildings.add("field_lab", state.map.command_center_origin() + Vector2i(4, 0), true)
	var first: Survivor = state.survivors.all()[0]
	var second: Survivor = state.survivors.all()[1]
	state.set_job(first.uid, Survivor.Job.RESEARCHER)
	state.set_job(second.uid, Survivor.Job.RESEARCHER)
	Jobs.tick(state, 0.01)
	assert_eq(first.activity, Survivor.Activity.WALKING, "Researcher walks to Field Lab during day")
	first.pos = Grid.tile_to_world(lab.origin + Vector2i(0, -1))
	second.pos = Grid.tile_to_world(lab.origin + Vector2i(1, -1))
	first.path.clear()
	second.path.clear()
	first.activity = Survivor.Activity.IDLE
	second.activity = Survivor.Activity.IDLE
	state.tech.choose("spotters")
	Jobs.tick(state, 0.01)
	Jobs.tick(state, 70.0)
	assert_eq(ProductionJob.workers_at(state, lab), 2)
	assert_almost_eq(float(state.tech.progress.get("spotters", 0.0)), 0.0, 0.0001, "two workers complete exactly 20 RP")
	assert_true(state.tech.is_done("spotters"))
	state.tech.choose("oiled_turrets")
	state.tech.add_points(5.5)
	state.tech.banked = 2.5
	state.buildings.remove(lab.uid)
	Jobs.tick(state, 0.1)
	assert_eq(first.work_uid, 0)
	assert_true(state.tech.is_done("spotters"))
	assert_almost_eq(float(state.tech.progress.oiled_turrets), 5.502857, 0.00001)
	assert_eq(state.tech.active, "oiled_turrets", "Lab destruction preserves the selected partial upgrade")
	assert_almost_eq(state.tech.banked, 2.5, 0.000001, "Lab destruction preserves banked RP")
	assert_almost_eq(GuardJob.effective_range_px(state, first), 6.0 * Grid.TILE, 0.001, "completed upgrades remain after Lab destruction")
	assert_eq(ProductionJob.workers_at(state, lab), 0, "destroyed Lab releases its Researcher slots")
	state.clock.phase = GameClock.Phase.NIGHT
	Jobs.tick(state, 0.1)
	for i: int in range(120):
		state.survivors.tick(0.1, state.pathfinder, state.map)
		Jobs.tick(state, 0.1)
	assert_true(first.sheltered, "Researcher follows ordinary night shelter rules")

func test_research_rp_uses_hunger_and_morale_work_multipliers() -> void:
	var lab: Building = state.buildings.add("field_lab", state.map.command_center_origin() + Vector2i(4, 0), true)
	var researcher: Survivor = state.survivors.all()[0]
	researcher.pos = Grid.tile_to_world(lab.origin + Vector2i(0, -1))
	state.set_job(researcher.uid, Survivor.Job.RESEARCHER)
	Jobs.tick(state, 0.01)
	researcher.hungry_days = 1
	researcher.morale = 30
	state.tech.choose("spotters")
	Jobs.tick(state, 70.0)
	assert_almost_eq(float(state.tech.progress.spotters), 4.251429, 0.00001)

func test_lab_build_completion_two_slots_and_suspended_researchers_do_not_produce() -> void:
	var origin: Vector2i = state.map.command_center_origin() + Vector2i(4, 0)
	var lab: Building = state.buildings.add("field_lab", origin, false)
	var builder: Survivor = state.survivors.all()[0]
	state.set_job(builder.uid, Survivor.Job.BUILDER)
	builder.pos = Grid.tile_to_world(origin + Vector2i(-1, 0))
	BuilderJob.tick(state, builder, 20.0)
	assert_true(lab.complete, "A Research Lab blueprint completes through BuilderJob")
	var workers: Array[Survivor] = []
	for i: int in range(3):
		var person: Survivor = state.survivors.add("Researcher %d" % i, "blue", origin + Vector2i(-1, 0))
		state.set_job(person.uid, Survivor.Job.RESEARCHER)
		workers.append(person)
	state.tech.choose("spotters")
	Jobs.tick(state, 0.01)
	assert_eq(ProductionJob.workers_at(state, lab), 2, "Field Lab accepts only its two Researcher slots")
	assert_eq(workers[2].work_uid, 0, "Third Researcher is denied a slot")
	workers[0].refusing = true
	workers[1].day_off = true
	workers[2].away = true
	assert_eq(ProductionJob.workers_at(state, lab), 0, "Refusing, day-off and away Researchers hold no slots")
	var progress_before: float = float(state.tech.progress.get("spotters", 0.0))
	Jobs.tick(state, 70.0)
	assert_almost_eq(float(state.tech.progress.get("spotters", 0.0)), progress_before, 0.000001,
		"Suspended Researchers produce no RP")

func test_lab_limit_counts_blueprints_and_allows_rebuild_after_loss() -> void:
	var origin: Vector2i = state.map.command_center_origin() + Vector2i(4, 0)
	state.clock.day = 1
	assert_eq(Placement.check(state, "field_lab", origin), Placement.Result.LOCKED)
	state.clock.day = 3
	var first: Building = state.buildings.add("field_lab", origin, false)
	assert_eq(Placement.check(state, "field_lab", origin + Vector2i(3, 0)), Placement.Result.LIMIT_REACHED)
	assert_eq(Placement.result_text(Placement.Result.LIMIT_REACHED), "Only one Field Lab")
	state.buildings.remove(first.uid)
	assert_eq(Placement.check(state, "field_lab", origin), Placement.Result.OK)
	var complete: Building = state.buildings.add("field_lab", origin, true)
	assert_eq(Placement.check(state, "field_lab", origin + Vector2i(3, 0)), Placement.Result.LIMIT_REACHED,
		"Completed Labs count against the singleton limit")
	state.buildings.remove(complete.uid)
	assert_eq(Placement.check(state, "field_lab", origin), Placement.Result.OK, "A lost Lab can be rebuilt")

func test_unresearched_state_is_seed_and_behavior_neutral() -> void:
	state.combat_rng.seed = 821
	state.waves.enabled = false
	var farm: Building = state.buildings.add("farm", state.map.command_center_origin() + Vector2i(0, -4), true)
	var farmer: Survivor = state.survivors.all()[0]
	farmer.job = Survivor.Job.FARMER
	farmer.work_uid = farm.uid
	farmer.activity = Survivor.Activity.FARMING
	var food_before: int = state.resources.get_amount("food")
	for i: int in range(280): ProductionJob.tick(state, farmer, 0.25)
	assert_eq(state.resources.get_amount("food") - food_before, 8, "Seeded pre-tech farm output remains eight per day")
	var turret: Building = state.buildings.add("turret", state.map.command_center_origin() + Vector2i(3, 0), true)
	state.resources.add("ammo", 2)
	var zombie: Zombie = state.spawn_zombie("brute", turret.center_world() + Vector2(Grid.TILE, 0))
	var shots: Array[int] = []
	state.shot_fired.connect(func(_from: Vector2, _to: Vector2, is_turret: bool) -> void:
		if is_turret: shots.append(1))
	Combat.tick_turrets(state, 0.5)
	assert_eq(shots.size(), 1, "Seeded baseline turret still fires once at its ordinary interval")
	assert_eq(zombie.hp, 160)
	assert_eq(state.tech.done, [])
	assert_eq(state.buildings.count_of("field_lab"), 0)
	assert_eq(state.tech.mult("gather_time"), 1.0)
	assert_eq(state.tech.bonus("guard_range_tiles"), 0.0)
	assert_eq(state.rng.state, 8924953523861730109, "Approved seed 821 simulation RNG fixture")
	assert_eq(state.combat_rng.state, -3803318923831855901, "Approved combat RNG fixture")
	state.clock.day = 8
	assert_eq(int(state.data.get_building("radio_tower").unlock_day), 8)
	state.clock.day = 21
	state.buildings.add("radio_tower", state.map.command_center_origin() + Vector2i(8, 0), true)
	state._check_win()
	assert_true(state.won, "Radio Tower still wins at dawn 21 with no Lab or research")
	assert_eq(state.tech.done, [])

