class_name ZombieAI extends RefCounted

static func tick(state: GameState, dt: float) -> void:
	var range_tiles: float = state.data.balance("zombie_survivor_range", 1.5)
	var range_px: float = range_tiles * Grid.TILE
	
	# Cache non-sheltered survivors
	var active_survivors: Array[Survivor] = []
	for s in state.survivors.all():
		if not s.away and not s.sheltered and not s.on_tower:
			active_survivors.append(s)
			
	var map_size: int = state.map.size()
	
	var zs := state.zombies.all()
	var spitter_fallback_cache: Dictionary = {}
	var spitter_cache_ready: bool = false
	for z in zs:
		if z.priority == "defences":
			if not spitter_cache_ready:
				var ranged: Dictionary = state.data.get_zombie(z.type_id).get("ranged", {})
				spitter_fallback_cache = _spitter_fallback_cache(state, int(ranged.get("range_tiles", 0)))
				spitter_cache_ready = true
			_tick_spitter(state, z, dt, spitter_fallback_cache)
			continue
		var target_s: Survivor = null
		var chase_blocked: bool = z.chase_cooldown > 0.0
		if chase_blocked:
			z.chase_cooldown = maxf(0.0, z.chase_cooldown - dt)
		
		# Structure priority takes precedence over nearby exposed survivors.
		if z.priority == "structures":
			var structure: Building = _adjacent_structure(state, z)
			if structure != null:
				z.target_survivor_uid = 0
				if _attack_building(state, z, structure, dt):
					continue

		if z.priority == "survivors" and not chase_blocked:
			var seek_px: float = state.data.balance("runner_seek_tiles", 6.0) * Grid.TILE
			var sought: Survivor = _nearest_survivor(z, active_survivors, seek_px)
			if sought != null and z.pos.distance_squared_to(sought.pos) > range_px * range_px:
				if _chase_progress(state, z, sought, dt):
					var step: Vector2i = _survivor_step(state, z, sought)
					if step != Vector2i(-1, -1):
						z.target_survivor_uid = 0
						z.target_building_uid = 0
						_move_toward(z, Grid.tile_to_world(step), dt)
						continue
			else:
				z.reset_chase()

		# 1. Survivor in range
		var best_dist_sq: float = range_px * range_px
		for s in active_survivors:
			var dist_sq: float = z.pos.distance_squared_to(s.pos)
			if dist_sq <= range_px * range_px:
				if target_s == null or dist_sq < best_dist_sq or (dist_sq == best_dist_sq and s.uid < target_s.uid):
					target_s = s
					best_dist_sq = dist_sq
		
		var tile: Vector2i = z.tile()
		
		if target_s != null:
			if z.target_survivor_uid != target_s.uid:
				z.target_survivor_uid = target_s.uid
				z.target_building_uid = 0
				z.attack_timer = 0.0
			z.attack_timer += dt
			_face(z, target_s.pos)
			if z.attack_timer >= z.attack_interval:
				z.attack_timer -= z.attack_interval
				state.damage_survivor(target_s, z.damage)
			if state.survivors.get_by_uid(target_s.uid) != null:
				continue
			
		z.target_survivor_uid = 0
		
		# 2. Movement
		var b_here: Building = state.buildings.get_at(tile)
		if b_here != null:
			if z.target_building_uid != b_here.uid:
				z.target_building_uid = b_here.uid
				z.attack_timer = 0.0
			z.attack_timer += dt
			_face(z, b_here.center_world())
			if z.attack_timer >= z.attack_interval:
				z.attack_timer -= z.attack_interval
				state.damage_building(b_here, z.damage)
			if state.buildings.get_by_uid(b_here.uid) != null:
				continue

		var next: Vector2i = state.flow.next_tile(tile)
		
		# Out of bounds
		if tile.x < 0 or tile.x >= map_size or tile.y < 0 or tile.y >= map_size:
			var target_tile_x: int = clampi(tile.x, 0, map_size - 1)
			var target_tile_y: int = clampi(tile.y, 0, map_size - 1)
			var target_pos: Vector2 = Grid.tile_to_world(Vector2i(target_tile_x, target_tile_y))
			_move_toward(z, target_pos, dt)
			continue
			
		# Unreachable pocket
		if next == Vector2i(-1, -1):
			var cc_origin := state.map.command_center_origin()
			var cc_center := Vector2(float((cc_origin.x + 1) * Grid.TILE), float((cc_origin.y + 1) * Grid.TILE))
			var move_vec := cc_center - z.pos
			if move_vec.length() > 0.001:
				var move_dist: float = z.speed * dt
				var target_pos: Vector2 = z.pos + move_vec.normalized() * move_dist
				var target_tile: Vector2i = Grid.world_to_tile(target_pos)
				var b_target: Building = state.buildings.get_at(target_tile)
				if b_target != null:
					if z.target_building_uid != b_target.uid:
						z.target_building_uid = b_target.uid
						z.attack_timer = 0.0
					z.attack_timer += dt
					_face(z, b_target.center_world())
					if z.attack_timer >= z.attack_interval:
						z.attack_timer -= z.attack_interval
						state.damage_building(b_target, z.damage)
					if state.buildings.get_by_uid(b_target.uid) != null:
						continue
				z.target_building_uid = 0
				_move_toward(z, cc_center, dt, false)
			continue
			
		# Building tile on path
		var b_target: Building = state.buildings.get_at(next)
		if b_target != null:
			if z.target_building_uid != b_target.uid:
				z.target_building_uid = b_target.uid
				z.attack_timer = 0.0
			z.attack_timer += dt
			_face(z, b_target.center_world())
			if z.attack_timer >= z.attack_interval:
				z.attack_timer -= z.attack_interval
				state.damage_building(b_target, z.damage)
			if state.buildings.get_by_uid(b_target.uid) != null:
				continue
		
		# The CC is handled by the building check above.
		if next == tile:
			continue
			
		z.target_building_uid = 0
		
		# Move to next tile center, retaining the existing flow distance carry-over.
		var remaining: float = _move_toward(z, Grid.tile_to_world(next), dt)
		if remaining > 0.0:
			var next2: Vector2i = state.flow.next_tile(next)
			if next2 != Vector2i(-1, -1) and next2 != next:
				if state.buildings.get_at(next2) == null:
					var move_vec: Vector2 = Grid.tile_to_world(next2) - z.pos
					if move_vec.length() > 0.001:
						z.pos += move_vec.normalized() * remaining
						z.facing = move_vec.normalized()

# Chase progress is tracked even when the greedy step falls back to flow.
static func _chase_progress(state: GameState, z: Zombie, target: Survivor, dt: float) -> bool:
	if z.chase_survivor_uid != target.uid:
		z.reset_chase()
		z.chase_survivor_uid = target.uid
	var dist: float = z.pos.distance_to(target.pos)
	if dist <= z.chase_best_dist - Grid.TILE * 0.25:
		z.chase_best_dist = dist
		z.chase_stall = 0.0
	else:
		z.chase_stall += dt
	if z.chase_stall >= float(state.data.balance("runner_chase_stall_time", 2.0)):
		z.chase_cooldown = float(state.data.balance("runner_chase_cooldown", 6.0))
		z.reset_chase()
		return false
	return true

# Returns unused movement distance for the flow field's carry-over step.
static func _move_toward(z: Zombie, target_pos: Vector2, dt: float, clamp_to_target: bool = true) -> float:
	var move_vec: Vector2 = target_pos - z.pos
	var dist: float = move_vec.length()
	if dist <= 0.001:
		return 0.0
	var move_dist: float = z.speed * dt
	if clamp_to_target and move_dist >= dist:
		z.pos = target_pos
	else:
		z.pos += move_vec.normalized() * move_dist
	z.facing = move_vec.normalized()
	return maxf(0.0, move_dist - dist)

static func _adjacent_structure(state: GameState, z: Zombie) -> Building:
	var best: Building = null
	for offset: Vector2i in [Vector2i.ZERO, Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var b: Building = state.buildings.get_at(z.tile() + offset)
		if b == null or b.type_id == "command_center":
			continue
		if b.uid == z.target_building_uid:
			return b
		if best == null or b.uid < best.uid:
			best = b
	return best

static func _attack_building(state: GameState, z: Zombie, b: Building, dt: float) -> bool:
	if z.target_building_uid != b.uid:
		z.target_building_uid = b.uid
		z.attack_timer = 0.0
	z.attack_timer += dt
	_face(z, b.center_world())
	if z.attack_timer >= z.attack_interval:
		z.attack_timer -= z.attack_interval
		state.damage_building(b, z.damage)
	return state.buildings.get_by_uid(b.uid) != null

static func _nearest_survivor(z: Zombie, survivors: Array[Survivor], seek_px: float) -> Survivor:
	var best: Survivor = null
	var best_dist: float = seek_px * seek_px
	for s: Survivor in survivors:
		var dist: float = z.pos.distance_squared_to(s.pos)
		if dist <= best_dist and (best == null or dist < best_dist or s.uid < best.uid):
			best = s
			best_dist = dist
	return best

static func _open_step(state: GameState, tile: Vector2i) -> bool:
	return state.map.is_passable(tile) and state.buildings.get_at(tile) == null

static func _survivor_step(state: GameState, z: Zombie, survivor: Survivor) -> Vector2i:
	var tile: Vector2i = z.tile()
	var best: Vector2i = Vector2i(-1, -1)
	# A step must make progress; otherwise a blocked chase uses the flow field.
	var best_dist: float = z.pos.distance_squared_to(survivor.pos)
	for y: int in range(-1, 2):
		for x: int in range(-1, 2):
			if x == 0 and y == 0:
				continue
			var candidate: Vector2i = tile + Vector2i(x, y)
			if not _open_step(state, candidate):
				continue
			if x != 0 and y != 0:
				if not _open_step(state, tile + Vector2i(x, 0)) or not _open_step(state, tile + Vector2i(0, y)):
					continue
			var dist: float = Grid.tile_to_world(candidate).distance_squared_to(survivor.pos)
			if dist < best_dist:
				best_dist = dist
				best = candidate
	return best

static func _target_tile(z: Zombie, b: Building) -> Vector2i:
	return Vector2i(clampi(z.tile().x, b.origin.x, b.origin.x + b.size.x - 1),
		clampi(z.tile().y, b.origin.y, b.origin.y + b.size.y - 1))

static func _tile_range(from: Vector2i, to: Vector2i) -> int:
	return maxi(absi(from.x - to.x), absi(from.y - to.y))

static func _spitter_fallback_cache(state: GameState, acid_radius: int) -> Dictionary:
	var cache: Dictionary = {"has_defences": false, "covered_tiles": {}}
	var defences: Array[Building] = []
	for b: Building in state.buildings.all():
		if b.complete and b.hp > 0 and b.type_id in ["turret", "watchtower"]:
			defences.append(b)
	if defences.is_empty():
		return cache
	cache["has_defences"] = true
	var covered_tiles: Dictionary = {}
	var centers: Array[Building] = state.buildings.all_of_type("command_center")
	if centers.is_empty():
		cache["covered_tiles"] = covered_tiles
		return cache
	var cc: Building = centers[0]
	var turret_range_px: float = Combat.turret_range_px(state)
	var watchtower_range_px: float = GuardJob.tower_range_px(state, "watchtower")
	# A spitter may trigger its stop check anywhere inside the tile, not only at
	# the center. Require the whole tile footprint to fit inside a defence ring.
	var tile_half_diagonal: float = sqrt(2.0) * Grid.TILE * 0.5
	for y: int in range(cc.origin.y - acid_radius, cc.origin.y + cc.size.y + acid_radius):
		for x: int in range(cc.origin.x - acid_radius, cc.origin.x + cc.size.x + acid_radius):
			var tile := Vector2i(x, y)
			var cc_tile := Vector2i(clampi(x, cc.origin.x, cc.origin.x + cc.size.x - 1),
				clampi(y, cc.origin.y, cc.origin.y + cc.size.y - 1))
			if _tile_range(tile, cc_tile) > acid_radius:
				continue
			var tile_pos: Vector2 = Grid.tile_to_world(tile)
			for defence: Building in defences:
				var range_px: float = turret_range_px if defence.type_id == "turret" else watchtower_range_px
				var safe_range: float = range_px - tile_half_diagonal
				if safe_range >= 0.0 and tile_pos.distance_squared_to(defence.center_world()) <= safe_range * safe_range:
					covered_tiles[tile] = true
					break
	cache["covered_tiles"] = covered_tiles
	return cache

static func _tick_spitter(state: GameState, z: Zombie, dt: float, fallback_cache: Dictionary) -> void:
	z.target_survivor_uid = 0
	var ranged: Dictionary = state.data.get_zombie(z.type_id).get("ranged", {})
	var radius: int = int(ranged.get("range_tiles", 0))
	z.defence_scan_timer -= dt
	if z.defence_scan_timer <= 0.0:
		z.defence_scan_timer = 0.25
		z.defence_uid = 0
		var best_distance: float = INF
		# Bounded tile scan uses the building occupancy index, not per-zombie A*.
		for y: int in range(z.tile().y - radius, z.tile().y + radius + 1):
			for x: int in range(z.tile().x - radius, z.tile().x + radius + 1):
				var b: Building = state.buildings.get_at(Vector2i(x, y))
				if b == null or not b.complete or b.hp <= 0 or b.type_id not in ["turret", "watchtower"]:
					continue
				var distance: float = Grid.tile_to_world(_target_tile(z, b)).distance_squared_to(Grid.tile_to_world(z.tile()))
				if distance < best_distance or (distance == best_distance and b.uid < z.defence_uid):
					best_distance = distance
					z.defence_uid = b.uid
	var target: Building = state.buildings.get_by_uid(z.defence_uid)
	if target != null and (not target.complete or _tile_range(z.tile(), _target_tile(z, target)) > radius):
		target = null
	var next: Vector2i = state.flow.next_tile(z.tile())
	if target == null:
		target = state.buildings.get_at(z.tile())
		if target == null:
			target = state.buildings.get_at(next)
		if target == null:
			var centers: Array[Building] = state.buildings.all_of_type("command_center")
			if not centers.is_empty():
				target = centers[0]
	if target != null and target.hp > 0:
		var tile: Vector2i = _target_tile(z, target)
		var distance: int = _tile_range(z.tile(), tile)
		if distance <= radius:
			if target.type_id == "command_center" and bool(fallback_cache.get("has_defences", false)) \
					and distance > 1 and not (fallback_cache.get("covered_tiles", {}) as Dictionary).has(z.tile()):
				# Keep following the shared flow field until this fallback firing tile is defended.
				pass
			else:
				if z.target_building_uid != target.uid:
					z.spit_timer = 0.0
					z.attack_timer = 0.0
				z.target_building_uid = target.uid
				_face(z, Grid.tile_to_world(tile))
				if distance <= 1:
					_attack_building(state, z, target, dt)
				else:
					z.spit_timer += dt
					var interval: float = float(ranged["interval"])
					while z.spit_timer + 0.000001 >= interval:
						z.spit_timer = maxf(0.0, z.spit_timer - interval)
						state.projectiles.launch(state, z.pos, target, tile, ranged)
				return
	z.target_building_uid = 0
	z.spit_timer = 0.0
	if not Grid.in_bounds(z.tile(), state.map.size()):
		var edge := Vector2i(clampi(z.tile().x, 0, state.map.size() - 1), clampi(z.tile().y, 0, state.map.size() - 1))
		_move_toward(z, Grid.tile_to_world(edge), dt)
	elif next == Vector2i(-1, -1):
		if target != null:
			_move_toward(z, target.center_world(), dt, false)
	elif next != z.tile():
		var remaining: float = _move_toward(z, Grid.tile_to_world(next), dt)
		if remaining > 0.0:
			var next2: Vector2i = state.flow.next_tile(next)
			if next2 != Vector2i(-1, -1) and next2 != next and state.buildings.get_at(next2) == null:
				var movement: Vector2 = Grid.tile_to_world(next2) - z.pos
				if movement.length() > 0.001:
					z.pos += movement.normalized() * remaining
					z.facing = movement.normalized()

static func _face(z: Zombie, target_pos: Vector2) -> void:
	var move_vec: Vector2 = target_pos - z.pos
	if move_vec.length() > 0.001:
		z.facing = move_vec.normalized()
