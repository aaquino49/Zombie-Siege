extends RefCounted
## Morale night: a completed Campfire flickers (four-frame strip at 6 fps)
## under its warm night light next to the Command Center. Night, unpaused
## so the flame animates for the capture, with waves disabled.

static func setup(main: Node) -> void:
	var state: GameState = Game.state
	state.waves.enabled = false
	state.clock.day = 3
	state.clock.phase = GameClock.Phase.NIGHT
	state.clock.elapsed = 10.0

	var origin: Vector2i = state.map.command_center_origin()
	state.resources.add("wood", 100)
	var tile: Vector2i = origin + Vector2i(-3, 2)
	for candidate: Vector2i in [origin + Vector2i(-3, 2), origin + Vector2i(3, 2),
			origin + Vector2i(-3, -3), origin + Vector2i(3, -3)]:
		if state.buildings.get_at(candidate) != null:
			continue
		if state.try_place("campfire", candidate) == Placement.Result.OK:
			tile = candidate
			break
	var fire: Building = state.buildings.get_at(tile)
	if fire != null and not fire.complete:
		state.buildings.finish(fire.uid)

	var camera: Camera2D = main.get_node("World/Camera2D")
	camera.position = Grid.tile_to_world(tile) + Vector2(Grid.TILE / 2.0, 0)
	camera.zoom = Vector2.ONE
	camera.set_process(false)
