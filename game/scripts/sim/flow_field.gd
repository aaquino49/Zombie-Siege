class_name FlowField extends RefCounted

var _map: WorldMap
var _data: GameData
var _buildings: BuildingStore
var _distances: PackedInt32Array
var _next_indices: PackedInt32Array
var _dirty: bool = true
var _size: int
var _cost_mult: float
var rebuild_count: int = 0

func _init(map: WorldMap, data: GameData, buildings: BuildingStore) -> void:
	_map = map
	_data = data
	_buildings = buildings
	_size = _map.size()
	_cost_mult = _data.balance("zombie_structure_cost_per_hp", 0.1)
	_distances.resize(_size * _size)
	_next_indices.resize(_size * _size)
	_distances.fill(-1)
	_next_indices.fill(-1)
	_map.changed.connect(_on_map_changed)

func _on_map_changed() -> void:
	_dirty = true


func is_dirty() -> bool:
	return _dirty

func distance(t: Vector2i) -> int:
	if is_dirty():
		rebuild()
	if t.x < 0 or t.x >= _size or t.y < 0 or t.y >= _size:
		return -1
	return _distances[t.y * _size + t.x]

func next_tile(t: Vector2i) -> Vector2i:
	if is_dirty():
		rebuild()
	if t.x < 0 or t.x >= _size or t.y < 0 or t.y >= _size:
		return Vector2i(-1, -1)
	var idx: int = _next_indices[t.y * _size + t.x]
	if idx < 0:
		return Vector2i(-1, -1)
	return Vector2i(idx % _size, idx / _size)

func _push_heap(dists: PackedInt32Array, indices: PackedInt32Array, dist: int, idx: int) -> void:
	var curr: int = dists.size()
	dists.append(dist)
	indices.append(idx)
	while curr > 0:
		var parent: int = (curr - 1) >> 1
		if dists[parent] <= dists[curr]:
			break
		var t_d := dists[parent]
		dists[parent] = dists[curr]
		dists[curr] = t_d
		var t_i := indices[parent]
		indices[parent] = indices[curr]
		indices[curr] = t_i
		curr = parent

func _pop_heap(dists: PackedInt32Array, indices: PackedInt32Array) -> int:
	var n: int = dists.size()
	if n == 0:
		return -1
	var result: int = indices[0]
	if n == 1:
		dists.resize(0)
		indices.resize(0)
		return result
	
	n -= 1
	dists[0] = dists[n]
	indices[0] = indices[n]
	dists.resize(n)
	indices.resize(n)
	
	var curr: int = 0
	while true:
		var left: int = (curr << 1) + 1
		var right: int = left + 1
		var smallest: int = curr
		
		if left < n and dists[left] < dists[smallest]:
			smallest = left
		if right < n and dists[right] < dists[smallest]:
			smallest = right
			
		if smallest == curr:
			break
			
		var t_d := dists[curr]
		dists[curr] = dists[smallest]
		dists[smallest] = t_d
		var t_i := indices[curr]
		indices[curr] = indices[smallest]
		indices[smallest] = t_i
		curr = smallest
		
	return result

func rebuild() -> void:
	_distances.fill(-1)
	_next_indices.fill(-1)
	
	var cc_origin := _map.command_center_origin()
	var pq_dist := PackedInt32Array()
	var pq_idx := PackedInt32Array()
	
	# The Dijkstra target is the CC tiles
	for y in range(cc_origin.y, cc_origin.y + 2):
		for x in range(cc_origin.x, cc_origin.x + 2):
			var idx := y * _size + x
			_distances[idx] = 0
			_next_indices[idx] = idx
			_push_heap(pq_dist, pq_idx, 0, idx)
			
	var dx: Array[int] = [0, 1, 0, -1, 1, -1, 1, -1]
	var dy: Array[int] = [-1, 0, 1, 0, -1, -1, 1, 1]
	var cost_base: Array[int] = [10, 10, 10, 10, 14, 14, 14, 14]
	
	# Cache impassable and building costs
	var is_impassable := PackedByteArray()
	is_impassable.resize(_size * _size)
	var building_costs := PackedInt32Array()
	building_costs.resize(_size * _size)
	
	for y in range(_size):
		for x in range(_size):
			var t := Vector2i(x, y)
			var idx: int = y * _size + x
			var occ: int = _map.occupant_at(t)
			if occ == WorldMap.Occupant.TREE or occ == WorldMap.Occupant.SCRAP or occ == WorldMap.Occupant.ROCK:
				is_impassable[idx] = 1
			else:
				is_impassable[idx] = 0
				
			if occ == WorldMap.Occupant.BUILDING:
				var b := _buildings.get_at(t)
				if b != null:
					var b_data := _data.get_building(b.type_id)
					var hp: int = b_data.get("hp", 100)
					building_costs[idx] = roundi(hp * _cost_mult * 10.0)
				else:
					building_costs[idx] = 0
			else:
				building_costs[idx] = 0
	
	while pq_dist.size() > 0:
		var u_dist: int = pq_dist[0]
		var u: int = _pop_heap(pq_dist, pq_idx)
		
		if u_dist > _distances[u]:
			continue
			
		var ux: int = u % _size
		var uy: int = u / _size
		
		# For each neighbor v (the source of the move)
		for i in range(8):
			var nx: int = ux + dx[i]
			var ny: int = uy + dy[i]
			
			if nx < 0 or nx >= _size or ny < 0 or ny >= _size:
				continue
				
			var v: int = ny * _size + nx
			
			if is_impassable[v]:
				continue
				
			if i >= 4:
				# Diagonal move check: orthogonal neighbors must not be impassable
				var ox1: int = nx
				var oy1: int = uy
				var ox2: int = ux
				var oy2: int = ny
				var o1: int = oy1 * _size + ox1
				var o2: int = oy2 * _size + ox2
				if is_impassable[o1] or is_impassable[o2] or building_costs[o1] > 0 or building_costs[o2] > 0:
					continue
					
			var cost: int = cost_base[i] + building_costs[u]
			var new_dist: int = u_dist + cost
			
			var old_dist: int = _distances[v]
			if old_dist == -1 or new_dist < old_dist:
				_distances[v] = new_dist
				_next_indices[v] = u
				_push_heap(pq_dist, pq_idx, new_dist, v)
				
	_dirty = false
	rebuild_count += 1

