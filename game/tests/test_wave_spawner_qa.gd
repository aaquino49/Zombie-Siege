extends TestCase
## Exercise the real tick path across nightfall and a subsequent night.

func test_frame_sized_ticks_spawn_night_one_on_schedule() -> void:
	var state: GameState = GameState.new(GameData.load_default(), 1337)
	state.waves.enabled = true
	var records: Array[Dictionary] = []
	var clock: GameClock = state.clock
	state.zombies.zombie_added.connect(func(z: Zombie) -> void:
		records.append({"type": z.type_id, "time": clock.elapsed}))
	state.clock.elapsed = float(state.data.balance("day_length")) - 0.005
	state.tick(0.02)
	assert_eq(state.clock.phase, GameClock.Phase.NIGHT)
	assert_eq(records.size(), 1)
	assert_almost_eq(float(records[0].time), 0.0)
	assert_eq(state.hostiles_remaining(), 7)
	for i: int in range(150):
		state.tick(0.1)
		assert_eq(state.hostiles_remaining(), 7)
	assert_eq(records.size(), 7)
	assert_eq(state.waves.pending(), 0)
	var window: float = float(state.data.balance("night_min_length")) * float(state.data.wave_value("spawn_window_fraction"))
	for i: int in range(records.size()):
		assert_eq(records[i].type, "walker")
		assert_almost_eq(float(records[i].time), window * i / 7.0)

func test_next_night_plans_a_fresh_wave_after_dawn() -> void:
	var state: GameState = GameState.new(GameData.load_default(), 1337)
	state.waves.enabled = true
	state.tick(float(state.data.balance("day_length")) + float(state.data.balance("night_min_length")) + 1.0)
	assert_eq(state.clock.phase, GameClock.Phase.NIGHT)
	assert_gt(state.zombies.count(), 0)
	for z: Zombie in state.zombies.all():
		state.zombies.damage(z.uid, 9999)
	state.tick(0.1)
	assert_eq(state.clock.day, 2)
	assert_eq(state.clock.phase, GameClock.Phase.DAY)
	assert_eq(state.hostiles_remaining(), 0)
	state.tick(state.clock.time_left())
	assert_eq(state.clock.phase, GameClock.Phase.NIGHT)
	assert_eq(state.hostiles_remaining(), 10)
	var window: float = float(state.data.balance("night_min_length")) * float(state.data.wave_value("spawn_window_fraction"))
	state.tick(window + 0.1)
	assert_eq(state.waves.pending(), 0)
	assert_eq(state.zombies.count(), 10)
	for z: Zombie in state.zombies.all():
		assert_eq(z.type_id, "walker")

func test_campaign_schedules_are_identical_with_endless_damping() -> void:
	var original_data: GameData = GameData.load_default()
	var damped_data: GameData = GameData.load_default()
	damped_data._waves["endless_wave_mult"] = 0.8
	assert_almost_eq(float(original_data.wave_value("endless_wave_mult")), 1.0)
	for difficulty: String in ["easy", "normal", "hard"]:
		var original: GameState = GameState.new(original_data, 1337, difficulty)
		var damped: GameState = GameState.new(damped_data, 1337, difficulty)
		for night: int in range(1, 21):
			original.waves.plan_night(night)
			damped.waves.plan_night(night)
			var context: String = "%s night %d" % [difficulty, night]
			assert_eq(damped.waves._schedule, original.waves._schedule, context + " preserves types, sides and times")
			assert_eq(damped.waves._rng.state, original.waves._rng.state, context + " preserves wave RNG")
			assert_eq(WaveSpawner.forecast(damped_data, night, damped.difficulty_multipliers, 1337), WaveSpawner.forecast(original_data, night, original.difficulty_multipliers, 1337), context + " preserves full forecast")

func test_damped_endless_schedules_keep_sides_and_spawn_window() -> void:
	var original_data: GameData = GameData.load_default()
	var damped_data: GameData = GameData.load_default()
	damped_data._waves["endless_wave_mult"] = 0.8
	var window: float = float(original_data.balance("night_min_length")) * float(original_data.wave_value("spawn_window_fraction"))
	for difficulty: String in ["easy", "normal", "hard"]:
		for night: int in [21, 25]:
			var original: GameState = GameState.new(original_data, 1337, difficulty)
			var damped: GameState = GameState.new(damped_data, 1337, difficulty)
			original.waves.plan_night(night)
			damped.waves.plan_night(night)
			var forecast: Dictionary = WaveSpawner.forecast(original_data, night, original.difficulty_multipliers, 1337)
			var scheduled: Dictionary = {"walker": 0, "runner": 0, "brute": 0, "spitter": 0}
			var sides: Dictionary = {}
			for i: int in range(damped.waves._schedule.size()):
				var entry: Dictionary = damped.waves._schedule[i]
				scheduled[String(entry["type"])] += 1
				sides[int(entry["side"])] = true
				assert_eq(entry["side"], original.waves._schedule[i]["side"], "Damping preserves chosen sides and rotation")
				assert_almost_eq(float(entry["time"]), window * i / damped.waves._schedule.size())
			assert_eq(sides.size(), int(forecast["sides"]))
			for type_id: String in scheduled:
				assert_eq(scheduled[type_id], roundi(float(forecast[type_id]) * 0.8), "%s night %d %s" % [difficulty, night, type_id])

func test_damped_endless_spawns_repeat_positions_and_preserve_game_rng() -> void:
	var data: GameData = GameData.load_default()
	data._waves["endless_wave_mult"] = 0.8
	var first: GameState = GameState.new(data, 98765, "hard")
	var second: GameState = GameState.new(data, 98765, "hard")
	first.waves.enabled = true
	second.waves.enabled = true
	first.clock.phase = GameClock.Phase.NIGHT
	second.clock.phase = GameClock.Phase.NIGHT
	var game_rng_before: int = first.rng.state
	for night: int in [21, 25]:
		first.waves.plan_night(night)
		second.waves.plan_night(night)
		assert_eq(first.waves._schedule, second.waves._schedule)
		for i: int in range(first.waves._schedule.size()):
			var side: int = int(first.waves._schedule[i]["side"])
			assert_eq(first.waves.spawn_point(side), second.waves.spawn_point(side), "Same seed repeats damped spawn positions")
		assert_eq(first.waves._rng.state, second.waves._rng.state)
	assert_eq(first.rng.state, game_rng_before, "Damping and spawning use only the wave RNG")
	assert_eq(second.rng.state, game_rng_before)
