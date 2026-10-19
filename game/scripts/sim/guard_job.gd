class_name GuardJob extends RefCounted

static func free_tower(state: GameState, s: Survivor) -> Building:
	var best: Building = null
	var best_dist: float = INF
	for b: Building in state.buildings.all_of_type("watchtower"):
		if not b.complete:
			continue
		var held: bool = false
		for other: Survivor in state.survivors.all():
			if other != s and other.job == Survivor.Job.GUARD and other.post_uid == b.uid:
				held = true
		if held:
			continue
		var dist: float = s.pos.distance_squared_to(b.center_world())
		if dist < best_dist or (dist == best_dist and (best == null or b.uid < best.uid)):
			best = b
			best_dist = dist
	return best

static func _reachable_tower(state: GameState, s: Survivor) -> Building:
	var candidates: Array[Building] = []
	for b: Building in state.buildings.all_of_type("watchtower"):
		if not b.complete:
			continue
		var held: bool = false
		for other: Survivor in state.survivors.all():
			if other != s and other.job == Survivor.Job.GUARD and other.post_uid == b.uid:
				held = true
		if held:
			continue
		candidates.append(b)
	candidates.sort_custom(func(a: Building, b: Building) -> bool:
		var da: float = s.pos.distance_squared_to(a.center_world())
		var db: float = s.pos.distance_squared_to(b.center_world())
		if da != db:
			return da < db
		return a.uid < b.uid
	)
	for b: Building in candidates:
		if s.on_tower and s.post_uid == b.uid:
			return b
		if not state.pathfinder.find_path_adjacent(s.tile(), b.origin, b.size).is_empty():
			return b
		if Grid.in_ring(s.tile(), b.origin, b.size) and state.map.is_passable(s.tile()):
			return b
	return null

static func pick_post(state: GameState, s: Survivor) -> void:
	var b: Building = _reachable_tower(state, s)
	if b != null:
		s.post_uid = b.uid
		s.post_building = b
		return
	var ring: Array[Vector2i] = state.cc_ring_tiles()
	for t: Vector2i in ring:
		s.post_tile = t
		var held: bool = false
		for other: Survivor in state.survivors.all():
			if other != s and other.job == Survivor.Job.GUARD and other.post_tile == t:
				held = true
		if not held:
			return

static func leave_post(state: GameState, s: Survivor) -> void:
	var b: Building = s.post_building
	if b == null:
		b = state.buildings.get_by_uid(s.post_uid)
	if s.on_tower and b != null:
		var released: bool = false
		for y: int in range(b.origin.y - 1, b.origin.y + b.size.y + 1):
			for x: int in range(b.origin.x - 1, b.origin.x + b.size.x + 1):
				var t := Vector2i(x, y)
				if not released and Grid.in_ring(t, b.origin, b.size) and state.map.is_passable(t):
					s.pos = Grid.tile_to_world(t)
					released = true
	s.on_tower = false
	s.post_uid = 0
	s.post_tile = Vector2i(-1, -1)
	s.post_building = null
	s.path.clear()
	s.activity = Survivor.Activity.IDLE
	s.job_timer = 0.0
	s.post_check_timer = 0.0
	s.fire_timer = 0.0
	# Handles an entirely blocked former ring without leaving a solid-tile guard.
	state.survivors.evict_from_solid(state.map)

static func tower_range_px(state: GameState, tower_type: String) -> float:
	var range_tiles: float = float(state.data.balance("guard_range_tiles")) + state.tech.bonus("guard_range_tiles")
	var range_px: float = range_tiles * float(state.data.get_building(tower_type)["guard_range_mult"]) * Grid.TILE
	return maxf(Grid.TILE, range_px + Weather.range_delta_px(state))

static func effective_range_px(state: GameState, s: Survivor, tower: Building = null) -> float:
	if s.on_tower and tower != null:
		return tower_range_px(state, tower.type_id)
	var range_px: float = (float(state.data.balance("guard_range_tiles")) + state.tech.bonus("guard_range_tiles")) * Grid.TILE
	return maxf(Grid.TILE, range_px + Weather.range_delta_px(state))

static func tick(state: GameState, s: Survivor, dt: float) -> void:
	var b: Building = state.buildings.get_by_uid(s.post_uid)
	if s.post_uid != 0 and (b == null or not b.complete):
		leave_post(state, s)
		b = null
	if s.post_uid == 0 and s.post_tile != Vector2i(-1, -1):
		s.post_check_timer -= dt
		if s.post_check_timer <= 0.0:
			s.post_check_timer = float(state.data.balance("guard_post_check_interval"))
			if not state.map.is_passable(s.post_tile) or _reachable_tower(state, s) != null:
				leave_post(state, s)
	if s.post_uid == 0 and s.post_tile == Vector2i(-1, -1):
		pick_post(state, s)
		b = state.buildings.get_by_uid(s.post_uid)
	if not s.on_tower:
		if s.is_moving():
			return
		var passable: bool = state.map.is_passable(s.tile()) or state.map.building_at(s.tile()) == "gate"
		if b != null and Grid.in_ring(s.tile(), b.origin, b.size) and passable:
			s.on_tower = true
			s.pos = b.center_world()
			s.path.clear()
			s.activity = Survivor.Activity.GUARDING
		elif b == null and s.post_tile != Vector2i(-1, -1) and s.tile() == s.post_tile:
			s.activity = Survivor.Activity.GUARDING
		else:
			if s.job_timer > 0.0:
				s.job_timer = maxf(0.0, s.job_timer - dt)
				return
			if b != null:
				s.path = state.pathfinder.find_path_adjacent(s.tile(), b.origin, b.size)
			elif s.post_tile != Vector2i(-1, -1):
				s.path = state.pathfinder.find_path(s.tile(), s.post_tile)
			if s.path.is_empty():
				if b != null:
					leave_post(state, s)
					return
				s.activity = Survivor.Activity.IDLE
				s.job_timer = float(state.data.balance("job_retry_interval"))
			else:
				s.target = s.path.back()
				s.activity = Survivor.Activity.WALKING
			return
	if s.activity != Survivor.Activity.GUARDING:
		return
	var interval: float = float(state.data.balance("guard_fire_interval"))
	var range_px: float = effective_range_px(state, s, b)
	s.fire_timer += dt
	while s.fire_timer + 0.000001 >= interval:
		var target: Zombie = Combat.try_fire(state, s.pos, range_px, int(state.data.balance("guard_damage")), false, Morale.hit_chance(state, s))
		if target == null:
			s.fire_timer = interval
			break
		s.fire_timer = maxf(0.0, s.fire_timer - interval)
		s.facing = (target.pos - s.pos).normalized()
