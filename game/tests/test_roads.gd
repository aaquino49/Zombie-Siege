extends TestCase

const SEEDS: Array[int] = [1, 1337, 4242, 9001]
const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

func _road(map: WorldMap, t: Vector2i) -> bool:
	return Grid.in_bounds(t, map.size()) and map.terrain_at(t) == WorldMap.Terrain.ROAD

func _in_block(map: WorldMap, t: Vector2i) -> bool:
	for dx: int in range(-1, 1):
		for dy: int in range(-1, 1):
			var full: bool = true
			for b: Vector2i in Grid.rect_tiles(t + Vector2i(dx, dy), Vector2i(2, 2)):
				full = full and _road(map, b)
			if full:
				return true
	return false

func _component(map: WorldMap, start: Vector2i) -> Array[Vector2i]:
	var queue: Array[Vector2i] = [start]
	var visited: Dictionary = {start: true}
	var index: int = 0
	while index < queue.size():
		var t: Vector2i = queue[index]
		index += 1
		for dir: Vector2i in DIRS:
			var next: Vector2i = t + dir
			if _road(map, next) and not visited.has(next):
				visited[next] = true
				queue.append(next)
	return queue

func test_seeded_tracks_geometry_connectivity_and_determinism() -> void:
	var data: GameData = GameData.load_default()
	var bent_seeds: int = 0
	for seed_value: int in SEEDS:
		var map: WorldMap = WorldMap.new(data, seed_value)
		map.generate()
		var twin: WorldMap = WorldMap.new(data, seed_value)
		twin.generate()
		var center: Vector2 = Vector2(map.size() / 2.0, map.size() / 2.0)
		var radius: float = float(data.balance("map_clear_radius")) + 1.0
		var border: Array[Vector2i] = []
		var starts: int = 0
		for edge: int in range(4):
			var was_road: bool = false
			for i: int in range(map.size()):
				var edges: Array[Vector2i] = [Vector2i(i, 0), Vector2i(map.size() - 1, i), Vector2i(i, map.size() - 1), Vector2i(0, i)]
				var t: Vector2i = edges[edge]
				var is_road: bool = _road(map, t)
				if is_road:
					border.append(t)
					if not was_road:
						starts += 1
				was_road = is_road
		assert_true(starts >= int(data.balance("map_roads_min")) and starts <= int(data.balance("map_roads_max")), "Border entrances seed %d" % seed_value)
		for x: int in range(map.size()):
			for y: int in range(map.size()):
				var t: Vector2i = Vector2i(x, y)
				assert_eq(map.terrain_at(t), twin.terrain_at(t), "Seed terrain determinism")
				assert_eq(map.occupant_at(t), twin.occupant_at(t), "Seed resource determinism")
				if not _road(map, t):
					continue
				assert_true(_in_block(map, t), "2x2 stamp seed %d tile %s" % [seed_value, t])
				assert_eq(map.occupant_at(t), WorldMap.Occupant.NONE, "No CC or resources on tracks")
				assert_false(t in Grid.rect_tiles(map.command_center_origin(), Vector2i(2, 2)), "No CC road")
				for dir: Vector2i in [Vector2i.UP, Vector2i.RIGHT]:
					assert_false(PathTiles._is_grass(map, t + dir) and PathTiles._is_grass(map, t - dir), "No opposite grass sides")
		var bent: bool = false
		for start: Vector2i in border:
			var reached: bool = false
			var lateral: Dictionary = {}
			for t: Vector2i in _component(map, start):
				reached = reached or Vector2(t).distance_to(center) <= radius
				lateral[t.x if start.y == 0 or start.y == map.size() - 1 else t.y] = true
			assert_true(reached, "Every border road reaches clearing seed %d" % seed_value)
			bent = bent or lateral.size() >= 3
		if bent:
			bent_seeds += 1
	assert_true(bent_seeds >= 3, "Tracks bend on at least three acceptance seeds")

func _stamp(map: WorldMap, pos: Vector2i) -> void:
	for t: Vector2i in Grid.rect_tiles(pos, Vector2i(2, 2)):
		map._terrain[t] = WorldMap.Terrain.ROAD

func test_straight_track_edges_and_boundary() -> void:
	var map: WorldMap = WorldMap.new(GameData.load_default(), 0)
	for x: int in range(4, 10):
		_stamp(map, Vector2i(x, 5))
	assert_eq(PathTiles.path_tile_for(map, Vector2i(7, 5)), "edge_n")
	assert_eq(PathTiles.path_tile_for(map, Vector2i(7, 6)), "edge_s")
	map._terrain[Vector2i(7, 4)] = WorldMap.Terrain.DIRT
	assert_eq(PathTiles.path_tile_for(map, Vector2i(7, 5)), "center", "DIRT counts as path interior")
	for y: int in range(4, 10):
		_stamp(map, Vector2i(0, y))
	assert_eq(PathTiles.path_tile_for(map, Vector2i(0, 7)), "center", "Out of bounds counts as dirt")

func test_l_corners_in_all_orientations_and_center() -> void:
	for rotation: int in range(4):
		var map: WorldMap = WorldMap.new(GameData.load_default(), 0)
		# Horizontal arm to east, vertical arm to south.
		var tiles: Dictionary = {}
		for i: int in range(5):
			for t: Vector2i in Grid.rect_tiles(Vector2i(i, 0), Vector2i(2, 2)):
				tiles[t] = true
			for t: Vector2i in Grid.rect_tiles(Vector2i(0, i), Vector2i(2, 2)):
				tiles[t] = true
		for t: Vector2i in tiles:
			map._terrain[_rotate(t, rotation) + Vector2i(15, 15)] = WorldMap.Terrain.ROAD
		var outer_names: Array[String] = ["nw", "ne", "se", "sw"]
		var inner_names: Array[String] = ["se", "sw", "nw", "ne"]
		assert_eq(PathTiles.path_tile_for(map, Vector2i(15, 15)), "outer_" + outer_names[rotation])
		assert_eq(PathTiles.path_tile_for(map, _rotate(Vector2i(1, 1), rotation) + Vector2i(15, 15)), "inner_" + inner_names[rotation])
	var full: WorldMap = WorldMap.new(GameData.load_default(), 0)
	for t: Vector2i in Grid.rect_tiles(Vector2i(10, 10), Vector2i(3, 3)):
		full._terrain[t] = WorldMap.Terrain.ROAD
	assert_eq(PathTiles.path_tile_for(full, Vector2i(11, 11)), "center")
	full._terrain[Vector2i(10, 10)] = WorldMap.Terrain.GRASS
	full._terrain[Vector2i(12, 12)] = WorldMap.Terrain.GRASS
	assert_eq(PathTiles.path_tile_for(full, Vector2i(11, 11)), "center", "Multiple grass diagonals fall back to center")

func _rotate(t: Vector2i, turns: int) -> Vector2i:
	for i: int in range(turns):
		t = Vector2i(-t.y, t.x)
	return t

func test_dirt_patches() -> void:
	var data: GameData = GameData.load_default()
	for seed_value: int in SEEDS:
		var map: WorldMap = WorldMap.new(data, seed_value)
		map.generate()
		for x: int in range(map.size()):
			for y: int in range(map.size()):
				var t: Vector2i = Vector2i(x, y)
				if map.terrain_at(t) != WorldMap.Terrain.DIRT:
					continue
				
				var in_2x2: bool = false
				for dx: int in range(-1, 1):
					for dy: int in range(-1, 1):
						var full: bool = true
						for b: Vector2i in Grid.rect_tiles(t + Vector2i(dx, dy), Vector2i(2, 2)):
							var tr: int = map.terrain_at(b)
							if tr != WorldMap.Terrain.DIRT and tr != WorldMap.Terrain.ROAD:
								full = false
						if full:
							in_2x2 = true
				assert_true(in_2x2, "DIRT tile in 2x2 block seed %d tile %s" % [seed_value, t])
				
				var n: bool = map.terrain_at(t + Vector2i.UP) == WorldMap.Terrain.GRASS
				var s: bool = map.terrain_at(t + Vector2i.DOWN) == WorldMap.Terrain.GRASS
				var e: bool = map.terrain_at(t + Vector2i.RIGHT) == WorldMap.Terrain.GRASS
				var w: bool = map.terrain_at(t + Vector2i.LEFT) == WorldMap.Terrain.GRASS
				assert_false(n and s, "DIRT tile opposite grass N+S seed %d tile %s" % [seed_value, t])
				assert_false(e and w, "DIRT tile opposite grass E+W seed %d tile %s" % [seed_value, t])


func test_resources_off_dirt_and_road() -> void:
	var data: GameData = GameData.load_default()
	for seed_value: int in SEEDS:
		var map: WorldMap = WorldMap.new(data, seed_value)
		map.generate()
		var trees: int = 0
		var scrap: int = 0
		var rocks: int = 0
		for x: int in range(map.size()):
			for y: int in range(map.size()):
				var t: Vector2i = Vector2i(x, y)
				var occ: int = map.occupant_at(t)
				if occ == WorldMap.Occupant.TREE or occ == WorldMap.Occupant.ROCK or occ == WorldMap.Occupant.SCRAP:
					assert_eq(map.terrain_at(t), WorldMap.Terrain.GRASS, "Resource %d must be on GRASS, seed %d tile %s" % [occ, seed_value, t])
					if occ == WorldMap.Occupant.TREE: trees += 1
					elif occ == WorldMap.Occupant.ROCK: rocks += 1
					elif occ == WorldMap.Occupant.SCRAP: scrap += 1
		assert_true(trees >= int(data.balance("map_trees_min")), "Trees meet minimum seed %d" % seed_value)
		assert_true(rocks >= int(data.balance("map_rocks_min")), "Rocks meet minimum seed %d" % seed_value)
		assert_true(scrap >= int(data.balance("map_scrap_min")), "Scrap meets minimum seed %d" % seed_value)

