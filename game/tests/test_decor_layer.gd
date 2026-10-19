extends TestCase

func _map(seed: int) -> WorldMap:
	var map := WorldMap.new(GameData.load_default(), seed)
	map.generate()
	return map

func test_plan_is_deterministic_over_five_seeds() -> void:
	var previous: Array[Dictionary] = []
	for seed: int in [1, 42, 120, 1337, 9001]:
		var map: WorldMap = _map(seed)
		var entries: Array[Dictionary] = DecorLayer.plan(map, seed)
		assert_eq(entries, DecorLayer.plan(map, seed), "Same seed gives identical order, tiles and textures")
		assert_eq(entries, DecorLayer.plan(_map(seed), seed), "Fresh map instance is identical")
		assert_ne(entries, previous, "Different seeds give different plans")
		assert_ne(entries, DecorLayer.plan(map, seed + 1), "Planner seed changes scenery on the same map")
		previous = entries

func test_every_footprint_is_valid_and_nonoverlapping_over_five_seeds() -> void:
	for seed: int in [1, 42, 120, 1337, 9001]:
		var map: WorldMap = _map(seed)
		var taken: Dictionary = {}
		for entry: Dictionary in DecorLayer.plan(map, seed):
			assert_true(ResourceLoader.exists(entry["texture_path"]), "Every selected pack texture exists")
			for tile: Vector2i in DecorLayer.footprint(entry):
				assert_true(Grid.in_bounds(tile, map.size()), "Footprint stays in bounds")
				assert_eq(map.terrain_at(tile), WorldMap.Terrain.GRASS, "Roads and dirt stay clear")
				assert_eq(map.occupant_at(tile), WorldMap.Occupant.NONE, "Resource/building tiles stay clear")
				for cc_tile: Vector2i in Grid.rect_tiles(map.command_center_origin(), Vector2i(2, 2)):
					assert_gt(Vector2(tile).distance_to(Vector2(cc_tile)), 6.0, "CC clearing stays clear")
				for dx: int in range(-1, 2):
					for dy: int in range(-1, 2):
						assert_false(map.occupant_at(tile + Vector2i(dx, dy)) in [WorldMap.Occupant.TREE, WorldMap.Occupant.ROCK, WorldMap.Occupant.SCRAP], "Includes diagonal resource neighbours")
				assert_false(taken.has(tile), "Decor footprints do not overlap")
				taken[tile] = true

func test_car_count_spacing_and_road_preference_over_five_seeds() -> void:
	for seed: int in [1, 42, 120, 1337, 9001]:
		var map: WorldMap = _map(seed)
		var cars: Array[Vector2i] = []
		var roadside: int = 0
		for entry: Dictionary in DecorLayer.plan(map, seed):
			if entry["size"] != Vector2i(3, 3):
				continue
			var tile: Vector2i = entry["tile"]
			assert_eq(DecorLayer.footprint(entry).size(), 9)
			for other: Vector2i in cars:
				assert_true(Vector2(tile).distance_to(Vector2(other)) >= 8.0, "Cars stay eight tiles apart")
			cars.append(tile)
			if DecorLayer._near_road(map, tile):
				roadside += 1
		assert_true(cars.size() >= 4 and cars.size() <= 8, "Four to eight cars on generated maps: seed %d has %d" % [seed, cars.size()])
		assert_gt(roadside, 0, "Prefer roadside candidates")

func test_small_prop_density_and_clusters() -> void:
	var map: WorldMap = _map(1337)
	var eligible_count: int = 0
	for x: int in range(map.size()):
		for y: int in range(map.size()):
			if DecorLayer.eligible(map, Vector2i(x, y)):
				eligible_count += 1
	var small: Dictionary = {}
	var kinds: Dictionary = {}
	for entry: Dictionary in DecorLayer.plan(map, 1337):
		if entry["size"] == Vector2i.ONE:
			small[entry["tile"]] = true
			kinds[String(entry["texture_path"]).get_file().get_slice("_", 0)] = true
	assert_eq(small.size(), roundi(eligible_count * 0.03), "About three percent of eligible tiles")
	assert_eq(kinds.size(), 5, "Seeded overview includes all five small prop kinds")
	var visited: Dictionary = {}
	var multiple: bool = false
	for tile: Vector2i in small:
		if visited.has(tile):
			continue
		var pending: Array[Vector2i] = [tile]
		visited[tile] = true
		var count: int = 0
		while not pending.is_empty():
			var current: Vector2i = pending.pop_back()
			count += 1
			for dir: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
				var neighbour: Vector2i = current + dir
				if small.has(neighbour) and not visited.has(neighbour):
					visited[neighbour] = true
					pending.append(neighbour)
		assert_true(count >= 1 and count <= 3, "Clusters contain one to three props")
		multiple = multiple or count > 1
	assert_true(multiple, "Includes clustered props")

func test_plan_handles_map_with_no_eligible_tiles() -> void:
	var map: WorldMap = _map(1337)
	map.occupy(Vector2i.ZERO, Vector2i(map.size(), map.size()), "wooden_wall")
	assert_eq(DecorLayer.plan(map, 1337).size(), 0, "Do not force invalid scenery onto constrained maps")

func test_bind_is_view_only_and_pixel_anchored() -> void:
	var state := GameState.new(GameData.load_default(), 1337)
	var occupants: Dictionary = state.map._occupants.duplicate()
	var terrain: Dictionary = state.map._terrain.duplicate()
	var rng_state: int = state.map._rng.state
	var decor := DecorLayer.new()
	decor.bind(state)
	assert_true(decor.y_sort_enabled)
	assert_eq(state.map._occupants, occupants, "Decor adds no map occupants")
	assert_eq(state.map._terrain, terrain, "Decor changes no terrain")
	assert_eq(state.map._rng.state, rng_state, "Decor does not consume simulation randomness")
	for index: int in range(decor._entries.size()):
		var entry: Dictionary = decor._entries[index]
		var sprite: Sprite2D = decor._sprites[index]
		assert_eq(sprite.scale, Vector2(4, 4))
		assert_eq(sprite.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
		assert_eq(sprite.rotation, 0.0)
		assert_eq(Vector2i(sprite.texture.get_size()), entry["size"] * Grid.PX_TILE)
		assert_eq(sprite.position, Grid.tile_to_world(entry["tile"]) + Vector2(0, Grid.TILE / 2.0))
		assert_almost_eq(sprite.get_rect().end.y, 0.0, 0.001, "Bottom edge is at y-sort anchor")
		for tile: Vector2i in DecorLayer.footprint(entry):
			assert_true(state.map.is_passable(tile), "Decor does not block movement")
	decor.free()

func test_building_and_blueprint_hide_each_car_tile_and_restore_it() -> void:
	var state := GameState.new(GameData.load_default(), 1337)
	var decor := DecorLayer.new()
	decor.bind(state)
	var sprite: Sprite2D = decor._sprites[0]
	var entry: Dictionary = decor._entries[0]
	assert_eq(entry["size"], Vector2i(3, 3))
	state.resources.add("wood", 1000)
	for tile: Vector2i in DecorLayer.footprint(entry):
		assert_eq(state.try_place("wooden_wall", tile), Placement.Result.OK, "Decor does not block placement")
		var building: Building = state.buildings.get_at(tile)
		assert_false(sprite.visible, "Any footprint tile hides the entire car under a blueprint")
		state.buildings.finish(building.uid)
		assert_false(sprite.visible, "Completed building keeps car hidden")
		state.buildings.remove(building.uid)
		assert_true(sprite.visible, "Removing building restores the same sprite")
	var tiles: Array[Vector2i] = DecorLayer.footprint(entry)
	var first: Building = state.buildings.add("wooden_wall", tiles[0], true)
	var second: Building = state.buildings.add("wooden_wall", tiles[8], false)
	state.buildings.remove(first.uid)
	assert_false(sprite.visible, "Another covering building still hides the car")
	state.buildings.remove(second.uid)
	assert_true(sprite.visible)
	decor.free()

func test_small_prop_hides_and_restores_and_rebinding_disconnects_old_state() -> void:
	var state := GameState.new(GameData.load_default(), 1337)
	var decor := DecorLayer.new()
	decor.bind(state)
	for index: int in range(decor._entries.size()):
		var entry: Dictionary = decor._entries[index]
		if entry["size"] != Vector2i.ONE:
			continue
		var sprite: Sprite2D = decor._sprites[index]
		var building: Building = state.buildings.add("wooden_wall", entry["tile"], false)
		assert_false(sprite.visible)
		state.buildings.remove(building.uid)
		assert_true(sprite.visible)
		break
	var new_state := GameState.new(GameData.load_default(), 42)
	decor.bind(new_state)
	assert_false(state.map.changed.is_connected(decor._refresh_all))
	assert_false(state.buildings.building_added.is_connected(decor._on_building_changed))
	assert_false(state.buildings.building_removed.is_connected(decor._on_building_changed))
	assert_eq(decor.get_child_count(), decor._entries.size(), "Rebind replaces rather than duplicates sprites")
	decor.free()
