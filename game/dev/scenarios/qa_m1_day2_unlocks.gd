extends RefCounted
## Reach dawn through GameState.tick, then buy all three new building types.

static func setup(main: Node) -> void:
	Game.state.waves.enabled = false
	var state: GameState = Game.state
	state.tick(float(state.data.balance("day_length")) + float(state.data.balance("night_min_length")))
	state.clock.set_paused(true)
	state.resources.add("wood", 100)
	var origin: Vector2i = state.map.command_center_origin()
	assert(state.try_place("storage", origin + Vector2i(-2, -2)) == Placement.Result.OK)
	assert(state.try_place("workshop", origin + Vector2i(2, -2)) == Placement.Result.OK)
	assert(state.try_place("watchtower", origin + Vector2i(3, 1)) == Placement.Result.OK)
	assert(state.clock.day == 2)
	main.get_node("World/Camera2D").set_process(false)
