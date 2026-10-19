extends RefCounted

static func setup(main: Node) -> void:
	var runner: Node = preload("res://dev/scenarios/qa_m9_runner.gd").new()
	runner.process_mode = Node.PROCESS_MODE_ALWAYS
	main.get_tree().root.add_child(runner)
	runner.call_deferred("run", main, "endless")
