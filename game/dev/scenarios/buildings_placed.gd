extends RefCounted

static func setup(main: Node) -> void:
	var state: GameState = Game.state
	state.resources.add("wood", 100)
	var o: Vector2i = state.map.command_center_origin()
	
	var r1: int = state.try_place("shelter", o + Vector2i(2, -2))
	if r1 != Placement.Result.OK:
		push_warning("Failed to place shelter")
		
	var r2: int = state.try_place("farm", o + Vector2i(-2, -2))
	if r2 != Placement.Result.OK:
		push_warning("Failed to place farm")
		
	var r3: int = state.try_place("wooden_wall", o + Vector2i(-2, 3))
	if r3 != Placement.Result.OK:
		push_warning("Failed to place wall 1")
		
	var r4: int = state.try_place("wooden_wall", o + Vector2i(-1, 3))
	if r4 != Placement.Result.OK:
		push_warning("Failed to place wall 2")
		
	var r5: int = state.try_place("wooden_wall", o + Vector2i(0, 3))
	if r5 != Placement.Result.OK:
		push_warning("Failed to place wall 3")
		
	for b in state.buildings.blueprints():
		state.buildings.finish(b.uid)

	# Cover real, seeded decor outside the CC clearing to exercise both complete
	# buildings and blueprints without changing the scenery plan or map resources.
	var decor: DecorLayer = main.get_node("World/YSort/Decor") as DecorLayer
	var car: Dictionary = {}
	var closest: float = INF
	for entry: Dictionary in decor._entries:
		if entry["size"] == Vector2i(3, 3):
			var distance: float = Vector2(entry["tile"]).distance_to(Vector2(o))
			if distance < closest:
				closest = distance
				car = entry
	if car.is_empty():
		return
	state.resources.add("wood", 300)
	var car_tile: Vector2i = car["tile"]
	var shelter_origin: Vector2i = car_tile - Vector2i(1, 2)
	if state.try_place("shelter", shelter_origin) == Placement.Result.OK:
		state.buildings.finish(state.buildings.get_at(shelter_origin).uid)
	else:
		push_warning("Failed to cover seeded car with shelter")
	if state.try_place("wooden_wall", car_tile + Vector2i.RIGHT) != Placement.Result.OK:
		push_warning("Failed to cover seeded car with blueprint")
	# Also hide a small prop with a blueprint, preferring one near the fixture.
	var small: Dictionary = {}
	closest = INF
	for entry: Dictionary in decor._entries:
		if entry["size"] == Vector2i.ONE:
			var distance: float = Vector2(entry["tile"]).distance_to(Vector2(car_tile))
			if distance < closest:
				closest = distance
				small = entry
	if not small.is_empty():
		if state.try_place("wooden_wall", small["tile"]) != Placement.Result.OK:
			push_warning("Failed to cover seeded small prop with blueprint")
	state.clock.set_paused(true)
	var camera: Camera2D = main.get_node("World/Camera2D") as Camera2D
	camera.zoom = Vector2.ONE * 0.45
	camera.position = (Grid.tile_to_world(o) + Grid.tile_to_world(car_tile)) / 2.0
	camera.set_process(false)
