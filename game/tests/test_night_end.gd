extends TestCase

var data: GameData
var state: GameState

func before_each() -> void:
	data = GameData.load_default()
	state = GameState.new(data, 1337)
	state.waves.enabled = false

func after_each() -> void:
	state = null
	data = null

# Copy the open-map AI fixture from test_zombie_priorities.gd. Tick AI and
# clock directly so idle targets stay exposed instead of seeking shelter.
func _chase_fixture() -> void:
	for s: Survivor in state.survivors.all():
		state.survivors.remove(s.uid)
	for tile: Vector2i in state.map._occupants:
		if state.map.occupant_at(tile) != WorldMap.Occupant.BUILDING:
			state.map._occupants[tile] = WorldMap.Occupant.NONE
	state.map.changed.emit()
	state.clock.phase = GameClock.Phase.NIGHT

func test_stuck_runner_leaves_wall_row_flip_flop_within_30_seconds() -> void:
	_chase_fixture()
	var walls: Array[Building] = []
	for x: int in range(21, 31):
		walls.append(state.buildings.add("wooden_wall", Vector2i(x, 30), true))
	var s: Survivor = state.survivors.add("Exposed", "blue", Vector2i(27, 27))
	var z: Zombie = state.zombies.add("runner", Grid.tile_to_world(Vector2i(27, 31)))
	var start_dist: int = state.flow.distance(z.tile())
	var visited: Dictionary = {z.tile(): true}
	var escaped: bool = false
	var cooled_down: bool = false
	for i: int in range(120):
		ZombieAI.tick(state, 0.25)
		state.clock.advance(0.25)
		visited[z.tile()] = true
		cooled_down = cooled_down or z.chase_cooldown > 0.0
		# Flow distances use 10 units per orthogonal tile.
		escaped = z.pos.distance_to(s.pos) <= float(data.balance("zombie_survivor_range")) * Grid.TILE
		escaped = escaped or state.flow.distance(z.tile()) <= start_dist - 30
		for wall: Building in walls:
			escaped = escaped or wall.hp < wall.max_hp
		if escaped:
			break
	assert_true(cooled_down, "A stalled chase must trigger its cooldown")
	assert_true(escaped, "Runner attacks or improves flow distance by three tiles within 30 seconds")
	assert_gt(visited.size(), 2, "Runner must leave the two-tile oscillation")
	assert_eq(state.clock.phase, GameClock.Phase.NIGHT)

func test_open_ground_runner_reaches_attack_range() -> void:
	_chase_fixture()
	var s: Survivor = state.survivors.add("Exposed", "blue", Vector2i(34, 24))
	var z: Zombie = state.zombies.add("runner", Grid.tile_to_world(Vector2i(30, 24)))
	var reached: bool = false
	for i: int in range(40):
		ZombieAI.tick(state, 0.25)
		if z.pos.distance_to(s.pos) <= float(data.balance("zombie_survivor_range")) * Grid.TILE:
			reached = true
			break
	assert_true(reached, "Open-ground runner still catches the exposed survivor")
	assert_eq(z.chase_cooldown, 0.0, "Progressing chases must not enter cooldown")
	ZombieAI.tick(state, z.attack_interval)
	assert_lt(s.hp, s.max_hp, "Runner attacks after reaching range")

func test_chase_memory_resets_for_changed_or_missing_target() -> void:
	_chase_fixture()
	var first: Survivor = state.survivors.add("First", "blue", Vector2i(34, 24))
	var z: Zombie = state.zombies.add("runner", Grid.tile_to_world(Vector2i(30, 24)))
	z.speed = 0.0
	ZombieAI.tick(state, 0.25)
	ZombieAI.tick(state, 1.5)
	assert_eq(z.chase_survivor_uid, first.uid)
	assert_almost_eq(z.chase_stall, 1.5)
	state.survivors.remove(first.uid)
	var second: Survivor = state.survivors.add("Second", "blue", Vector2i(33, 24))
	ZombieAI.tick(state, 0.25)
	assert_eq(z.chase_survivor_uid, second.uid)
	assert_eq(z.chase_stall, 0.0)
	assert_eq(z.chase_cooldown, 0.0)
	second.sheltered = true
	ZombieAI.tick(state, 0.25)
	assert_eq(z.chase_survivor_uid, 0)
	assert_eq(z.chase_best_dist, INF)
	assert_eq(z.chase_stall, 0.0)

func test_configured_chase_cooldown_expires_and_seeking_resumes() -> void:
	_chase_fixture()
	data._balance["runner_chase_stall_time"] = 0.5
	data._balance["runner_chase_cooldown"] = 1.0
	state.survivors.add("Exposed", "blue", Vector2i(34, 24))
	var z: Zombie = state.zombies.add("runner", Grid.tile_to_world(Vector2i(30, 24)))
	z.speed = 0.0
	for i: int in range(3):
		ZombieAI.tick(state, 0.25)
	assert_eq(z.chase_cooldown, 1.0)
	assert_eq(z.chase_survivor_uid, 0)
	z.speed = float(data.get_zombie("runner")["speed"])
	for i: int in range(4):
		var before: Vector2 = z.pos
		ZombieAI.tick(state, 0.25)
		assert_lt(z.pos.x, before.x, "Cooldown uses CC flow instead of chasing east")
	assert_eq(z.chase_cooldown, 0.0)
	var before: Vector2 = z.pos
	ZombieAI.tick(state, 0.25)
	assert_gt(z.pos.x, before.x, "Seeking resumes after cooldown expires")

func test_default_clock_night_ends_exactly_at_cap_despite_hostiles() -> void:
	var clock: GameClock = GameClock.new()
	clock.phase = GameClock.Phase.NIGHT
	clock.night_end_check = func() -> bool: return false
	for i: int in range(1199):
		clock.advance(0.25)
		assert_eq(clock.phase, GameClock.Phase.NIGHT, "Night cannot end before its 300-second cap")
	assert_eq(clock.elapsed, 299.75)
	assert_eq(clock.time_left(), 0.0, "Overtime HUD countdown stays nonnegative")
	clock.advance(0.25)
	assert_eq(clock.phase, GameClock.Phase.DAY)
	assert_eq(clock.day, 2)
	assert_eq(clock.elapsed, 0.0)

func test_configured_cap_and_large_tick_preserve_leftover_day_time() -> void:
	data._balance["night_max_length"] = 60.0
	var clock: GameClock = GameClock.new(data)
	clock.phase = GameClock.Phase.NIGHT
	clock.night_end_check = func() -> bool: return false
	clock.advance(59.75)
	assert_eq(clock.phase, GameClock.Phase.NIGHT)
	clock.advance(5.25)
	assert_eq(clock.phase, GameClock.Phase.DAY)
	assert_eq(clock.elapsed, 5.0)
	data._balance["night_max_length"] = 10.0
	clock = GameClock.new(data)
	clock.phase = GameClock.Phase.NIGHT
	clock.night_end_check = func() -> bool: return false
	clock.advance(39.75)
	assert_eq(clock.phase, GameClock.Phase.NIGHT, "The 40-second minimum still applies")
	clock.advance(0.25)
	assert_eq(clock.phase, GameClock.Phase.DAY)

func test_capped_dawn_removes_zombies_pending_spawns_and_views_without_kills() -> void:
	state.clock.phase = GameClock.Phase.NIGHT
	var z: Zombie = state.zombies.add("runner", Grid.tile_to_world(Vector2i(40, 40)))
	z.speed = 0.0
	z.damage = 0
	state.waves.plan_night(20)
	assert_gt(state.waves.pending(), 0)
	state.zombies_killed = 7
	var killed: Array[int] = []
	var removed: Array[int] = []
	var dawn: Array[Dictionary] = []
	state.zombie_killed.connect(func(dead: Zombie) -> void: killed.append(dead.uid))
	state.zombies.zombie_removed.connect(func(fled: Zombie) -> void: removed.append(fled.uid))
	state.dawn_processed.connect(func(report: Dictionary) -> void:
		dawn.append({"hostiles": state.hostiles_remaining(), "fled": report["zombies_fled"]}))
	var layer: ZombieLayer = ZombieLayer.new()
	layer.bind(state)
	for i: int in range(1199):
		state.tick(0.25)
	assert_eq(state.clock.phase, GameClock.Phase.NIGHT)
	assert_eq(state.zombies.count(), 1)
	state.tick(0.25)
	assert_eq(state.clock.phase, GameClock.Phase.DAY)
	assert_eq(state.clock.elapsed, 0.0)
	assert_eq(state.zombies.count(), 0)
	assert_eq(state.waves.pending(), 0)
	assert_eq(state.zombies_killed, 7)
	assert_true(killed.is_empty(), "Retreat emits no zombie_killed signal")
	assert_eq(removed, [z.uid], "Retreat uses the normal store removal signal")
	assert_eq(int(state.last_dawn_report["zombies_fled"]), 1)
	assert_eq(dawn, [{"hostiles": 0, "fled": 1}], "Dawn observers see retreat and cleared schedule")
	assert_false((layer.get_child(0) as AnimatedSprite2D).visible, "Retreat hides the pooled view")
	layer.free()

func test_state_splits_large_tick_at_cap_before_day_jobs_run() -> void:
	state.clock.phase = GameClock.Phase.NIGHT
	state.clock.elapsed = 299.75
	var z: Zombie = state.zombies.add("walker", Grid.tile_to_world(Vector2i(40, 40)))
	z.speed = 0.0
	z.damage = 0
	state.tick(1.0)
	assert_eq(state.clock.phase, GameClock.Phase.DAY)
	assert_almost_eq(state.clock.elapsed, 0.75)
	assert_eq(state.zombies.count(), 0)
	assert_eq(state.zombies_killed, 0)

func test_missing_new_balance_keys_use_code_defaults() -> void:
	data._balance.erase("night_max_length")
	data._balance.erase("runner_chase_stall_time")
	data._balance.erase("runner_chase_cooldown")
	var clock: GameClock = GameClock.new(data)
	clock.phase = GameClock.Phase.NIGHT
	clock.night_end_check = func() -> bool: return false
	clock.advance(300.0)
	assert_eq(clock.phase, GameClock.Phase.DAY)
	_chase_fixture()
	state.survivors.add("Exposed", "blue", Vector2i(34, 24))
	var z: Zombie = state.zombies.add("runner", Grid.tile_to_world(Vector2i(30, 24)))
	z.speed = 0.0
	ZombieAI.tick(state, 0.25)
	for i: int in range(7):
		ZombieAI.tick(state, 0.25)
	assert_eq(z.chase_cooldown, 0.0)
	ZombieAI.tick(state, 0.25)
	assert_eq(z.chase_cooldown, 6.0)
