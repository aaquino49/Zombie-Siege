extends RefCounted
## Each type overlaps a wall from the north (behind) and south (in front).

static func setup(main: Node) -> void:
	var state: GameState = Game.state
	state.waves.enabled = false
	state.clock.set_paused(true)
	var origin: Vector2i = state.map.command_center_origin() + Vector2i(6, 0)
	for y: int in range(origin.y - 3, origin.y + 4):
		for x: int in range(origin.x - 2, origin.x + 11):
			var tile := Vector2i(x, y)
			if state.map.occupant_at(tile) != WorldMap.Occupant.BUILDING:
				state.map._occupants[tile] = WorldMap.Occupant.NONE
				state.map._node_amounts.erase(tile)
	state.map.changed.emit()
	main.get_node("World")._draw_props()
	main.get_node("World")._draw_ground_detail()
	for index: int in range(ZombieLayer.TYPES.size()):
		var center: Vector2i = origin + Vector2i(index * 4, 0)
		state.buildings.add("wooden_wall", center + Vector2i.LEFT, true)
		var wall: Building = state.buildings.add("wooden_wall", center, true)
		state.buildings.add("wooden_wall", center + Vector2i.RIGHT, true)
		for south: bool in [false, true]:
			var z: Zombie = state.spawn_zombie(ZombieLayer.TYPES[index], wall.center_world() + Vector2(0, 48 if south else -12))
			z.facing = Vector2.UP if south else Vector2.DOWN
			z.target_building_uid = wall.uid
	var camera: Camera2D = main.get_node("World/Camera2D")
	camera.position = Grid.tile_to_world(origin + Vector2i(4, -1))
	camera.zoom = Vector2.ONE
	camera.set_process(false)
