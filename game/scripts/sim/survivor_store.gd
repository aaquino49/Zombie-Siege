class_name SurvivorStore extends RefCounted

signal survivor_added(s: Survivor)
signal survivor_removed(s: Survivor)

var _uid_counter: int = 1
var _survivors: Dictionary = {}
var _data: GameData

func _init(data: GameData) -> void:
	_data = data

func add(p_name: String, variant: String, t: Vector2i) -> Survivor:
	var s := Survivor.new()
	s.uid = _uid_counter
	_uid_counter += 1
	s.name = p_name
	s.variant = variant
	s.max_hp = _data.balance("survivor_hp", 50)
	s.hp = s.max_hp
	s.pos = Grid.tile_to_world(t)
	
	_survivors[s.uid] = s
	survivor_added.emit(s)
	return s

func remove(uid: int) -> void:
	if _survivors.has(uid):
		var s: Survivor = _survivors[uid]
		_survivors.erase(uid)
		survivor_removed.emit(s)

func get_by_uid(uid: int) -> Survivor:
	return _survivors.get(uid, null)

func all() -> Array[Survivor]:
	var arr: Array[Survivor] = []
	for uid in _survivors:
		arr.append(_survivors[uid])
	return arr

func count() -> int:
	return _survivors.size()

func next_uid() -> int:
	return _uid_counter

func set_next_uid(v: int) -> void:
	_uid_counter = maxi(1, v)

func restore(s: Survivor) -> Survivor:
	_survivors[s.uid] = s
	_uid_counter = maxi(_uid_counter, s.uid + 1)
	return s

func tick(sim_dt: float, pathfinder: Pathfinder, map: WorldMap) -> void:
	if sim_dt <= 0.0:
		return
	var speed: float = _data.balance("survivor_speed", 96.0)
	var hungry_speed: float = float(_data.balance("food_hungry_speed"))
	var move_dist: float = speed * sim_dt
		
	for uid in _survivors:
		var s: Survivor = _survivors[uid]
		if s.away or s.sheltered or s.on_tower or not s.is_moving():
			continue
			
		var dist_left: float = move_dist * (hungry_speed if s.is_hungry() else 1.0)
		while dist_left > 0.0 and s.path.size() > 0:
			var next_tile := s.path[0]
			var next_solid: bool = not map.is_passable(next_tile)
			if map.building_at(next_tile) == "gate":
				next_solid = false
				
			if next_solid:
				var new_path := pathfinder.find_path(s.tile(), s.target)
				if new_path.is_empty():
					s.path.clear()
					s.pos = Grid.tile_to_world(s.tile())
					break
				s.path = new_path
				next_tile = s.path[0]
				
			var target_pos := Grid.tile_to_world(next_tile)
			var to_target := target_pos - s.pos
			var dist_to_target := to_target.length()
			
			if dist_to_target <= dist_left:
				s.pos = target_pos
				s.path.pop_front()
				if dist_to_target > 0.0001:
					s.facing = to_target.normalized()
				dist_left -= dist_to_target
			else:
				var dir := to_target.normalized()
				s.facing = dir
				s.pos += dir * dist_left
				dist_left = 0.0

func evict_from_solid(map: WorldMap) -> void:
	for uid in _survivors:
		var s: Survivor = _survivors[uid]
		if s.away or s.sheltered or s.on_tower or s.is_moving():
			continue
			
		var current_tile := s.tile()
		var is_solid: bool = not map.is_passable(current_tile)
		if map.building_at(current_tile) == "gate":
			is_solid = false
			
		if not is_solid:
			continue
			
		var queue: Array[Vector2i] = [current_tile]
		var visited: Dictionary = {current_tile: true}
		var found_tile := current_tile
		var found := false
		
		while queue.size() > 0:
			var curr: Vector2i = queue.pop_front()
			
			var curr_solid: bool = not map.is_passable(curr)
			if map.building_at(curr) == "gate":
				curr_solid = false
				
			if not curr_solid:
				found_tile = curr
				found = true
				break
				
			var neighbors: Array[Vector2i] = [
				curr + Vector2i(0, -1),
				curr + Vector2i(-1, 0),
				curr + Vector2i(1, 0),
				curr + Vector2i(0, 1)
			]
			
			for n in neighbors:
				if Grid.in_bounds(n, map.size()) and not visited.has(n):
					visited[n] = true
					queue.append(n)
					
		if found:
			s.pos = Grid.tile_to_world(found_tile)
			s.path.clear()
			s.work_tile = Vector2i(-1, -1)
			s.activity = Survivor.Activity.IDLE
			s.job_timer = 0.0
