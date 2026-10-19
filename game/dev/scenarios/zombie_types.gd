extends RefCounted

static func setup(main: Node) -> void:
	var state: GameState = Game.state
	state.waves.enabled = false
	state.clock.phase = GameClock.Phase.DAY
	state.clock.elapsed = 0.0
	var origin: Vector2i = state.map.command_center_origin()
	var wall_x: int = origin.x + 5
	# Clear the demonstration area without changing the other scenarios.
	for y: int in range(origin.y - 5, origin.y + 9):
		for x: int in range(origin.x + 2, wall_x + 9):
			var tile := Vector2i(x, y)
			if state.map.occupant_at(tile) != WorldMap.Occupant.BUILDING:
				state.map._occupants[tile] = WorldMap.Occupant.NONE
				state.map._node_amounts.erase(tile)
	state.map.changed.emit()
	for y: int in range(origin.y - 4, origin.y + 5):
		if y != origin.y + 1:
			state.buildings.add("wooden_wall", Vector2i(wall_x, y), true)
	# One exposed worker, five tiles outside the wall, harvesting a real node.
	var gather_tile := Vector2i(wall_x + 5, origin.y - 2)
	var node_tile: Vector2i = gather_tile + Vector2i.UP
	state.map._occupants[node_tile] = WorldMap.Occupant.TREE
	state.map._node_amounts[node_tile] = int(state.data.balance("map_tree_wood_max", 40))
	state.map.changed.emit()
	main.get_node("World")._draw_props()
	main.get_node("World")._draw_ground_detail()
	var gatherer: Survivor = state.survivors.all()[0]
	for s: Survivor in state.survivors.all():
		state.set_job(s.uid, Survivor.Job.IDLE)
	state.set_job(gatherer.uid, Survivor.Job.GATHERER, "wood")
	gatherer.pos = Grid.tile_to_world(gather_tile)
	gatherer.work_tile = node_tile
	gatherer.activity = Survivor.Activity.HARVESTING
	state.spawn_zombie("runner", Grid.tile_to_world(gather_tile + Vector2i(0, 4)))
	state.spawn_zombie("brute", Grid.tile_to_world(Vector2i(wall_x + 1, origin.y - 2)))
	state.spawn_zombie("walker", Grid.tile_to_world(Vector2i(wall_x + 3, origin.y + 2)))
	for i: int in range(180):
		state.tick(1.0 / 60.0)
	state.clock.set_paused(true)
	var camera: Camera2D = main.get_node("World/Camera2D")
	camera.position = Grid.tile_to_world(Vector2i(wall_x + 1, origin.y + 1))
	camera.zoom = Vector2.ONE

	camera.set_process(false)
