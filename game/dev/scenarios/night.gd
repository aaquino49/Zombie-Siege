extends RefCounted

const Siege: GDScript = preload("res://dev/scenarios/zombies.gd")

static func setup(main: Node) -> void:
	var state: GameState = Game.state
	var origin: Vector2i = state.map.command_center_origin()
	# A readable mixed siege, with the existing real-AI wall attack fixture.
	for y: int in range(origin.y - 5, origin.y + 8):
		for x: int in range(origin.x - 4, origin.x + 14):
			var tile := Vector2i(x, y)
			if state.map.occupant_at(tile) != WorldMap.Occupant.BUILDING:
				state.map._occupants[tile] = WorldMap.Occupant.NONE
				state.map._node_amounts.erase(tile)
	state.map.changed.emit()
	main.get_node("World")._draw_props()
	main.get_node("World")._draw_ground_detail()
	Siege.setup(main)
	var camera: Camera2D = main.get_node("World/Camera2D")
	camera.position = Grid.tile_to_world(origin + Vector2i(5, 0)) + Vector2(0, Grid.TILE / 2.0)
	camera.zoom = Vector2.ONE
	camera.set_process(false)
