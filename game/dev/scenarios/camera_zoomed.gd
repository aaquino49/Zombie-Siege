extends RefCounted

static func setup(main: Node) -> void:
	var world: Node2D = main.get_node("World")
	
	# Force camera near top-left corner
	var cam: CameraController = world.get_node("Camera2D")
	cam.zoom = Vector2(2.0, 2.0)
	
	# Aim at tile (2, 2)
	cam.position = Vector2(2, 2) * Grid.TILE
	
	var map_px: Vector2 = cam.map_px
	if Game.state and Game.state.map:
		var size: int = Game.state.map.size()
		map_px = Vector2(size, size) * Grid.TILE
	
	cam.map_px = map_px
	
	cam.position = CameraMath.clamp_position(cam.position, cam.zoom.x, CameraMath.viewport_size_for(cam), map_px)
