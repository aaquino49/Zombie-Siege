class_name ShelterRules extends RefCounted

static func beds_held(state: GameState, b: Building) -> int:
	var held: int = 0
	for s: Survivor in state.survivors.all():
		if s.shelter_uid == b.uid:
			held += 1
	return held

static func pick_shelter(state: GameState, s: Survivor, exclude: Dictionary = {}) -> Building:
	var best: Building = null
	var cc: Building = null
	var best_dist: float = INF
	for b: Building in state.buildings.all():
		if not b.complete or exclude.has(b.uid):
			continue
		var beds: int = state.buildings.beds_for(b)
		if b.type_id == "command_center":
			cc = b
		if beds <= 0 or beds_held(state, b) >= beds:
			continue
		var dist: float = s.pos.distance_squared_to(b.center_world())
		if dist < best_dist or (dist == best_dist and (best == null or b.uid < best.uid)):
			best = b
			best_dist = dist
	if best != null:
		return best
	if cc != null and not exclude.has(cc.uid):
		return cc
	return null

static func tick(state: GameState, s: Survivor, sim_dt: float) -> void:
	if state.clock.phase == GameClock.Phase.NIGHT:
		if s.shelter_night != state.clock.day:
			s.shelter_night = state.clock.day
			s.job_timer = 0.0
			s.reset_shelter_exclusions()
	else:
		s.shelter_night = 0
		s.reset_shelter_exclusions()

	var b: Building = state.buildings.get_by_uid(s.shelter_uid)
	if s.shelter_uid != 0 and (b == null or not b.complete):
		release(state, s)
		b = null
	if s.sheltered:
		return
	if b == null:
		# Interrupt work even if no complete shelter currently exists.
		s.path.clear()
		s.work_uid = 0
		s.work_acc = 0.0
		s.activity = Survivor.Activity.IDLE
	if s.job_timer > 0.0:
		s.job_timer = maxf(0.0, s.job_timer - sim_dt)
		if s.job_timer > 0.0:
			return
		if s.shelter_uid == 0:
			s.unreachable_shelters.clear()
	if b == null:
		b = _pick_and_path_shelter(state, s)
		if b == null:
			return
	if s.is_moving():
		return
	# Match Pathfinder and SurvivorStore: gates are traversable approaches.
	var approach_passable: bool = state.map.is_passable(s.tile()) or state.map.building_at(s.tile()) == "gate"
	if Grid.in_ring(s.tile(), b.origin, b.size) and approach_passable:
		s.sheltered = true
		s.activity = Survivor.Activity.SHELTERED
		s.path.clear()
		if s.carry_amount > 0:
			state.resources.add(s.carry_kind, s.carry_amount)
			state.resource_delivered.emit(s.carry_kind, s.carry_amount, b.center_world())
			s.carry_amount = 0
			s.carry_kind = ""
		return
	s.path = state.pathfinder.find_path_adjacent(s.tile(), b.origin, b.size)
	if s.path.is_empty():
		s.unreachable_shelters[b.uid] = true
		release(state, s)
		_pick_and_path_shelter(state, s)
	else:
		s.target = s.path.back()
		s.activity = Survivor.Activity.WALKING

static func _pick_and_path_shelter(state: GameState, s: Survivor) -> Building:
	while true:
		var b: Building = pick_shelter(state, s, s.unreachable_shelters)
		if b == null:
			s.activity = Survivor.Activity.IDLE
			s.job_timer = float(state.data.balance("job_retry_interval"))
			if not s.unsheltered_warned:
				s.unsheltered_warned = true
				state.survivor_unsheltered.emit(s)
			return null

		s.shelter_uid = b.uid
		s.shelter_building = b

		var approach_passable: bool = state.map.is_passable(s.tile()) or state.map.building_at(s.tile()) == "gate"
		if Grid.in_ring(s.tile(), b.origin, b.size) and approach_passable:
			s.sheltered = true
			s.activity = Survivor.Activity.SHELTERED
			s.path.clear()
			s.job_timer = 0.0
			if s.carry_amount > 0:
				state.resources.add(s.carry_kind, s.carry_amount)
				state.resource_delivered.emit(s.carry_kind, s.carry_amount, b.center_world())
				s.carry_amount = 0
				s.carry_kind = ""
			return b

		s.path = state.pathfinder.find_path_adjacent(s.tile(), b.origin, b.size)
		if s.path.is_empty():
			s.unreachable_shelters[b.uid] = true
			release(state, s)
		else:
			s.target = s.path.back()
			s.activity = Survivor.Activity.WALKING
			s.job_timer = 0.0
			return b
	return null

static func release(state: GameState, s: Survivor) -> void:
	var b: Building = s.shelter_building
	if b == null:
		b = state.buildings.get_by_uid(s.shelter_uid)
	if s.sheltered and b != null:
		var ring: Array[Vector2i] = []
		if b.type_id == "command_center":
			ring = state.cc_ring_tiles()
		else:
			for y: int in range(b.origin.y - 1, b.origin.y + b.size.y + 1):
				for x: int in range(b.origin.x - 1, b.origin.x + b.size.x + 1):
					var t := Vector2i(x, y)
					if Grid.in_ring(t, b.origin, b.size) and state.map.is_passable(t):
						ring.append(t)
		if not ring.is_empty():
			s.pos = Grid.tile_to_world(ring[0])
	s.sheltered = false
	s.shelter_uid = 0
	s.shelter_building = null
	s.path.clear()
	s.activity = Survivor.Activity.IDLE
	s.job_timer = 0.0
