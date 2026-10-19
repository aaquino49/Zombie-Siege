class_name TestVictorySetup extends TestCase

func test_places_finished_radio_tower_across_seeds() -> void:
	var data: GameData = GameData.load_default()
	for seed_value: int in [1337, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20]:
		var state: GameState = GameState.new(data, seed_value)
		state.waves.enabled = false
		state.clock.day = 20
		state.resources.add("wood", 300)
		state.resources.add("scrap", 300)

		var tower: Building = VictorySetup.place_finished_tower(state)
		assert_not_null(tower, "Seed %d should place a radio tower" % seed_value)
		if tower == null:
			continue
		assert_eq(tower.type_id, "radio_tower", "Seed %d tower type" % seed_value)
		assert_true(tower.complete, "Seed %d tower is finished" % seed_value)
		assert_eq(state.buildings.all_of_type("radio_tower").size(), 1, "Seed %d has one tower" % seed_value)
		if seed_value == 1337:
			assert_eq(tower.origin, state.map.command_center_origin() + Vector2i(-4, 0),
				"Seed 1337 keeps the established tower position")
