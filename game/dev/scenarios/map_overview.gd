extends RefCounted
## Fit the entire seeded map so entrances, bends and clearing are visible.

static func setup(main: Node) -> void:
	if main and main.has_node("World"):
		var world: Node2D = main.get_node("World")
		var camera: Camera2D = world.get_node("Camera2D")
		camera.zoom = Vector2(0.2, 0.2)
		camera.set_process(false)
		if main.has_node("BuildBarLayer"):
			(main.get_node("BuildBarLayer") as CanvasLayer).hide()
		if Game.state and Game.state.map:
			Game.state.clock.set_paused(true)
			var size: int = Game.state.map.size()
			var center_t: Vector2 = Vector2(size / 2.0, size / 2.0)
			camera.position = center_t * float(Grid.TILE)
