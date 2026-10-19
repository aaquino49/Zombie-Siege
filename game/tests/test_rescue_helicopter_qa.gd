extends TestCase

func test_position_at_midpoint_is_strictly_between_endpoints() -> void:
	var start := Vector2(900, -600)
	var target := Vector2(32, 64)
	var midpoint := RescueHelicopter.position_at(start, target, 0.5)
	assert_gt(midpoint.x, target.x)
	assert_lt(midpoint.x, start.x)
	assert_gt(midpoint.y, start.y)
	assert_lt(midpoint.y, target.y)
	assert_almost_eq(midpoint.distance_to(start) / start.distance_to(target), sin(PI / 4.0))

func test_skip_finishes_once_per_rescue() -> void:
	var state := GameState.new(GameData.load_default(), 1337)
	var helicopter := RescueHelicopter.new()
	var camera := Camera2D.new()
	var emissions: Array[int] = [0]
	helicopter.bind(state, camera)
	helicopter.rescue_finished.connect(func() -> void: emissions[0] += 1)
	helicopter.skip()
	helicopter.skip()
	var target: Vector2 = state.buildings.all_of_type("command_center")[0].center_world()
	assert_eq(emissions[0], 1, "A completed rescue must emit rescue_finished only once")
	assert_eq(helicopter.position, target)
	assert_eq(camera.position, target)
	assert_true(helicopter.visible)
	helicopter.free()
	camera.free()

func test_rotor_spins_while_clock_is_paused_and_locked() -> void:
	var state := GameState.new(GameData.load_default(), 1337)
	var helicopter := RescueHelicopter.new()
	helicopter.bind(state, null)
	helicopter.skip()
	state.clock.set_paused(true)
	state.clock.locked = true
	var rotor: Sprite2D = helicopter.get_node("Body").get_child(0) as Sprite2D
	var before: float = rotor.rotation_degrees
	helicopter._process(0.1)
	assert_almost_eq(rotor.rotation_degrees - before, RescueHelicopter.ROTOR_DEG_PER_SEC * 0.1)
	var shadow: Sprite2D = helicopter.get_node("Shadow")
	assert_eq(shadow.position, Vector2(24, 32))
	assert_almost_eq(shadow.modulate.a, 0.35)
	helicopter.free()
