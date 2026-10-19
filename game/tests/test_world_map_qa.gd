extends TestCase

var _change_count: int = 0


func _on_map_changed() -> void:
	_change_count += 1


func test_command_center_exact_footprint_across_seeds() -> void:
	var data: GameData = GameData.load_default()
	var size: int = int(data.balance("map_size"))
	var radius: float = float(data.balance("map_clear_radius"))
	var expected_origin: Vector2i = Vector2i(size / 2 - 1, size / 2 - 1)
	var center: Vector2 = Vector2(size / 2.0, size / 2.0)
	var expected_tiles: Array[Vector2i] = Grid.rect_tiles(expected_origin, Vector2i(2, 2))
	for map_seed: int in [10, 20, 30, 40, 50]:
		var map: WorldMap = WorldMap.new(data, map_seed)
		map.generate()
		assert_eq(map.command_center_origin(), expected_origin)
		var building_count: int = 0
		for x: int in range(size):
			for y: int in range(size):
				var tile: Vector2i = Vector2i(x, y)
				if map.occupant_at(tile) == WorldMap.Occupant.BUILDING:
					building_count += 1
					assert_has(expected_tiles, tile, "Only the four center tiles may contain buildings")
				if tile in expected_tiles:
					assert_eq(map.occupant_at(tile), WorldMap.Occupant.BUILDING)
					assert_eq(map.building_at(tile), "command_center")
				elif Vector2(tile).distance_to(center) < radius:
					assert_eq(map.occupant_at(tile), WorldMap.Occupant.NONE)
		assert_eq(building_count, 4)


func test_passability_for_every_generated_occupant() -> void:
	var map: WorldMap = WorldMap.new(GameData.load_default(), 1337)
	map.generate()
	var seen: Dictionary = {}
	for x in range(map.size()):
		for y in range(map.size()):
			var tile: Vector2i = Vector2i(x, y)
			var occupant: int = map.occupant_at(tile)
			if not seen.has(occupant):
				seen[occupant] = true
				assert_eq(map.is_passable(tile), occupant == WorldMap.Occupant.NONE,
					"Passability for occupant %d" % occupant)
	for occupant: int in WorldMap.Occupant.values():
		assert_has(seen, occupant, "Generated map must exercise every occupant type")
	assert_false(map.is_passable(Vector2i(-1, 0)))
	assert_false(map.is_passable(Vector2i(int(GameData.load_default().balance("map_size")), 0)))


func test_generated_tree_and_scrap_harvest_and_changed_signal() -> void:
	var map: WorldMap = WorldMap.new(GameData.load_default(), 1337)
	map.generate()
	map.changed.connect(_on_map_changed)
	for occupant: int in [WorldMap.Occupant.TREE, WorldMap.Occupant.SCRAP]:
		var found: bool = false
		for x in range(map.size()):
			for y in range(map.size()):
				var tile: Vector2i = Vector2i(x, y)
				if map.occupant_at(tile) != occupant:
					continue
				found = true
				var original: int = map.get_node_amount(tile)
				assert_gt(original, 1, "Generated resource must be harvestable")
				if original <= 1:
					break
				var changes_before: int = _change_count
				assert_eq(map.harvest(tile, 1), 1)
				assert_eq(map.get_node_amount(tile), original - 1)
				assert_eq(map.occupant_at(tile), occupant)
				assert_false(map.is_passable(tile))
				assert_eq(map.harvest(tile, original + 1), original - 1)
				assert_eq(map.get_node_amount(tile), 0)
				assert_eq(map.occupant_at(tile), WorldMap.Occupant.NONE)
				assert_true(map.is_passable(tile))
				# harvest() emits changed only on depletion
				assert_eq(_change_count, changes_before + 1)
				assert_eq(map.harvest(tile, 1), 0)
				break
			if found:
				break
		assert_true(found, "Expected a generated resource of type %d" % occupant)


func test_regeneration_restores_seeded_state() -> void:
	var map: WorldMap = WorldMap.new(GameData.load_default(), 1337)
	map.generate()
	var terrain: Dictionary = map._terrain.duplicate()
	var occupants: Dictionary = map._occupants.duplicate()
	var amounts: Dictionary = map._node_amounts.duplicate()
	var buildings: Dictionary = map._buildings.duplicate()
	var found_tree = false
	for x in range(map.size()):
		for y in range(map.size()):
			var tile: Vector2i = Vector2i(x, y)
			if map.occupant_at(tile) == WorldMap.Occupant.TREE:
				map.harvest(tile, map.get_node_amount(tile))
				found_tree = true
				break
		if found_tree:
			break
	map.vacate(map.command_center_origin(), Vector2i(2, 2))
	map.generate()
	assert_eq(map._terrain, terrain)
	assert_eq(map._occupants, occupants)
	assert_eq(map._node_amounts, amounts)
	assert_eq(map._buildings, buildings)


func test_building_storage_and_changed_signal() -> void:
	var map: WorldMap = WorldMap.new(GameData.load_default(), 1337)
	map.generate()
	map.changed.connect(_on_map_changed)
	var origin: Vector2i = map.command_center_origin() + Vector2i(-2, 0)
	var size: Vector2i = Vector2i(2, 2)
	assert_true(map.is_free(origin, size))
	assert_false(map.is_free(map.command_center_origin(), size))
	map.occupy(origin, size, "qa_shelter")
	assert_false(map.is_free(origin, size))
	for tile: Vector2i in Grid.rect_tiles(origin, size):
		assert_eq(map.building_at(tile), "qa_shelter")
		assert_false(map.is_passable(tile))
	map.vacate(origin, size)
	assert_true(map.is_free(origin, size))
	for tile: Vector2i in Grid.rect_tiles(origin, size):
		assert_eq(map.building_at(tile), "")
		assert_true(map.is_passable(tile))
	assert_eq(_change_count, 2)
	assert_false(map.is_free(Vector2i(-1, 0), size))


func test_grid_centers_boundaries_and_rectangle() -> void:
	for x: int in [-48, -2, -1, 0, 1, 47, 48]:
		for y: int in [-48, -1, 0, 1, 48]:
			var tile: Vector2i = Vector2i(x, y)
			var center: Vector2 = Grid.tile_to_world(tile)
			assert_eq(center, Vector2(tile) * Grid.TILE + Vector2.ONE * Grid.TILE / 2.0)
			assert_eq(Grid.world_to_tile(center), tile)
	assert_eq(Grid.world_to_tile(Vector2(-0.01, -0.01)), Vector2i(-1, -1))
	assert_eq(Grid.world_to_tile(Vector2(-64, 64)), Vector2i(-1, 1))
	assert_eq(Grid.world_to_tile(Vector2(-64.01, 63.99)), Vector2i(-2, 0))
	assert_true(Grid.in_bounds(Vector2i(0, 0), 48))
	assert_true(Grid.in_bounds(Vector2i(47, 47), 48))
	assert_false(Grid.in_bounds(Vector2i(-1, 0), 48))
	assert_false(Grid.in_bounds(Vector2i(0, -1), 48))
	assert_false(Grid.in_bounds(Vector2i(48, 47), 48))
	assert_false(Grid.in_bounds(Vector2i(47, 48), 48))
	var tiles: Array[Vector2i] = Grid.rect_tiles(Vector2i(-2, -1), Vector2i(2, 3))
	assert_eq(tiles.size(), 6)
	for x: int in range(-2, 0):
		for y: int in range(-1, 2):
			assert_has(tiles, Vector2i(x, y))


func test_average_outer_ring_tree_density_across_seeds() -> void:
	var data: GameData = GameData.load_default()
	var size: int = int(data.balance("map_size"))
	var outer_trees: int = 0
	var inner_trees: int = 0
	var outer_tiles: int = 0
	var inner_tiles: int = 0
	for map_seed: int in [0, 1, 10, 20, 30, 40, 50, 111, 1337, 9999]:
		var map: WorldMap = WorldMap.new(data, map_seed)
		map.generate()
		for x in range(size):
			for y in range(size):
				var tile: Vector2i = Vector2i(x, y)
				if tile.x < 8 or tile.y < 8 or tile.x >= size - 8 or tile.y >= size - 8:
					outer_tiles += 1
					if map.occupant_at(tile) == WorldMap.Occupant.TREE:
						outer_trees += 1
				else:
					inner_tiles += 1
					if map.occupant_at(tile) == WorldMap.Occupant.TREE:
						inner_trees += 1
	assert_gt(float(outer_trees) / outer_tiles, float(inner_trees) / inner_tiles)


func test_generated_resource_amounts_match_balance_ranges() -> void:
	var data: GameData = GameData.load_default()
	for map_seed: int in [10, 20, 30, 40, 50]:
		var map: WorldMap = WorldMap.new(data, map_seed)
		map.generate()
		for x: int in range(map.size()):
			for y: int in range(map.size()):
				var tile: Vector2i = Vector2i(x, y)
				var occupant: int = map.occupant_at(tile)
				var amount: int = map.get_node_amount(tile)
				if occupant == WorldMap.Occupant.TREE:
					assert_true(amount >= int(data.balance("map_tree_wood_min"))
						and amount <= int(data.balance("map_tree_wood_max")), "Tree yield must use balance range")
				elif occupant == WorldMap.Occupant.SCRAP:
					assert_true(amount >= int(data.balance("map_scrap_amount_min"))
						and amount <= int(data.balance("map_scrap_amount_max")), "Scrap yield must use balance range")
				else:
					assert_eq(amount, 0, "Only trees and scrap are resource nodes")


func test_resource_yields_follow_changed_balance_configuration() -> void:
	var data: GameData = GameData.load_default()
	# Fixture overrides use values outside the defaults to expose hard-coded yields.
	for tree_amount: int in [73, 91]:
		var scrap_amount: int = tree_amount + 5
		data._balance["map_tree_wood_min"] = tree_amount
		data._balance["map_tree_wood_max"] = tree_amount
		data._balance["map_scrap_amount_min"] = scrap_amount
		data._balance["map_scrap_amount_max"] = scrap_amount
		var map: WorldMap = WorldMap.new(data, 1337)
		map.generate()
		var seen: Dictionary = {}
		for x: int in range(map.size()):
			for y: int in range(map.size()):
				var tile: Vector2i = Vector2i(x, y)
				var occupant: int = map.occupant_at(tile)
				if occupant == WorldMap.Occupant.TREE or occupant == WorldMap.Occupant.SCRAP:
					seen[occupant] = true
					var expected: int = tree_amount if occupant == WorldMap.Occupant.TREE else scrap_amount
					assert_eq(map.get_node_amount(tile), expected, "Configured yield must reach generated nodes")
		assert_has(seen, WorldMap.Occupant.TREE)
		assert_has(seen, WorldMap.Occupant.SCRAP)
