extends SceneTree
## Bounded live QA: --script res://dev/scenarios/qa_t025_menu_flow.gd -- --quit-frames=600.
## No --scenario argument, so the real default launch and reload menu condition applies.

const RELOAD_WAIT_MAX_FRAMES: int = 180

func _initialize() -> void:
	_launch.call_deferred()

func _launch() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await setup(main)

static func setup(main: Node) -> void:
	var tree: SceneTree = main.get_tree()
	var game: Node = tree.root.get_node("Game")
	var failures: Array[String] = []
	var checks: Array[String] = []
	await _frames(tree, 3)
	var initial_seed: int = game.state.map_seed
	_check(main.get_node("MainMenu").visible, "Default launch shows main menu", failures, checks)
	_check(game.state.clock.paused and game.state.clock.locked, "Menu pauses and locks clock", failures, checks)
	_check(not main.get_node("HUD").visible and not main.get_node("BuildBarLayer").visible and not main.get_node("RosterPanel").visible,
		"Menu hides gameplay layers", failures, checks)
	await _capture(tree, "qa_default_launch.png")
	for pair: Array in [["HowToPlay", "HowToPlay"], ["Settings", "SettingsScreen"], ["Credits", "CreditsScreen"]]:
		main.get_node("MainMenu/Dim/Center/Panel/Margin/Content/Buttons/" + pair[0]).pressed.emit()
		await _frames(tree, 2)
		_check(main.get_node(pair[1]).visible, "Main menu opens " + pair[1], failures, checks)
		_key(KEY_ESCAPE, true)
		_key(KEY_ESCAPE, false)
		_check(main.get_node("MainMenu").visible and not main.get_node(pair[1]).visible, "Esc returns from " + pair[1], failures, checks)

	var camera: Camera2D = main.get_node("World/Camera2D")
	var before: Vector2 = camera.position
	_key(KEY_D, true)
	await _frames(tree, 6)
	_key(KEY_D, false)
	_check(camera.position.is_equal_approx(before), "Menu blocks D camera pan (movement=%s)" % (camera.position - before), failures, checks)
	for keycode: int in [KEY_SPACE, KEY_1, KEY_2, KEY_3]:
		_key(keycode, true)
		_key(keycode, false)
	_check(game.state.clock.paused and game.state.clock.locked, "Menu blocks clock keyboard controls", failures, checks)
	var bar_panel: Control = main.get_node("BuildBarLayer/Panel")
	var bar_visible: bool = bar_panel.visible
	_key(KEY_B, true)
	_key(KEY_B, false)
	_check(bar_panel.visible == bar_visible, "Menu blocks build-menu keyboard toggle", failures, checks)
	var roster: Node = main.get_node("RosterPanel")
	var roster_open: bool = roster.is_open()
	_key(KEY_R, true)
	_key(KEY_R, false)
	_check(roster.is_open() == roster_open, "Menu blocks roster keyboard toggle", failures, checks)
	var count: int = game.state.buildings.all().size()
	_click(tree, Vector2(200, 180))
	_check(game.state.buildings.all().size() == count and main.get_node("World/Selection").selected_kind == "",
		"Menu dim blocks world clicks", failures, checks)
	camera = null
	bar_panel = null
	roster = null
	await _button_reload(tree, "MainMenu", "NewGame", failures, checks)
	_check(game.state.map_seed != initial_seed and game.next_seed == game.state.map_seed, "New Game uses a fresh seed", failures, checks)
	_running(tree, failures, checks)
	await _capture(tree, "qa_new_game.png")
	var seed_value: int = game.state.map_seed
	for terminal: String in ["GameOverScreen", "VictoryScreen"]:
		_terminal(tree, terminal)
		_check(tree.current_scene.get_node(terminal).visible, terminal + " opens", failures, checks)
		await _frames(tree, 3)
		await _button_reload(tree, terminal, "Restart", failures, checks)
		_check(game.state.map_seed == seed_value and game.next_seed == seed_value, terminal + " Restart preserves seed", failures, checks)
		_running(tree, failures, checks)
	for terminal: String in ["GameOverScreen", "VictoryScreen"]:
		_terminal(tree, terminal)
		await _frames(tree, 3)
		await _button_reload(tree, terminal, "MainMenu", failures, checks)
		_check(tree.current_scene.get_node("MainMenu").visible and game.show_menu, terminal + " Main Menu returns to menu", failures, checks)
		_check(game.state.clock.paused and game.state.clock.locked, terminal + " Main Menu locks fresh state", failures, checks)
		await _button_reload(tree, "MainMenu", "NewGame", failures, checks)
		_check(game.state.map_seed != seed_value, "New Game after " + terminal + " changes seed", failures, checks)
		seed_value = game.state.map_seed
		_running(tree, failures, checks)
	var old_ref: WeakRef = weakref(game.state)
	game.quit_to_menu()
	await _wait_freed(tree, old_ref, RELOAD_WAIT_MAX_FRAMES)
	await _frames(tree, 4)
	await _wait_transition_complete(tree, game, RELOAD_WAIT_MAX_FRAMES)
	var report_path: String = ProjectSettings.globalize_path("res://../project/runs/T-025/a1/qa_live_flow.json")
	for arg: String in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if arg.begins_with("--flow-report="):
			report_path = arg.trim_prefix("--flow-report=")
	var file: FileAccess = FileAccess.open(report_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": failures.is_empty(), "failures": failures, "checks": checks}, "\t"))
	file.close()
	print("T-025 live QA: %d checks, %d failures; exercising Quit button" % [checks.size(), failures.size()])
	tree.current_scene.get_node("MainMenu/Dim/Center/Panel/Margin/Content/Buttons/Quit").pressed.emit()

static func _terminal(tree: SceneTree, terminal: String) -> void:
	if terminal == "VictoryScreen":
		(load("res://dev/scenarios/victory_setup.gd") as GDScript).call("trigger_win")
		tree.current_scene.get_node("VictoryScreen").visible = true
	else:
		load("res://dev/scenarios/game_over.gd").setup(tree.current_scene)

static func _running(tree: SceneTree, failures: Array[String], checks: Array[String]) -> void:
	var game: Node = tree.root.get_node("Game")
	_check(not tree.current_scene.get_node("MainMenu").visible and not game.show_menu, "Reload hides menu for gameplay", failures, checks)
	_check(not game.state.clock.paused and not game.state.clock.locked and not game.state.game_over and game.state.clock.day == 1,
		"Reload creates fresh running day-1 state", failures, checks)
	_check(tree.current_scene.get_node("HUD").visible and tree.current_scene.get_node("BuildBarLayer").visible, "Reload restores HUD and build bar", failures, checks)

static func _button_reload(tree: SceneTree, overlay: String, button_name: String, failures: Array[String], checks: Array[String]) -> void:
	var game: Node = tree.root.get_node("Game")
	var old_ref: WeakRef = weakref(game.state)
	var button: Button = tree.current_scene.get_node(overlay + "/Dim/Center/Panel/Margin/Content/Buttons/" + button_name)
	var button_visible: bool = button.is_visible_in_tree()
	if button_visible:
		button.pressed.emit()
	button = null
	if overlay == "MainMenu" and button_name == "NewGame":
		var picker: Node = tree.current_scene.get_node("MainMenu/DifficultyPicker")
		await _wait_visible(tree, picker, RELOAD_WAIT_MAX_FRAMES)
		_check(picker.visible, "MainMenu/NewGame opens difficulty picker", failures, checks)
		var hard: Button = picker.get_node("Dim/Center/Panel/Margin/Content/Options/Hard/Select")
		var hard_visible: bool = hard.is_visible_in_tree()
		if hard_visible:
			hard.pressed.emit()
		_check(hard_visible, "Difficulty picker Hard option is visible", failures, checks)
	await _wait_freed(tree, old_ref, RELOAD_WAIT_MAX_FRAMES)
	await _frames(tree, 4)
	await _wait_transition_complete(tree, game, RELOAD_WAIT_MAX_FRAMES)
	_check(button_visible and old_ref.get_ref() == null,
		overlay + "/" + button_name + " is visible and frees previous GameState", failures, checks)
	if overlay == "MainMenu" and button_name == "NewGame":
		_check(game.state != null and game.state.difficulty == "hard",
			"New Game picker starts a hard game", failures, checks)

static func _wait_visible(tree: SceneTree, node: Node, max_frames: int) -> void:
	for i: int in range(max_frames):
		if node.visible:
			return
		await tree.process_frame

static func _wait_freed(tree: SceneTree, ref: WeakRef, max_frames: int) -> void:
	for i: int in range(max_frames):
		if ref.get_ref() == null:
			return
		await tree.process_frame

static func _wait_transition_complete(tree: SceneTree, game: Node, max_frames: int) -> void:
	for i: int in range(max_frames):
		if not game.transitioning:
			return
		await tree.process_frame

static func _frames(tree: SceneTree, count: int) -> void:
	for i: int in range(count):
		await tree.process_frame

static func _capture(tree: SceneTree, filename: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var path: String = ProjectSettings.globalize_path("res://../project/runs/T-025/a1/" + filename)
	for arg: String in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			path = arg.trim_prefix("--capture-dir=").path_join(filename)
	tree.root.get_texture().get_image().save_png(path)

static func _key(keycode: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

static func _click(tree: SceneTree, point: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		tree.root.push_input(event)

static func _check(condition: bool, description: String, failures: Array[String], checks: Array[String]) -> void:
	checks.append(description)
	if not condition:
		failures.append(description)
