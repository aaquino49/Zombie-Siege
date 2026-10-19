extends TestCase

func _state(data: GameData = null) -> GameState:
	if data == null:
		data = GameData.load_default()
	var state := GameState.new(data, 1337)
	state.waves.enabled = false
	for s: Survivor in state.survivors.all():
		state.survivors.remove(s.uid)
	for tile: Vector2i in state.map._occupants:
		if state.map.occupant_at(tile) != WorldMap.Occupant.BUILDING:
			state.map._occupants[tile] = WorldMap.Occupant.NONE
	state.map.changed.emit()
	return state

func _survivor(state: GameState, tile: Vector2i) -> Survivor:
	return state.survivors.add("Exposed", "blue", tile)

func test_runner_chases_instead_of_flow() -> void:
	var state := _state()
	var tile := Vector2i(30, 24)
	var s := _survivor(state, tile + Vector2i(4, 0))
	var z := state.spawn_zombie("runner", Grid.tile_to_world(tile))
	var start: Vector2 = z.pos
	assert_lt(state.flow.next_tile(tile).x, tile.x)
	for i: int in range(60):
		ZombieAI.tick(state, 1.0 / 60.0)
	assert_lt(z.pos.distance_to(s.pos), start.distance_to(s.pos))
	assert_gt(z.pos.x, start.x)
	assert_almost_eq(z.pos.distance_to(start), z.speed, 0.01)

func test_blocked_runner_follows_flow_without_corner_cutting() -> void:
	var state := _state()
	var tile := Vector2i(30, 24)
	_survivor(state, tile + Vector2i(4, 0))
	state.buildings.add("wooden_wall", tile + Vector2i.RIGHT, true)
	var z := state.spawn_zombie("runner", Grid.tile_to_world(tile))
	var start: Vector2 = z.pos
	var direction: Vector2 = (Grid.tile_to_world(state.flow.next_tile(tile)) - start).normalized()
	ZombieAI.tick(state, 0.1)
	assert_eq(z.pos, start + direction * z.speed * 0.1)
	assert_lt(z.pos.x, start.x)

func test_runner_ignores_sheltered_tower_and_distant_survivors() -> void:
	for exclusion: String in ["sheltered", "tower", "distant"]:
		var state := _state()
		var tile := Vector2i(30, 24)
		var s := _survivor(state, tile + Vector2i(4 if exclusion != "distant" else 8, 0))
		s.sheltered = exclusion == "sheltered"
		s.on_tower = exclusion == "tower"
		var z := state.spawn_zombie("runner", Grid.tile_to_world(tile))
		var start: Vector2 = z.pos
		var direction: Vector2 = (Grid.tile_to_world(state.flow.next_tile(tile)) - start).normalized()
		ZombieAI.tick(state, 0.1)
		assert_eq(z.pos, start + direction * z.speed * 0.1, exclusion)
		assert_eq(z.target_survivor_uid, 0)

func test_brute_wall_priority_and_walker_survivor_priority() -> void:
	for type_id: String in ["brute", "walker"]:
		var state := _state()
		var tile := Vector2i(30, 24)
		var wall := state.buildings.add("wooden_wall", tile + Vector2i.RIGHT, true)
		var s := _survivor(state, tile + Vector2i.UP)
		var z := state.spawn_zombie(type_id, Grid.tile_to_world(tile))
		ZombieAI.tick(state, z.attack_interval)
		if type_id == "brute":
			assert_eq(wall.hp, wall.max_hp - z.damage)
			assert_eq(s.hp, s.max_hp)
			assert_eq(z.target_building_uid, wall.uid)
		else:
			assert_eq(wall.hp, wall.max_hp)
			assert_eq(s.hp, s.max_hp - z.damage)
			assert_eq(z.target_survivor_uid, s.uid)

func test_brute_retains_target_then_chooses_lowest_uid() -> void:
	var state := _state()
	var tile := Vector2i(30, 24)
	var first := state.buildings.add("wooden_wall", tile + Vector2i.UP, true)
	var second := state.buildings.add("wooden_wall", tile + Vector2i.LEFT, true)
	var third := state.buildings.add("wooden_wall", tile + Vector2i.DOWN, true)
	var z := state.spawn_zombie("brute", Grid.tile_to_world(tile))
	z.target_building_uid = third.uid
	ZombieAI.tick(state, 0.1)
	assert_eq(z.target_building_uid, third.uid)
	state.buildings.remove(third.uid)
	ZombieAI.tick(state, 0.1)
	assert_eq(z.target_building_uid, first.uid)
	state.buildings.remove(first.uid)
	ZombieAI.tick(state, 0.1)
	assert_eq(z.target_building_uid, second.uid)

func test_brute_attacks_building_on_own_tile() -> void:
	var state := _state()
	var tile := Vector2i(30, 24)
	var wall := state.buildings.add("wooden_wall", tile, true)
	var s := _survivor(state, tile + Vector2i.RIGHT)
	var z := state.spawn_zombie("brute", Grid.tile_to_world(tile))
	ZombieAI.tick(state, z.attack_interval)
	assert_eq(wall.hp, wall.max_hp - z.damage)
	assert_eq(s.hp, s.max_hp)

func test_brute_cc_fallback_and_nonadjacent_flow() -> void:
	var state := _state()
	var cc: Building = state.buildings.get_by_uid(1)
	var tile: Vector2i = cc.origin + Vector2i(2, 0)
	var z := state.spawn_zombie("brute", Grid.tile_to_world(tile))
	ZombieAI.tick(state, z.attack_interval)
	assert_eq(z.target_building_uid, cc.uid)
	assert_eq(cc.hp, cc.max_hp - z.damage)
	state.zombies.remove(z.uid)
	tile = Vector2i(30, 24)
	z = state.spawn_zombie("brute", Grid.tile_to_world(tile))
	var start: Vector2 = z.pos
	ZombieAI.tick(state, 0.1)
	assert_lt(z.pos.x, start.x)

func test_runner_uses_existing_survivor_attack_in_range() -> void:
	var state := _state()
	var s := _survivor(state, Vector2i(30, 24))
	var z := state.spawn_zombie("runner", s.pos + Vector2(Grid.TILE, 0))
	var start: Vector2 = z.pos
	ZombieAI.tick(state, z.attack_interval)
	assert_eq(s.hp, s.max_hp - z.damage)
	assert_eq(z.target_survivor_uid, s.uid)
	assert_eq(z.pos, start)

func test_priorities_and_seek_radius_come_from_data() -> void:
	for priority: String in ["command_center", "survivors", "structures"]:
		var data := GameData.load_default()
		data._zombies = data._zombies.duplicate(true)
		data._zombies["walker"]["target_priority"] = priority
		var state := _state(data)
		var tile := Vector2i(30, 24)
		_survivor(state, tile + Vector2i(4, 0))
		var wall := state.buildings.add("wooden_wall", tile + Vector2i.UP, true)
		var z := state.spawn_zombie("walker", Grid.tile_to_world(tile))
		assert_eq(z.priority, priority)
		var start: Vector2 = z.pos
		ZombieAI.tick(state, 0.1)
		match priority:
			"command_center": assert_lt(z.pos.x, start.x)
			"survivors": assert_gt(z.pos.x, start.x)
			"structures": assert_eq(z.target_building_uid, wall.uid)
	var data := GameData.load_default()
	data._balance["runner_seek_tiles"] = 3.0
	var state := _state(data)
	_survivor(state, Vector2i(34, 24))
	var z := state.spawn_zombie("runner", Grid.tile_to_world(Vector2i(30, 24)))
	var start: Vector2 = z.pos
	ZombieAI.tick(state, 0.1)
	assert_lt(z.pos.x, start.x)

func test_missing_priority_defaults_to_command_center() -> void:
	var data := GameData.load_default()
	data._zombies["runner"].erase("target_priority")
	var state := _state(data)
	_survivor(state, Vector2i(34, 24))
	var z := state.spawn_zombie("runner", Grid.tile_to_world(Vector2i(30, 24)))
	assert_eq(z.priority, "command_center")
	var start: Vector2 = z.pos
	ZombieAI.tick(state, 0.1)
	assert_lt(z.pos.x, start.x)

func test_runner_nearest_survivor_ties_use_lowest_uid() -> void:
	var state := _state()
	var tile := Vector2i(30, 24)
	_survivor(state, tile + Vector2i(4, 0))
	_survivor(state, tile - Vector2i(4, 0))
	var z := state.spawn_zombie("runner", Grid.tile_to_world(tile))
	var start: Vector2 = z.pos
	ZombieAI.tick(state, 0.1)
	assert_gt(z.pos.x, start.x)
