extends TestCase

func _state(fog: bool) -> GameState:
	var state := GameState.new(GameData.load_default(), 1337)
	state.clock.day = 5
	state.data.weather_config()["fog"]["chance"] = 1.0 if fog else 0.0
	state.resources.add("wood", 1000)
	state.resources.add("scrap", 1000)
	return state

func _distance_to_cc(state: GameState, tile: Vector2i) -> float:
	# Both defense buildings occupy one tile; measure in tiles independently
	# of the bot's range predicate and pixel conversion.
	var center: Vector2 = Vector2(tile) + Vector2(0.5, 0.5)
	var cc_center: Vector2 = Vector2(state.map.command_center_origin()) + Vector2.ONE
	var outside: Vector2 = (center - cc_center).abs() - Vector2.ONE
	return Vector2(maxf(0.0, outside.x), maxf(0.0, outside.y)).length()

func _assert_placement(type_id: String, clear_range: float, fog_range: float) -> void:
	var clear_state: GameState = _state(false)
	var fog_state: GameState = _state(true)
	var far_tile := Vector2i(-1, -1)
	var near_tile := Vector2i(-1, -1)
	var cc_ring: Array[Vector2i] = clear_state.cc_ring_tiles()
	for y: int in range(clear_state.map.size()):
		for x: int in range(clear_state.map.size()):
			var tile := Vector2i(x, y)
			if cc_ring.has(tile) or Placement.check(clear_state, type_id, tile) != Placement.Result.OK:
				continue
			var distance: float = _distance_to_cc(clear_state, tile)
			if far_tile.x < 0 and distance > fog_range and distance <= clear_range:
				far_tile = tile
			if near_tile.x < 0 and distance > 1.0 and distance <= fog_range:
				near_tile = tile
	assert_true(far_tile.x >= 0, "Fixture needs a legal site in the clear-only range annulus")
	assert_true(near_tile.x >= 0, "Fixture needs a legal site inside fog range")
	if far_tile.x < 0 or near_tile.x < 0:
		return
	var interior: Array[Vector2i] = [far_tile, near_tile]
	# Offer the clear-only site first so omitting the fog filter fails this test.
	assert_eq(BalanceBot._place_inside(clear_state, {"interior": interior}, type_id), Placement.Result.OK)
	assert_eq(BalanceBot._place_inside(fog_state, {"interior": interior}, type_id), Placement.Result.OK)
	var clear_buildings: Array[Building] = clear_state.buildings.all_of_type(type_id)
	var fog_buildings: Array[Building] = fog_state.buildings.all_of_type(type_id)
	assert_eq(clear_buildings.size(), 1)
	assert_eq(fog_buildings.size(), 1)
	if clear_buildings.is_empty() or fog_buildings.is_empty():
		return
	assert_eq(clear_buildings[0].origin, far_tile, "Clear forecast accepts the first legal site")
	assert_eq(fog_buildings[0].origin, near_tile, "Fog forecast skips the site beyond reduced range")
	assert_true(_distance_to_cc(fog_state, fog_buildings[0].origin) <= fog_range)

func test_fog_turret_rejects_clear_only_range_site() -> void:
	_assert_placement("turret", 6.0, 5.0)

func test_fog_watchtower_rejects_clear_only_range_site() -> void:
	_assert_placement("watchtower", 7.5, 6.5)
