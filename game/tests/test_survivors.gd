class_name TestSurvivors extends TestCase

func test_survivors_start() -> void:
	var state := GameState.new(GameData.load_default(), 1337)
	assert_eq(state.survivors.count(), 4, "4 survivors start")
	var s_all := state.survivors.all()
	var names: Dictionary = {}
	var tiles: Dictionary = {}
	var cc_origin := state.map.command_center_origin()
	for s in s_all:
		assert_ne(s.name, "", "unique non-empty names")
		assert_false(names.has(s.name), "unique names")
		names[s.name] = true
		assert_eq(s.hp, 50, "hp 50")
		assert_eq(s.max_hp, 50, "max hp 50")
		var t := s.tile()
		assert_false(tiles.has(t), "distinct tiles")
		tiles[t] = true
		assert_true(state.map.is_passable(t), "passable tile")
		
		var is_touching: bool = false
		for y in range(cc_origin.y - 1, cc_origin.y + 3):
			for x in range(cc_origin.x - 1, cc_origin.x + 3):
				if x >= cc_origin.x and x < cc_origin.x + 2 and y >= cc_origin.y and y < cc_origin.y + 2:
					continue
				if Vector2i(x, y) == t:
					is_touching = true
		assert_true(is_touching, "in the ring around CC")

func test_next_uid_previews_additions_without_consuming_ids() -> void:
	var store: SurvivorStore = SurvivorStore.new(GameData.load_default())
	assert_eq(store.next_uid(), 1)
	assert_eq(store.next_uid(), 1, "Reading the next UID does not consume it")
	var first: Survivor = store.add("First", "blue", Vector2i.ZERO)
	assert_eq(first.uid, 1)
	assert_eq(store.next_uid(), 2)
	store.remove(first.uid)
	assert_eq(store.next_uid(), 2, "Removed survivor IDs are not reused")
	var second: Survivor = store.add("Second", "blue", Vector2i.ZERO)
	assert_eq(second.uid, 2)
	assert_eq(store.next_uid(), 3)

func test_movement() -> void:
	var state := GameState.new(GameData.load_default(), 1337)
	for uid in [1, 2, 3, 4]: state.set_job(uid, Survivor.Job.IDLE)
	var s := state.survivors.all()[0]
	var start_tile := s.tile()
	
	for i in range(1, 6):
		var t := start_tile + Vector2i(i, 0)
		state.map.vacate(t, Vector2i(1, 1))
	
	var target := start_tile + Vector2i(5, 0)
	state.set_job(s.uid, Survivor.Job.IDLE)
	var r := state.order_move(s.uid, target)
	assert_true(r, "can move")
	
	for i in range(28):
		state.tick(0.1)
		
	assert_true(s.is_moving(), "still moving after 2.8s")
	
	for i in range(2):
		state.tick(0.1)
	
	assert_false(s.is_moving(), "arrived after 3.0s")
	assert_eq(s.tile(), target, "arrived exactly on target tile")
	assert_eq(s.pos, Grid.tile_to_world(target), "exactly on centre")
	
	var s2 := state.survivors.all()[1]
	state.set_job(s2.uid, Survivor.Job.IDLE)
	state.order_move(s2.uid, s2.tile() + Vector2i(0, 1))
	var p_before := s2.pos
	state.clock.set_speed(0)
	state.tick(1.0)
	assert_eq(s2.pos, p_before, "paused doesn't move")
	
	state.clock.set_speed(2)
	var s3 := state.survivors.all()[2]
	var s3_start := s3.tile()
	for i in range(1, 6):
		var t := s3_start + Vector2i(0, i)
		state.map.vacate(t, Vector2i(1, 1))
	state.set_job(s3.uid, Survivor.Job.IDLE)
	state.order_move(s3.uid, s3_start + Vector2i(0, 5))
	state.tick(1.75)
	assert_false(s3.is_moving(), "arrived by 1.75s at 2x")
	
	state.clock.set_speed(1)
	var s4 := state.survivors.all()[3]
	var s4_start := s4.tile()
	for i in range(1, 6):
		var t := s4_start + Vector2i(0, i)
		state.map.vacate(t, Vector2i(1, 1))
	for i in range(1, 6):
		var t := s4_start + Vector2i(1, i)
		state.map.vacate(t, Vector2i(1, 1))
	for i in range(1, 6):
		var t := s4_start + Vector2i(-1, i)
		state.map.vacate(t, Vector2i(1, 1))
	state.set_job(s4.uid, Survivor.Job.IDLE)
	state.order_move(s4.uid, s4_start + Vector2i(0, 5))
	state.tick(1.0)
	state.try_place("wooden_wall", s4_start + Vector2i(0, 3))
	state.tick(10.0)
	assert_false(s4.is_moving(), "arrived")
	assert_eq(s4.tile(), s4_start + Vector2i(0, 5), "arrived at target despite wall")
	
	var t_tree := Vector2i(10, 10)
	state.map._occupants[t_tree] = WorldMap.Occupant.TREE # Force tree
	state.map.changed.emit()
	state.set_job(s.uid, Survivor.Job.IDLE)
	var rt := state.order_move(s.uid, t_tree)
	assert_false(rt, "order_move to tree returns false")

func test_survivor_unstick() -> void:
	var state := GameState.new(GameData.load_default(), 1337)
	var s := state.survivors.all()[0]
	var start_tile := s.tile()
	
	# Vacate space for farm placement and movement path
	for x in range(start_tile.x - 2, start_tile.x + 8):
		for y in range(start_tile.y - 2, start_tile.y + 3):
			var t := Vector2i(x, y)
			if not state.map.is_passable(t):
				state.map.vacate(t, Vector2i(1, 1))
	
	var r_place := state.try_place("farm", start_tile)
	assert_eq(r_place, Placement.Result.OK, "placed farm over survivor")
	
	var target := start_tile + Vector2i(5, 0)
	state.set_job(s.uid, Survivor.Job.IDLE)
	var r_move := state.order_move(s.uid, target)
	assert_true(r_move, "can move off solid tile")
	
	for i in range(50):
		state.tick(0.1)
		
	assert_false(s.is_moving(), "arrived")
	assert_eq(s.tile(), target, "arrived exactly on target tile")
	assert_eq(s.pos, Grid.tile_to_world(target), "exactly on centre")

func test_evict_from_solid() -> void:
	var state := GameState.new(GameData.load_default(), 1337)
	var s := state.survivors.all()[0]
	state.set_job(s.uid, Survivor.Job.FARMER)
	s.activity = Survivor.Activity.FARMING
	s.path.clear()
	
	var start_tile := s.tile()
	state.map.occupy(start_tile, Vector2i(1, 1), "wooden_wall")
	state.tick(0.1)
	
	assert_true(state.map.is_passable(s.tile()), "stationary survivor evicted to passable tile")
	assert_eq(s.job, Survivor.Job.FARMER, "job unchanged")
	assert_eq(s.activity, Survivor.Activity.IDLE, "activity becomes IDLE")
	
	var s2 := state.survivors.all()[1]
	state.set_job(s2.uid, Survivor.Job.IDLE)
	s2.path.clear()
	var s2_start := s2.tile()
	assert_true(state.map.is_passable(s2_start))
	state.tick(0.1)
	assert_eq(s2.tile(), s2_start, "passable tile position unchanged")
	
	var s3 := state.survivors.all()[2]
	s3.sheltered = true
	var s3_start := s3.tile()
	state.map.occupy(s3_start, Vector2i(1, 1), "wooden_wall")
	state.tick(0.1)
	assert_eq(s3.tile(), s3_start, "sheltered survivor never evicted")
	
	var state_a := GameState.new(GameData.load_default(), 123)
	var state_b := GameState.new(GameData.load_default(), 123)
	var sa := state_a.survivors.all()[0]
	var sb := state_b.survivors.all()[0]
	state_a.map.occupy(sa.tile(), Vector2i(1, 1), "wooden_wall")
	state_b.map.occupy(sb.tile(), Vector2i(1, 1), "wooden_wall")
	state_a.tick(0.1)
	state_b.tick(0.1)
	assert_eq(sa.tile(), sb.tile(), "same seed gives same final tile")
