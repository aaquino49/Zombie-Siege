extends TestCase
## T-221 final M12 release QA: cross-feature work rates, Researcher suspension,
## Camp Songs mood, First Aid order, Bunk Beds real occupancy, spitter fallback
## fix (T-212) and seeded combat/weather determinism. Save round trips live in
## test_m12_save_qa.gd. Reports, never patches: no game code changes here.

func _vacate(state: GameState, origin: Vector2i, w: int, h: int) -> void:
	for y: int in range(origin.y, origin.y + h):
		for x: int in range(origin.x, origin.x + w):
			var tile := Vector2i(x, y)
			if state.map.occupant_at(tile) != WorldMap.Occupant.BUILDING:
				state.map.vacate(tile, Vector2i.ONE)

func _idle_others(state: GameState, keep_uid: int) -> void:
	for s: Survivor in state.survivors.all():
		if s.uid != keep_uid:
			state.set_job(s.uid, Survivor.Job.IDLE)

func _post_researcher(state: GameState, s: Survivor, lab: Building) -> void:
	s.job = Survivor.Job.RESEARCHER
	s.pos = Grid.tile_to_world(lab.origin + Vector2i(-1, 0))
	s.work_uid = lab.uid
	s.activity = Survivor.Activity.IDLE
	s.job_timer = 0.0

func _researcher_state(morale_value: int, hungry: bool) -> Dictionary:
	var data: GameData = GameData.load_default()
	var state := GameState.new(data, 22101)
	state.clock.phase = GameClock.Phase.DAY
	_vacate(state, Vector2i(30, 30), 4, 4)
	var lab: Building = state.buildings.add("field_lab", Vector2i(30, 30), true)
	var s: Survivor = state.survivors.all()[0]
	_idle_others(state, s.uid)
	_post_researcher(state, s, lab)
	s.morale = morale_value
	s.hungry_days = 1 if hungry else 0
	state.tech.choose("spotters")
	return {"state": state, "worker": s, "lab": lab}

func test_cross_feature_work_rates_follow_morale_bands() -> void:
	# Researcher RP: 10 RP/day over the 70 s day, scaled by band x hungry.
	for case: Array in [[80, false, 1.15], [50, false, 1.0], [30, false, 0.85], [10, false, 0.7], [30, true, 0.425]]:
		var fix: Dictionary = _researcher_state(int(case[0]), bool(case[1]))
		var state: GameState = fix["state"]
		Jobs.tick(state, 7.0)
		assert_almost_eq(float(state.tech.progress.get("spotters", 0.0)), float(case[2]), 0.00001,
			"Researcher 7 s at morale %d hungry %s" % [int(case[0]), str(bool(case[1]))])
	# Farmer food: 8 per full Steady worker-day; Low earns proportionally less.
	for case: Array in [[50, 1], [30, 0]]:
		var data: GameData = GameData.load_default()
		var state := GameState.new(data, 22102)
		state.clock.phase = GameClock.Phase.DAY
		_vacate(state, Vector2i(34, 30), 4, 4)
		var farm: Building = state.buildings.add("farm", Vector2i(34, 30), true)
		var s: Survivor = state.survivors.all()[0]
		_idle_others(state, s.uid)
		s.job = Survivor.Job.FARMER
		s.pos = Grid.tile_to_world(farm.origin + Vector2i(-1, 0))
		s.work_uid = farm.uid
		s.activity = Survivor.Activity.FARMING
		s.morale = int(case[0])
		var before: int = state.resources.get_amount("food")
		Jobs.tick(state, 8.75)
		assert_eq(state.resources.get_amount("food"), before + int(case[1]),
			"Farmer 8.75 s at morale %d" % int(case[0]))
	# Crafter cycle: Steady finishes a 5 s craft in one tick; Low needs more.
	var data: GameData = GameData.load_default()
	var craft_time: float = float(data.get_building("workshop").get("craft_time", 5.0))
	var per_scrap: int = int(data.get_building("workshop").get("ammo_per_scrap", 12))
	for case: Array in [[50, true], [30, false]]:
		var st := GameState.new(data, 22103)
		st.clock.phase = GameClock.Phase.DAY
		_vacate(st, Vector2i(30, 34), 4, 4)
		var shop: Building = st.buildings.add("workshop", Vector2i(30, 34), true)
		var s: Survivor = st.survivors.all()[0]
		_idle_others(st, s.uid)
		s.job = Survivor.Job.CRAFTER
		s.pos = Grid.tile_to_world(shop.origin + Vector2i(-1, 0))
		s.work_uid = shop.uid
		s.activity = Survivor.Activity.CRAFTING
		s.morale = int(case[0])
		var ammo_before: int = st.resources.get_amount("ammo")
		Jobs.tick(st, craft_time)
		assert_eq(st.resources.get_amount("ammo") == ammo_before + per_scrap, bool(case[1]),
			"Crafter one craft_time at morale %d" % int(case[0]))

func test_researcher_suspension_holds_no_slot_and_stops_rp() -> void:
	var fix: Dictionary = _researcher_state(50, false)
	var state: GameState = fix["state"]
	var s: Survivor = fix["worker"]
	var lab: Building = fix["lab"]
	Jobs.tick(state, 7.0)
	assert_eq(s.activity, Survivor.Activity.RESEARCHING)
	assert_eq(ProductionJob.workers_at(state, lab), 1)
	var earned: float = float(state.tech.progress.get("spotters", 0.0))
	assert_gt(earned, 0.0)
	# A Breaking refusal suspends exactly like a day off: no slot, no RP.
	for flag: String in ["refusing", "day_off"]:
		s.refusing = flag == "refusing"
		s.day_off = flag == "day_off"
		Morale.suspend(s)
		s.work_uid = lab.uid
		Jobs.tick(state, 7.0)
		assert_eq(s.activity, Survivor.Activity.IDLE, flag)
		assert_eq(ProductionJob.workers_at(state, lab), 0, flag)
		assert_almost_eq(float(state.tech.progress.get("spotters", 0.0)), earned, 0.000001, flag)
	# Changing jobs while refusing is allowed and takes effect when refusal ends.
	s.refusing = true
	s.day_off = false
	state.set_job(s.uid, Survivor.Job.FARMER)
	assert_eq(s.job, Survivor.Job.FARMER)
	assert_eq(s.activity, Survivor.Activity.IDLE)

func test_camp_songs_raises_campfire_mood_value() -> void:
	for done: Array in [[], ["camp_songs"]]:
		var state := GameState.new(GameData.load_default(), 22104)
		state.clock.phase = GameClock.Phase.DAY
		for s: Survivor in state.survivors.all():
			state.set_job(s.uid, Survivor.Job.IDLE)
		_vacate(state, Vector2i(36, 36), 3, 3)
		state.buildings.add("campfire", Vector2i(36, 36), true)
		for id: String in done:
			state.tech.done.append(id)
		Morale.begin_dawn(state)
		var report: Dictionary = {"left": [], "cc_damage": 0, "buildings_destroyed": [],
			"survivors_killed": [], "scavenging": []}
		Morale.end_dawn(state, report)
		for s: Survivor in state.survivors.all():
			var value: int = 0
			for mood: Dictionary in s.moods:
				if str(mood.get("id", "")) == "campfire":
					value = int(mood.get("value", 0))
			var expected: int = 9 if not done.is_empty() else 6
			assert_eq(value, expected, "campfire mood with %s" % str(done))

func test_first_aid_heals_once_before_hurt_mood() -> void:
	var state := GameState.new(GameData.load_default(), 22105)
	state.tech.done.append("camp_songs")
	state.tech.done.append("first_aid")
	var people: Array[Survivor] = state.survivors.all()
	people[0].hp = 10
	people[1].hp = 20
	people[2].hp = 48
	state.tech.apply_dawn_heal(state)
	assert_eq(people[0].hp, 20)
	assert_eq(people[1].hp, 30)
	assert_eq(people[2].hp, people[2].max_hp, "Heal caps at max HP")
	for s: Survivor in state.survivors.all():
		state.set_job(s.uid, Survivor.Job.IDLE)
	Morale.begin_dawn(state)
	var report: Dictionary = {"left": [], "cc_damage": 0, "buildings_destroyed": [],
		"survivors_killed": [], "scavenging": []}
	Morale.end_dawn(state, report)
	assert_true(_has_mood(people[0], "hurt"), "Still below half after heal")
	assert_false(_has_mood(people[1], "hurt"), "Heal ran before the hurt check")
	assert_false(_has_mood(people[2], "hurt"))

func _has_mood(s: Survivor, id: String) -> bool:
	for mood: Dictionary in s.moods:
		if str(mood.get("id", "")) == id:
			return true
	return false

func test_bunk_beds_adds_real_shelter_occupancy() -> void:
	for done: Array in [[], ["camp_songs", "first_aid", "bunk_beds"]]:
		var state := GameState.new(GameData.load_default(), 22106)
		_vacate(state, Vector2i(38, 30), 4, 4)
		var shelter: Building = state.buildings.add("shelter", Vector2i(38, 30), true)
		for id: String in done:
			state.tech.done.append(id)
		assert_eq(state.buildings.beds_for(shelter), 6 if not done.is_empty() else 4)
		var cc: Building = state.buildings.all_of_type("command_center")[0]
		state.survivors.add("TestOne", "blue", shelter.origin + Vector2i(-2, 0))
		state.survivors.add("TestTwo", "brown", shelter.origin + Vector2i(-2, 1))
		var seated: int = 0
		for s: Survivor in state.survivors.all():
			var pick: Building = ShelterRules.pick_shelter(state, s, {cc.uid: true})
			if pick == shelter:
				s.shelter_uid = shelter.uid
				seated += 1
		var expected: int = 6 if not done.is_empty() else 4
		assert_eq(seated, expected, "Shelter seats %d with %s" % [expected, str(done)])
		assert_eq(ShelterRules.beds_held(state, shelter), expected)

func test_spitter_cc_fallback_stops_only_inside_defence_reach() -> void:
	# T-212 guarantee: a fallback spitter never sieges the CC from a tile no
	# defender can hit; with no defended tile on its route it takes melee.
	var state := GameState.new(GameData.load_default(), 1337)
	state.waves.enabled = false
	var cc: Building = state.buildings.all_of_type("command_center")[0]
	for y: int in range(cc.origin.y - 4, cc.origin.y + 7):
		for x: int in range(cc.origin.x - 5, cc.origin.x + 7):
			var tile := Vector2i(x, y)
			if state.map.occupant_at(tile) != WorldMap.Occupant.BUILDING:
				state.map.vacate(tile, Vector2i.ONE)
	var defence: Building = state.buildings.add("turret", cc.origin + Vector2i(4, 3), true)
	var z: Zombie = state.spawn_zombie("spitter", Grid.tile_to_world(cc.origin + Vector2i(-3, 4)))
	var fired: Array[Vector2] = []
	state.spit_fired.connect(func(_from: Vector2, to: Vector2) -> void: fired.append(to))
	var stopped: bool = false
	for _i: int in range(1200):
		ZombieAI.tick(state, 1.0 / 60.0)
		if z.target_building_uid == cc.uid:
			stopped = true
			break
	assert_true(stopped, "Spitter reaches a CC fallback attack position")
	var melee: int = ZombieAI._tile_range(z.tile(), ZombieAI._target_tile(z, cc))
	if melee <= 1:
		assert_eq(melee, 1, "No defended ranged tile on route: melee escape")
	else:
		var reach: float = Combat.turret_range_px(state)
		assert_true(z.pos.distance_squared_to(defence.center_world()) <= reach * reach,
			"Ranged stop must be shootable")
		assert_eq(Combat.nearest_zombie(state, defence.center_world(), reach), z)
		for _i: int in range(240):
			state.projectiles.tick(state, 1.0 / 60.0)
			ZombieAI.tick(state, 1.0 / 60.0)
			Combat.tick_turrets(state, 1.0 / 60.0)
		assert_eq(cc.hp, cc.max_hp, "Stocked turret kills the spitter before acid lands")
	assert_true(fired.is_empty(), "An uncovered fallback position never launches acid")

func test_radio_win_needs_no_research() -> void:
	# The §10 win path never consults the tech tree: a complete tower on
	# day 21 wins with an empty tree, and nothing else changes.
	var state := GameState.new(GameData.load_default(), 22110)
	state.clock.day = 21
	state.buildings.add("radio_tower", Vector2i(30, 30), true)
	var observed: Dictionary = {"wins": 0}
	state.game_won.connect(func() -> void: observed["wins"] += 1)
	state._check_win()
	assert_true(state.won)
	assert_eq(observed["wins"], 1)
	assert_true(state.tech.done.is_empty())
	assert_eq(state.tech.active, "")
	assert_eq(state.tech.banked, 0.0)
	var bare := GameState.new(GameData.load_default(), 22111)
	bare.clock.day = 21
	bare.buildings.add("radio_tower", Vector2i(30, 30), false)
	bare._check_win()
	assert_false(bare.won, "A tower blueprint is not a win")

func _fire_sequence(seed: int, day: int, hit_chance: float, shots: int) -> Dictionary:
	var state := GameState.new(GameData.load_default(), seed)
	state.clock.day = day
	state._on_phase_changed(GameClock.Phase.NIGHT, day)
	var start_rng: int = state.combat_rng.state
	for _i: int in range(8):
		state.spawn_zombie("brute", Grid.tile_to_world(state.map.command_center_origin() + Vector2i(5, 0)))
	var outcomes: Array = []
	var misses: int = 0
	var origin: Vector2 = state.buildings.all_of_type("command_center")[0].center_world()
	for _i: int in range(shots):
		var target: Zombie = Combat.nearest_zombie(state, origin, 99999.0)
		if target == null:
			break
		var before: int = target.hp
		Combat.try_fire(state, origin, 99999.0, int(state.data.balance("guard_damage")), false, hit_chance)
		outcomes.append([target.uid, before, target.hp])
		if target.hp == before:
			misses += 1
	return {"outcomes": outcomes, "misses": misses, "rng": state.combat_rng.state,
		"draws": state.combat_rng.state != start_rng}

func test_seeded_restart_repeats_miss_sequence_and_weather() -> void:
	# Same seed + day repeats the exact Low-guard miss sequence after Restart.
	var first: Dictionary = _fire_sequence(1337, 5, 0.7, 30)
	var second: Dictionary = _fire_sequence(1337, 5, 0.7, 30)
	assert_eq(first["outcomes"], second["outcomes"], "Identical seeds repeat the miss sequence")
	assert_true(bool(first["draws"]), "Below-100% guards draw combat RNG")
	assert_gt(int(first["misses"]), 0, "A 30-shot Low sequence misses at least once")
	# Steady and Inspired colonies draw nothing and replay exactly as before.
	var steady: Dictionary = _fire_sequence(1337, 5, 1.0, 30)
	assert_false(bool(steady["draws"]), "100% hit chance consumes no RNG")
	assert_eq(steady["misses"], 0)
	# Weather is seeded per map seed + day: identical on Restart, and the fog
	# rules (never night 20, never twice running) hold across probe seeds.
	for day: int in [5, 8, 20]:
		var a := GameState.new(GameData.load_default(), 1337)
		var b := GameState.new(GameData.load_default(), 1337)
		a.clock.day = day
		b.clock.day = day
		assert_eq(a.weather_day(), b.weather_day(), "day %d" % day)
		assert_eq(a.weather_night(), b.weather_night(), "night %d" % day)
	for seed: int in [1337, 1, 2, 7, 42]:
		var previous_fog: bool = false
		for day: int in range(5, 21):
			var probe := GameState.new(GameData.load_default(), seed)
			probe.clock.day = day
			var fog: bool = probe.weather_night() == "fog"
			assert_false(fog and day == 20, "Never fog on the Final Horde")
			assert_false(fog and previous_fog, "Never two fog nights running")
			previous_fog = fog
