extends TestCase

var shake: ScreenShake

func before_each() -> void:
	shake = ScreenShake.new(42)

func after_each() -> void:
	shake = null

func test_add_clamps_trauma() -> void:
	shake.add(0.4)
	assert_almost_eq(shake.trauma, 0.4)
	shake.add(0.9)
	assert_almost_eq(shake.trauma, 1.0)
	shake.add(5.0)
	assert_almost_eq(shake.trauma, 1.0)

func test_tick_decays_to_zero() -> void:
	shake.add(1.0)
	shake.tick(0.5)
	assert_almost_eq(shake.trauma, 1.0 - ScreenShake.DECAY_RATE * 0.5)
	shake.tick(1.0)
	assert_almost_eq(shake.trauma, 0.0)
	assert_eq(shake.offset(), Vector2.ZERO)

func test_full_trauma_settles_within_about_a_second() -> void:
	shake.add(1.0)
	shake.tick(1.0)
	assert_almost_eq(shake.trauma, 0.0, 0.001, "1.6/s decay clears full trauma in 0.625 s")

func test_offset_zero_at_zero_trauma_and_bounded() -> void:
	assert_eq(shake.offset(), Vector2.ZERO)
	for amount: float in [0.1, 0.3, 0.5, 0.8, 1.0]:
		var s := ScreenShake.new(7)
		s.add(amount)
		var off: Vector2 = s.offset()
		assert_true(off.length() <= ScreenShake.MAX_OFFSET + 0.001, "offset within 6 px max")
		assert_true(off.length() > 0.0, "nonzero trauma gives nonzero offset")

func test_offset_scales_with_trauma_squared() -> void:
	var probe := ScreenShake.new(11)
	probe.add(1.0)
	var full_mag: float = probe.offset().length()
	assert_almost_eq(full_mag, ScreenShake.MAX_OFFSET, 0.001)
	var half := ScreenShake.new(11)
	half.add(0.5)
	# Same seed, first draw: half trauma gives quarter magnitude.
	assert_almost_eq(half.offset().length(), ScreenShake.MAX_OFFSET * 0.25, 0.001)

func test_deterministic_with_seed() -> void:
	var a := ScreenShake.new(99)
	var b := ScreenShake.new(99)
	a.add(0.6)
	b.add(0.6)
	for i: int in range(8):
		assert_eq(a.offset(), b.offset(), "same seed gives same offsets")

func test_disabled_setting_ignores_add() -> void:
	shake.enabled = false
	shake.add(1.0)
	assert_almost_eq(shake.trauma, 0.0)
	assert_eq(shake.offset(), Vector2.ZERO)
	shake.enabled = true
	shake.add(0.5)
	assert_almost_eq(shake.trauma, 0.5)
