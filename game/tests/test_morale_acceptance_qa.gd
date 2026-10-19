extends TestCase
## T-215: exercise hooks and job effects, rather than only multiplier accessors.

func _state() -> GameState:
	var state := GameState.new(GameData.load_default(), 21501)
	for s: Survivor in state.survivors.all():
		state.set_job(s.uid, Survivor.Job.IDLE)
	return state

func _has(s: Survivor, id: String) -> bool:
	for mood: Dictionary in s.moods:
		if mood.id == id: return true
	return false

func _report() -> Dictionary:
	return {"left":[], "cc_damage":0, "buildings_destroyed":[], "survivors_killed":[], "scavenging":[]}

func test_every_mood_expires_at_its_nth_dawn_and_refresh_appends() -> void:
	var state: GameState = _state()
	var s: Survivor = state.survivors.all()[0]
	for id: String in state.data.morale_config().moods:
		s.moods.clear()
		assert_true(Morale.add_mood(state, s, id, "Mara"))
		var days: int = int(state.data.morale_config().moods[id].days)
		for dawn: int in range(1, days + 1):
			Morale.begin_dawn(state)
			assert_eq(_has(s, id), dawn < days, "%s dawn %d" % [id, dawn])
		assert_eq(s.morale, 50, id + " expiry restores baseline")
		s.moods.clear()
		Morale.add_mood(state, s, id, "A")
		Morale.add_mood(state, s, "feast")
		for i: int in range(int(state.data.morale_config().moods[id].stack) + 1):
			Morale.add_mood(state, s, id, str(i))
		var count: int = 0
		for mood: Dictionary in s.moods:
			if mood.id == id: count += 1
		assert_eq(count, int(state.data.morale_config().moods[id].stack), id + " same-tick cap")
		assert_eq(s.moods.back().id, id, "refresh appends newest")

func test_morale_clamps_and_bed_moods_are_exclusive() -> void:
	var state: GameState = _state()
	var s: Survivor = state.survivors.all()[0]
	for id: String in ["feast", "day_off", "radio_tower", "rescued", "still_standing"]:
		Morale.add_mood(state, s, id)
	assert_eq(s.morale, 100)
	s.moods.clear()
	for id: String in ["death", "death", "hungry", "hurt", "no_bed", "rough_night"]:
		Morale.add_mood(state, s, id, "Mara")
	assert_eq(s.morale, 0)
	Morale.add_mood(state, s, "bed")
	assert_false(_has(s, "no_bed"))
	Morale.add_mood(state, s, "no_bed")
	assert_false(_has(s, "bed"))

func test_same_tick_night_moods_are_mutually_exclusive() -> void:
	var state: GameState = _state()
	var s: Survivor = state.survivors.all()[0]
	Morale.add_mood(state, s, "quiet_night")
	Morale.add_mood(state, s, "rough_night")
	assert_true(_has(s, "rough_night"))
	assert_false(_has(s, "quiet_night"), "quiet/rough are mutually exclusive, like bed/no_bed")
	Morale.add_mood(state, s, "quiet_night")
	assert_false(_has(s, "rough_night"))

func test_actual_work_jobs_and_hungry_low_follow_band_rates() -> void:
	for pair: Array in [[80,1.15,0], [50,1.0,0], [30,0.85,0], [10,0.7,0], [30,0.425,1]]:
		for job: int in [Survivor.Job.FARMER, Survivor.Job.CRAFTER, Survivor.Job.BUILDER, Survivor.Job.GATHERER]:
			var state: GameState = _state()
			var s: Survivor = state.survivors.all()[0]
			s.job = job
			s.morale = pair[0]
			s.hungry_days = pair[2]
			var expected: float = 0.1 * float(pair[1])
			var b: Building = null
			if job == Survivor.Job.GATHERER:
				s.work_tile = state.map.nodes_of(WorldMap.Occupant.TREE)[0]
				s.activity = Survivor.Activity.HARVESTING
			elif job == Survivor.Job.BUILDER:
				b = state.buildings.add("shelter", Vector2i(10,10), false)
				s.work_uid = b.uid
				s.activity = Survivor.Activity.BUILDING
			else:
				var id: String = "farm" if job == Survivor.Job.FARMER else "workshop"
				b = state.buildings.add(id, Vector2i(10,10), true)
				s.work_uid = b.uid
				s.activity = Survivor.Activity.FARMING if job == Survivor.Job.FARMER else Survivor.Activity.CRAFTING
				if job == Survivor.Job.FARMER:
					expected *= float(state.data.get_building("farm").food_per_farmer) / float(state.data.balance("day_length"))
			Jobs.tick(state, 0.1)
			assert_almost_eq(b.progress if job == Survivor.Job.BUILDER else s.work_acc, expected, 0.000001, "job %d morale %d hunger %d" % [job, pair[0], pair[2]])
			if job == Survivor.Job.BUILDER:
				b.complete = true
				b.hp = b.max_hp - 50
				s.activity = Survivor.Activity.REPAIRING
				Jobs.tick(state, 0.001)
				var repair: float = 0.001 * float(pair[1]) * b.max_hp / (b.build_time * float(state.data.balance("repair_time_fraction")))
				assert_almost_eq(s.work_acc, repair, 0.000001, "repair rate")

func test_movement_and_guard_cadence_remain_at_existing_rates() -> void:
	for morale: int in [80,50,30,10]:
		var state: GameState = _state()
		var s: Survivor = state.survivors.all()[0]
		s.morale = morale
		var start: Vector2 = s.pos
		s.path = [s.tile() + Vector2i.LEFT] as Array[Vector2i]
		s.target = s.path.back()
		state.map.vacate(s.target, Vector2i.ONE)
		state.survivors.tick(0.1, state.pathfinder, state.map)
		assert_almost_eq(start.distance_to(s.pos), float(state.data.balance("survivor_speed")) * 0.1)
		s.path.clear()
		s.job = Survivor.Job.GUARD
		s.post_tile = s.tile()
		s.post_check_timer = 100.0
		s.activity = Survivor.Activity.GUARDING
		var z: Zombie = state.spawn_zombie("brute", s.pos + Vector2(48,0))
		z.hp = 10000
		var ammo: int = state.resources.get_amount("ammo")
		var interval: float = float(state.data.balance("guard_fire_interval"))
		for i: int in range(30): Jobs.tick(state, interval / 10.0)
		assert_eq(state.resources.get_amount("ammo"), ammo - 3, "cadence unchanged at morale %d" % morale)
		assert_almost_eq(s.fire_timer, 0.0)

func test_departure_mood_does_not_cascade_to_a_second_breaking_check() -> void:
	var state: GameState = _state()
	var people: Array[Survivor] = state.survivors.all()
	people[0].moods = [{"id":"death", "label":"A died", "value":-40, "days":3}] as Array[Dictionary]
	people[0].breaking_days = 1
	people[1].moods = [{"id":"death", "label":"B died", "value":-28, "days":3}] as Array[Dictionary]
	Morale.begin_dawn(state)
	var report: Dictionary = _report()
	report.cc_damage = 1
	Morale.end_dawn(state, report)
	assert_eq(state.survivors.count(), 3)
	assert_eq(people[1].morale, 15)
	assert_false(people[1].refusing, "departure mood must not trigger another check")
	assert_eq(people[1].breaking_days, 0)
	assert_eq(report.left.size(), 1)

func test_endless_milestone_is_after_night_25_not_night_24() -> void:
	for day: int in [25,26,30,31]:
		var state: GameState = _state()
		state.endless = true
		state.clock.day = day
		state._on_dawn(day)
		assert_eq(_has(state.survivors.all()[0], "still_standing"), day in [26,31], "dawn day %d follows night %d" % [day, day - 1])

func test_suspended_guard_shelters_and_retains_sheltered_activity() -> void:
	for flag: String in ["refusing", "day_off"]:
		var state: GameState = _state()
		var s: Survivor = state.survivors.all()[0]
		s.job = Survivor.Job.GUARD
		s.set(flag, true)
		state.clock.phase = GameClock.Phase.NIGHT
		state.spawn_zombie("brute", s.pos + Vector2(48,0))
		var ammo: int = state.resources.get_amount("ammo")
		for i: int in range(100):
			Jobs.tick(state, 0.1)
			state.survivors.tick(0.1, state.pathfinder, state.map)
		assert_true(s.sheltered, flag + " guard reaches shelter")
		assert_eq(s.activity, Survivor.Activity.SHELTERED, flag + " guard remains sheltered")
		assert_eq(state.resources.get_amount("ammo"), ammo)
		assert_eq(s.post_uid, 0)

func test_scripted_steady_fixture_pins_pre_morale_production_and_kills() -> void:
	var state: GameState = _state()
	var people: Array[Survivor] = state.survivors.all()
	for s: Survivor in people:
		s.moods.clear()
		Morale.recompute(state, s)
	var farm: Building = state.buildings.add("farm", Vector2i(10,10), true)
	people[0].job = Survivor.Job.FARMER
	people[0].work_uid = farm.uid
	people[0].activity = Survivor.Activity.FARMING
	var shop: Building = state.buildings.add("workshop", Vector2i(13,10), true)
	people[1].job = Survivor.Job.CRAFTER
	people[1].work_uid = shop.uid
	people[1].activity = Survivor.Activity.CRAFTING
	var shelter: Building = state.buildings.add("shelter", Vector2i(16,10), false)
	people[2].job = Survivor.Job.BUILDER
	people[2].work_uid = shelter.uid
	people[2].activity = Survivor.Activity.BUILDING
	people[3].job = Survivor.Job.GATHERER
	people[3].work_tile = state.map.nodes_of(WorldMap.Occupant.TREE)[0]
	people[3].activity = Survivor.Activity.HARVESTING
	var guard: Survivor = state.survivors.add("Fixture guard", "blue", state.cc_ring_tiles()[0])
	guard.job = Survivor.Job.GUARD
	guard.post_tile = guard.tile()
	guard.post_check_timer = 100.0
	guard.activity = Survivor.Activity.GUARDING
	state.spawn_zombie("walker", guard.pos + Vector2(48,0))
	var food: int = state.resources.get_amount("food")
	var ammo: int = state.resources.get_amount("ammo")
	var scrap: int = state.resources.get_amount("scrap")
	var rng_before: int = state.rng.state
	var combat_before: int = state.combat_rng.state
	for i: int in range(80): Jobs.tick(state, 0.125)
	assert_eq(state.resources.get_amount("food"), food + 1)
	assert_eq(state.resources.get_amount("ammo"), ammo + 24 - 1)
	assert_eq(state.resources.get_amount("scrap"), scrap - 2)
	assert_almost_eq(shelter.progress, 10.0)
	assert_eq(people[3].carry_amount, 16)
	assert_eq(state.zombies_killed, 1)
	assert_eq(state.rng.state, rng_before)
	assert_eq(state.combat_rng.state, combat_before)

func test_feast_counts_away_people_and_rejection_preserves_all_state() -> void:
	var state: GameState = _state()
	var people: Array[Survivor] = state.survivors.all()
	people[0].away = true
	state.resources.take("food", state.resources.get_amount("food"))
	state.resources.add("food", 7)
	var before: Dictionary = SaveGame.capture(state)
	assert_eq(Morale.feast_block_reason(state), "Need 1 food")
	assert_false(Morale.hold_feast(state))
	assert_eq(SaveGame.capture(state), before)
	state.resources.add("food", 1)
	assert_true(Morale.hold_feast(state))
	assert_eq(state.resources.get_amount("food"), 0)
	for person: Survivor in people: assert_true(_has(person, "feast"))

func test_day_off_precedence_and_suspension_clear_work_preserve_cargo_job() -> void:
	var state: GameState = _state()
	var s: Survivor = state.survivors.all()[0]
	state.game_over = true
	assert_eq(Morale.day_off_block_reason(state, null), "Game over")
	state.game_over = false
	assert_eq(Morale.day_off_block_reason(state, null), "Missing survivor")
	s.away = true
	state.clock.elapsed = 28.0
	assert_eq(Morale.day_off_block_reason(state, s), "Not morning")
	state.clock.elapsed = 0.0
	s.refusing = true
	s.day_off = true
	assert_eq(Morale.day_off_block_reason(state, s), "Away")
	s.away = false
	assert_eq(Morale.day_off_block_reason(state, s), "Refusing work")
	s.refusing = false
	assert_eq(Morale.day_off_block_reason(state, s), "Already off")
	s.day_off = false
	s.job = Survivor.Job.GATHERER
	s.work_uid = 100
	s.work_acc = 2.0
	s.work_tile = Vector2i(10,10)
	s.path = [s.tile() + Vector2i.LEFT] as Array[Vector2i]
	s.carry_kind = "wood"
	s.carry_amount = 3
	assert_true(Morale.give_day_off(state, s.uid))
	assert_eq(s.job, Survivor.Job.GATHERER)
	assert_eq(s.carry_amount, 3)
	assert_eq(s.carry_kind, "wood")
	assert_eq(s.work_uid, 0)
	assert_eq(s.work_acc, 0.0)
	assert_eq(s.work_tile, Vector2i(-1,-1))
	assert_true(s.path.is_empty())
	assert_false(state.order_move(s.uid, s.tile() + Vector2i.LEFT))
	assert_false(state.expeditions.send(s.uid))
	assert_true(state.set_job(s.uid, Survivor.Job.BUILDER))
	Jobs.tick(state, 1.0)
	assert_true(s.day_off)
	assert_eq(s.work_uid, 0)
	assert_eq(s.work_acc, 0.0)

func test_scavenging_hurt_and_loss_have_correct_moods_and_night_summary() -> void:
	for lost: bool in [false,true]:
		var state: GameState = _state()
		var people: Array[Survivor] = state.survivors.all()
		var config: Dictionary = state.data.expeditions()
		config.hurt_base = 1.0
		config.hurt_max = 1.0
		config.lost_base = 1.0 if lost else 0.0
		config.lost_max = 1.0 if lost else 0.0
		config.newcomer_chance = 0.0
		state.expeditions._return_run(state, people[0], {"day":1})
		assert_false(_has(people[0], "scavenged"))
		assert_eq(_has(people[1], "death"), lost)
		assert_false(_has(people[1], "left"))
		state.clock.day = 2
		state._on_dawn(2)
		assert_eq(_has(people[1], "quiet_night"), not lost)
		assert_false(_has(people[1], "rough_night"))
