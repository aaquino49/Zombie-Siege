extends TestCase

func test_harvest_rate() -> void:
	var state := GameState.new(GameData.load_default(), 1337)
	var s: Survivor = state.survivors.all()[1]
	state.set_job(s.uid, Survivor.Job.GATHERER, "wood")
	
	var trees := state.map.nodes_of(WorldMap.Occupant.TREE)
	var tree_t: Vector2i = trees[0]
	assert_true(state.map.get_node_amount(tree_t) >= 3, "Tree should have at least 3 wood")
	var start_tile := tree_t + Vector2i(1, 0)
	if not state.map.is_passable(start_tile):
		start_tile = tree_t + Vector2i(-1, 0)
	assert_true(state.map.is_passable(start_tile), "Start tile should be passable")
	s.pos = Grid.tile_to_world(start_tile)
	s.carry_amount = 0
	
	for i in range(12):
		state.tick(0.1)
	assert_eq(s.carry_amount, 1)
	for i in range(1):
		state.tick(0.1)
	assert_eq(s.carry_amount, 2)

func test_harvest_rate_scrap() -> void:
	var state := GameState.new(GameData.load_default(), 1337)
	var s: Survivor = state.survivors.all()[1]
	state.set_job(s.uid, Survivor.Job.GATHERER, "scrap")
	
	var scraps := state.map.nodes_of(WorldMap.Occupant.SCRAP)
	var scrap_t: Vector2i = scraps[0]
	var start_tile := scrap_t + Vector2i(1, 0)
	if not state.map.is_passable(start_tile):
		start_tile = scrap_t + Vector2i(-1, 0)
	s.pos = Grid.tile_to_world(start_tile)
	s.carry_amount = 0
	
	for i in range(13):
		state.tick(0.1)
	assert_eq(s.carry_amount, 1)

func test_harvest_rate_lumber_yard() -> void:
	var state := GameState.new(GameData.load_default(), 1337)
	var s: Survivor = state.survivors.all()[1]
	state.set_job(s.uid, Survivor.Job.GATHERER, "wood")
	
	var trees := state.map.nodes_of(WorldMap.Occupant.TREE)
	var tree_t: Vector2i = trees[0]
	
	state.resources.add("wood", 1000)
	state.clock.day = 3
	state.map.vacate(tree_t + Vector2i(1, 1), Vector2i(2, 2))
	assert_eq(state.try_place("lumber_yard", tree_t + Vector2i(1, 1)), 0) # 0 is OK
	var b := state.buildings.all_of_type("lumber_yard")[0]
	b.complete = true
	b.progress = b.build_time
	
	s.pos = Grid.tile_to_world(tree_t + Vector2i(-1, 0))
	s.carry_amount = 0
	
	for i in range(16):
		state.tick(0.1)
	assert_eq(s.carry_amount, 3)

func test_delivery() -> void:
	var state := GameState.new(GameData.load_default(), 1337)
	var s: Survivor = state.survivors.all()[1]
	state.set_job(s.uid, Survivor.Job.GATHERER, "wood")
	s.carry_amount = 20
	s.carry_kind = "wood"
	var initial_wood := state.resources.get_amount("wood")
	
	var emissions := [0]
	state.resource_delivered.connect(func(k: String, a: int, p: Vector2):
		if k == "wood":
			emissions[0] += 1
			assert_eq(a, 20)
	)
	
	while s.carry_amount > 0:
		state.tick(0.1)
		
	assert_eq(state.resources.get_amount("wood"), initial_wood + 20)
	assert_eq(emissions[0], 1)

func test_complete_storage_receives_delivery() -> void:
	var state := GameState.new(GameData.load_default(), 1337)
	state.clock.day = 3
	var s: Survivor = state.survivors.all()[1]
	
	state.map.vacate(Vector2i(5, 5), Vector2i(5, 5))
	s.pos = Grid.tile_to_world(Vector2i(5, 5))
	
	state.set_job(s.uid, Survivor.Job.GATHERER, "wood")
	s.carry_amount = 10
	s.carry_kind = "wood"
	
	var storage_t := Vector2i(7, 5)
	state.resources.add("wood", 100)
	state.try_place("storage", storage_t)
	var st_b := state.buildings.all_of_type("storage")[0]
	st_b.complete = true
	
	var delivered_pos := [Vector2.ZERO]
	state.resource_delivered.connect(func(k, a, p): delivered_pos[0] = p)
	
	while s.carry_amount > 0:
		state.tick(0.1)
		
	assert_eq(delivered_pos[0], st_b.center_world())

func test_incomplete_storage_ignored_for_delivery() -> void:
	var state := GameState.new(GameData.load_default(), 1337)
	state.clock.day = 3
	var s: Survivor = state.survivors.all()[1]
	
	state.map.vacate(Vector2i(5, 5), Vector2i(5, 5))
	s.pos = Grid.tile_to_world(Vector2i(5, 5))
	
	state.set_job(s.uid, Survivor.Job.GATHERER, "wood")
	s.carry_amount = 10
	s.carry_kind = "wood"
	
	var storage_t := Vector2i(7, 5)
	state.resources.add("wood", 100)
	state.try_place("storage", storage_t)
	var st_b := state.buildings.all_of_type("storage")[0]
	st_b.complete = false
	
	var delivered_pos := [Vector2.ZERO]
	state.resource_delivered.connect(func(k, a, p): delivered_pos[0] = p)
	
	while s.carry_amount > 0:
		state.tick(0.1)
		
	var cc := state.buildings.all_of_type("command_center")[0]
	assert_eq(delivered_pos[0], cc.center_world())

func test_carry_capacity_and_return() -> void:
	var state := GameState.new(GameData.load_default(), 1337)
	var s: Survivor = state.survivors.all()[1]
	state.set_job(s.uid, Survivor.Job.GATHERER, "wood")
	
	var trees := state.map.nodes_of(WorldMap.Occupant.TREE)
	var tree_t: Vector2i = trees[0]
	state.map._node_amounts[tree_t] = 100
	
	var start_tile := tree_t + Vector2i(1, 0)
	if not state.map.is_passable(start_tile):
		start_tile = tree_t + Vector2i(-1, 0)
	s.pos = Grid.tile_to_world(start_tile)
	s.carry_amount = 0
	
	while s.activity != Survivor.Activity.RETURNING:
		state.tick(0.1)
		assert_true(s.carry_amount <= 20)
		
	assert_eq(s.carry_amount, 20)

func test_switch_job_banks_load() -> void:
	var state := GameState.new(GameData.load_default(), 1337)
	var s: Survivor = state.survivors.all()[1]
	state.set_job(s.uid, Survivor.Job.GATHERER, "wood")
	s.carry_amount = 6
	s.carry_kind = "wood"
	var initial_wood := state.resources.get_amount("wood")
	
	state.set_job(s.uid, Survivor.Job.IDLE)
	assert_eq(state.resources.get_amount("wood"), initial_wood + 6)
	assert_eq(s.carry_amount, 0)
	assert_eq(s.carry_kind, "")
	
	assert_false(state.set_job(s.uid, Survivor.Job.GATHERER, "invalid"))
	
	assert_true(state.set_job(s.uid, Survivor.Job.GATHERER, "scrap"))
	assert_eq(s.gather_kind, "scrap")

func test_depletion() -> void:
	var state := GameState.new(GameData.load_default(), 1337)
	var s: Survivor = state.survivors.all()[1]
	state.set_job(s.uid, Survivor.Job.GATHERER, "wood")
	
	var trees := state.map.nodes_of(WorldMap.Occupant.TREE)
	var tree_t: Vector2i = trees[0]
	state.map._node_amounts[tree_t] = 3
	
	var start_tile := tree_t + Vector2i(1, 0)
	if not state.map.is_passable(start_tile):
		start_tile = tree_t + Vector2i(-1, 0)
	s.pos = Grid.tile_to_world(start_tile)
	s.carry_amount = 0
	
	var changed_count := [0]
	state.map.changed.connect(func(): changed_count[0] += 1)
	
	var prev_changes = changed_count[0]
	while state.map.occupant_at(tree_t) == WorldMap.Occupant.TREE:
		state.tick(0.1)
		
	# give it a couple of ticks to re-path
	state.tick(0.1)
	state.tick(0.1)
	state.tick(0.1)
		
	assert_eq(state.map.occupant_at(tree_t), WorldMap.Occupant.NONE)
	assert_true(state.map.is_passable(tree_t))
	assert_eq(changed_count[0], prev_changes + 1)
	assert_eq(s.carry_amount, 3)
	assert_ne(s.work_tile, tree_t)
	assert_ne(s.work_tile, Vector2i(-1, -1))
	assert_eq(state.map.occupant_at(s.work_tile), WorldMap.Occupant.TREE)

func test_60_seconds_sim() -> void:
	var state := GameState.new(GameData.load_default(), 1337)
	var init_w := state.resources.get_amount("wood")
	var init_s := state.resources.get_amount("scrap")
	
	for i in range(600):
		state.tick(0.1)
		for s in state.survivors.all():
			assert_true(state.map.is_passable(s.tile()), "Survivor on impassable tile")
			
	var del_w := state.resources.get_amount("wood") - init_w
	var del_s := state.resources.get_amount("scrap") - init_s
	assert_true(del_w + del_s > 0, "Expected some resources delivered")
