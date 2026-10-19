extends TestCase

func _state() -> GameState:
	var state := GameState.new(GameData.load_default(), 1337)
	state.waves.enabled = false
	for s: Survivor in state.survivors.all():
		state.survivors.remove(s.uid)
	for tile: Vector2i in state.map._occupants:
		if state.map.occupant_at(tile) != WorldMap.Occupant.BUILDING:
			state.map._occupants[tile] = WorldMap.Occupant.NONE
	state.map.changed.emit()
	return state

func test_runner_diagonal_chase_requires_both_orthogonal_tiles_open() -> void:
	for blocked: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
		var state := _state()
		var tile := Vector2i(30, 24)
		state.survivors.add("Exposed", "blue", tile + Vector2i(4, 4))
		state.buildings.add("wooden_wall", tile + blocked, true)
		var z := state.spawn_zombie("runner", Grid.tile_to_world(tile))
		var start: Vector2 = z.pos
		var safe_direction := Vector2.DOWN if blocked == Vector2i.RIGHT else Vector2.RIGHT
		ZombieAI.tick(state, 0.1)
		assert_eq(z.pos, start + safe_direction * z.speed * 0.1,
			"A chase must take the open orthogonal step instead of cutting the wall corner")

func test_runner_seeks_nearest_exposed_survivor_after_protected_targets_are_excluded() -> void:
	var state := _state()
	var tile := Vector2i(30, 24)
	var sheltered := state.survivors.add("Sheltered", "blue", tile + Vector2i.LEFT)
	sheltered.sheltered = true
	var tower_guard := state.survivors.add("Tower", "blue", tile + Vector2i.UP)
	tower_guard.on_tower = true
	state.survivors.add("Far exposed", "blue", tile + Vector2i(-5, 0))
	state.survivors.add("Near exposed", "blue", tile + Vector2i(3, 0))
	var z := state.spawn_zombie("runner", Grid.tile_to_world(tile))
	var start: Vector2 = z.pos
	ZombieAI.tick(state, 0.1)
	assert_eq(z.pos, start + Vector2.RIGHT * z.speed * 0.1)
	assert_eq(sheltered.hp, sheltered.max_hp)
	assert_eq(tower_guard.hp, tower_guard.max_hp)
