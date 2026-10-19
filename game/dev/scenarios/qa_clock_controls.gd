extends RefCounted
## Integration checks through the live viewport's input pipeline.

static func setup(main: Node) -> void:
	Game.state.waves.enabled = false
	var failures: Array[String] = []
	var tree: SceneTree = main.get_tree()
	var clock: GameClock = Game.state.clock
	var hud: CanvasLayer = main.get_node("HUD")
	var camera: CameraController = main.get_node("World/Camera2D")
	clock.set_paused(true)
	await tree.process_frame
	await tree.process_frame
	for speed: int in [3, 2, 1]:
		_send_key(main, KEY_1 + speed - 1, true)
		_send_key(main, KEY_1 + speed - 1, false)
		await tree.process_frame
		await tree.process_frame
		_check(clock.speed == speed and not clock.paused,
			"Physical key %d must select speed and unpause" % speed, failures)
		var button: Button = hud.get("btn_%dx" % speed)
		_check(button.button_pressed, "Speed button must follow key %d" % speed, failures)
	_send_key(main, KEY_SPACE, true)
	_send_key(main, KEY_SPACE, false)
	await tree.process_frame
	await tree.process_frame
	_check(clock.paused, "Space must pause", failures)
	var elapsed: float = clock.elapsed
	var before: Vector2 = camera.position
	_send_key(main, KEY_D, true)
	_check(Input.is_action_pressed("cam_right"), "Physical D must enter the held input state", failures)
	for frame: int in range(8):
		await tree.process_frame
	_send_key(main, KEY_D, false)
	_check(camera.position.x > before.x, "D must pan the camera while paused", failures)
	_check(is_equal_approx(clock.elapsed, elapsed), "Paused clock must remain frozen while panning", failures)
	_send_key(main, KEY_SPACE, true)
	_send_key(main, KEY_SPACE, false)
	await tree.process_frame
	await tree.process_frame
	_check(not clock.paused, "Second Space must resume", failures)
	var pause_button: Button = hud.get("btn_pause")
	_click(main, pause_button)
	await tree.process_frame
	await tree.process_frame
	_check(clock.paused and pause_button.button_pressed, "Click Pause must pause and select Pause", failures)
	var speed_button: Button = hud.get("btn_2x")
	_click(main, speed_button)
	await tree.process_frame
	await tree.process_frame
	_check(not clock.paused and clock.speed == 2 and speed_button.button_pressed,
		"Click 2x must resume at speed 2 and select 2x", failures)
	_send_key(main, KEY_SPACE, true)
	_send_key(main, KEY_SPACE, false)
	await tree.process_frame
	await tree.process_frame
	_check(clock.paused, "Space after button clicks must toggle exactly once", failures)
	_check(main.get_viewport().gui_get_focus_owner() == null, "Clock buttons must not steal keyboard focus", failures)
	var file: FileAccess = FileAccess.open("res://../project/runs/T-009/a1/clock_controls_qa.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": failures.is_empty(), "failures": failures,
		"camera_pan_x": camera.position.x - before.x, "paused_elapsed": elapsed,
		"scene_tree_paused": tree.paused, "engine_time_scale": Engine.time_scale}, "\t"))
	file.close()
	# Restore the requested screenshot state once the integration checks finish.
	clock.day = 1
	clock.phase = GameClock.Phase.DAY
	clock.elapsed = 0.0
	var day_length: float = float(Game.state.data.balance("day_length"))
	var night_length: float = float(Game.state.data.balance("night_min_length"))
	clock.advance(day_length + night_length + day_length - 100.0)
	clock.set_paused(true)
	camera.position = before

static func _send_key(main: Node, keycode: int, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

static func _click(main: Node, button: Button) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = button.get_global_rect().get_center()
		event.global_position = event.position
		main.get_viewport().push_input(event)

static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
