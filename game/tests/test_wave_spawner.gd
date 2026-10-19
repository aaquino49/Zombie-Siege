extends TestCase

func _night(n: int, seed_value: int = 1337) -> GameState:
	var state: GameState = GameState.new(GameData.load_default(), seed_value)
	state.waves.enabled = true
	state.clock.day = n
	state.clock.advance(float(state.data.balance("day_length")))
	return state

func _capture(state: GameState, records: Array[Dictionary]) -> void:
	# Signal captures only record storage and the clock, never the owning state.
	var clock: GameClock = state.clock
	state.zombies.zombie_added.connect(func(z: Zombie) -> void:
		records.append({"type": z.type_id, "time": clock.elapsed, "pos": z.pos}))

func test_disabled_by_default() -> void:
	var state: GameState = GameState.new(GameData.load_default(), 1337)
	assert_false(state.waves.enabled)
	state.tick(float(state.data.balance("day_length")))
	assert_eq(state.zombies.count(), 0)
	assert_eq(state.waves.pending(), 0)
	state.tick(float(state.data.balance("night_min_length")))
	assert_eq(state.clock.phase, GameClock.Phase.DAY)
	assert_eq(state.clock.day, 2)

func test_counts_sides_timing_and_positions() -> void:
	for n: int in [1, 4, 8, 20]:
		var state: GameState = _night(n)
		var wave: Dictionary = state.data.wave_for_night(n)
		var total: int = int(wave.walker) + int(wave.runner) + int(wave.brute) + int(wave.spitter)
		assert_eq(state.hostiles_remaining(), total)
		var planned: Array[Dictionary] = state.waves._schedule.duplicate(true)
		var chosen: Dictionary = {}
		for entry: Dictionary in planned:
			chosen[entry.side] = true
		assert_eq(chosen.size(), int(wave.sides))
		var records: Array[Dictionary] = []
		_capture(state, records)
		var window: float = float(state.data.balance("night_min_length")) * float(state.data.wave_value("spawn_window_fraction"))
		# A large tick must still respect each spawn boundary.
		state.tick(window + 0.1)
		assert_eq(records.size(), total)
		assert_eq(state.waves.pending(), 0)
		var counts: Dictionary = {"walker": 0, "runner": 0, "brute": 0, "spitter": 0}
		var slices: Array[int] = []
		slices.resize(10)
		slices.fill(0)
		var extent: float = state.map.size() * Grid.TILE
		for i: int in range(records.size()):
			var record: Dictionary = records[i]
			counts[record.type] += 1
			assert_almost_eq(record.time, float(planned[i].time))
			assert_true(float(record.time) <= window + 0.1)
			slices[mini(9, int((float(record.time) + 0.000001) / window * 10))] += 1
			var pos: Vector2 = record.pos
			var outside_x: bool = pos.x < 0 or pos.x >= extent
			var outside_y: bool = pos.y < 0 or pos.y >= extent
			assert_true(outside_x != outside_y)
			var side: int = 0 if pos.y < 0 else (1 if pos.x >= extent else (2 if pos.y >= extent else 3))
			assert_eq(side, int(planned[i].side))
		for type_id: String in counts:
			assert_eq(counts[type_id], int(wave[type_id]))
		for slice_count: int in slices:
			assert_true(slice_count <= ceili(total / 10.0))
		assert_almost_eq(records[0].time, 0.0)
		if n == 1:
			assert_eq(counts.walker, 7)
		if n == 4:
			assert_eq(counts.walker, 16)
			assert_eq(counts.runner, 2)
		if n == 8:
			assert_eq(counts.brute, 0)
		if n == 20:
			assert_eq(counts.walker, 192)
			assert_eq(counts.runner, 102)
			assert_eq(counts.brute, 30)

func test_live_zombies_hold_night_until_killed() -> void:
	var state: GameState = _night(1)
	state.tick(float(state.data.balance("night_min_length")) + 1.0)
	assert_eq(state.clock.phase, GameClock.Phase.NIGHT)
	assert_gt(state.zombies.count(), 0)
	for z: Zombie in state.zombies.all():
		state.zombies.damage(z.uid, 9999)
	state.tick(0.1)
	assert_eq(state.clock.phase, GameClock.Phase.DAY)
	assert_eq(state.clock.day, 2)

func test_same_seed_same_spawn_list() -> void:
	var first: GameState = _night(4)
	var second: GameState = _night(4)
	var a: Array[Dictionary] = []
	var b: Array[Dictionary] = []
	_capture(first, a)
	_capture(second, b)
	first.tick(28.0)
	second.tick(28.0)
	assert_eq(a, b)
	assert_eq(first.rng.state, second.rng.state)

func test_endless_multiplier_only_changes_nights_after_final_horde() -> void:
	var normal_data: GameData = GameData.load_default()
	var damped_data: GameData = GameData.load_default()
	damped_data._waves["endless_wave_mult"] = 0.8
	for n: int in range(1, 21):
		var normal_state: GameState = GameState.new(normal_data, 1337)
		var damped_state: GameState = GameState.new(damped_data, 1337)
		var normal_forecast: Dictionary = WaveSpawner.forecast(normal_data, n, normal_state.difficulty_multipliers, 1337)
		var damped_forecast: Dictionary = WaveSpawner.forecast(damped_data, n, damped_state.difficulty_multipliers, 1337)
		for type_id: String in ["walker", "runner", "brute", "spitter"]:
			assert_eq(damped_forecast[type_id], normal_forecast[type_id], "Night %d %s must remain unchanged" % [n, type_id])
	for n: int in [21, 25]:
		var normal_state: GameState = GameState.new(normal_data, 1337)
		var damped_state: GameState = GameState.new(damped_data, 1337)
		var normal_forecast: Dictionary = WaveSpawner.forecast(normal_data, n, normal_state.difficulty_multipliers, 1337)
		var damped_forecast: Dictionary = WaveSpawner.forecast(damped_data, n, damped_state.difficulty_multipliers, 1337)
		damped_state.waves.plan_night(n)
		var normal_total: int = 0
		var damped_total: int = 0
		var scheduled: Dictionary = {"walker": 0, "runner": 0, "brute": 0, "spitter": 0}
		for entry: Dictionary in damped_state.waves._schedule:
			scheduled[String(entry["type"])] += 1
		for type_id: String in ["walker", "runner", "brute", "spitter"]:
			normal_total += int(normal_forecast[type_id])
			damped_total += int(damped_forecast[type_id])
			assert_eq(int(damped_forecast[type_id]), roundi(float(normal_forecast[type_id]) * 0.8), "Night %d %s uses nearest-integer damping" % [n, type_id])
			assert_eq(scheduled[type_id], damped_forecast[type_id], "Night %d schedule matches damped %s forecast" % [n, type_id])
		assert_lt(damped_total, normal_total, "Damping should reduce the night %d wave" % n)

func test_endless_spawn_schedule_is_repeatable_for_same_seed() -> void:
	var first: GameState = _night(23, 98765)
	var second: GameState = _night(23, 98765)
	assert_eq(first.waves._schedule, second.waves._schedule)

func test_dawn_clears_schedule_and_owner_is_released() -> void:
	var state: GameState = _night(4)
	state.clock.phase_changed.emit(GameClock.Phase.DAY, 5)
	assert_eq(state.waves.pending(), 0)
	var owner: WeakRef = weakref(state)
	state = null
	assert_eq(owner.get_ref(), null)

func test_real_game_enables_waves() -> void:
	var game: Node = load("res://scripts/autoload/game.gd").new()
	game.new_game(Game.DEFAULT_SEED, GameSettings.PATH, "normal")
	assert_true(game.state.waves.enabled)
	game.state.tick(float(game.state.data.balance("day_length")))
	assert_eq(game.state.hostiles_remaining(), 7)
	game.state.tick(15.0)
	assert_eq(game.state.zombies.count(), 7)
	game.free()

func test_data_driven_schedule_and_independent_rng() -> void:
	var data: GameData = GameData.load_default()
	data._balance["night_min_length"] = 100.0
	data._waves["spawn_window_fraction"] = 0.25
	data._waves["walkers_base"] = 1
	data._waves["walkers_per_night"] = 3
	var state: GameState = GameState.new(data, 1337)
	var rng_before: int = state.rng.state
	state.waves.enabled = true
	state.clock.phase = GameClock.Phase.NIGHT
	state.waves.plan_night(1)
	assert_eq(state.waves.pending(), 4)
	assert_almost_eq(state.waves._schedule[3].time, 18.75)
	for i: int in range(4):
		state.clock.elapsed = i * 6.25
		state.waves.tick(state, 0.0)
	assert_eq(state.zombies.count(), 4)
	assert_eq(state.rng.state, rng_before)
