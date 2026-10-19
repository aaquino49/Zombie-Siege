extends RefCounted
## Reuses the submitted scenario, with unobstructed framing for visual QA.

static func setup(main: Node) -> void:
	preload("res://dev/scenarios/buildings_pixel.gd").setup(main)
	var state: GameState = Game.state
	state.clock.elapsed = 10.0
	var o: Vector2i = state.map.command_center_origin()
	for type_id: String in state.data.building_ids():
		print("QA T104 count ", type_id, ": ", state.buildings.all_of_type(type_id).size())
	print("QA T104 reinforced ring tile: ", state.map.building_at(o + Vector2i(1, 4)))
	var camera: Camera2D = main.get_node("World/Camera2D") as Camera2D
	camera.position = Grid.tile_to_world(o) + Vector2(0, 96)
	camera.zoom = Vector2(0.75, 0.75)
	main.get_node("BuildBarLayer/Panel").hide()
	main.get_node("HUD/PhaseBanner").set_process(false)
	main.get_node("HUD/PhaseBanner").hide()
	main.get_node("World/DayNightTint").set_process(false)
	main.get_node("World/DayNightTint").set("color", Color.WHITE)
	# A second diagnostic view exposes tall build-bar icons and the footprint outline.
	if "--qa-icons" in OS.get_cmdline_user_args():
		(main.get_node("BuildBarLayer") as BuildBar).refresh(8)
		main.get_node("BuildBarLayer/Panel").show()
		var storage: Building = state.buildings.all_of_type("storage")[0]
		main.get_node("World/Selection").call("select_building", storage.uid)
	if "--qa-ring" in OS.get_cmdline_user_args():
		camera.position = Grid.tile_to_world(o + Vector2i(0, 5))
		camera.zoom = Vector2(2, 2)
