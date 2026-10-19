extends RefCounted

const RUNNER := preload("res://dev/scenarios/qa_t146_continue_flow_runner.gd")

static func setup(main: Node) -> void:
	var runner: Node = RUNNER.new()
	runner.process_mode = Node.PROCESS_MODE_ALWAYS
	main.get_tree().root.add_child(runner)
	runner.call_deferred("run", main)
