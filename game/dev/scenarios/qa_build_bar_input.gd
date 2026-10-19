extends RefCounted
## Bounded live input checks, run with --frames=120 and --screenshot.

static func setup(main: Node) -> void:
	var failures: Array[String] = []
	var tree: SceneTree = main.get_tree()
	var state: GameState = Game.state
	var bar: BuildBar = main.get_node("BuildBarLayer") as BuildBar
	var panel: PanelContainer = bar.get_node("Panel") as PanelContainer
	var buttons: HBoxContainer = bar.get_node("Panel/HBox") as HBoxContainer
	var mode: BuildMode = main.get_node("World/BuildMode") as BuildMode
	state.clock.set_paused(true)
	await tree.process_frame
	await tree.process_frame
	var gate: Button = buttons.get_child(1) as Button
	var count: int = state.buildings.all().size()
	var wood: int = state.resources.get_amount("wood")
	_click(main, gate.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_check(mode.active_type == "gate" and gate.button_pressed, "Click gate must select BuildMode and press the button", failures)
	_check(state.buildings.all().size() == count and state.resources.get_amount("wood") == wood, "Selection click must not place or spend", failures)
	_click(main, gate.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_check(mode.active_type == "" and not gate.button_pressed, "Second click must cancel", failures)
	var cost_icon: Control = gate.get_node("Content/Cost/WoodIcon") as Control
	_click(main, cost_icon.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_check(mode.active_type == "gate" and gate.button_pressed, "Cost icon and backing must pass clicks to button", failures)
	var cost_amount: Control = gate.get_node("Content/Cost/WoodAmount") as Control
	_click(main, cost_amount.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_check(mode.active_type == "" and not gate.button_pressed, "Cost number must pass clicks to button", failures)
	_click(main, gate.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_key(KEY_ESCAPE)
	_check(mode.active_type == "" and not gate.button_pressed, "Esc must cancel and unpress", failures)
	_click(main, gate.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_click(main, Vector2(100, 100), MOUSE_BUTTON_RIGHT)
	_check(mode.active_type == "" and not gate.button_pressed, "World right-click must cancel and unpress", failures)
	_click(main, gate.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_click(main, panel.get_global_rect().position + Vector2(2, 2), MOUSE_BUTTON_LEFT)
	_check(mode.active_type == "gate" and state.buildings.all().size() == count and state.resources.get_amount("wood") == wood, "Panel padding click must be swallowed", failures)
	_key(KEY_B)
	_check(not panel.visible, "B must hide bar", failures)
	_key(KEY_B)
	_check(panel.visible, "Second B must show bar", failures)
	_key(KEY_ESCAPE)
	state.resources.take("wood", wood)
	_click(main, gate.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_check(mode.active_type == "gate" and gate.button_pressed and is_equal_approx(gate.modulate.a, 0.5), "Dimmed button must still select", failures)
	_check(state.buildings.all().size() == count, "Bar clicks must never place", failures)
	state.resources.add("wood", wood)
	_key(KEY_ESCAPE)
	var report_path: String = "res://../project/runs/T-046/a1/build_bar_input_qa.json"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-report="):
			report_path = argument.trim_prefix("--qa-report=")
	var file: FileAccess = FileAccess.open(report_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": failures.is_empty(), "failures": failures}, "\t"))
	file.close()
	for failure: String in failures:
		push_error("Build bar QA: " + failure)
	print("Build bar live input QA: %d failures" % failures.size())

static func _click(main: Node, position: Vector2, button_index: int) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = button_index
		event.pressed = pressed
		event.position = position
		event.global_position = position
		main.get_viewport().push_input(event)

static func _key(keycode: int) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = keycode
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()

static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
