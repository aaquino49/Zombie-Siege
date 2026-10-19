extends TestCase

func test_readable_night_and_red_final_palette() -> void:
	assert_true(DayNightTint.NIGHT_COLOR.is_equal_approx(Color(0.55, 0.60, 0.80)))
	assert_true(DayNightTint.FINAL_COLOR.is_equal_approx(Color(0.80, 0.42, 0.42)))
	assert_gt(DayNightTint.NIGHT_COLOR.b, DayNightTint.NIGHT_COLOR.r)
	assert_gt(DayNightTint.FINAL_COLOR.r, DayNightTint.FINAL_COLOR.g)
	assert_gt(DayNightTint.FINAL_COLOR.r, DayNightTint.FINAL_COLOR.b)

func test_tint_day_night_and_dusk() -> void:
	assert_true(DayNightTint.tint_for(GameClock.Phase.DAY, 75.0, 75.0, 1, 20).is_equal_approx(Color.WHITE))
	assert_true(DayNightTint.tint_for(GameClock.Phase.NIGHT, 10.0, 35.0, 1, 20).is_equal_approx(DayNightTint.NIGHT_COLOR))
	assert_true(DayNightTint.tint_for(GameClock.Phase.DAY, 144.0, 6.0, 1, 20).is_equal_approx(Color.WHITE.lerp(DayNightTint.NIGHT_COLOR, 0.5)))
	assert_true(DayNightTint.tint_for(GameClock.Phase.DAY, 138.0, 12.0, 1, 20).is_equal_approx(Color.WHITE))
	assert_true(DayNightTint.tint_for(GameClock.Phase.DAY, 150.0, 0.0, 1, 20).is_equal_approx(DayNightTint.NIGHT_COLOR))

func test_tint_dawn_and_day_one() -> void:
	assert_true(DayNightTint.tint_for(GameClock.Phase.DAY, 0.0, 150.0, 1, 20).is_equal_approx(Color.WHITE))
	assert_true(DayNightTint.tint_for(GameClock.Phase.DAY, 0.0, 150.0, 2, 20).is_equal_approx(DayNightTint.NIGHT_COLOR))
	assert_true(DayNightTint.tint_for(GameClock.Phase.DAY, 3.0, 147.0, 2, 20).is_equal_approx(DayNightTint.NIGHT_COLOR.lerp(Color.WHITE, 0.5)))
	assert_true(DayNightTint.tint_for(GameClock.Phase.DAY, DayNightTint.DAWN_SECONDS, 144.0, 2, 20).is_equal_approx(Color.WHITE))

func test_final_tint_and_following_dawn() -> void:
	assert_true(DayNightTint.tint_for(GameClock.Phase.NIGHT, 1.0, 44.0, 8, 8).is_equal_approx(DayNightTint.FINAL_COLOR))
	assert_true(DayNightTint.tint_for(GameClock.Phase.DAY, 144.0, 6.0, 8, 8).is_equal_approx(Color.WHITE.lerp(DayNightTint.FINAL_COLOR, 0.5)))
	assert_true(DayNightTint.tint_for(GameClock.Phase.DAY, 0.0, 150.0, 9, 8).is_equal_approx(DayNightTint.FINAL_COLOR))
	assert_true(DayNightTint.tint_for(GameClock.Phase.NIGHT, 1.0, 44.0, 9, 8).is_equal_approx(DayNightTint.NIGHT_COLOR))

func test_banner_text_and_visibility() -> void:
	assert_eq(PhaseBanner.banner_for(GameClock.Phase.NIGHT, 0.5, 3, 20), {"text": "NIGHT 3", "alpha": 1.0, "final": false})
	assert_eq(PhaseBanner.banner_for(GameClock.Phase.NIGHT, 5.0, 3, 20)["text"], "")
	assert_eq(PhaseBanner.banner_for(GameClock.Phase.DAY, 0.5, 2, 20)["text"], "DAY 2")
	assert_eq(PhaseBanner.banner_for(GameClock.Phase.DAY, 0.0, 1, 20)["text"], "")
	assert_eq(PhaseBanner.banner_for(GameClock.Phase.DAY, 4.0, 2, 20)["text"], "")
	assert_eq(PhaseBanner.banner_for(GameClock.Phase.NIGHT, 0.5, 8, 8), {"text": "FINAL HORDE", "alpha": 1.0, "final": true})
	assert_false(PhaseBanner.banner_for(GameClock.Phase.NIGHT, 0.5, 9, 8)["final"])

func test_banner_alpha_fade() -> void:
	for phase: int in [GameClock.Phase.DAY, GameClock.Phase.NIGHT]:
		assert_almost_eq(PhaseBanner.banner_for(phase, 3.0, 2, 20)["alpha"], 1.0)
		assert_almost_eq(PhaseBanner.banner_for(phase, 3.5, 2, 20)["alpha"], 0.5)
		assert_eq(PhaseBanner.banner_for(phase, 4.0, 2, 20)["alpha"], 0.0)

var _cleared: bool = false

func test_clock_waits_for_clear_then_ends() -> void:
	var clock: GameClock = GameClock.new()
	clock.night_end_check = func() -> bool: return _cleared
	clock.advance(150.0)
	clock.advance(200.0)
	assert_eq(clock.phase, GameClock.Phase.NIGHT)
	assert_eq(clock.day, 1)
	assert_almost_eq(clock.elapsed, 200.0)
	assert_almost_eq(clock.time_left(), 0.0)
	_cleared = true
	clock.advance(0.1)
	assert_eq(clock.phase, GameClock.Phase.DAY)
	assert_eq(clock.day, 2)
	assert_almost_eq(clock.elapsed, 0.1)

func test_clock_requires_minimum_even_when_clear() -> void:
	var clock: GameClock = GameClock.new()
	clock.night_end_check = func() -> bool: return true
	clock.advance(150.0)
	clock.advance(44.0)
	assert_eq(clock.phase, GameClock.Phase.NIGHT)
	clock.advance(1.0)
	assert_eq(clock.phase, GameClock.Phase.DAY)
	assert_eq(clock.day, 2)

func test_clock_default_and_state_still_end_night() -> void:
	var data: GameData = GameData.load_default()
	var clock: GameClock = GameClock.new(data)
	assert_true(clock.night_end_check.is_null())
	clock.advance(float(data.balance("day_length")))
	clock.advance(float(data.balance("night_min_length")))
	assert_eq(clock.phase, GameClock.Phase.DAY)
	assert_eq(clock.day, 2)
	var state: GameState = GameState.new(data, 1337)
	assert_eq(state.hostiles_remaining(), 0)
	assert_false(state.clock.night_end_check.is_null())
	state.clock.elapsed = float(data.balance("day_length")) - 0.1
	state.tick(0.1)
	assert_eq(state.clock.phase, GameClock.Phase.NIGHT)
	state.tick(float(data.balance("night_min_length")))
	assert_eq(state.clock.phase, GameClock.Phase.DAY)
	assert_eq(state.clock.day, 2)

func test_night_hud_text() -> void:
	assert_eq(HudText.night_text(0, 44), "Night – dawn in 0:44")
	assert_eq(HudText.night_text(7, 0), "Night – 7 zombies left")
	assert_eq(HudText.night_text(0, -1), "Night – dawn in 0:00")
	assert_eq(HudText.night_text(0, 65), "Night – dawn in 1:05")

func test_final_night_reads_wave_data() -> void:
	assert_eq(GameData.new().final_night(), 20)
	var data: GameData = GameData.load_default()
	assert_eq(data.final_night(), 20)
	data._waves["final_night"] = 8
	assert_eq(data.final_night(), 8)
	assert_true(data.wave_for_night(8)["final"])
	assert_false(data.wave_for_night(20)["final"])
