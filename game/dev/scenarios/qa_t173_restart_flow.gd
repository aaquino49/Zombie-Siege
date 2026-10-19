extends SceneTree
## Bounded real Continue/button/reload QA. Run with -- --quit-frames=10000000.

const CONTENT := "/Dim/Center/Panel/Margin/Content/"
const MAP_SEED := 424242
var checks: Array[String] = []
var failures: Array[String] = []
var _settings_existed: bool
var _settings_text: String

func _initialize() -> void:
	_run.call_deferred()

func _frames(count: int = 4) -> void:
	for i: int in range(count):
		await process_frame

func _check(condition: bool, description: String) -> void:
	checks.append(description)
	if not condition:
		failures.append(description)
		print("T-173 FAIL: " + description)

func _press(overlay: String, button: String) -> void:
	var game: Node = root.get_node("Game")
	var target: Button = current_scene.get_node(overlay + CONTENT + "Buttons/" + button)
	_check(target.is_visible_in_tree(), overlay + "/" + button + " is visible")
	target.pressed.emit()
	await _frames()
	for i: int in range(360):
		if not game.transitioning:
			break
		await process_frame
	_check(not game.transitioning, overlay + "/" + button + " completes transition")

func _capture(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(arg.trim_prefix("--capture-dir=").path_join(name + ".png"))

func _run() -> void:
	_settings_existed = FileAccess.file_exists(GameSettings.PATH)
	_settings_text = FileAccess.get_file_as_string(GameSettings.PATH) if _settings_existed else ""
	root.size = Vector2i(1280, 720)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main = null
	await _frames()
	var game: Node = root.get_node("Game")
	var original_save_path: String = game.save_path
	game.save_path = "user://test_t173_restart_flow_%d.json" % OS.get_process_id()
	game.delete_save()
	for pair: Array in [["easy", "hard"], ["hard", "easy"]]:
		var remembered: String = pair[0]
		var active: String = pair[1]
		for overlay: String in ["PauseMenu", "GameOverScreen", "VictoryScreen"]:
			var context: String = remembered + " remembered / " + active + " saved / " + overlay
			GameSettings.save_difficulty(remembered)
			var fixture: GameState = GameState.new(GameData.load_default(), MAP_SEED, active)
			fixture.clock.day = 4
			fixture.resources.add("wood", 999)
			fixture.zombies_killed = 123
			var save_file: FileAccess = FileAccess.open(game.save_path, FileAccess.WRITE)
			save_file.store_string(SaveGame.to_json(SaveGame.capture(fixture)))
			save_file.close()
			fixture = null
			current_scene.get_node("MainMenu").open(game.state)
			await _press("MainMenu", "Continue")
			_check(game.state.difficulty == active and game.state.clock.day == 4,
				context + ": Continue restores active difficulty and progress")
			_check(game.state.map_seed == MAP_SEED,
				context + ": Continue restores seed")
			if overlay == "PauseMenu":
				current_scene.get_node("PauseMenu").open()
			elif overlay == "GameOverScreen":
				var cc: Building = game.state.buildings.all_of_type("command_center")[0]
				game.state.damage_building(cc, cc.hp)
				game.state.tick(0.0)
			else:
				load("res://dev/scenarios/victory.gd").setup(current_scene)
			await _frames(24)
			_check(current_scene.get_node(overlay).visible, context + ": overlay opens")
			_check(current_scene.get_node(overlay + CONTENT + "Difficulty").text == "Difficulty: " + active.capitalize(),
				context + ": overlay displays active difficulty")
			await _capture("qa_t173_" + active + "_" + overlay)
			var old_state: WeakRef = weakref(game.state)
			await _press(overlay, "Restart")
			_check(old_state.get_ref() == null, context + ": previous run is freed")
			_check(game.state.difficulty == active, context + ": Restart retains active difficulty")
			_check(game.state.difficulty_multipliers == game.state.data.difficulty_config(active),
				context + ": Restart retains balance multipliers")
			_check(game.state.map_seed == MAP_SEED, context + ": Restart retains seed (expected %d, got %d)"
				% [MAP_SEED, game.state.map_seed])
			_check(game.state.clock.day == 1 and game.state.clock.phase == GameClock.Phase.DAY
				and not game.state.game_over and not game.state.won and game.state.zombies_killed == 0,
				context + ": Restart clears saved and terminal progress")
			_check(game.state.buildings.all().size() == 1 and game.state.zombies.count() == 0,
				context + ": Restart creates a fresh colony")
			_check(not game.state.clock.paused and not game.state.clock.locked and not game.show_menu,
				context + ": Restart resumes gameplay")
			_check(GameSettings.load_difficulty() == remembered, context + ": Restart preserves remembered choice")
			current_scene.get_node("PauseMenu").open()
			_check(current_scene.get_node("PauseMenu" + CONTENT + "Difficulty").text == "Difficulty: " + active.capitalize(),
				context + ": fresh pause header retains difficulty")
			await _capture("qa_t173_" + active + "_after_" + overlay)
			await _press("PauseMenu", "MainMenu")
			await _press("MainMenu", "NewGame")
			var picker: Node = current_scene.get_node("MainMenu/DifficultyPicker")
			_check(picker.visible, context + ": picker reopens")
			var expected_button: Button = picker.get_node(CONTENT.trim_prefix("/") + "Options/" + remembered.capitalize() + "/Select")
			_check(root.gui_get_focus_owner() == expected_button, context + ": picker focuses remembered choice")
			await _press("MainMenu/DifficultyPicker", "Back")
	game.delete_save()
	game.save_path = original_save_path
	if _settings_existed:
		var settings_file: FileAccess = FileAccess.open(GameSettings.PATH, FileAccess.WRITE)
		settings_file.store_string(_settings_text)
		settings_file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSettings.PATH))
	var report_path: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--flow-report="):
			report_path = arg.trim_prefix("--flow-report=")
	if not report_path.is_empty():
		var report: FileAccess = FileAccess.open(report_path, FileAccess.WRITE)
		report.store_string(JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures}, "\t"))
		report.close()
	print("T-173 LIVE FLOW: %d checks, %d failures" % [checks.size(), failures.size()])
	game.request_quit(0 if failures.is_empty() else 1)
