extends RefCounted
## Bounded rendered integration checks for the v1.1 build-card and shake extras.

static func setup(main: Node) -> void:
	var state: GameState = Game.state
	state.clock.set_paused(true)
	var tree: SceneTree = main.get_tree()
	var out: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			out = arg.trim_prefix("--capture-dir=")
	var checks: Array[String] = []
	var failures: Array[String] = []
	await tree.process_frame
	await tree.process_frame
	var bar: BuildBar = main.get_node("BuildBarLayer")
	for type_id: String in ["wooden_wall", "shelter"]:
		var button: Button = bar._button_for(type_id)
		button.mouse_entered.emit()
		for _frame: int in range(12):
			await tree.process_frame
		var card: BuildInfoCard = bar.get_node("BuildInfoCard")
		var rect: Rect2 = card.get_global_rect()
		_check(checks, failures, card.visible and card.current_type() == type_id,
			"Day 1 hover shows " + type_id)
		_check(checks, failures, tree.root.get_visible_rect().encloses(rect) and rect.position.y > 80.0,
			"Card stays on screen below top bar: " + type_id)
		if not out.is_empty() and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			main.get_viewport().get_texture().get_image().save_png(out.path_join("hover_" + type_id + ".png"))
		button.mouse_exited.emit()
	var existed: bool = FileAccess.file_exists(GameSettings.PATH)
	var original: PackedByteArray = FileAccess.get_file_as_bytes(GameSettings.PATH) if existed else PackedByteArray()
	var settings: SettingsScreen = main.get_node("SettingsScreen")
	var toggle: CheckButton = settings.get_node("Dim/Center/Panel/Margin/Content/Options/ScreenShake")
	toggle.set_pressed_no_signal(true)
	toggle.button_pressed = false
	var camera: CameraController = main.get_node("World/Camera2D")
	camera._tick_shake(0.6)
	camera.shake.add(1.0)
	camera._tick_shake(0.01)
	_check(checks, failures, not GameSettings.load_screen_shake() and not camera.shake.enabled and camera.offset == Vector2.ZERO,
		"Settings toggle disables shake in the live camera")
	if existed:
		var restored: FileAccess = FileAccess.open(GameSettings.PATH, FileAccess.WRITE)
		restored.store_buffer(original)
		restored.close()
	else:
		DirAccess.remove_absolute(GameSettings.PATH)
	var result: Dictionary = {"checks": checks, "failures": failures, "passed": failures.is_empty()}
	if not out.is_empty():
		var file: FileAccess = FileAccess.open(out.path_join("extras_flow.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(result, "\t"))
		file.close()
	print("T113 EXTRAS ", JSON.stringify(result))
	for failure: String in failures:
		push_error(failure)

static func _check(checks: Array[String], failures: Array[String], condition: bool, description: String) -> void:
	checks.append(description)
	if not condition:
		failures.append(description)
