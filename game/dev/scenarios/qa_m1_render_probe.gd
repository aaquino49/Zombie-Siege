extends RefCounted
## Compare initial terrain rendering with a small pan and return to center.

static func setup(main: Node) -> void:
	Game.state.clock.set_paused(true)
	var camera: CameraController = main.get_node("World/Camera2D") as CameraController
	camera.set_process(false)
	var center: Vector2 = camera.position
	var ground: TileMapLayer = main.get_node("World/Ground") as TileMapLayer
	var roads: Array[Vector2i] = []
	for x: int in range(14, 34):
		var tile: Vector2i = Vector2i(x, 24)
		if Game.state.map.terrain_at(tile) == WorldMap.Terrain.ROAD:
			roads.append(tile)
			print("M1 road probe: tile=%s source=%s" % [tile, ground.get_cell_source_id(tile)])
	print("M1 road probe: center=%s roads=%s" % [center, roads])
	for frame: int in range(20):
		await main.get_tree().process_frame
	await RenderingServer.frame_post_draw
	main.get_viewport().get_texture().get_image().save_png("res://../project/runs/T-010/a1/qa_m1_render_initial.png")
	camera.position += Vector2(16, -48)
	for frame: int in range(20):
		await main.get_tree().process_frame
	await RenderingServer.frame_post_draw
	main.get_viewport().get_texture().get_image().save_png("res://../project/runs/T-010/a1/qa_m1_render_panned.png")
	camera.position = center
