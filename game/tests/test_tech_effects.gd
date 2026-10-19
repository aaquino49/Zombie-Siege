extends TestCase

var state: GameState

func before_each() -> void:
	state = GameState.new(GameData.load_default(), 821)
	for survivor: Survivor in state.survivors.all(): state.set_job(survivor.uid, Survivor.Job.IDLE)

func test_guard_range_and_fog_and_turret_interval_use_effect_lookups() -> void:
	state.tech.done.append_array(["spotters", "oiled_turrets"])
	var guard: Survivor = state.survivors.all()[0]
	var tower: Building = state.buildings.add("watchtower", state.map.command_center_origin() + Vector2i(4, 4), true)
	guard.on_tower = true
	assert_almost_eq(GuardJob.effective_range_px(state, guard), 6.0 * Grid.TILE)
	assert_almost_eq(GuardJob.effective_range_px(state, guard, tower), 9.0 * Grid.TILE)
	state.clock.day = 6
	state.clock.phase = GameClock.Phase.NIGHT
	var fog: Dictionary = state.data.weather_config().fog
	fog.chance = 1.0
	fog.no_repeat = false
	assert_almost_eq(GuardJob.effective_range_px(state, guard), 5.0 * Grid.TILE)
	assert_almost_eq(GuardJob.effective_range_px(state, guard, tower), 8.0 * Grid.TILE)
	state.clock.phase = GameClock.Phase.DAY
	var turret: Building = state.buildings.add("turret", state.map.command_center_origin() + Vector2i(3, 0), true)
	var shots: Array[int] = []
	state.shot_fired.connect(func(_a: Vector2, _b: Vector2, is_turret: bool) -> void:
		if is_turret: shots.append(1))
	state.spawn_zombie("brute", turret.center_world() + Vector2(Grid.TILE, 0))
	Combat.tick_turrets(state, 0.4)
	assert_eq(shots.size(), 1, "Oiled Turrets fires at the 0.4-second boundary")

func test_farm_exact_clear_and_rain_yields_and_camp_songs_dawn_value() -> void:
	state.tech.done.append_array(["crop_rotation", "camp_songs"])
	var farm: Building = state.buildings.add("farm", state.map.command_center_origin() + Vector2i(0, -4), true)
	var farmer: Survivor = state.survivors.all()[0]
	state.set_job(farmer.uid, Survivor.Job.FARMER)
	farmer.work_uid = farm.uid
	farmer.activity = Survivor.Activity.FARMING
	state._weather_day_cache_key = [state.map_seed, state.clock.day, state.data.weather_config().hash()]
	state._weather_day_cache_result = "clear"
	var initial: int = state.resources.get_amount("food")
	for i: int in range(280): ProductionJob.tick(state, farmer, 0.25)
	assert_eq(state.resources.get_amount("food") - initial, 10)
	state._weather_day_cache_result = "rain"
	initial = state.resources.get_amount("food")
	for i: int in range(280): ProductionJob.tick(state, farmer, 0.25)
	assert_eq(state.resources.get_amount("food") - initial, 15)
	state.buildings.add("campfire", state.map.command_center_origin() + Vector2i(-4, 0), true)
	Morale.begin_dawn(state)
	Morale.end_dawn(state, {"left": [], "cc_damage": 0, "buildings_destroyed": [], "scavenging": [], "survivors_killed": []})
	var fire_mood: Dictionary = {}
	for mood: Dictionary in farmer.moods:
		if mood.id == "campfire": fire_mood = mood
	assert_eq(fire_mood.value, 9)

func test_ammo_press_and_damage_rounding_minimum_zero_and_command_center() -> void:
	state.tech.done.append_array(["ammo_press", "reinforced_frames"])
	var workshop: Building = state.buildings.add("workshop", state.map.command_center_origin() + Vector2i(0, 4), true)
	var crafter: Survivor = state.survivors.all()[0]
	state.set_job(crafter.uid, Survivor.Job.CRAFTER)
	crafter.work_uid = workshop.uid
	crafter.activity = Survivor.Activity.CRAFTING
	state.resources.add("scrap", 1)
	var ammo: int = state.resources.get_amount("ammo")
	ProductionJob.tick(state, crafter, 5.0)
	assert_eq(state.resources.get_amount("ammo") - ammo, 15)
	var wall: Building = state.buildings.add("wooden_wall", state.map.command_center_origin() + Vector2i(-3, 0), true)
	var hp: int = wall.hp
	var spitter: Zombie = state.spawn_zombie("spitter", wall.center_world() + Vector2(Grid.TILE * 2.0, 0))
	state.projectiles.launch(state, spitter.pos, wall, wall.origin, {"projectile_speed": 10000.0, "damage": 6})
	state.projectiles.tick(state, 1.0)
	assert_eq(wall.hp, hp - 5, "Each acid hit rounds after mitigation")
	var melee: Zombie = state.spawn_zombie("walker", wall.center_world())
	melee.damage = 1
	hp = wall.hp
	ZombieAI._attack_building(state, melee, wall, melee.attack_interval)
	assert_eq(wall.hp, hp - 1, "Real positive melee damage retains the minimum-one rule")
	hp = wall.hp
	state.damage_building(wall, 0)
	assert_eq(wall.hp, hp, "Zero damage stays zero")
	var cc: Building = state.buildings.all_of_type("command_center")[0]
	hp = cc.hp
	melee.damage = 6
	ZombieAI._attack_building(state, melee, cc, melee.attack_interval)
	assert_eq(cc.hp, hp - 5, "Command Center uses the real melee damage path and mitigation")

func test_gather_speed_multiplier_stacks_with_yard() -> void:
	state.tech.done.append("better_tools")
	var trees: Array[Vector2i] = state.map.nodes_of(WorldMap.Occupant.TREE)
	assert_gt(trees.size(), 0)
	var tree: Vector2i = trees[0]
	state.buildings.add("lumber_yard", tree + Vector2i(2, 0), true)
	var gatherer: Survivor = state.survivors.all()[0]
	state.set_job(gatherer.uid, Survivor.Job.GATHERER, "wood")
	gatherer.pos = Grid.tile_to_world(tree + Vector2i(-1, 0))
	gatherer.work_tile = tree
	gatherer.activity = Survivor.Activity.HARVESTING
	GathererJob.tick(state, gatherer, 0.34)
	assert_eq(gatherer.carry_amount, 1, "Better Tools stacks with the yard gather speed")
	var scrap_nodes: Array[Vector2i] = state.map.nodes_of(WorldMap.Occupant.SCRAP)
	assert_gt(scrap_nodes.size(), 0)
	var scrap_tile: Vector2i = scrap_nodes[0]
	var salvager: Survivor = state.survivors.all()[1]
	state.set_job(salvager.uid, Survivor.Job.GATHERER, "scrap")
	salvager.pos = Grid.tile_to_world(scrap_tile + Vector2i(-1, 0))
	salvager.work_tile = scrap_tile
	salvager.activity = Survivor.Activity.HARVESTING
	GathererJob.tick(state, salvager, 0.99)
	assert_eq(salvager.carry_amount, 0, "Scrap gather threshold includes Better Tools")
	GathererJob.tick(state, salvager, 0.01)
	assert_eq(salvager.carry_amount, 1)

func test_first_aid_dawn_heal_caps_hp_and_runs_before_morale() -> void:
	state.tech.done.append("first_aid")
	state.tech.choose("spotters")
	state.tech.add_points(20.0)
	var survivor: Survivor = state.survivors.all()[0]
	survivor.hp = survivor.max_hp - 5
	state._on_dawn(2)
	assert_eq(survivor.hp, survivor.max_hp, "Dawn heal caps at max HP")
	var has_hurt: bool = false
	for mood: Dictionary in survivor.moods:
		if mood.id == "hurt": has_hurt = true
	assert_false(has_hurt, "Morale samples HP after the independent First Aid hook")
	assert_eq(state.last_dawn_report.research.done_today, ["spotters"])
	assert_true(state.tech.done_today.is_empty(), "Dawn report clears the completion journal before save")

func test_bunk_beds_changes_newcomer_threshold_and_real_night_capacity() -> void:
	state.tech.done.append("bunk_beds")
	var origin: Vector2i = state.map.command_center_origin() + Vector2i(5, 0)
	var shelter: Building = state.buildings.add("shelter", origin, true)
	for i: int in range(4): state.survivors.add("Base %d" % i, "blue", state.cc_ring_tiles().back())
	assert_eq(state.buildings.total_beds(), 10)
	assert_gt(DawnRules.process(state).arrived.size(), 0,
		"Upgraded capacity admits newcomers at population eight")
	var matched: GameState = GameState.new(GameData.load_default(), 821)
	for i: int in range(4): matched.survivors.add("Base %d" % i, "blue", matched.cc_ring_tiles().back())
	matched.buildings.add("shelter", matched.map.command_center_origin() + Vector2i(5, 0), true)
	assert_eq(matched.buildings.total_beds(), 8)
	assert_true(DawnRules.process(matched).arrived.is_empty(), "Base beds reject newcomers at population eight")
	var ring_tile: Vector2i = origin + Vector2i(-1, 0)
	for i: int in range(7):
		var person: Survivor = state.survivors.add("Night %d" % i, "blue", ring_tile)
		state.set_job(person.uid, Survivor.Job.IDLE)
		state.clock.phase = GameClock.Phase.NIGHT
		ShelterRules.tick(state, person, 0.1)
		if i < 6:
			assert_eq(person.shelter_uid, shelter.uid)
			assert_true(person.sheltered)
		else:
			assert_ne(person.shelter_uid, shelter.uid, "Seventh occupant uses the remaining CC bed")
	assert_eq(ShelterRules.beds_held(state, shelter), 6)
