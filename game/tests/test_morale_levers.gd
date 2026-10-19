extends "res://tests/test_case.gd"

func test_feast_spend_and_cooldown_are_atomic() -> void:
	var state := GameState.new(GameData.load_default(), 219)
	state.clock.day = 5
	state.resources.add("food", 1000)
	var before: int = state.resources.get_amount("food")
	assert_true(Morale.hold_feast(state))
	assert_eq(state.resources.get_amount("food"), before - 2 * state.survivors.count())
	assert_eq(state.last_feast_day, 5)
	var after: int = state.resources.get_amount("food")
	assert_false(Morale.hold_feast(state))
	assert_eq(state.resources.get_amount("food"), after)
	assert_eq(Morale.feast_block_reason(state), "Next feast: day 8")

func test_day_off_boundary_and_suspension_flags() -> void:
	var state := GameState.new(GameData.load_default(), 220)
	var s: Survivor = state.survivors.all()[0]
	state.clock.elapsed = 27.999
	assert_true(Morale.give_day_off(state, s.uid))
	assert_true(s.day_off)
	assert_true(s.path.is_empty())
	Morale.begin_dawn(state)
	Morale.end_dawn(state, {"left":[],"cc_damage":1,"buildings_destroyed":[],"survivors_killed":[],"scavenging":[]})
	assert_false(s.day_off)
	assert_true(_has_mood(s, "day_off"), "Day off is awarded at the next dawn")
	var other: Survivor = state.survivors.all()[1]
	state.clock.elapsed = 28.0
	assert_eq(Morale.day_off_block_reason(state, other), "Not morning")
	assert_false(Morale.give_day_off(state, other.uid))

func test_suspension_cannot_be_bypassed_by_move_or_job_change() -> void:
	var state := GameState.new(GameData.load_default(), 221)
	var s: Survivor = state.survivors.all()[0]
	s.refusing = true
	assert_false(state.order_move(s.uid, s.tile() + Vector2i.RIGHT))
	assert_true(state.set_job(s.uid, Survivor.Job.FARMER))
	assert_true(s.refusing)
	assert_false(state.expeditions.send(s.uid))

func test_feast_reason_precedence_and_cannot_cancel_refusal() -> void:
	var state := GameState.new(GameData.load_default(), 228)
	state.clock.phase = GameClock.Phase.NIGHT
	state.game_over = true
	assert_eq(Morale.feast_block_reason(state), "Game over")
	state.game_over = false
	assert_eq(Morale.feast_block_reason(state), "Night")
	state.clock.phase = GameClock.Phase.DAY
	state.resources.take("food", state.resources.get_amount("food"))
	assert_eq(Morale.feast_block_reason(state), "Need 8 food")
	state.last_feast_day = state.clock.day
	assert_eq(Morale.feast_block_reason(state), "Next feast: day 4")
	var s: Survivor = state.survivors.all()[0]
	s.refusing = true
	state.clock.day = 4
	state.resources.add("food", 100)
	assert_true(Morale.hold_feast(state))
	assert_true(s.refusing)

func test_breaking_refuses_then_leaves_at_most_one_by_morale_then_uid() -> void:
	var state := GameState.new(GameData.load_default(), 229)
	var people: Array[Survivor] = state.survivors.all()
	people[0].morale = 10
	people[1].morale = 5
	people[2].morale = 5
	var report := {"left":[]}
	Morale._apply_breaking(state, report)
	assert_true(people[0].refusing)
	assert_true(people[2].refusing)
	assert_true(people[1].refusing)
	assert_eq(people[0].breaking_days, 1)
	Morale._apply_breaking(state, report)
	assert_eq(state.survivors.count(), 3)
	assert_eq(report.left_morale, [people[1].name])
	assert_true(people[0].refusing)

func test_last_breaking_survivor_causes_normal_loss() -> void:
	var state := GameState.new(GameData.load_default(), 230)
	var person: Survivor = state.survivors.all()[0]
	for other: Survivor in state.survivors.all():
		if other.uid != person.uid: state.survivors.remove(other.uid)
	person.morale = 10
	Morale._apply_breaking(state, {"left":[]})
	Morale._apply_breaking(state, {"left":[]})
	state._check_lose()
	assert_true(state.game_over)
	assert_eq(state.lose_reason, "survivors")

func test_cancelled_scavenging_gives_no_return_mood() -> void:
	var state := GameState.new(GameData.load_default(), 231)
	var person: Survivor = state.survivors.all()[0]
	assert_true(state.expeditions.send(person.uid))
	state.expeditions._on_phase_changed(GameClock.Phase.NIGHT, state.clock.day)
	assert_false(person.away)
	assert_false(_has_mood(person, "scavenged"))

func test_unhurt_scavenging_return_grants_mood() -> void:
	var state := GameState.new(GameData.load_default(), 232)
	var person: Survivor = state.survivors.all()[0]
	state.data._expeditions.hurt_base = 0.0
	state.data._expeditions.hurt_per_day = 0.0
	state.data._expeditions.lost_base = 0.0
	state.data._expeditions.lost_per_day = 0.0
	state.data._expeditions.newcomer_chance = 0.0
	state.expeditions._return_run(state, person, {"day":1})
	assert_true(_has_mood(person, "scavenged"))

func _has_mood(s: Survivor, id: String) -> bool:
	for mood: Dictionary in s.moods:
		if mood.id == id: return true
	return false

func test_guard_miss_spends_ammo_returns_target_and_uses_isolated_seeded_rng() -> void:
	var state := GameState.new(GameData.load_default(), 233)
	var person: Survivor = state.survivors.all()[0]
	var target: Zombie = state.spawn_zombie("walker", person.pos + Vector2(48.0, 0.0))
	state.combat_rng.seed = 9981
	var sim_rng_before: int = state.rng.state
	var ammo_before: int = state.resources.get_amount("ammo")
	var health_before: int = target.hp
	var returned: Zombie = Combat.try_fire(state, person.pos, 100.0, 20, false, 0.0)
	assert_eq(returned, target)
	assert_eq(state.resources.get_amount("ammo"), ammo_before - 1)
	assert_eq(target.hp, health_before)
	assert_ne(state.combat_rng.state, 9981)
	assert_eq(state.rng.state, sim_rng_before)

func test_no_target_no_ammo_and_certain_hits_do_not_draw_combat_rng() -> void:
	var state := GameState.new(GameData.load_default(), 234)
	var person: Survivor = state.survivors.all()[0]
	state.combat_rng.seed = 8822
	var initial: int = state.combat_rng.state
	assert_eq(Combat.try_fire(state, person.pos, 100.0, 10, false, 0.8), null)
	assert_eq(state.combat_rng.state, initial)
	var target: Zombie = state.spawn_zombie("walker", person.pos + Vector2(48.0, 0.0))
	var hp: int = target.hp
	assert_eq(Combat.try_fire(state, person.pos, 100.0, 10, false, 1.0), target)
	assert_eq(target.hp, hp - 10)
	assert_eq(state.combat_rng.state, initial)
	state.resources.take("ammo", state.resources.get_amount("ammo"))
	assert_eq(Combat.try_fire(state, person.pos, 100.0, 10, false, 0.7), null)
	assert_eq(state.combat_rng.state, initial)

func test_same_seed_same_night_repeats_misses_ammo_and_damage() -> void:
	var first: Array = _seeded_volley(235)
	var second: Array = _seeded_volley(235)
	assert_eq(first, second)

func _seeded_volley(seed_value: int) -> Array:
	var state := GameState.new(GameData.load_default(), seed_value)
	var person: Survivor = state.survivors.all()[0]
	var target: Zombie = state.spawn_zombie("brute", person.pos + Vector2(48.0, 0.0))
	state.combat_rng.seed = hash([state.map_seed, state.clock.day, "combat"])
	var health: Array[int] = []
	for _shot: int in range(8):
		Combat.try_fire(state, person.pos, 100.0, 10, false, 0.7)
		health.append(target.hp)
	return [health, state.resources.get_amount("ammo"), state.rng.state, state.combat_rng.state]
