extends RefCounted

static func setup(main: Node) -> void:
	var records_path := "user://t196_main_menu_records.cfg"
	Records.remove_file(records_path)
	main.tree_exiting.connect(func() -> void: Records.remove_file(records_path), CONNECT_ONE_SHOT)
	Records.submit("easy", 12, false, 0.0, records_path)
	Records.submit("normal", 23, false, 0.0, records_path)
	Records.submit("hard", 9, false, 0.0, records_path)
	Game.save_path = "user://t146_main_menu_empty.json"
	Game.delete_save()
	var state: GameState = Game.state
	(main.get_node("MainMenu") as MainMenu).records_path = records_path
	var camera: Camera2D = main.get_node("World/Camera2D")
	var cc = state.buildings.all_of_type("command_center")[0]
	camera.position = cc.center_world()
	main.get_node("MainMenu").open(state)
	# Seek to the approach; frame 120 catches a shot and the first blood burst.
	main.get_node("MainMenu/TitleScene").start_capture()
