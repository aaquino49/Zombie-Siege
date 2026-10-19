extends TestCase

func test_game_state_initialization() -> void:
	var data = GameData.load_default()
	var state = GameState.new(data, 12345)
	
	assert_not_null(state.map, "Map should be generated")
	assert_eq(state.map_seed, 12345, "Seed should match")
	
	var cc_origin = state.map.command_center_origin()
	assert_eq(state.map.building_at(cc_origin), "command_center", "CC should be at origin")
	assert_eq(state.map.occupant_at(cc_origin), WorldMap.Occupant.BUILDING, "CC tile should be occupied by building")

func test_game_state_determinism() -> void:
	var data = GameData.load_default()
	var state1 = GameState.new(data, 999)
	var state2 = GameState.new(data, 999)
	
	var t = Vector2i(10, 10)
	assert_eq(state1.map.terrain_at(t), state2.map.terrain_at(t), "Terrain should match for same seed")
	assert_eq(state1.map.occupant_at(t), state2.map.occupant_at(t), "Occupants should match for same seed")

func test_game_state_tick() -> void:
	var data = GameData.load_default()
	var state = GameState.new(data, 12345)
	state.tick(0.1) # Should not error
