extends TestCase

func test_seed_determinism() -> void:
	var data = GameData.load_default()
	var map1 = WorldMap.new(data, 123)
	map1.generate()
	var map2 = WorldMap.new(data, 123)
	map2.generate()
	var map3 = WorldMap.new(data, 456)
	map3.generate()
	
	# map1 and map2 should be identical
	for x in range(data.balance("map_size")):
		for y in range(data.balance("map_size")):
			var t = Vector2i(x, y)
			assert_eq(map1.terrain_at(t), map2.terrain_at(t))
			assert_eq(map1.occupant_at(t), map2.occupant_at(t))
	
	# map1 and map3 should differ (not guaranteed for EVERY tile, but at least one should differ)
	var diff_found = false
	for x in range(data.balance("map_size")):
		for y in range(data.balance("map_size")):
			var t = Vector2i(x, y)
			if map1.occupant_at(t) != map3.occupant_at(t):
				diff_found = true
				break
	assert_true(diff_found, "Different seeds should produce different maps")

func test_center_clear_area() -> void:
	var data = GameData.load_default()
	var map = WorldMap.new(data, 789)
	map.generate()
	
	var clear_radius = data.balance("map_clear_radius")
	var size = data.balance("map_size")
	var center_f = Vector2(size / 2.0, size / 2.0)
	var cc_origin = map.command_center_origin()
	var cc_tiles = Grid.rect_tiles(cc_origin, Vector2i(2, 2))
	
	for x in range(size):
		for y in range(size):
			var t = Vector2i(x, y)
			if t in cc_tiles:
				assert_eq(map.occupant_at(t), WorldMap.Occupant.BUILDING, "Command center tile should be building")
				assert_eq(map.building_at(t), "command_center", "Command center building ID should be command_center")
			else:
				var dist = Vector2(t).distance_to(center_f)
				if dist < clear_radius:
					assert_eq(map.occupant_at(t), WorldMap.Occupant.NONE, "Tile in clear radius should be empty")

func test_node_counts() -> void:
	var data = GameData.load_default()
	
	for seed_val in [10, 20, 30, 40, 50]:
		var map = WorldMap.new(data, seed_val)
		map.generate()
		
		var trees = 0
		var scrap = 0
		var rocks = 0
		var size = data.balance("map_size")
		for x in range(size):
			for y in range(size):
				var t = Vector2i(x, y)
				var occ = map.occupant_at(t)
				if occ == WorldMap.Occupant.TREE: trees += 1
				elif occ == WorldMap.Occupant.SCRAP: scrap += 1
				elif occ == WorldMap.Occupant.ROCK: rocks += 1
				
		assert_true(trees >= data.balance("map_trees_min") and trees <= data.balance("map_trees_max"), "Trees in range")
		assert_true(scrap >= data.balance("map_scrap_min") and scrap <= data.balance("map_scrap_max"), "Scrap in range")
		assert_true(rocks >= data.balance("map_rocks_min") and rocks <= data.balance("map_rocks_max"), "Rocks in range")

func test_outer_ring_density() -> void:
	var data = GameData.load_default()
	var map = WorldMap.new(data, 111)
	map.generate()
	
	var size = data.balance("map_size")
	var outer_trees = 0
	var outer_total = 0
	var inner_trees = 0
	var inner_total = 0
	
	for x in range(size):
		for y in range(size):
			var t = Vector2i(x, y)
			var is_outer = x < 8 or x >= size - 8 or y < 8 or y >= size - 8
			if is_outer:
				outer_total += 1
				if map.occupant_at(t) == WorldMap.Occupant.TREE: outer_trees += 1
			else:
				inner_total += 1
				if map.occupant_at(t) == WorldMap.Occupant.TREE: inner_trees += 1
				
	var outer_density = float(outer_trees) / outer_total
	var inner_density = float(inner_trees) / inner_total
	assert_true(outer_density > inner_density, "Outer tree density should be higher than inner")

func test_harvest_and_passable() -> void:
	var data = GameData.load_default()
	var map = WorldMap.new(data, 222)
	map.generate()
	
	var t = Vector2i(0, 0)
	map._occupants[t] = WorldMap.Occupant.TREE
	map._node_amounts[t] = 15
	
	assert_false(map.is_passable(t), "Tree should be impassable")
	
	var taken = map.harvest(t, 10)
	assert_eq(taken, 10)
	assert_eq(map.get_node_amount(t), 5)
	assert_false(map.is_passable(t))
	
	taken = map.harvest(t, 10)
	assert_eq(taken, 5)
	assert_eq(map.get_node_amount(t), 0)
	assert_true(map.is_passable(t), "Cleared tile should be passable")
	assert_eq(map.occupant_at(t), WorldMap.Occupant.NONE)

func test_rock_cannot_be_harvested() -> void:
	var data = GameData.load_default()
	var map = WorldMap.new(data, 333)
	map.generate()
	
	var rock_t = Vector2i(-1, -1)
	for x in range(map.size()):
		for y in range(map.size()):
			var t = Vector2i(x, y)
			if map.occupant_at(t) == WorldMap.Occupant.ROCK:
				rock_t = t
				break
		if rock_t.x != -1:
			break
			
	assert_true(rock_t.x != -1, "Should have generated at least one rock")
	assert_eq(map.get_node_amount(rock_t), 0, "Rock should have 0 node amount")
	var taken = map.harvest(rock_t, 10)
	assert_eq(taken, 0, "Harvesting rock should return 0")
	assert_eq(map.occupant_at(rock_t), WorldMap.Occupant.ROCK, "Rock should still be there")
	assert_false(map.is_passable(rock_t), "Rock should still be impassable")

func test_grid_conversions() -> void:
	var t1 = Vector2i(5, -3)
	var w1 = Grid.tile_to_world(t1)
	var t2 = Grid.world_to_tile(w1)
	assert_eq(t2, t1)
	
	var w2 = Vector2(-15.0, 20.0)
	var t3 = Grid.world_to_tile(w2)
	assert_eq(t3, Vector2i(-1, 0))
