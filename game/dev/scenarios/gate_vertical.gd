extends RefCounted

static func setup(main: Node) -> void:
	var game_obj: Object = main.get_node("/root/Game")
	var state: GameState = game_obj.get("state") if game_obj else null
	if state == null:
		return
	state.waves.enabled = false
	state.clock.set_paused(true)
	state.clock.day = 8
	state.clock.elapsed = 10.0
	state.resources.add("wood", 500)
	var o: Vector2i = state.map.command_center_origin()
	var vertical_x: int = o.x
	var horizontal_y: int = o.y - 4
	var horizontal_x: int = vertical_x + 9

	# Clear a three-tile-wide corridor around both wall lines before placing them.
	# Vacating occupants alone does not remove the already-drawn prop/detail sprites.
	for dy in range(-2, 3):
		for dx in range(-1, 2):
			var tile := Vector2i(vertical_x + dx, horizontal_y + dy)
			if state.map.occupant_at(tile) != WorldMap.Occupant.NONE:
				state.map.vacate(tile, Vector2i.ONE)
	for dx in range(-2, 3):
		for dy in range(-1, 2):
			var tile := Vector2i(horizontal_x + dx, horizontal_y + dy)
			if state.map.occupant_at(tile) != WorldMap.Occupant.NONE:
				state.map.vacate(tile, Vector2i.ONE)

	var world: Node = main.get_node("World")
	if world and world.has_method("_draw_props"):
		world._draw_props()
	if world and world.has_method("_draw_ground_detail"):
		world._draw_ground_detail()

	for dx in range(-2, 3):
		var tile := Vector2i(horizontal_x + dx, horizontal_y)
		if dx == 0:
			state.try_place("gate", tile)
		else:
			state.try_place("wooden_wall", tile)
	for dy in range(-2, 3):
		var tile := Vector2i(vertical_x, horizontal_y + dy)
		if dy == 0:
			state.try_place("gate", tile)
		else:
			state.try_place("wooden_wall", tile)
	for b: Building in state.buildings.blueprints():
		state.buildings.finish(b.uid)

	var camera: Camera2D = main.get_node("World/Camera2D") as Camera2D
	if camera:
		camera.position = Grid.tile_to_world(o) + Vector2(48, -96)
		camera.zoom = Vector2(0.75, 0.75)

