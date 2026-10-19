extends RefCounted
## Twelve-tile line: seven affordable walls and an unaffordable remainder.

static func setup(main: Node) -> void:
	var state: GameState = Game.state
	state.clock.set_paused(true)
	var start: Vector2i = state.map.command_center_origin() + Vector2i(-5, -3)
	# Find an intact strip without modifying the seeded map.
	var found: bool = false
	for y: int in range(start.y - 2, start.y + 3):
		var candidate: Vector2i = Vector2i(start.x, y)
		if state.map.is_free(candidate, Vector2i(12, 1)):
			start = candidate
			found = true
			break
	assert(found, "Seeded map must offer a twelve-tile test strip")
	var cost: int = int(state.data.get_building("wooden_wall")["cost"]["wood"])
	state.resources.take("wood", state.resources.get_amount("wood"))
	state.resources.add("wood", cost * 7 + cost - 1)
	var placed: int = 0
	for tile: Vector2i in Placement.line_tiles(start, start + Vector2i(11, 0)):
		var result: int = state.try_place("wooden_wall", tile)
		if result == Placement.Result.UNAFFORDABLE:
			break
		assert(result == Placement.Result.OK)
		placed += 1
	assert(placed == 7)
	assert(state.resources.get_amount("wood") == cost - 1)
	var mode: BuildMode = main.get_node("World/BuildMode") as BuildMode
	mode.select("wooden_wall")
	mode.preview_at(start + Vector2i(7, 0))
	var camera: CameraController = main.get_node("World/Camera2D") as CameraController
	var cc_center: Vector2 = Vector2(state.map.command_center_origin() + Vector2i.ONE) * Grid.TILE
	camera.position = (Grid.tile_to_world(start + Vector2i(5, 0)) + cc_center) / 2.0
	camera.set_process(false)
