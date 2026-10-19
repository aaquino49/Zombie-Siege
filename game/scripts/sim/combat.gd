class_name Combat extends RefCounted

static func nearest_zombie(state: GameState, from: Vector2, range_px: float) -> Zombie:
	var best: Zombie = null
	var best_dist: float = range_px * range_px
	for z: Zombie in state.zombies.all():
		var dist: float = from.distance_squared_to(z.pos)
		if dist <= best_dist and (best == null or dist < best_dist or z.uid < best.uid):
			best = z
			best_dist = dist
	return best

static func try_fire(state: GameState, from: Vector2, range_px: float, damage: int, is_turret: bool, hit_chance: float = 1.0) -> Zombie:
	if state.resources.get_amount("ammo") < 1:
		return null
	var target: Zombie = nearest_zombie(state, from, range_px)
	if target == null:
		return null
	state.resources.take("ammo", 1)
	state.shot_fired.emit(from, target.pos, is_turret)
	if hit_chance >= 1.0 or state.combat_rng.randf() < hit_chance:
		state.damage_zombie(target, damage)
	return target

static func turret_range_px(state: GameState) -> float:
	var stats: Dictionary = state.data.get_building("turret")
	return maxf(Grid.TILE, float(stats["range_tiles"]) * Grid.TILE + Weather.range_delta_px(state))

static func tick_turrets(state: GameState, dt: float) -> void:
	if dt <= 0.0:
		return
	var stats: Dictionary = state.data.get_building("turret")
	var interval: float = float(stats["fire_interval"]) * state.tech.mult("turret_fire_interval")
	for b: Building in state.buildings.all_of_type("turret"):
		if not b.complete:
			continue
		b.fire_timer += dt
		# Carry fractional time; first shot is after one full interval.
		while b.fire_timer + 0.000001 >= interval:
			var target: Zombie = try_fire(state, b.center_world(), turret_range_px(state), int(stats["damage"]), true)
			if target == null:
				b.fire_timer = interval
				break
			b.fire_timer = maxf(0.0, b.fire_timer - interval)
			b.aim = (target.pos - b.center_world()).normalized()
