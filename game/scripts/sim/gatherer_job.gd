class_name GathererJob extends RefCounted

static func tick(state: GameState, s: Survivor, sim_dt: float) -> void:
	if s.job_timer > 0.0 and s.activity == Survivor.Activity.IDLE:
		s.job_timer -= sim_dt
		return

	var map: WorldMap = state.map
	var capacity: int = int(state.data.balance("carry_capacity", 10))
	var gather_time: float = float(state.data.balance("gather_time_" + s.gather_kind, 1.5)) * state.tech.mult("gather_time")
	var target_occupant: int = WorldMap.Occupant.TREE if s.gather_kind == "wood" else WorldMap.Occupant.SCRAP

	if s.activity == Survivor.Activity.RETURNING and s.is_moving():
		return

	if s.activity == Survivor.Activity.RETURNING and not s.is_moving():
		var cc: Array[Building] = state.buildings.all_of_type("command_center")
		var storage: Array[Building] = state.buildings.all_of_type("storage")
		var candidates: Array[Building] = []
		candidates.append_array(cc)
		candidates.append_array(storage)
		var drop_off: Building = null
		for b: Building in candidates:
			if b.complete and Grid.in_ring(s.tile(), b.origin, b.size):
				drop_off = b
				break
		if drop_off:
			_do_deliver(state, s, drop_off)
			s.activity = Survivor.Activity.IDLE
		else:
			_go_deliver(state, s)
		return

	if s.activity == Survivor.Activity.IDLE or (s.activity == Survivor.Activity.HARVESTING and map.get_node_amount(s.work_tile) <= 0):
		if s.carry_amount >= capacity:
			_go_deliver(state, s)
			return
		
		var st: Vector2i = s.tile()
		
		if map.get_node_amount(s.work_tile) > 0:
			if Grid.in_ring(st, s.work_tile, Vector2i.ONE):
				s.activity = Survivor.Activity.HARVESTING
				s.path.clear()
				return
			
			var p: Array[Vector2i] = state.pathfinder.find_path_adjacent(st, s.work_tile, Vector2i.ONE)
			if not p.is_empty():
				s.path = p
				s.target = p.back()
				s.activity = Survivor.Activity.WALKING
				return
		
		# Need a new node
		var nodes: Array[Vector2i] = map.nodes_of(target_occupant)
		nodes.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return st.distance_squared_to(a) < st.distance_squared_to(b)
		)
		var found := false
		for i in range(mini(5, nodes.size())):
			var t: Vector2i = nodes[i]
			if Grid.in_ring(st, t, Vector2i.ONE):
				s.work_tile = t
				s.activity = Survivor.Activity.HARVESTING
				s.path.clear()
				found = true
				break
			var p: Array[Vector2i] = state.pathfinder.find_path_adjacent(st, t, Vector2i.ONE)
			if not p.is_empty():
				s.work_tile = t
				s.path = p
				s.target = p.back()
				s.activity = Survivor.Activity.WALKING
				found = true
				break
		if not found:
			if s.carry_amount > 0:
				_go_deliver(state, s)
			else:
				s.work_tile = Vector2i(-1, -1)
				s.job_timer = state.data.balance("job_retry_interval", 1.0)
				s.activity = Survivor.Activity.IDLE
			return

	if s.activity == Survivor.Activity.WALKING and not s.is_moving():
		# Arrived at node
		if map.get_node_amount(s.work_tile) > 0 and Grid.in_ring(s.tile(), s.work_tile, Vector2i.ONE):
			s.activity = Survivor.Activity.HARVESTING
		else:
			s.work_tile = Vector2i(-1, -1)
			s.activity = Survivor.Activity.IDLE

	if s.activity == Survivor.Activity.HARVESTING:
		if map.get_node_amount(s.work_tile) <= 0:
			s.activity = Survivor.Activity.IDLE
			return
		
		var mult: float = 1.0
		if s.gather_kind == "wood":
			var yards: Array[Building] = state.buildings.all_of_type("lumber_yard")
			for y: Building in yards:
				if y.complete:
					var y_data: Dictionary = state.data.get_building("lumber_yard")
					var radius: float = float(y_data.get("radius", 6))
					var center: Vector2 = y.center_world() / float(Grid.TILE)
					var node_center: Vector2 = Vector2(s.work_tile) + Vector2(0.5, 0.5)
					if center.distance_to(node_center) <= radius:
						mult = 1.0 + float(y_data.get("chop_bonus", 0.5))
						break
		
		s.work_acc += sim_dt * mult
		while s.work_acc >= gather_time:
			s.work_acc -= gather_time
			var taken: int = map.harvest(s.work_tile, 1)
			if taken > 0:
				s.carry_amount += taken
				s.carry_kind = s.gather_kind
				
			if s.carry_amount >= capacity:
				s.work_acc = 0.0
				_go_deliver(state, s)
				break
			elif map.get_node_amount(s.work_tile) <= 0:
				s.work_acc = 0.0
				s.activity = Survivor.Activity.IDLE
				break

static func _go_deliver(state: GameState, s: Survivor) -> void:
	var st: Vector2i = s.tile()
	var candidates: Array[Building] = []
	candidates.append_array(state.buildings.all_of_type("command_center"))
	candidates.append_array(state.buildings.all_of_type("storage"))
	
	var valid_candidates: Array[Building] = []
	for b: Building in candidates:
		if b.complete:
			valid_candidates.append(b)
			
	valid_candidates.sort_custom(func(a: Building, b: Building) -> bool:
		return st.distance_squared_to(a.origin) < st.distance_squared_to(b.origin)
	)
	
	for b: Building in valid_candidates:
		if Grid.in_ring(st, b.origin, b.size):
			s.path.clear()
			_do_deliver(state, s, b)
			s.activity = Survivor.Activity.IDLE
			return
			
		var p: Array[Vector2i] = state.pathfinder.find_path_adjacent(st, b.origin, b.size)
		if not p.is_empty():
			s.path = p
			s.target = p.back()
			s.activity = Survivor.Activity.RETURNING
			return
			
	s.job_timer = state.data.balance("job_retry_interval", 1.0)
	s.activity = Survivor.Activity.IDLE

static func _do_deliver(state: GameState, s: Survivor, b: Building) -> void:
	if s.carry_amount <= 0:
		return
	var c: String = s.carry_kind
	var a: int = s.carry_amount
	s.carry_amount = 0
	s.carry_kind = ""
	
	var world_pos: Vector2 = b.center_world() if b != null else s.pos
	
	state.resources.add(c, a)
	state.resource_delivered.emit(c, a, world_pos)
