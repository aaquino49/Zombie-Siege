class_name TestPathfinder extends TestCase

func test_find_path() -> void:
	var state := GameState.new(GameData.load_default(), 1337)
	
	var start := Vector2i(10, 10)
	var end := Vector2i(15, 10)
	var path := state.pathfinder.find_path(start, end)
	
	assert_gt(path.size(), 0, "path should not be empty")
	var current := start
	for p in path:
		var dist_x := absi(p.x - current.x)
		var dist_y := absi(p.y - current.y)
		assert_true(dist_x <= 1 and dist_y <= 1, "each step is an 8-neighbour")
		assert_true(state.map.is_passable(p), "should not step on impassable")
		current = p
	assert_eq(current, end, "path ends at target")

	state.try_place("wooden_wall", Vector2i(12, 10))
	var path2 := state.pathfinder.find_path(start, end)
	for p in path2:
		assert_ne(p, Vector2i(12, 10), "avoids the wall")

	state.try_place("gate", Vector2i(12, 11))
	var path_gate := state.pathfinder.find_path(start, Vector2i(15, 11))
	assert_gt(path_gate.size(), 0, "should find path through or around gate")
	
	state.try_place("wooden_wall", Vector2i(20, 20))
	state.try_place("wooden_wall", Vector2i(21, 20))
	state.try_place("wooden_wall", Vector2i(22, 20))
	state.try_place("wooden_wall", Vector2i(20, 21))
	state.try_place("wooden_wall", Vector2i(22, 21))
	state.try_place("wooden_wall", Vector2i(20, 22))
	state.try_place("wooden_wall", Vector2i(21, 22))
	state.try_place("wooden_wall", Vector2i(22, 22))
	
	var path3 := state.pathfinder.find_path(start, Vector2i(21, 21))
	assert_eq(path3.size(), 0, "fully walled off returns []")
	
	var path_solid := state.pathfinder.find_path(start, Vector2i(20, 20))
	assert_eq(path_solid.size(), 0, "solid returns []")
	
	# Test starting on solid tile, go somewhere that doesn't cross the gate
	var path_from_solid := state.pathfinder.find_path(Vector2i(20, 20), Vector2i(20, 10))
	assert_gt(path_from_solid.size(), 0, "solid from should not return empty")
	for i in range(path_from_solid.size()):
		assert_true(state.map.is_passable(path_from_solid[i]), "each step after first is passable")
	var solid_still_solid := state.pathfinder.find_path(start, Vector2i(20, 20))
	assert_eq(solid_still_solid.size(), 0, "start tile is still solid afterwards")
	
	var cc_origin := state.map.command_center_origin()
	var path4 := state.pathfinder.find_path_adjacent(start, cc_origin, Vector2i(2, 2))
	if path4.size() > 0:
		var last: Vector2i = path4.back()
		var is_touching: bool = false
		for y in range(cc_origin.y - 1, cc_origin.y + 3):
			for x in range(cc_origin.x - 1, cc_origin.x + 3):
				if x >= cc_origin.x and x < cc_origin.x + 2 and y >= cc_origin.y and y < cc_origin.y + 2:
					continue
				if Vector2i(x, y) == last:
					is_touching = true
		assert_true(is_touching, "ends on a tile touching CC footprint")

func test_find_path_adjacent_from_solid() -> void:
	var state := GameState.new(GameData.load_default(), 1337)
	var cc_origin := state.map.command_center_origin()
	var t := cc_origin + Vector2i(-1, -1)
	assert_eq(state.try_place("wooden_wall", t), Placement.Result.OK)
	var path := state.pathfinder.find_path_adjacent(t, cc_origin, Vector2i(2, 2))
	assert_gt(path.size(), 0, "path should not be empty")
	assert_true(state.map.is_passable(path.back()), "path should end on a passable tile")
