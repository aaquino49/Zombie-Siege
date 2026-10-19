class_name TestNoRefCycles extends TestCase

func test_game_state_frees_cleanly() -> void:
	var refs: Array[WeakRef] = _build_and_tick_state()
	
	assert_true(refs[0].get_ref() == null, "GameState leaked")
	assert_true(refs[1].get_ref() == null, "FlowField leaked")
	assert_true(refs[2].get_ref() == null, "ZombieStore leaked")
	assert_true(refs[3].get_ref() == null, "BuildingStore leaked")
	assert_true(refs[4].get_ref() == null, "WorldMap leaked")
	assert_true(refs[5].get_ref() == null, "Pathfinder leaked")
	assert_true(refs[6].get_ref() == null, "SurvivorStore leaked")

func _build_and_tick_state() -> Array[WeakRef]:
	var data := GameData.load_default()
	var state := GameState.new(data, 1337)
	
	for i in range(5):
		state.spawn_zombie("walker", Vector2(100, 100))
	assert_eq(state.zombies.count(), 5, "Lifecycle setup must spawn five walkers")
		
	var wall_pos := state.map.command_center_origin() + Vector2i(5, 5)
	assert_eq(state.try_place("wooden_wall", wall_pos), Placement.Result.OK,
		"Lifecycle setup must place a wall")
	var b := state.buildings.get_at(wall_pos)
	assert_not_null(b, "Lifecycle setup must contain the placed wall")
	if b != null:
		b.complete = true
		state.buildings.building_completed.emit(b)
	assert_eq(state.buildings_built, 1, "Lifecycle setup must complete the wall")
			
	for i in range(120):
		state.tick(0.016)
		
	var zombies := state.zombies.all()
	if zombies.size() > 0:
		state.damage_zombie(zombies[0], 9999)
	assert_eq(state.zombies_killed, 1, "Lifecycle setup must kill a zombie through the damage API")
		
	var survivors := state.survivors.all()
	if survivors.size() > 0:
		state.damage_survivor(survivors[0], 9999)
	assert_eq(state.survivors_lost, 1, "Lifecycle setup must kill a survivor through the damage API")
		
	var refs: Array[WeakRef] = []
	refs.append(weakref(state))
	refs.append(weakref(state.flow))
	refs.append(weakref(state.zombies))
	refs.append(weakref(state.buildings))
	refs.append(weakref(state.map))
	refs.append(weakref(state.pathfinder))
	refs.append(weakref(state.survivors))
	
	return refs
