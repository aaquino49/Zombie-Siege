extends TestCase

func test_command_center_in_store() -> void:
	var data := GameData.load_default()
	var state := GameState.new(data, 1337)
	
	var cc_origin := state.map.command_center_origin()
	var cc1 := state.buildings.get_at(cc_origin)
	var cc2 := state.buildings.get_at(cc_origin + Vector2i(1, 0))
	var cc3 := state.buildings.get_at(cc_origin + Vector2i(0, 1))
	var cc4 := state.buildings.get_at(cc_origin + Vector2i(1, 1))
	
	assert_true(cc1 != null, "Command center tile is occupied")
	assert_eq(cc1, cc2, "All 4 tiles return same Building")
	assert_eq(cc1, cc3, "All 4 tiles return same Building")
	assert_eq(cc1, cc4, "All 4 tiles return same Building")
	assert_eq(state.buildings.count_of("command_center"), 1, "One command center in store")
	assert_eq(cc1.type_id, "command_center", "Command center has correct type_id")

func test_placement_ok() -> void:
	var data := GameData.load_default()
	var state := GameState.new(data, 1337)
	var cc_origin := state.map.command_center_origin()
	
	var ok_origin := cc_origin + Vector2i(3, 0)
	var r := Placement.check(state, "wooden_wall", ok_origin)
	assert_eq(r, Placement.Result.OK, "Placement OK for wooden_wall near CC")

func test_placement_blocked_overlap() -> void:
	var data := GameData.load_default()
	var state := GameState.new(data, 1337)
	var cc_origin := state.map.command_center_origin()
	
	var r := Placement.check(state, "shelter", cc_origin + Vector2i(1, 1))
	assert_eq(r, Placement.Result.BLOCKED, "Shelter overlapping CC is BLOCKED")

func test_placement_blocked_tree() -> void:
	var data := GameData.load_default()
	var state := GameState.new(data, 1337)
	
	var tree_t := Vector2i(-1, -1)
	for x in range(state.map.size()):
		for y in range(state.map.size()):
			var t := Vector2i(x, y)
			if state.map.occupant_at(t) == WorldMap.Occupant.TREE:
				tree_t = t
				break
		if tree_t.x != -1:
			break
			
	assert_true(tree_t.x != -1, "Found a tree tile")
	var r := Placement.check(state, "wooden_wall", tree_t)
	assert_eq(r, Placement.Result.BLOCKED, "Placement on tree is BLOCKED")

func test_placement_out_of_bounds() -> void:
	var data := GameData.load_default()
	var state := GameState.new(data, 1337)
	
	var max_idx := state.map.size() - 1
	var r := Placement.check(state, "shelter", Vector2i(max_idx, max_idx))
	assert_eq(r, Placement.Result.OUT_OF_BOUNDS, "Shelter at map corner is OUT_OF_BOUNDS")
	
	r = Placement.check(state, "wooden_wall", Vector2i(-1, 0))
	assert_eq(r, Placement.Result.OUT_OF_BOUNDS, "Wall at (-1, 0) is OUT_OF_BOUNDS")

func test_placement_locked() -> void:
	var data := GameData.load_default()
	var state := GameState.new(data, 1337)
	var ok_origin := state.map.command_center_origin() + Vector2i(3, 0)
	
	var r := Placement.check(state, "radio_tower", ok_origin)
	assert_eq(r, Placement.Result.LOCKED, "radio_tower is LOCKED on day 1")
	
	r = Placement.check(state, "storage", ok_origin)
	assert_eq(r, Placement.Result.LOCKED, "storage is LOCKED on day 1")
	
	var day_length: float = state.data.balance("day_length", 150.0)
	var night_length: float = state.data.balance("night_min_length", 45.0)
	state.clock.advance(day_length + night_length)
	
	assert_true(state.clock.day >= 2, "Clock advanced to day 2")
	r = Placement.check(state, "storage", ok_origin)
	assert_eq(r, Placement.Result.OK, "storage is OK on day 2")

func test_placement_not_placeable_and_unknown() -> void:
	var data := GameData.load_default()
	var state := GameState.new(data, 1337)
	var ok_origin := state.map.command_center_origin() + Vector2i(3, 0)
	
	var r := Placement.check(state, "command_center", ok_origin)
	assert_eq(r, Placement.Result.NOT_PLACEABLE, "command_center is NOT_PLACEABLE")
	
	r = Placement.check(state, "reinforced_wall", ok_origin)
	assert_eq(r, Placement.Result.NOT_PLACEABLE, "reinforced_wall is NOT_PLACEABLE")
	
	r = Placement.check(state, "castle", ok_origin)
	assert_eq(r, Placement.Result.UNKNOWN_TYPE, "castle is UNKNOWN_TYPE")

func test_placement_unaffordable() -> void:
	var data := GameData.load_default()
	var state := GameState.new(data, 1337)
	var ok_origin := state.map.command_center_origin() + Vector2i(3, 0)
	
	var old_wood := state.resources.get_amount("wood")
	state.resources.take("wood", old_wood)
	
	var r := Placement.check(state, "wooden_wall", ok_origin)
	assert_eq(r, Placement.Result.UNAFFORDABLE, "wall is UNAFFORDABLE with no wood")

func test_try_place() -> void:
	var data := GameData.load_default()
	var state := GameState.new(data, 1337)
	var ok_origin := state.map.command_center_origin() + Vector2i(3, 0)
	
	var cost_wood: int = int(state.data.get_building("wooden_wall").get("cost", {}).get("wood", 0))
	var wood_before := state.resources.get_amount("wood")
	if wood_before < cost_wood:
		state.resources.add("wood", cost_wood - wood_before)
		wood_before = state.resources.get_amount("wood")
		
	var r := state.try_place("wooden_wall", ok_origin)
	assert_eq(r, Placement.Result.OK, "try_place wooden_wall returns OK")
	
	var wood_after := state.resources.get_amount("wood")
	assert_eq(wood_before - wood_after, cost_wood, "try_place deducted exactly cost_wood")
	assert_eq(state.buildings.count_of("wooden_wall"), 1, "wooden_wall added to store")
	
	r = state.try_place("wooden_wall", ok_origin)
	assert_eq(r, Placement.Result.BLOCKED, "try_place at same origin is BLOCKED")
	assert_eq(state.resources.get_amount("wood"), wood_after, "Resources unchanged on failed try_place")

func test_adjacent_walls_different_uids() -> void:
	var data := GameData.load_default()
	var state := GameState.new(data, 1337)
	var ok_origin := state.map.command_center_origin() + Vector2i(3, 0)
	var ok_origin2 := ok_origin + Vector2i(1, 0)
	
	var cost_wood: int = int(state.data.get_building("wooden_wall").get("cost", {}).get("wood", 0))
	state.resources.add("wood", cost_wood * 2)
	
	state.try_place("wooden_wall", ok_origin)
	state.try_place("wooden_wall", ok_origin2)
	
	var w1 := state.buildings.get_at(ok_origin)
	var w2 := state.buildings.get_at(ok_origin2)
	
	assert_true(w1 != null, "w1 exists")
	assert_true(w2 != null, "w2 exists")
	assert_true(w1.uid != w2.uid, "Two adjacent walls have different uids")

func test_remove_building() -> void:
	var data := GameData.load_default()
	var state := GameState.new(data, 1337)
	var ok_origin := state.map.command_center_origin() + Vector2i(3, 0)
	
	var cost_wood: int = int(state.data.get_building("wooden_wall").get("cost", {}).get("wood", 0))
	state.resources.add("wood", cost_wood)
	state.try_place("wooden_wall", ok_origin)
	
	var w1 := state.buildings.get_at(ok_origin)
	var uid_to_remove := w1.uid
	
	var signal_fired := [false]
	var signal_handler: Callable = func(b: Building) -> void:
		if b.uid == uid_to_remove:
			signal_fired[0] = true
	
	state.buildings.building_removed.connect(signal_handler)
	state.buildings.remove(uid_to_remove)
	
	assert_true(signal_fired[0], "building_removed fired correctly")
	var r := Placement.check(state, "wooden_wall", ok_origin)
	assert_eq(r, Placement.Result.OK, "Tile is OK again after remove")

func test_line_tiles() -> void:
	var line1 := Placement.line_tiles(Vector2i(0, 0), Vector2i(4, 1))
	assert_eq(line1.size(), 5, "line_tiles((0,0),(4,1)) has 5 tiles")
	if line1.size() == 5:
		assert_eq(line1[0], Vector2i(0, 0), "start")
		assert_eq(line1[4], Vector2i(4, 0), "end")
		
	var line2 := Placement.line_tiles(Vector2i(0, 0), Vector2i(1, -3))
	assert_eq(line2.size(), 4, "line_tiles((0,0),(1,-3)) has 4 tiles")
	if line2.size() == 4:
		assert_eq(line2[0], Vector2i(0, 0), "start")
		assert_eq(line2[3], Vector2i(0, -3), "end")
		
	var line3 := Placement.line_tiles(Vector2i(5, 5), Vector2i(5, 5))
	assert_eq(line3.size(), 1, "size 1")
	assert_eq(line3[0], Vector2i(5, 5), "start=end")

func test_is_placeable_type() -> void:
	var data := GameData.load_default()
	assert_true(Placement.is_placeable_type(data, "wooden_wall"), "wooden_wall is placeable")
	assert_false(Placement.is_placeable_type(data, "command_center"), "command_center not placeable")
	assert_false(Placement.is_placeable_type(data, "reinforced_wall"), "reinforced_wall not placeable")
	assert_false(Placement.is_placeable_type(data, "castle"), "castle not placeable")

func test_result_text() -> void:
	assert_eq(Placement.result_text(Placement.Result.OK), "OK", "result_text OK")
	assert_eq(Placement.result_text(Placement.Result.UNAFFORDABLE), "Not enough resources", "result_text UNAFFORDABLE")
