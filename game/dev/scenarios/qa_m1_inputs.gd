extends RefCounted
## Bounded live input routing; run with --frames=120 and --qa-report=<path>.

static func setup(main: Node) -> void:
	var failures: Array[String] = []
	var limitations: Array[String] = []
	var tree: SceneTree = main.get_tree()
	var state: GameState = Game.state
	var camera: CameraController = main.get_node("World/Camera2D") as CameraController
	var mode: BuildMode = main.get_node("World/BuildMode") as BuildMode
	var hud: CanvasLayer = main.get_node("HUD") as CanvasLayer
	var bar: BuildBar = main.get_node("BuildBarLayer") as BuildBar
	var panel: PanelContainer = bar.get_node("Panel") as PanelContainer
	var buttons: HBoxContainer = bar.get_node("Panel/HBox") as HBoxContainer
	var center: Vector2 = camera.position
	var viewport: Viewport = main.get_viewport()
	var viewport_size: Vector2 = viewport.get_visible_rect().size
	camera.set_process(false)
	state.clock.set_paused(true)
	await tree.process_frame
	await tree.process_frame
	Input.warp_mouse(viewport_size / 2.0)
	await tree.process_frame
	await tree.process_frame
	_motion(main, viewport_size / 2.0)
	for speed: int in [1, 2, 3]:
		_key(KEY_1 + speed - 1, true)
		_key(KEY_1 + speed - 1, false)
		_check(not state.clock.paused and state.clock.speed == speed, "Speed key %d" % speed, failures)
		var button: Button = hud.get("btn_%dx" % speed) as Button
		_check(button.button_pressed, "Speed key updates active HUD button", failures)
	_key(KEY_SPACE, true)
	_key(KEY_SPACE, false)
	_check(state.clock.paused, "Space pauses", failures)
	var elapsed: float = state.clock.elapsed
	# Exercise the real camera process with actual held physical-key state.
	for keycode: int in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_LEFT, KEY_DOWN, KEY_RIGHT]:
		camera.position = center
		_key(keycode, true)
		camera._process(0.1)
		_key(keycode, false)
		var movement: Vector2 = camera.position - center
		var expected: Vector2 = Vector2.ZERO
		if keycode in [KEY_W, KEY_UP]: expected = Vector2.UP
		if keycode in [KEY_A, KEY_LEFT]: expected = Vector2.LEFT
		if keycode in [KEY_S, KEY_DOWN]: expected = Vector2.DOWN
		if keycode in [KEY_D, KEY_RIGHT]: expected = Vector2.RIGHT
		_check(movement.dot(expected) > 0.0, "Camera direction for physical key %d" % keycode, failures)
	await tree.process_frame
	_check(is_equal_approx(state.clock.elapsed, elapsed), "Clock stays frozen during camera movement", failures)
	if main.get_window().has_focus():
		for point: Vector2 in [Vector2(1, viewport_size.y / 2), Vector2(viewport_size.x - 1, viewport_size.y / 2), Vector2(viewport_size.x / 2, 1), Vector2(viewport_size.x / 2, viewport_size.y - 1)]:
			camera.position = center
			# Edge pan polls the OS cursor, rather than the pushed event position.
			Input.warp_mouse(point)
			await tree.process_frame
			await tree.process_frame
			_motion(main, point)
			camera._process(0.1)
			_check((camera.position - center).dot(point - viewport_size / 2) > 0.0, "Edge pan toward %s (observed cursor %s)" % [point, viewport.get_mouse_position()], failures)
	else:
		limitations.append("OS window did not have focus; live edge-pan focus gate was not exercised")
	Input.warp_mouse(viewport_size / 2 + Vector2(160, 80))
	await tree.process_frame
	await tree.process_frame
	_motion(main, viewport_size / 2 + Vector2(160, 80))
	camera.position = center
	camera.zoom = Vector2.ONE
	var offset: Vector2 = viewport.get_mouse_position() - viewport_size / 2.0
	var anchor: Vector2 = camera.position + offset / camera.zoom.x
	_click(main, viewport.get_mouse_position(), MOUSE_BUTTON_WHEEL_UP)
	_check(camera.zoom.x > 1.0, "Wheel up zooms in", failures)
	_check((camera.position + offset / camera.zoom.x).distance_to(anchor) < 0.01, "Wheel zoom preserves cursor anchor", failures)
	_click(main, viewport.get_mouse_position(), MOUSE_BUTTON_WHEEL_DOWN)
	_check(is_equal_approx(camera.zoom.x, 1.0), "Wheel down zooms out", failures)
	for wheel: int in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP]:
		for i: int in range(30):
			_click(main, viewport.get_mouse_position(), wheel)
		_check(is_equal_approx(camera.zoom.x, 0.5 if wheel == MOUSE_BUTTON_WHEEL_DOWN else 2.0), "Wheel clamps zoom limit", failures)
	for zoom_value: float in [0.5, 1.0, 2.0]:
		camera.zoom = Vector2.ONE * zoom_value
		for corner: Vector2 in [Vector2(-10000, -10000), Vector2(10000, 10000), Vector2(-10000, 10000), Vector2(10000, -10000)]:
			camera.position = corner
			camera._process(0.0)
			var half: Vector2 = viewport_size / zoom_value / 2.0
			var minimum: Vector2 = camera.position - half
			var maximum: Vector2 = camera.position + half
			_check(minimum.x >= -0.01 and minimum.y >= -0.01 and maximum.x <= camera.map_px.x + 0.01 and maximum.y <= camera.map_px.y + 0.01, "Camera map bounds at %sx" % zoom_value, failures)
	camera.position = center
	camera.zoom = Vector2.ONE
	camera.force_update_scroll()
	_motion(main, viewport_size / 2)
	var count: int = state.buildings.all().size()
	var wood: int = state.resources.get_amount("wood")
	var gate_button: Button = buttons.get_child(1) as Button
	_click(main, gate_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_check(mode.active_type == "gate" and gate_button.button_pressed, "Build bar selects gate", failures)
	_click(main, panel.get_global_rect().position + Vector2(2, 2), MOUSE_BUTTON_LEFT)
	var top_bar: Control = hud.get("top_bar") as Control
	_click(main, top_bar.get_global_rect().position + Vector2(12, 12), MOUSE_BUTTON_LEFT)
	_check(state.buildings.all().size() == count and state.resources.get_amount("wood") == wood, "Top bar and build bar clicks never place or spend", failures)
	# Pin the same origins used by the mouse input handler to avoid OS-cursor dependence.
	var origin: Vector2i = state.map.command_center_origin() + Vector2i(-2, -2)
	mode.preview_at(origin)
	_click(main, Vector2(180, 300), MOUSE_BUTTON_LEFT, true)
	_check(mode.active_type == "gate" and state.buildings.get_at(origin) != null, "Shift-click places and retains build mode", failures)
	mode.preview_at(origin + Vector2i(1, 0))
	_click(main, Vector2(180, 300), MOUSE_BUTTON_LEFT, true)
	_check(state.buildings.count_of("gate") == 2, "Second shift-click repeats placement", failures)
	_click(main, Vector2(180, 300), MOUSE_BUTTON_RIGHT)
	_check(mode.active_type == "" and not gate_button.button_pressed, "Right-click cancels selection", failures)
	mode.select("shelter")
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	_check(mode.active_type == "", "Escape cancels selection", failures)
	mode.select("wooden_wall")
	var line_start: Vector2i = state.map.command_center_origin() + Vector2i(-2, 3)
	var wall_cost: int = int(state.data.get_building("wooden_wall")["cost"]["wood"])
	state.resources.take("wood", state.resources.get_amount("wood"))
	state.resources.add("wood", wall_cost * 3 + wall_cost - 1)
	mode.preview_at(line_start)
	_mouse_button(main, Vector2(180, 300), MOUSE_BUTTON_LEFT, true, false)
	mode.preview_at(line_start + Vector2i(5, 0))
	_mouse_button(main, Vector2(180, 300), MOUSE_BUTTON_LEFT, false, false)
	_check(state.buildings.count_of("wooden_wall") == 3 and state.resources.get_amount("wood") == wall_cost - 1, "Wall input drag stops when wood runs out", failures)
	_check(mode.active_type == "", "Non-shift drag exits build mode", failures)
	for kind: String in ResourceStore.KINDS:
		var label: Label = hud.get(kind + "_label") as Label
		var icon: TextureRect = hud.get(kind + "_icon") as TextureRect
		_check(label.text == str(state.resources.get_amount(kind)) and icon.texture != null, "HUD resource icon/amount " + kind, failures)
	var report_path: String = "res://../project/runs/T-010/a1/input_checks.json"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-report="):
			report_path = argument.trim_prefix("--qa-report=")
	var file: FileAccess = FileAccess.open(report_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": failures.is_empty(), "failures": failures, "limitations": limitations}, "\t"))
	file.close()
	print("M1 live input QA: %d failures; %d limitations" % [failures.size(), limitations.size()])

static func _motion(main: Node, position: Vector2) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	main.get_viewport().push_input(event)

static func _key(keycode: int, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

static func _click(main: Node, position: Vector2, button: int, shift: bool = false) -> void:
	for pressed: bool in [true, false]:
		_mouse_button(main, position, button, pressed, shift)

static func _mouse_button(main: Node, position: Vector2, button: int, pressed: bool, shift: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	event.position = position
	event.global_position = position
	event.pressed = pressed
	event.shift_pressed = shift
	main.get_viewport().push_input(event)

static func _check(condition: bool, description: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(description)
