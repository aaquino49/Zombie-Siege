class_name WorldMap extends RefCounted

signal changed

enum Terrain { GRASS, DIRT, ROAD }
enum Occupant { NONE, TREE, SCRAP, ROCK, BUILDING }

var _data: GameData
var _map_seed: int
var _rng: RandomNumberGenerator
var _size: int

var _terrain: Dictionary = {}
var _occupants: Dictionary = {}
var _node_amounts: Dictionary = {}
var _buildings: Dictionary = {}

func _init(data: GameData, map_seed: int) -> void:
	_data = data
	_map_seed = map_seed
	_size = int(data.balance("map_size", 48))
	_rng = RandomNumberGenerator.new()

func generate() -> void:
	_rng.seed = _map_seed
	
	_terrain.clear()
	_occupants.clear()
	_node_amounts.clear()
	_buildings.clear()
	
	var clear_radius: int = int(_data.balance("map_clear_radius", 5))
	var cc_origin: Vector2i = command_center_origin()
	var cc_tiles: Array[Vector2i] = Grid.rect_tiles(cc_origin, Vector2i(2, 2))
	
	# Generate base terrain
	for x in range(_size):
		for y in range(_size):
			var t: Vector2i = Vector2i(x, y)
			_terrain[t] = Terrain.GRASS
			_occupants[t] = Occupant.NONE
	
	# Add dirt patches
	var dirt_patches: int = int(_data.balance("map_dirt_patches", 10))
	for i in range(dirt_patches):
		var center: Vector2i = Vector2i(_rng.randi_range(0, _size - 1), _rng.randi_range(0, _size - 1))
		var radius: int = _rng.randi_range(int(_data.balance("map_dirt_radius_min", 1)), int(_data.balance("map_dirt_radius_max", 3)))
		for t in _tiles_in_radius(center, radius):
			var t0: Vector2i = t
			var t1: Vector2i = t + Vector2i.RIGHT
			var t2: Vector2i = t + Vector2i.DOWN
			var t3: Vector2i = t + Vector2i(1, 1)
			if Grid.in_bounds(t0, _size) and Grid.in_bounds(t1, _size) and Grid.in_bounds(t2, _size) and Grid.in_bounds(t3, _size):
				for pt: Vector2i in [t0, t1, t2, t3]:
					if _terrain.get(pt, Terrain.GRASS) != Terrain.ROAD:
						_terrain[pt] = Terrain.DIRT
	
	var dirt_changed: bool = true
	while dirt_changed:
		dirt_changed = false
		for x in range(_size):
			for y in range(_size):
				var t: Vector2i = Vector2i(x, y)
				if _terrain.get(t, Terrain.GRASS) == Terrain.DIRT:
					var grass_n: bool = terrain_at(t + Vector2i.UP) == Terrain.GRASS
					var grass_s: bool = terrain_at(t + Vector2i.DOWN) == Terrain.GRASS
					var grass_e: bool = terrain_at(t + Vector2i.RIGHT) == Terrain.GRASS
					var grass_w: bool = terrain_at(t + Vector2i.LEFT) == Terrain.GRASS
					if (grass_n and grass_s) or (grass_e and grass_w):
						_terrain[t] = Terrain.GRASS
						dirt_changed = true
	
	# Add roads
	var roads_min: int = int(_data.balance("map_roads_min", 1))
	var roads_max: int = int(_data.balance("map_roads_max", 2))
	for i in range(_rng.randi_range(roads_min, roads_max)):
		_generate_road()
	
	# Generate resources
	var trees_to_place: int = _rng.randi_range(int(_data.balance("map_trees_min", 100)), int(_data.balance("map_trees_max", 150)))
	var scrap_to_place: int = _rng.randi_range(int(_data.balance("map_scrap_min", 20)), int(_data.balance("map_scrap_max", 30)))
	var rocks_to_place: int = _rng.randi_range(int(_data.balance("map_rocks_min", 30)), int(_data.balance("map_rocks_max", 40)))
	
	var center_f: Vector2 = Vector2(_size / 2.0, _size / 2.0)
	var max_dist: float = center_f.length()
	
	var potential_tiles: Array[Vector2i] = []
	for x in range(_size):
		for y in range(_size):
			var t: Vector2i = Vector2i(x, y)
			if t in cc_tiles or terrain_at(t) == Terrain.ROAD or terrain_at(t) == Terrain.DIRT:
				continue
			var dist: float = Vector2(t).distance_to(center_f)
			if dist < clear_radius:
				continue
			potential_tiles.append(t)
			
	_place_nodes(Occupant.TREE, trees_to_place, potential_tiles, center_f, max_dist, true)
	_place_nodes(Occupant.SCRAP, scrap_to_place, potential_tiles, center_f, max_dist, true)
	_place_nodes(Occupant.ROCK, rocks_to_place, potential_tiles, center_f, max_dist, false)
	
	# Command Center
	occupy(cc_origin, Vector2i(2, 2), "command_center")

func _roll_amount(type: int) -> int:
	if type == Occupant.TREE:
		return _rng.randi_range(int(_data.balance("map_tree_wood_min", 20)), int(_data.balance("map_tree_wood_max", 40)))
	elif type == Occupant.SCRAP:
		return _rng.randi_range(int(_data.balance("map_scrap_amount_min", 15)), int(_data.balance("map_scrap_amount_max", 30)))
	return 0

func _place_nodes(type: int, count: int, potential_tiles: Array[Vector2i], center_f: Vector2, max_dist: float, prefer_edges: bool) -> void:
	var placed: int = 0
	var attempts: int = 0
	while placed < count and attempts < 50000 and potential_tiles.size() > 0:
		attempts += 1
		var index: int = _rng.randi_range(0, potential_tiles.size() - 1)
		var t: Vector2i = potential_tiles[index]
		
		var dist: float = Vector2(t).distance_to(center_f)
		var prob: float = 1.0
		if prefer_edges:
			prob = dist / max_dist
			prob = prob * prob * prob # stronger edge preference
		
		if _rng.randf() <= prob:
			_occupants[t] = type
			if type != Occupant.ROCK:
				_node_amounts[t] = _roll_amount(type)
			potential_tiles.remove_at(index)
			placed += 1
			
	# Force place if not enough placed due to rejection
	while placed < count and potential_tiles.size() > 0:
		var index: int = _rng.randi_range(0, potential_tiles.size() - 1)
		var t: Vector2i = potential_tiles[index]
		_occupants[t] = type
		if type != Occupant.ROCK:
			_node_amounts[t] = _roll_amount(type)
		potential_tiles.remove_at(index)
		placed += 1

func _generate_road() -> void:
	# Snapshot only earlier tracks: overlapping stamps of this walk are normal.
	var earlier: Dictionary = {}
	for t: Vector2i in _terrain:
		if terrain_at(t) == Terrain.ROAD:
			earlier[t] = true
	var inward_dirs: Array[Vector2i] = [Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP, Vector2i.RIGHT]
	var edge: int = _rng.randi_range(0, 3)
	var along: int = _rng.randi_range(8, _size - 10)
	var starts: Array[Vector2i] = [Vector2i(along, 0), Vector2i(_size - 2, along), Vector2i(along, _size - 2), Vector2i(0, along)]
	var pos: Vector2i = starts[edge]
	# Keep separate entrances even if two tracks roll the same edge/start.
	while _road_touches(pos, earlier):
		along = 8 + (along - 8 + 3) % (_size - 17)
		starts = [Vector2i(along, 0), Vector2i(_size - 2, along), Vector2i(along, _size - 2), Vector2i(0, along)]
		pos = starts[edge]
	var inward: Vector2i = inward_dirs[edge]
	var sideways: Vector2i = Vector2i(inward.y, inward.x)
	var center: Vector2 = Vector2(_size / 2.0, _size / 2.0)
	var radius: float = float(_data.balance("map_clear_radius", 5)) + 1.0
	var cooldown: int = 4
	var side_steps: int = 0
	var side_sign: int = 1
	var turn_chance: float = float(_data.balance("map_road_turn_chance", 0.2))
	while true:
		var reached: bool = false
		for t: Vector2i in Grid.rect_tiles(pos, Vector2i(2, 2)):
			_terrain[t] = Terrain.ROAD
			if Vector2(t).distance_to(center) <= radius:
				reached = true
		if reached or _road_touches(pos, earlier):
			return
		# At the centre's depth, converge sideways instead of overshooting.
		var depth_delta: float = (Vector2(pos) - center).dot(Vector2(inward))
		var lateral_delta: float = (center - Vector2(pos)).dot(Vector2(sideways))
		if depth_delta >= -radius + 2.0:
			pos += sideways * (1 if lateral_delta > 0.0 else -1)
			continue
		if side_steps == 0 and cooldown <= 0 and _rng.randf() < turn_chance:
			side_steps = _rng.randi_range(2, 5)
			side_sign = 1 if _rng.randi_range(0, 1) == 1 else -1
		if side_steps > 0:
			var next: Vector2i = pos + sideways * side_sign
			var lateral: int = next.x if sideways.x != 0 else next.y
			if lateral >= 4 and lateral <= _size - 6:
				pos = next
				side_steps -= 1
				if side_steps == 0:
					cooldown = 3
				continue
			side_steps = 0
			cooldown = 3
		pos += inward
		cooldown -= 1

func _road_touches(pos: Vector2i, earlier: Dictionary) -> bool:
	for t: Vector2i in Grid.rect_tiles(pos, Vector2i(2, 2)):
		if earlier.has(t):
			return true
		for dir: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			if earlier.has(t + dir):
				return true
	return false

func _tiles_in_radius(center: Vector2i, radius: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for x in range(center.x - radius, center.x + radius + 1):
		for y in range(center.y - radius, center.y + radius + 1):
			if Vector2(x, y).distance_to(Vector2(center)) <= radius:
				tiles.append(Vector2i(x, y))
	return tiles

func size() -> int:
	return _size

func terrain_at(t: Vector2i) -> int:
	if not Grid.in_bounds(t, _size):
		return Terrain.GRASS
	return _terrain.get(t, Terrain.GRASS)

func occupant_at(t: Vector2i) -> int:
	if not Grid.in_bounds(t, _size):
		return Occupant.NONE
	return _occupants.get(t, Occupant.NONE)

func get_node_amount(t: Vector2i) -> int:
	return _node_amounts.get(t, 0)

func nodes_of(occupant: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for t in _node_amounts:
		if _occupants.get(t, Occupant.NONE) == occupant:
			result.append(t)
	return result

func harvest(t: Vector2i, amount: int) -> int:
	var current: int = get_node_amount(t)
	if current <= 0:
		return 0
	var taken: int = mini(current, amount)
	var new_amount: int = current - taken
	if new_amount <= 0:
		_node_amounts.erase(t)
		_occupants[t] = Occupant.NONE
		changed.emit()
	else:
		_node_amounts[t] = new_amount
	return taken

func is_passable(t: Vector2i) -> bool:
	if not Grid.in_bounds(t, _size):
		return false
	var occ: int = _occupants.get(t, Occupant.NONE)
	# trees, rocks, scrap piles and buildings are impassable
	return occ == Occupant.NONE

func command_center_origin() -> Vector2i:
	return Vector2i(_size / 2 - 1, _size / 2 - 1)

func occupy(origin: Vector2i, size: Vector2i, building_id: String) -> void:
	for t in Grid.rect_tiles(origin, size):
		_occupants[t] = Occupant.BUILDING
		_buildings[t] = building_id
	changed.emit()

func vacate(origin: Vector2i, size: Vector2i) -> void:
	for t in Grid.rect_tiles(origin, size):
		_occupants[t] = Occupant.NONE
		_buildings.erase(t)
	changed.emit()

func is_free(origin: Vector2i, size: Vector2i) -> bool:
	for t in Grid.rect_tiles(origin, size):
		if not Grid.in_bounds(t, _size):
			return false
		if _occupants.get(t, Occupant.NONE) != Occupant.NONE:
			return false
	return true

func building_at(t: Vector2i) -> String:
	return _buildings.get(t, "")

func export_nodes() -> Array:
	var result: Array = []
	for t in _node_amounts:
		var occ: int = _occupants.get(t, Occupant.NONE)
		if occ == Occupant.TREE or occ == Occupant.SCRAP:
			result.append({"tile": [t.x, t.y], "occupant": occ, "amount": int(_node_amounts[t])})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ta: Array = a["tile"]
		var tb: Array = b["tile"]
		return int(ta[0]) < int(tb[0]) or (int(ta[0]) == int(tb[0]) and int(ta[1]) < int(tb[1])))
	return result

func import_nodes(nodes: Array) -> void:
	var wanted: Dictionary = {}
	for e in nodes:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var arr: Array = (e as Dictionary).get("tile", [])
		if arr.size() != 2:
			continue
		var t := Vector2i(int(arr[0]), int(arr[1]))
		var occ: int = int((e as Dictionary).get("occupant", Occupant.NONE))
		var amount: int = int((e as Dictionary).get("amount", 0))
		if occ != Occupant.TREE and occ != Occupant.SCRAP:
			continue
		if amount <= 0:
			continue
		wanted[t] = {"occupant": occ, "amount": amount}
	for t in _node_amounts.keys().duplicate():
		if not wanted.has(t):
			_node_amounts.erase(t)
			if _occupants.get(t, Occupant.NONE) == Occupant.TREE or _occupants.get(t, Occupant.NONE) == Occupant.SCRAP:
				_occupants[t] = Occupant.NONE
	for t in wanted:
		var entry: Dictionary = wanted[t]
		_occupants[t] = int(entry["occupant"])
		_node_amounts[t] = int(entry["amount"])
	changed.emit()
