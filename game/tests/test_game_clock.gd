extends TestCase

func test_init_and_time_left() -> void:
	var clock: GameClock = GameClock.new(null)
	assert_eq(clock.day, 1)
	assert_eq(clock.phase, GameClock.Phase.DAY)
	assert_eq(clock.time_left(), 150.0)
	
	# scale uses speed 1 by default
	assert_eq(clock.scale(1.0), 1.0)

func test_advance_to_night() -> void:
	var clock: GameClock = GameClock.new(null)
	clock.advance(150.0)
	
	assert_eq(clock.day, 1)
	assert_eq(clock.phase, GameClock.Phase.NIGHT)
	assert_eq(clock.time_left(), 45.0)

func test_advance_to_day_2() -> void:
	var clock: GameClock = GameClock.new(null)
	clock.advance(150.0 + 45.0)
	
	assert_eq(clock.day, 2)
	assert_eq(clock.phase, GameClock.Phase.DAY)
	assert_eq(clock.time_left(), 150.0)

func test_advance_multi_phase() -> void:
	var clock: GameClock = GameClock.new(null)
	# 150 (day 1) + 45 (night 1) + 150 (day 2) + 45 (night 2) + 10 (day 3)
	clock.advance(150.0 + 45.0 + 150.0 + 45.0 + 10.0)
	
	assert_eq(clock.day, 3)
	assert_eq(clock.phase, GameClock.Phase.DAY)
	assert_eq(clock.time_left(), 140.0)

func test_speed_scaling_and_pause() -> void:
	var clock: GameClock = GameClock.new(null)
	
	# default
	assert_eq(clock.scale(1.0), 1.0)
	
	# speed 2
	clock.set_speed(2)
	assert_eq(clock.scale(1.0), 2.0)
	
	# speed 3
	clock.set_speed(3)
	assert_eq(clock.scale(1.0), 3.0)
	
	# clamp speed
	clock.set_speed(5)
	assert_eq(clock.speed, 3)
	
	# pause
	clock.set_paused(true)
	assert_eq(clock.scale(1.0), 0.0)
	assert_eq(clock.paused, true)
	
	# set_speed unpauses
	clock.set_speed(1)
	assert_eq(clock.paused, false)
	assert_eq(clock.scale(1.0), 1.0)

var _dawn_emitted := 0
var _speed_emitted := 0

func test_signals() -> void:
	var clock: GameClock = GameClock.new(null)
	
	_dawn_emitted = 0
	_speed_emitted = 0
	
	clock.dawn.connect(func(_d: int) -> void: _dawn_emitted += 1)
	clock.speed_changed.connect(func(_p: bool, _s: int) -> void: _speed_emitted += 1)
	
	clock.advance(150.0 + 45.0)
	assert_eq(_dawn_emitted, 1)
	
	clock.set_paused(true)
	assert_eq(_speed_emitted, 1)
	
	clock.set_paused(true) # no change
	assert_eq(_speed_emitted, 1)
	
	clock.set_speed(2) # unpauses and changes speed
	assert_eq(_speed_emitted, 2)
	
	clock.set_speed(2) # no change
	assert_eq(_speed_emitted, 2)

func test_game_state_tick() -> void:
	var data: GameData = GameData.load_default()
	var state: GameState = GameState.new(data, 0)
	state.clock.set_speed(3)
	state.tick(1.0)
	
	assert_eq(state.clock.elapsed, 3.0)
	assert_eq(state.clock.time_left(), float(data.balance("day_length")) - 3.0)
	state.clock.set_paused(true)
	state.tick(1.0)
	assert_eq(state.clock.elapsed, 3.0)
	assert_eq(state.clock.time_left(), float(data.balance("day_length")) - 3.0)

func test_transition_signal_payloads_and_leftover_time() -> void:
	var clock: GameClock = GameClock.new(null)
	var phases: Array[Vector2i] = []
	var dawn_days: Array[int] = []
	clock.phase_changed.connect(func(phase: int, day: int) -> void:
		phases.append(Vector2i(phase, day)))
	clock.dawn.connect(func(day: int) -> void: dawn_days.append(day))
	clock.advance(150.0)
	assert_eq(phases, [Vector2i(GameClock.Phase.NIGHT, 1)])
	assert_true(dawn_days.is_empty())
	clock.advance(45.0)
	assert_eq(dawn_days, [2])
	assert_eq(phases, [Vector2i(GameClock.Phase.NIGHT, 1), Vector2i(GameClock.Phase.DAY, 2)])
	clock.advance(205.0)
	assert_eq(dawn_days, [2, 3])
	assert_eq(phases.size(), 4)
	assert_eq(phases[2], Vector2i(GameClock.Phase.NIGHT, 2))
	assert_eq(phases[3], Vector2i(GameClock.Phase.DAY, 3))
	assert_almost_eq(clock.elapsed, 10.0)

func test_configured_durations_and_multipliers_drive_clock() -> void:
	var data: GameData = GameData.load_default()
	var balance: Dictionary = data.get("_balance")
	balance["day_length"] = 12.0
	balance["night_min_length"] = 4.0
	balance["speed_mult_1"] = 1.25
	balance["speed_mult_2"] = 2.5
	balance["speed_mult_3"] = 3.75
	var clock: GameClock = GameClock.new(data)
	assert_almost_eq(clock.time_left(), 12.0)
	assert_almost_eq(clock.scale(2.0), 2.5)
	clock.set_speed(2)
	assert_almost_eq(clock.scale(2.0), 5.0)
	clock.set_speed(3)
	assert_almost_eq(clock.scale(2.0), 7.5)
	clock.advance(12.0)
	assert_eq(clock.phase, GameClock.Phase.NIGHT)
	assert_almost_eq(clock.time_left(), 4.0)
	clock.advance(4.0 + 2.0)
	assert_eq(clock.day, 2)
	assert_eq(clock.phase, GameClock.Phase.DAY)
	assert_almost_eq(clock.elapsed, 2.0)

func test_lower_speed_clamp_and_pause_payloads() -> void:
	var clock: GameClock = GameClock.new(null)
	var changes: Array[Vector2i] = []
	clock.speed_changed.connect(func(paused: bool, speed: int) -> void:
		changes.append(Vector2i(int(paused), speed)))
	clock.set_paused(false)
	assert_true(changes.is_empty())
	clock.toggle_pause()
	assert_eq(changes, [Vector2i(1, 1)])
	clock.set_paused(true)
	assert_eq(changes.size(), 1)
	clock.set_speed(-1)
	assert_eq(clock.speed, 1)
	assert_false(clock.paused)
	assert_eq(changes[1], Vector2i(0, 1))

