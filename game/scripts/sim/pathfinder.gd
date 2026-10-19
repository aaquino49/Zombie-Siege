class_name Pathfinder extends RefCounted

var _astar: AStarGrid2D
var _map: WorldMap
var _dirty: bool = true

func _init(map: WorldMap) -> void:
	_map = map
	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(0, 0, map.size(), map.size())
	_astar.cell_size = Vector2(Grid.TILE, Grid.TILE)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()
	_map.changed.connect(_on_map_changed)

func _on_map_changed() -> void:
	_dirty = true

func _update_solids() -> void:
	if not _dirty:
		return
	var size := _map.size()
	for y in range(size):
		for x in range(size):
			var t := Vector2i(x, y)
			var solid := not _map.is_passable(t)
			if _map.building_at(t) == "gate":
				solid = false
			_astar.set_point_solid(t, solid)
	_dirty = false

func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	_update_solids()
	if not _astar.is_in_bounds(from.x, from.y) or not _astar.is_in_bounds(to.x, to.y):
		return []
	if _astar.is_point_solid(to):
		return []
		
	var from_was_solid: bool = _astar.is_point_solid(from)
	if from_was_solid:
		_astar.set_point_solid(from, false)
	
	var id_path := _astar.get_id_path(from, to)
	
	if from_was_solid:
		_astar.set_point_solid(from, true)
		
	var res: Array[Vector2i] = []
	for p in id_path:
		res.append(p)
		
	if res.size() > 0 and res[0] == from:
		res.pop_front()
	return res

# Returns shortest path to any passable tile in the 1-tile ring around the rect.
# If `from` is already in the ring, return [] (caller should treat as "arrived").
func find_path_adjacent(from: Vector2i, origin: Vector2i, size: Vector2i) -> Array[Vector2i]:
	_update_solids()
	if Grid.in_ring(from, origin, size) and not _astar.is_point_solid(from):
		return []
		
	var best_path: Array[Vector2i] = []
	var best_dist: float = INF
	
	for x in range(origin.x - 1, origin.x + size.x + 1):
		for y in range(origin.y - 1, origin.y + size.y + 1):
			if x >= origin.x and x < origin.x + size.x and y >= origin.y and y < origin.y + size.y:
				continue
			var t := Vector2i(x, y)
			if _astar.is_in_bounds(t.x, t.y) and not _astar.is_point_solid(t):
				var p := find_path(from, t)
				if p.is_empty():
					continue
				var dist: float = 0.0
				var current := from
				for pt in p:
					dist += current.distance_to(pt)
					current = pt
				if dist < best_dist:
					best_dist = dist
					best_path = p
					
	return best_path
