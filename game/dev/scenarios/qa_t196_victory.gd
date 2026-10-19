extends RefCounted

static func setup(main: Node) -> void:
	var path: String = "user://qa_t196_victory_%d.cfg" % OS.get_process_id()
	Records.remove_file(path)
	main.tree_exiting.connect(func() -> void: Records.remove_file(path), CONNECT_ONE_SHOT)
	(main.get_node("VictoryScreen") as VictoryScreen).records_path = path
	VictorySetup.trigger_win()
	(main.get_node("World/RescueHelicopter") as RescueHelicopter).skip()
