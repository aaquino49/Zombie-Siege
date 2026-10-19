class_name TestExpeditions extends TestCase

var data: GameData
var state: GameState

func before_each() -> void:
	data = GameData.load_default()
	state = GameState.new(data, 1337)
	state.waves.enabled = false

func after_each() -> void:
	state = null
	data = null

func _first_survivor() -> Survivor:
	return state.survivors.all()[0]

func _arrive_at_edge(s: Survivor) -> void:
	state.survivors.tick(1000.0, state.pathfinder, state.map)
	state.expeditions.tick(state, 0.0)

func _dusk() -> void:
	state.clock.elapsed = float(data.balance("day_length")) - 0.1
	state.clock.advance(0.2)

func _dawn() -> void:
	state.clock.elapsed = float(data.balance("night_min_length")) - 0.1
	state.clock.advance(0.2)

func _force_return(chance: String, value: float) -> Dictionary:
	var config: Dictionary = data._expeditions
	config["hurt_base"] = 0.0
	config["hurt_per_day"] = 0.0
	config["hurt_max"] = 1.0
	config["lost_base"] = 0.0
	config["lost_per_day"] = 0.0
	config["lost_max"] = 1.0
	config["newcomer_chance"] = 0.0
	config[chance] = value
	var s: Survivor = _first_survivor()
	assert_true(state.expeditions.send(s.uid))
	_arrive_at_edge(s)
	_dusk()
	return state.expeditions._dawn_report.back() if not state.expeditions._dawn_report.is_empty() else {}

func test_can_send_reports_each_reason() -> void:
	var s: Survivor = _first_survivor()
	state.clock.elapsed = float(data.balance("day_length")) * 0.4
	assert_eq(state.expeditions.can_send(s), "not morning")
	state.clock.elapsed = 0.0
	s.job = Survivor.Job.GUARD
	assert_eq(state.expeditions.can_send(s), "guard")
	s.job = Survivor.Job.IDLE
	s.away = true
	assert_eq(state.expeditions.can_send(s), "already away")
	s.away = false
	s.sheltered = true
	assert_eq(state.expeditions.can_send(s), "sheltered")
	s.sheltered = false
	var dead := Survivor.new()
	dead.uid = -1
	dead.hp = 0
	assert_eq(state.expeditions.can_send(dead), "dead")
	assert_true(state.expeditions.send(s.uid))
	assert_eq(state.expeditions.can_send(state.survivors.all()[1]), "run limit")

func test_run_goes_away_and_returns_at_dusk_with_loot() -> void:
	var s: Survivor = _first_survivor()
	s.job = Survivor.Job.BUILDER
	assert_true(state.expeditions.send(s.uid))
	assert_eq(s.job, Survivor.Job.BUILDER)
	assert_eq(state.expeditions.active().size(), 1)
	_arrive_at_edge(s)
	assert_true(s.away)
	assert_false(state.expeditions.send(s.uid))
	_dusk()
	assert_false(s.away)
	assert_eq(s.job, Survivor.Job.BUILDER)
	_dawn()
	assert_true(state.last_dawn_report.has("scavenging"))
	var entry: Dictionary = state.last_dawn_report["scavenging"][0]
	assert_eq(entry["name"], s.name)
	for kind: String in ["wood", "scrap", "food", "ammo"]:
		var bounds: Array = data.expeditions()["loot"][kind]
		assert_true(int(entry["loot"][kind]) >= int(bounds[0]))
		assert_true(int(entry["loot"][kind]) <= int(bounds[1]))
		assert_true(state.resources.get_amount(kind) >= int(entry["loot"][kind]))

func test_hurt_lost_and_newcomer_results() -> void:
	var hurt: Dictionary = _force_return("hurt_base", 1.0)
	assert_true(bool(hurt.get("hurt", false)))
	assert_false(bool(hurt.get("lost", false)))
	var hurt_survivor: Survivor = state.survivors.get_by_uid(1)
	assert_eq(hurt_survivor.hp, hurt_survivor.max_hp / 2)

	state = GameState.new(data, 1337)
	state.waves.enabled = false
	var lost: Dictionary = _force_return("lost_base", 1.0)
	assert_true(bool(lost.get("lost", false)))
	assert_eq(state.survivors_lost, 1)
	assert_eq(state.survivors.get_by_uid(1), null)
	assert_eq(lost["lost"], true)

	state = GameState.new(data, 1337)
	state.waves.enabled = false
	state.buildings.add("shelter", state.map.command_center_origin() + Vector2i(3, 0), true)
	_force_return("newcomer_chance", 1.0)
	assert_eq(state.survivors.count(), 5)

func test_result_is_deterministic_for_seed_day_and_uid() -> void:
	var first: Dictionary = state.expeditions._roll_result(state, _first_survivor(), state.clock.day)
	var second_state := GameState.new(GameData.load_default(), 1337)
	var second: Dictionary = second_state.expeditions._roll_result(second_state, second_state.survivors.all()[0], second_state.clock.day)
	assert_eq(first, second)

func test_no_survivor_is_away_at_dawn() -> void:
	var s: Survivor = _first_survivor()
	assert_true(state.expeditions.send(s.uid))
	_arrive_at_edge(s)
	_dusk()
	assert_false(s.away)
	state.clock.elapsed = float(data.balance("night_min_length")) - 0.1
	state.clock.advance(0.2)
	for survivor: Survivor in state.survivors.all():
		assert_false(survivor.away)

func test_zombies_ignore_away_survivors() -> void:
	var s: Survivor = _first_survivor()
	for other: Survivor in state.survivors.all():
		if other != s:
			state.survivors.remove(other.uid)
	s.away = true
	var zombie: Zombie = state.spawn_zombie("walker", s.pos)
	var hp: int = s.hp
	ZombieAI.tick(state, zombie.attack_interval * 2.0)
	assert_eq(s.hp, hp)
	assert_eq(zombie.target_survivor_uid, 0)

func test_state_tick_reaches_edge_and_return_preserves_rng_and_adds_loot() -> void:
	data._expeditions["lost_base"] = 0.0
	data._expeditions["lost_per_day"] = 0.0
	data._expeditions["newcomer_chance"] = 0.0
	var s: Survivor = _first_survivor()
	s.job = Survivor.Job.IDLE
	var rng_before: int = state.rng.state
	var returned: Array[Dictionary] = []
	state.expeditions.run_returned.connect(func(_s: Survivor, result: Dictionary) -> void:
		returned.append(result))
	assert_true(state.expeditions.send(s.uid))
	for i: int in range(500):
		state.tick(0.1)
		if s.away:
			break
	assert_true(s.away, "GameState must detect arrival after movement")
	var before: Dictionary = {}
	for kind: String in ["wood", "scrap", "food", "ammo"]:
		before[kind] = state.resources.get_amount(kind)
	_dusk()
	assert_eq(returned.size(), 1)
	if returned.is_empty():
		return
	for kind: String in before:
		assert_eq(state.resources.get_amount(kind) - int(before[kind]), int(returned[0]["loot"][kind]))
	assert_eq(state.rng.state, rng_before, "A run must leave the shared RNG stream untouched")
	assert_true(state.cc_ring_tiles().has(s.tile()))
	assert_true(state.map.is_passable(s.tile()))
	for other: Survivor in state.survivors.all():
		if other != s:
			assert_ne(s.tile(), other.tile())
	assert_true(state.expeditions.active().is_empty())

func test_outbound_run_is_cancelled_at_dusk_and_walks_home_without_loot() -> void:
	var s: Survivor = _first_survivor()
	s.job = Survivor.Job.BUILDER
	assert_true(state.expeditions.send(s.uid))
	state.survivors.tick(1.0, state.pathfinder, state.map)
	assert_false(s.away)
	var before: Dictionary = {}
	for kind: String in ["wood", "scrap", "food", "ammo"]:
		before[kind] = state.resources.get_amount(kind)
	_dusk()
	assert_false(s.away)
	assert_true(state.cc_ring_tiles().has(s.target))
	assert_eq(s.job, Survivor.Job.BUILDER)
	for kind: String in before:
		assert_eq(state.resources.get_amount(kind), before[kind])
	assert_true(state.expeditions.take_dawn_report().is_empty())
	state.survivors.tick(1000.0, state.pathfinder, state.map)
	state.expeditions.tick(state, 0.0)
	assert_true(state.cc_ring_tiles().has(s.tile()))
	assert_true(state.expeditions.active().is_empty())

func test_away_survivor_does_not_work_move_or_take_shelter() -> void:
	var s: Survivor = _first_survivor()
	var farm: Building = state.buildings.add("farm", state.map.command_center_origin() + Vector2i(4, 0), true)
	s.job = Survivor.Job.FARMER
	s.work_uid = farm.uid
	s.activity = Survivor.Activity.FARMING
	s.away = true
	s.path = state.pathfinder.find_path(s.tile(), state.cc_ring_tiles().back())
	var pos: Vector2 = s.pos
	var food: int = state.resources.get_amount("food")
	assert_eq(ProductionJob.workers_at(state, farm), 0)
	Jobs.tick(state, float(data.balance("day_length")))
	state.survivors.tick(1000.0, state.pathfinder, state.map)
	assert_eq(s.pos, pos)
	assert_eq(s.work_acc, 0.0)
	assert_eq(state.resources.get_amount("food"), food)
	state.clock.phase = GameClock.Phase.NIGHT
	Jobs.tick(state, 10.0)
	assert_false(s.sheltered)
	assert_eq(s.shelter_uid, 0)

func test_second_run_becomes_available_on_day_ten() -> void:
	for s: Survivor in state.survivors.all():
		s.job = Survivor.Job.IDLE
	state.clock.day = 9
	assert_true(state.expeditions.send(_first_survivor().uid))
	assert_eq(state.expeditions.can_send(state.survivors.all()[1]), "run limit")
	state.clock.day = 10
	assert_true(state.expeditions.send(state.survivors.all()[1].uid))
	assert_true(state.expeditions.send(state.survivors.all()[2].uid))
	assert_eq(state.expeditions.can_send(state.survivors.all()[3]), "run limit")

func test_lost_reason_and_hurt_minimum_hp() -> void:
	var s: Survivor = _first_survivor()
	s.hp = 1
	_force_return("hurt_base", 1.0)
	assert_eq(s.hp, 1)
	state = GameState.new(data, 1337)
	state.waves.enabled = false
	s = _first_survivor()
	var before: int = state.resources.get_amount("wood")
	_force_return("lost_base", 1.0)
	assert_eq(s.loss_reason, "lost on a scavenging run")
	assert_eq(state.resources.get_amount("wood"), before)

func test_newcomer_uses_store_signal_and_shared_name_variant_with_free_bed() -> void:
	state.buildings.add("shelter", state.map.command_center_origin() + Vector2i(3, 0), true)
	var uid: int = state.survivors.next_uid()
	var expected_name: String = DawnRules.free_name(state, uid)
	var expected_variant: String = DawnRules.variant_for_uid(state, uid)
	var added: Array[Survivor] = []
	state.survivors.survivor_added.connect(func(s: Survivor) -> void: added.append(s))
	_force_return("newcomer_chance", 1.0)
	assert_eq(added.size(), 1)
	if added.is_empty():
		return
	assert_eq(added[0].name, expected_name)
	assert_eq(added[0].variant, expected_variant)
	assert_true(state.cc_ring_tiles().has(added[0].tile()))

