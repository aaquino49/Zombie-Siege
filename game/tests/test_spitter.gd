extends TestCase
## T-164: ranged combat, transient projectiles and unchanged early-night RNG.

class LegacySpawner extends WaveSpawner:
	func plan_night(n: int) -> void:
		_schedule.clear()
		var state: GameState = _state_ref.get_ref() as GameState
		if state == null:
			return
		var wave: Dictionary = state.data.wave_for_night(n)
		var counts: Dictionary = wave.duplicate()
		for type_id: String in ["walker", "runner", "brute"]:
			var base: int = int(wave[type_id])
			var scaled: int = roundi(base * float(state.difficulty_multipliers.get("wave_size_mult", 1.0)))
			counts[type_id] = maxi(1, scaled) if base >= 1 else scaled
		var sides: Array[int] = [0, 1, 2, 3]
		_shuffle(sides)
		var side_count: int = int(counts["sides"])
		if side_count == 0:
			return
		var types: Array[String] = []
		for type_id: String in ["walker", "runner", "brute"]:
			var scaled_count: int = int(counts[type_id])
			for i: int in range(scaled_count):
				types.append(type_id)
		_shuffle(types)
		var window: float = float(state.data.balance("night_min_length")) * float(state.data.wave_value("spawn_window_fraction"))
		for i: int in range(types.size()):
			_schedule.append({"time": window * i / types.size(), "type": types[i], "side": sides[i % side_count]})
	

var state: GameState
var turret: Building
var wall: Building
var z: Zombie
var fired: Array[Vector2] = []
var hits: Array[Vector2] = []

func before_each() -> void:
	state = GameState.new(GameData.load_default(), 1337)
	state.waves.enabled = false
	var origin: Vector2i = state.map.command_center_origin() + Vector2i(4, 0)
	for y: int in range(origin.y - 5, origin.y + 6):
		for x: int in range(origin.x - 1, origin.x + 7):
			var tile := Vector2i(x, y)
			if state.map.occupant_at(tile) != WorldMap.Occupant.BUILDING:
				state.map.vacate(tile, Vector2i.ONE)
	turret = state.buildings.add("turret", origin, true)
	wall = state.buildings.add("wooden_wall", origin + Vector2i.RIGHT, true)
	z = state.spawn_zombie("spitter", Grid.tile_to_world(origin + Vector2i(2, 0)))
	fired.clear()
	hits.clear()
	state.spit_fired.connect(func(_from: Vector2, to: Vector2) -> void: fired.append(to))
	state.acid_hit.connect(func(pos: Vector2) -> void: hits.append(pos))

func _combat(seconds: float) -> void:
	for _i: int in range(roundi(seconds * 60.0)):
		state.projectiles.tick(state, 1.0 / 60.0)
		ZombieAI.tick(state, 1.0 / 60.0)

func _acid() -> int:
	return int(state.data.get_zombie("spitter")["ranged"]["damage"])

func after_each() -> void:
	state = null
	turret = null
	wall = null
	z = null

func test_wave_counts_and_forecast_on_all_difficulties() -> void:
	for night: int in [7, 8, 13, 19, 20]:
		var expected: int = {7: 0, 8: 1, 13: 2, 19: 4, 20: 15}[night]
		assert_eq(state.data.wave_for_night(night)["spitter"], expected)
		for difficulty: String in ["easy", "normal", "hard"]:
			var other := GameState.new(state.data, 1337, difficulty)
			var forecast: Dictionary = WaveSpawner.forecast(other.data, night, other.difficulty_multipliers)
			var scaled: int = roundi(expected * float(other.difficulty_multipliers["wave_size_mult"]))
			assert_eq(forecast["spitter"], maxi(1, scaled) if expected > 0 else 0)
			other.waves.plan_night(night)
			var count: int = 0
			for entry: Dictionary in other.waves._schedule:
				if entry["type"] == "spitter": count += 1
			assert_eq(count, forecast["spitter"])
	assert_eq(WaveSpawner.forecast(state.data, 19, state.data.difficulty_config("hard"))["spitter"], 4)

func test_old_data_and_optional_ranged_validation() -> void:
	var zombies: Dictionary = state.data._zombies.duplicate(true)
	zombies.erase("spitter")
	assert_true(state.data._validate_zombies(zombies), "Only the original three ids are required")
	for key: String in ["range_tiles", "damage", "interval", "projectile_speed"]:
		var invalid: Dictionary = state.data._zombies.duplicate(true)
		invalid["spitter"]["ranged"].erase(key)
		assert_false(state.data._validate_zombies(invalid))
		invalid = state.data._zombies.duplicate(true)
		invalid["spitter"]["ranged"][key] = 0
		assert_false(state.data._validate_zombies(invalid))
	state.data._waves.erase("spitters_mult")
	assert_eq(state.data.wave_for_night(20)["spitter"], 0)
	assert_true(state.data._validate_waves(state.data._waves), "Optional spitter keys preserve old data")
	state.data._waves["spitters_div"] = 0
	assert_false(state.data._validate_waves(state.data._waves))
	state.data._waves.clear()
	assert_eq(state.data.wave_for_night(20)["spitter"], 0)

func test_acid_bypasses_wall_at_two_tiles() -> void:
	var start: Vector2 = z.pos
	_combat(1.9)
	assert_eq(fired.size(), 0, "Full two-second windup")
	_combat(0.2)
	assert_eq(fired.size(), 1)
	assert_eq(turret.hp, turret.max_hp, "Damage waits for projectile arrival")
	assert_eq(state.projectiles.globs.size(), 1)
	_combat(1.2)
	assert_eq(turret.hp, turret.max_hp - _acid())
	assert_eq(wall.hp, wall.max_hp)
	assert_eq(z.pos, start)
	assert_eq(z.facing, Vector2.LEFT)
	assert_eq(hits, [turret.center_world()])

func test_diagonal_chebyshev_range_and_incomplete_defence() -> void:
	z.pos = Grid.tile_to_world(turret.origin + Vector2i(2, 2))
	_combat(2.1)
	assert_eq(z.target_building_uid, turret.uid)
	assert_eq(fired.size(), 1, "Diagonal two tiles is inside range")
	turret.complete = false
	_combat(0.3)
	assert_ne(z.target_building_uid, turret.uid)

func test_glob_fizzles_if_target_dies_or_is_replaced() -> void:
	_combat(2.1)
	state.damage_building(turret, 9999)
	var replacement: Building = state.buildings.add("turret", turret.origin, true)
	state.projectiles.tick(state, 2.0)
	assert_eq(replacement.hp, replacement.max_hp)
	assert_true(state.projectiles.globs.is_empty())
	assert_eq(hits.size(), 0)

func test_watchtower_and_posted_guard_take_same_acid_damage() -> void:
	state.buildings.remove(turret.uid)
	var tower: Building = state.buildings.add("watchtower", turret.origin, true)
	tower.hp = _acid()
	var guard: Survivor = state.survivors.all()[0]
	guard.job = Survivor.Job.GUARD
	guard.post_uid = tower.uid
	guard.on_tower = true
	guard.pos = tower.center_world()
	var hp: int = guard.hp
	_combat(3.3)
	assert_eq(guard.hp, hp - _acid(), "Posted guard is hit even when tower is destroyed")
	assert_eq(state.buildings.get_by_uid(tower.uid), null)
	assert_eq(hits.size(), 1)

func test_ground_survivors_are_never_targeted() -> void:
	var survivor: Survivor = state.survivors.all()[0]
	survivor.pos = z.pos
	survivor.sheltered = false
	survivor.on_tower = false
	var hp: int = survivor.hp
	_combat(5.0)
	assert_eq(survivor.hp, hp)
	assert_eq(z.target_survivor_uid, 0)

func test_nearest_completed_defence_wins_and_retargets_after_destruction() -> void:
	# Two-tile range (T-207): offset the spitter so the tower is strictly nearer than the turret.
	z.pos = Grid.tile_to_world(turret.origin + Vector2i(2, 1))
	var tower: Building = state.buildings.add("watchtower", turret.origin + Vector2i(2, 3), true)
	var unfinished: Building = state.buildings.add("turret", z.tile() + Vector2i.UP, false)
	_combat(3.2)
	assert_eq(z.target_building_uid, tower.uid, "Nearest completed defence takes priority over the wall and unfinished turret")
	assert_eq(tower.hp, tower.max_hp - _acid())
	assert_eq(turret.hp, turret.max_hp)
	assert_eq(wall.hp, wall.max_hp)
	assert_eq(unfinished.hp, unfinished.max_hp)
	state.damage_building(tower, 9999)
	_combat(0.3)
	assert_eq(z.target_building_uid, turret.uid, "Cached defence targeting recovers when the selected tower is destroyed")

func test_adjacent_spitter_melees_for_four_damage() -> void:
	state.buildings.remove(wall.uid)
	z.pos = Grid.tile_to_world(turret.origin + Vector2i.RIGHT)
	_combat(2.1)
	assert_eq(turret.hp, turret.max_hp - 4)
	assert_eq(fired.size(), 0)

func test_blocking_structure_and_cc_fallback() -> void:
	state.buildings.remove(turret.uid)
	z.pos = wall.center_world()
	_combat(2.1)
	assert_eq(wall.hp, wall.max_hp - 4)
	state.buildings.remove(wall.uid)
	var cc: Building = state.buildings.all_of_type("command_center")[0]
	z.pos = Grid.tile_to_world(cc.origin + Vector2i(-2, 0))
	var fallback_pos: Vector2 = z.pos
	_combat(3.3)
	assert_eq(cc.hp, cc.max_hp - _acid())
	assert_eq(z.pos, fallback_pos, "Without completed defences, the CC fallback stop is unchanged")

func test_cc_fallback_walks_off_uncovered_tile_and_only_fires_inside_ring() -> void:
	state.buildings.remove(turret.uid)
	state.buildings.remove(wall.uid)
	var cc: Building = state.buildings.all_of_type("command_center")[0]
	var cover_turret: Building = state.buildings.add("turret", cc.origin + Vector2i(-6, -3), true)
	z.pos = Grid.tile_to_world(cc.origin + Vector2i(-2, 3))
	var cache: Dictionary = ZombieAI._spitter_fallback_cache(state, 2)
	var covered_tiles: Dictionary = cache["covered_tiles"]
	assert_true(bool(cache["has_defences"]))
	assert_false(covered_tiles.has(z.tile()), "The first fallback tile is outside the turret ring")
	var protected_stop: Vector2i = cc.origin + Vector2i(-2, 0)
	assert_true(covered_tiles.has(protected_stop), "A later CC fallback tile is inside the turret ring")
	var fallback_start: Vector2 = z.pos
	var reached_protected_stop: bool = false
	var reached_melee: bool = false
	for _i: int in range(1800):
		state.projectiles.tick(state, 1.0 / 60.0)
		ZombieAI.tick(state, 1.0 / 60.0)
		if z.target_building_uid == cc.uid:
			if ZombieAI._tile_range(z.tile(), ZombieAI._target_tile(z, cc)) <= 1:
				reached_melee = true
				break
			assert_true(covered_tiles.has(z.tile()), "The spitter only stops to spit from inside a defence ring")
			var reach: float = Combat.turret_range_px(state)
			assert_true(z.pos.distance_squared_to(cover_turret.center_world()) <= reach * reach,
				"The actual ranged stop position is inside turret combat reach")
			reached_protected_stop = true
			break
	assert_ne(z.pos, fallback_start, "The spitter keeps following the shared flow field from the uncovered fallback tile")
	assert_true(reached_protected_stop or reached_melee,
		"The spitter reaches defended firing range or melee before stopping")
	assert_true(fired.is_empty(), "The spitter does not launch acid from an uncovered CC fallback tile")
	z.pos = Grid.tile_to_world(protected_stop)
	z.target_building_uid = 0
	_combat(2.1)
	assert_eq(z.tile(), protected_stop)
	assert_eq(z.target_building_uid, cc.uid)
	assert_false(fired.is_empty(), "A covered CC fallback tile remains a valid firing position")
	assert_eq(state.buildings.get_by_uid(cover_turret.uid), cover_turret)

func test_cc_fallback_stopping_position_is_in_actual_combat_reach() -> void:
	state.buildings.remove(turret.uid)
	state.buildings.remove(wall.uid)
	var cc: Building = state.buildings.all_of_type("command_center")[0]
	for y: int in range(cc.origin.y - 4, cc.origin.y + 7):
		for x: int in range(cc.origin.x - 5, cc.origin.x + 7):
			var tile := Vector2i(x, y)
			if state.map.occupant_at(tile) != WorldMap.Occupant.BUILDING:
				state.map.vacate(tile, Vector2i.ONE)
	var defence: Building = state.buildings.add("turret", cc.origin + Vector2i(4, 3), true)
	z.pos = Grid.tile_to_world(cc.origin + Vector2i(-3, 4))
	var stopped: bool = false
	for _i: int in range(1200):
		ZombieAI.tick(state, 1.0 / 60.0)
		if z.target_building_uid == cc.uid:
			stopped = true
			break
	assert_true(stopped, "Spitter reaches a CC fallback attack position")
	var melee_distance: int = ZombieAI._tile_range(z.tile(), ZombieAI._target_tile(z, cc))
	if melee_distance <= 1:
		assert_eq(melee_distance, 1, "If no defended ranged tile lies on the route, the spitter uses the melee escape")
	else:
		var reach: float = Combat.turret_range_px(state)
		assert_true(z.pos.distance_squared_to(defence.center_world()) <= reach * reach,
			"Actual ranged stop position must be shootable: distance %.3f px, reach %.3f px, tile %s" %
			[z.pos.distance_to(defence.center_world()), reach, str(z.tile())])
		assert_eq(Combat.nearest_zombie(state, defence.center_world(), reach), z,
			"Combat must be able to acquire the fallback spitter")
		for _i: int in range(240):
			state.projectiles.tick(state, 1.0 / 60.0)
			ZombieAI.tick(state, 1.0 / 60.0)
			Combat.tick_turrets(state, 1.0 / 60.0)
		assert_eq(cc.hp, cc.max_hp, "The stocked turret should kill this spitter before it launches acid")
	assert_true(fired.is_empty(), "An uncovered fallback position never launches acid")

func _fallback_watchtower() -> Building:
	state.buildings.remove(turret.uid)
	state.buildings.remove(wall.uid)
	var cc: Building = state.buildings.all_of_type("command_center")[0]
	return state.buildings.add("watchtower", cc.origin + Vector2i(-6, -3), true)

func _fallback_weather(fog: bool) -> void:
	state.clock.phase = GameClock.Phase.NIGHT
	state.clock.day = int(state.data.weather_config()["fog"]["first_night"])
	state.data.weather_config()["fog"]["chance"] = 1.0 if fog else 0.0
	assert_eq(state.weather_night(), "fog" if fog else "clear")

func test_watchtower_cache_matches_spotters_guard_range_clear_and_fog() -> void:
	var tower: Building = _fallback_watchtower()
	var cc: Building = state.buildings.all_of_type("command_center")[0]
	var guard: Survivor = state.survivors.all()[0]
	guard.job = Survivor.Job.GUARD
	guard.post_uid = tower.uid
	guard.on_tower = true
	guard.pos = tower.center_world()
	state.tech.done.append("spotters")
	for fog: bool in [false, true]:
		_fallback_weather(fog)
		var reach: float = GuardJob.effective_range_px(state, guard, tower)
		assert_almost_eq(GuardJob.tower_range_px(state, "watchtower"), reach)
		var expected_reach: float = (float(state.data.balance("guard_range_tiles")) +
			state.tech.bonus("guard_range_tiles")) * float(state.data.get_building("watchtower")["guard_range_mult"]) * Grid.TILE
		assert_almost_eq(reach, expected_reach + Weather.range_delta_px(state))
		var expected_tiles: Dictionary = {}
		var safe_reach: float = reach - sqrt(2.0) * Grid.TILE * 0.5
		for y: int in range(cc.origin.y - 2, cc.origin.y + cc.size.y + 2):
			for x: int in range(cc.origin.x - 2, cc.origin.x + cc.size.x + 2):
				var tile := Vector2i(x, y)
				if Grid.tile_to_world(tile).distance_to(guard.pos) <= safe_reach:
					expected_tiles[tile] = true
		assert_false(expected_tiles.is_empty(), "Fixture includes defended fallback tiles")
		var rng_before: int = state.rng.state
		var combat_rng_before: int = state.combat_rng.state
		var cache: Dictionary = ZombieAI._spitter_fallback_cache(state, 2)
		assert_eq(cache["covered_tiles"], expected_tiles, "Cache uses the on-tower guard radius, fog=%s" % fog)
		ZombieAI.tick(state, 1.0 / 60.0)
		assert_eq(state.rng.state, rng_before, "Coverage and spitter tick do not draw simulation RNG")
		assert_eq(state.combat_rng.state, combat_rng_before, "Coverage and spitter tick do not draw combat RNG")

func test_watchtower_fallback_tile_outside_old_ring_requires_spotters() -> void:
	var tower: Building = _fallback_watchtower()
	var cc: Building = state.buildings.all_of_type("command_center")[0]
	for fog: bool in [false, true]:
		_fallback_weather(fog)
		state.tech.done.clear()
		var tile: Vector2i = cc.origin + (Vector2i(-2, 3) if fog else Vector2i(-1, 3))
		var old_reach: float = (float(state.data.balance("guard_range_tiles")) *
			float(state.data.get_building("watchtower")["guard_range_mult"]) * Grid.TILE + Weather.range_delta_px(state))
		var distance: float = Grid.tile_to_world(tile).distance_to(tower.center_world())
		assert_gt(distance, old_reach, "Tile center lies outside the old ring")
		var old_cache: Dictionary = ZombieAI._spitter_fallback_cache(state, 2)
		assert_false(old_cache["covered_tiles"].has(tile), "Without Spotters this tile remains uncovered")
		state.tech.done.append("spotters")
		var guard: Survivor = state.survivors.all()[0]
		guard.on_tower = true
		var new_reach: float = GuardJob.effective_range_px(state, guard, tower)
		assert_lt(distance + sqrt(2.0) * Grid.TILE * 0.5, new_reach, "Whole tile fits inside the Spotters ring")
		var new_cache: Dictionary = ZombieAI._spitter_fallback_cache(state, 2)
		assert_true(new_cache["covered_tiles"].has(tile), "Spotters makes the fallback tile covered, fog=%s" % fog)

func test_globs_clear_before_dawn_save() -> void:
	_combat(2.1)
	assert_false(state.projectiles.globs.is_empty())
	state.zombies.remove(z.uid)
	state.clock.phase = GameClock.Phase.NIGHT
	state.clock.elapsed = float(state.data.balance("night_min_length"))
	var snapshots: Array[Dictionary] = []
	var owner_ref: WeakRef = weakref(state)
	state.dawn_processed.connect(func(_report: Dictionary) -> void:
		var owner: GameState = owner_ref.get_ref() as GameState
		assert_true(owner.projectiles.globs.is_empty(), "No acid exists at snapshot time")
		snapshots.append(SaveGame.capture(owner)))
	state.tick(0.1)
	assert_eq(snapshots.size(), 1)
	assert_false(snapshots[0].is_empty())
	assert_false(snapshots[0].has("projectiles"))
	var restored: GameState = SaveGame.restore(state.data, snapshots[0])
	assert_not_null(restored)
	assert_true(restored.projectiles.globs.is_empty())

func _night_logs(legacy: bool, nights: int) -> Array[Dictionary]:
	var game := GameState.new(GameData.load_default(), 1337)
	if legacy:
		game.clock.phase_changed.disconnect(game.waves._on_phase_changed)
		game.waves = LegacySpawner.new(game)
	game.waves.enabled = true
	var logs: Array[Dictionary] = []
	game.dawn_processed.connect(func(report: Dictionary) -> void: logs.append(report.duplicate(true)))
	var memo: Dictionary = {}
	var decide_acc: float = 5.0
	for _i: int in range(60000):
		if game.game_over or game.clock.day > nights: break
		if game.clock.phase == GameClock.Phase.DAY and decide_acc >= 5.0:
			decide_acc = fmod(decide_acc, 5.0)
			BalanceBot._decide(game, memo)
		var before: float = game.time_played
		game.tick(0.25)
		decide_acc += game.time_played - before
	assert_eq(logs.size(), nights, "Bot must reach every compared dawn")
	return logs

func test_seed_1337_nights_one_to_six_match_prechange_spawner() -> void:
	assert_eq(_night_logs(false, 6), _night_logs(true, 6), "All six full dawn/night reports match the original planner")

func test_spitter_night_logs_are_deterministic() -> void:
	assert_eq(_night_logs(false, 9), _night_logs(false, 9))

func test_spitter_pool_uses_own_frames_and_resets_modulation() -> void:
	var layer := ZombieLayer.new()
	layer.bind(state)
	var sprite: AnimatedSprite2D = layer._active_sprites[z.uid]
	assert_eq(sprite.sprite_frames, layer._frames["spitter"])
	assert_eq(sprite.self_modulate, Color.WHITE)
	state.zombies.remove(z.uid)
	var walker: Zombie = state.spawn_zombie("walker", z.pos)
	assert_eq(layer._active_sprites[walker.uid], sprite)
	assert_eq(sprite.self_modulate, Color.WHITE)
	layer.unbind()
	assert_eq(layer.get_child_count(), 0)
	layer.free()

func test_250_spitters_use_shared_flow_and_bounded_scans() -> void:
	for i: int in range(249):
		state.spawn_zombie("spitter", Grid.tile_to_world(turret.origin + Vector2i(2, i % 3 - 1)))
	var rebuilds: int = state.flow.rebuild_count
	var started: int = Time.get_ticks_usec()
	_combat(1.0)
	var ms: float = (Time.get_ticks_usec() - started) / 1000.0
	print("Performance (250 spitters): %.3f ms total" % ms)
	assert_true(ms < 1500.0)
	assert_true(state.flow.rebuild_count - rebuilds <= 1)
	assert_eq(fired.size(), 0)
