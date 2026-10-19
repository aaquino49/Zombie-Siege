extends RefCounted
## Normal minimum zoom at the top-left clamp, with seeded-map evidence.

static func setup(main: Node) -> void:
	var state: GameState = Game.state
	state.clock.set_paused(true)
	var duplicate: GameState = GameState.new(state.data, state.map_seed)
	var counts: Dictionary = {"tree": 0, "scrap": 0, "rock": 0, "building": 0}
	var matching: bool = true
	for x: int in range(state.map.size()):
		for y: int in range(state.map.size()):
			var tile: Vector2i = Vector2i(x, y)
			var occupant: int = state.map.occupant_at(tile)
			matching = matching and occupant == duplicate.map.occupant_at(tile)
			matching = matching and state.map.terrain_at(tile) == duplicate.map.terrain_at(tile)
			matching = matching and state.map.get_node_amount(tile) == duplicate.map.get_node_amount(tile)
			match occupant:
				WorldMap.Occupant.TREE: counts["tree"] += 1
				WorldMap.Occupant.SCRAP: counts["scrap"] += 1
				WorldMap.Occupant.ROCK: counts["rock"] += 1
				WorldMap.Occupant.BUILDING: counts["building"] += 1
	assert(matching)
	assert(state.map.size() == 48)
	assert(counts["tree"] > 0 and counts["scrap"] > 0 and counts["rock"] > 0 and counts["building"] == 4)
	var camera: CameraController = main.get_node("World/Camera2D") as CameraController
	camera.zoom = Vector2(0.5, 0.5)
	camera.position = CameraMath.clamp_position(Vector2.ZERO, 0.5, main.get_viewport().get_visible_rect().size, camera.map_px)
	camera.set_process(false)
	print("M1 seeded map QA: size=%d seed=%d matching=%s counts=%s" % [state.map.size(), state.map_seed, matching, counts])
