extends TestCase

func test_flow_field() -> void:
	var data: GameData = GameData.load_default()
	var state: GameState = GameState.new(data, 1337)
	state.resources.add("wood", 10000)
	
	var flow: FlowField = state.flow
	flow.rebuild()
	
	# CC tiles distance 0
	var cc_origin: Vector2i = state.map.command_center_origin()
	for y in range(cc_origin.y, cc_origin.y + 2):
		for x in range(cc_origin.x, cc_origin.x + 2):
			assert_eq(flow.distance(Vector2i(x, y)), 0)
			
	# trees/rocks -1
	for x in range(state.map.size()):
		for y in range(state.map.size()):
			var t: Vector2i = Vector2i(x, y)
			var occ: int = state.map.occupant_at(t)
			if occ == WorldMap.Occupant.TREE or occ == WorldMap.Occupant.SCRAP or occ == WorldMap.Occupant.ROCK:
				assert_eq(flow.distance(t), -1)
				
	# corners reach CC
	var corners: Array[Vector2i] = [Vector2i(0, 0), Vector2i(47, 0), Vector2i(0, 47), Vector2i(47, 47)]
	for c in corners:
		if flow.distance(c) != -1:
			var steps: int = 0
			var curr: Vector2i = c
			while flow.distance(curr) > 0 and steps < 200:
				curr = flow.next_tile(curr)
				steps += 1
			assert_eq(flow.distance(curr), 0)
			assert_true(steps < 200)

	# short walls detoured
	# find an open approach
	var wall_start: Vector2i = Vector2i(cc_origin.x + 5, cc_origin.y)
	state.try_place("wooden_wall", wall_start)
	state.try_place("wooden_wall", wall_start + Vector2i(0, 1))
	state.try_place("wooden_wall", wall_start + Vector2i(0, 2))
	flow.rebuild()
	
	var start_t: Vector2i = wall_start + Vector2i(3, 1)
	var curr: Vector2i = start_t
	var hit_wall: bool = false
	while flow.distance(curr) > 0:
		var n: Vector2i = flow.next_tile(curr)
		if state.buildings.get_at(n) != null and state.buildings.get_at(n).type_id == "wooden_wall":
			hit_wall = true
		curr = n
	assert_false(hit_wall)
	
	# full wall ring breached at exactly one wall tile
	for uid in state.buildings._buildings.keys():
		if state.buildings._buildings[uid].type_id == "wooden_wall":
			state.buildings.remove(uid)
			
	for y in range(cc_origin.y - 3, cc_origin.y + 5):
		for x in range(cc_origin.x - 3, cc_origin.x + 5):
			if max(abs(x - (cc_origin.x + 0.5)), abs(y - (cc_origin.y + 0.5))) > 2.5:
				var t: Vector2i = Vector2i(x, y)
				if state.map.is_free(t, Vector2i(1, 1)):
					state.try_place("wooden_wall", t)
					
	flow.rebuild()
	start_t = Vector2i(cc_origin.x + 8, cc_origin.y)
	curr = start_t
	var walls_entered: int = 0
	var print_steps: int = 0
	while flow.distance(curr) > 0 and print_steps < 100:
		var n: Vector2i = flow.next_tile(curr)
		var b: Building = state.buildings.get_at(n)
		if b != null and b.type_id == "wooden_wall":
			walls_entered += 1
		curr = n
		print_steps += 1
	assert_eq(walls_entered, 1)
	
	# dirty flag
	assert_false(flow.is_dirty())
	state.map.vacate(Vector2i(0, 0), Vector2i(1, 1))
	var test_b: int = state.try_place("wooden_wall", Vector2i(0, 0))
	assert_true(flow.is_dirty())
	flow.rebuild()
	assert_false(flow.is_dirty())
	
	var b2: Building = state.buildings.get_at(Vector2i(0, 0))
	if b2 != null:
		state.damage_building(b2, 10)
	assert_false(flow.is_dirty())
	
	# Warm up before measuring so startup and cache noise do not affect the gate.
	for i in range(2):
		state.map.changed.emit()
		assert_true(flow.is_dirty())
		flow.rebuild()
		assert_false(flow.is_dirty())

	# This gate catches order-of-magnitude regressions, not machine noise.
	# rebuild time (minimum of 9 against a documented 60 ms ceiling)
	var times: Array[float] = []
	for i in range(9):
		state.map.changed.emit()
		assert_true(flow.is_dirty())
		var t0: int = Time.get_ticks_usec()
		flow.rebuild()
		var t1: int = Time.get_ticks_usec()
		var ms: float = (t1 - t0) / 1000.0
		times.append(ms)
		assert_false(flow.is_dirty())
	
	var sorted_times: Array[float] = times.duplicate()
	sorted_times.sort()
	var min_ms: float = sorted_times[0]
	var median_ms: float = sorted_times[4]
	print("Rebuild times: min=%.3f ms, median=%.3f ms (9 runs)" % [min_ms, median_ms])
	assert_true(min_ms < 60.0, "Rebuild time (minimum of 9) exceeded 60 ms ceiling: min=%.3f ms, median=%.3f ms" % [min_ms, median_ms])

