extends RefCounted
## Completed adjacent walls and gates at native 1x, near the Command Center.

static func setup(main: Node) -> void:
	var state: GameState = Game.state
	state.clock.set_paused(true)
	state.resources.add("wood", 200)
	var origin: Vector2i = state.map.command_center_origin()
	var horizontal: Vector2i = origin + Vector2i(-3, -3)
	var vertical: Vector2i = origin + Vector2i(-5, -3)
	assert(state.map.is_free(horizontal, Vector2i(7, 1)), "Horizontal strip must be free")
	assert(state.map.is_free(vertical, Vector2i(1, 7)), "Vertical strip must be free")
	for i: int in range(7):
		var type_id: String = "gate" if i == 4 else "wooden_wall"
		_place_finished(state, type_id, horizontal + Vector2i(i, 0))
		_place_finished(state, type_id, vertical + Vector2i(0, i))
	_place_finished(state, "shelter", origin + Vector2i(3, 1))
	var reinforced_tile: Vector2i = horizontal + Vector2i(7, 0)
	assert(state.map.is_free(reinforced_tile, Vector2i.ONE))
	state.buildings.add("reinforced_wall", reinforced_tile, true)
	var camera: CameraController = main.get_node("World/Camera2D") as CameraController
	camera.zoom = Vector2.ONE
	camera.position = Vector2(origin + Vector2i(0, 1)) * Grid.TILE
	camera.set_process(false)
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 20
	main.add_child(layer)
	var title: Label = Label.new()
	title.text = "Wall tiling at 1x: 4 walls / gate / 2 walls in each direction; reinforced wall at right"
	title.position = Vector2(28, 80)
	layer.add_child(title)

static func _place_finished(state: GameState, type_id: String, tile: Vector2i) -> void:
	var result: int = state.try_place(type_id, tile)
	assert(result == Placement.Result.OK, "Scenario placement failed: %s at %s" % [type_id, tile])
	var building: Building = state.buildings.get_at(tile)
	assert(building != null)
	state.buildings.finish(building.uid)
