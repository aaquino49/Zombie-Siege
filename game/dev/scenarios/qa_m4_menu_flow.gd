extends SceneTree
## Real launch/reload/button flow: --script ... -- --quit-frames=10000000.

const SUPPORT: GDScript = preload("res://dev/scenarios/qa_m4_support.gd")
const BUTTONS: String = "/Dim/Center/Panel/Margin/Content/Buttons/"
const CONTINUE_SAVE := "user://test_t146_menu_flow.json"
var checks: Array[String] = []
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _frames(count: int = 4) -> void:
	for i: int in range(count):
		await process_frame

func _check(condition: bool, description: String) -> void:
	checks.append(description)
	if not condition:
		failures.append(description)
	SUPPORT.check(condition, description)

func _press(overlay: String, button: String) -> void:
	current_scene.get_node(overlay + BUTTONS + button).pressed.emit()
	await _frames()

func _new_game(difficulty: String = "hard") -> void:
	await _press("MainMenu", "NewGame")
	_check(current_scene.get_node("MainMenu/DifficultyPicker").visible, "New Game opens difficulty picker")
	current_scene.get_node("MainMenu/DifficultyPicker/Dim/Center/Panel/Margin/Content/Options/" + difficulty.capitalize() + "/Select").pressed.emit()
	await _frames()

func _fresh(expected_difficulty: String = "normal") -> void:
	var state: GameState = root.get_node("Game").state
	_check(state.difficulty == expected_difficulty, "Fresh game uses " + expected_difficulty + " difficulty")
	_check(state.clock.day == 1 and state.clock.phase == GameClock.Phase.DAY and not state.game_over,
		"Fresh running day 1 after reload")
	_check(state.zombies.count() == 0 and state.buildings.all().size() == 1 and state.last_dawn_report.is_empty(),
		"Reload clears zombies, buildings and dawn data")
	for overlay: String in ["MainMenu", "MainMenu/DifficultyPicker", "GameOverScreen", "VictoryScreen", "DawnReport", "PauseMenu", "SettingsScreen", "HowToPlay", "CreditsScreen"]:
		_check(not current_scene.get_node(overlay).visible, "Reload hides " + overlay)
	_check(current_scene.get_node("World/FloatingText").get_child_count() == 0, "Reload clears floating popups")
	_check(not current_scene.get_node("World/RescueHelicopter").visible, "Reload clears helicopter")
	var camera: Camera2D = current_scene.get_node("World/Camera2D")
	# Headless reports mouse=(0,0), causing genuine edge-pan during these four frames.
	# Require CC near the viewport center; exact initial positioning has existing coverage.
	_check(camera.position.distance_to(state.buildings.all_of_type("command_center")[0].center_world()) < 3.0 * Grid.TILE,
		"New game camera shows CC near center")
	_check(current_scene.get_node("HUD").visible and not state.clock.locked and not state.clock.paused, "Fresh HUD and clock")

func _screen_buttons() -> void:
	for pair: Array in [["HowToPlay", "HowToPlay"], ["Settings", "SettingsScreen"], ["Credits", "CreditsScreen"]]:
		await _press("MainMenu", pair[0])
		_check(current_scene.get_node(pair[1]).visible and not current_scene.get_node("MainMenu/Dim").visible, "Main menu opens " + pair[1])
		await _press(pair[1], "Back")
		_check(current_scene.get_node("MainMenu").visible and not current_scene.get_node(pair[1]).visible, "Back returns from " + pair[1])

func _run() -> void:
	var original_difficulty: String = GameSettings.load_difficulty()
	root.size = Vector2i(1280, 720)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main = null
	await _frames()
	var game: Node = root.get_node("Game")
	game.save_path = CONTINUE_SAVE
	game.delete_save()
	_check(current_scene.get_node("MainMenu").visible, "Default launch opens main menu")
	_check(current_scene.get_node("MainMenu/TitleScene") != null, "Title scene loaded")
	_check(game.state.clock.paused and game.state.clock.locked, "Main menu locks clock")
	await _screen_buttons()
	await _press("MainMenu", "NewGame")
	_check(current_scene.get_node("MainMenu/DifficultyPicker").visible, "New Game opens difficulty picker")
	await _press("MainMenu/DifficultyPicker", "Back")
	_check(not current_scene.get_node("MainMenu/DifficultyPicker").visible and current_scene.get_node("MainMenu").visible,
		"Picker Back returns to main menu")
	await _press("MainMenu", "NewGame")
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true
	root.push_input(event)
	await _frames()
	_check(not current_scene.get_node("MainMenu/DifficultyPicker").visible and current_scene.get_node("MainMenu").visible,
		"Picker Escape returns to main menu")
	await _new_game("hard")
	_fresh("hard")
	# Escape opens pause; Resume, Restart and Quit to Menu exercise their real buttons.
	root.push_input(event)
	_check(current_scene.get_node("PauseMenu").visible, "Esc opens pause")
	_check(current_scene.get_node("PauseMenu/Dim/Center/Panel/Margin/Content/Difficulty").text == "Difficulty: Hard",
		"Pause header shows selected difficulty")
	await _press("PauseMenu", "Resume")
	_check(not current_scene.get_node("PauseMenu").visible and not game.state.clock.paused, "Resume returns to game")
	var original_volumes: Dictionary = AudioSettings.load_volumes()
	current_scene.get_node("PauseMenu").open()
	await _press("PauseMenu", "Settings")
	current_scene.get_node("SettingsScreen/Dim/Center/Panel/Margin/Content/Volumes/MasterRow/Master").value = 37.0
	await _press("SettingsScreen", "Back")
	_check(current_scene.get_node("PauseMenu").visible and game.state.clock.paused and game.state.clock.locked, "Settings Back returns to paused menu")
	await _press("PauseMenu", "Settings")
	root.push_input(event)
	_check(current_scene.get_node("PauseMenu").visible and not current_scene.get_node("SettingsScreen").visible and game.state.clock.paused and game.state.clock.locked, "Settings Esc returns to Pause without resuming in same press")
	await _press("PauseMenu", "Restart")
	_fresh("hard")
	_check(is_equal_approx(float(AudioSettings.load_volumes()["Master"]), 0.37), "Volume saved across Restart")
	current_scene.get_node("PauseMenu").open()
	await _press("PauseMenu", "Settings")
	_check(is_equal_approx(current_scene.get_node("SettingsScreen/Dim/Center/Panel/Margin/Content/Volumes/MasterRow/Master").value, 37.0), "Reloaded Settings slider uses saved volume")
	await _press("SettingsScreen", "Back")
	current_scene.get_node("PauseMenu").open()
	await _press("PauseMenu", "MainMenu")
	_check(current_scene.get_node("MainMenu").visible, "Pause Quit to Menu returns to title")
	await _new_game("hard")
	_fresh("hard")
	for reason: String in ["command_center", "survivors"]:
		var state: GameState = game.state
		if reason == "command_center":
			var cc: Building = state.buildings.all_of_type("command_center")[0]
			state.damage_building(cc, cc.hp)
		else:
			for person: Survivor in state.survivors.all():
				state.damage_survivor(person, person.hp)
		state.tick(0.0)
		_check(state.lose_reason == reason and current_scene.get_node("GameOverScreen").visible, "Real Game Over: " + reason)
		_check(current_scene.get_node("GameOverScreen/Dim/Center/Panel/Margin/Content/Difficulty").text == "Difficulty: Hard",
			"Game Over shows selected difficulty")
		var rows: Node = current_scene.get_node("GameOverScreen/Dim/Center/Panel/Margin/Content/Stats")
		var expected: Array[Array] = load("res://scripts/ui/game_over_screen.gd").stat_rows(state.stats())
		_check(rows.get_child_count() == 10, "Game Over contains five stat rows")
		for i: int in range(expected.size()):
			_check(rows.get_child(i * 2 + 1).text == expected[i][1], "Game Over stat " + expected[i][0])
		var before: float = state.time_played
		state.clock.set_speed(3)
		state.clock.set_paused(false)
		state.tick(1.0)
		_check(state.clock.locked and state.time_played == before, "Game Over cannot resume clock")
		state = null
		await _press("GameOverScreen", "Restart" if reason == "command_center" else "MainMenu")
		if reason == "survivors":
			_check(current_scene.get_node("MainMenu").visible, "Game Over Main Menu works")
			await _new_game("hard")
		_fresh("hard")
	# Real victory condition, real helicopter signal, and both terminal buttons.
	for button: String in ["Restart", "MainMenu"]:
		var state: GameState = game.state
		state.waves.enabled = false
		state.clock.day = 20
		state.resources.add("wood", 1000)
		state.resources.add("scrap", 1000)
		SUPPORT.place(state, "radio_tower")
		state.clock.phase = GameClock.Phase.NIGHT
		state.clock.phase_changed.emit(GameClock.Phase.NIGHT, 20)
		state.clock.elapsed = float(state.data.balance("night_min_length")) - 0.25
		state.tick(0.25)
		_check(state.won and not current_scene.get_node("GameOverScreen").visible, "Real dawn win excludes Game Over")
		current_scene.get_node("World/RescueHelicopter").skip()
		_check(current_scene.get_node("VictoryScreen").visible, "Rescue completion shows Victory")
		_check(current_scene.get_node("VictoryScreen/Dim/Center/Panel/Margin/Content/Difficulty").text == "Difficulty: Hard",
			"Victory shows selected difficulty")
		await _frames()
		_check(not current_scene.get_node("DawnReport").visible, "Won-game dawn suppresses report overlay")
		state = null
		await _press("VictoryScreen", button)
		if button == "MainMenu":
			_check(current_scene.get_node("MainMenu").visible, "Victory Main Menu works")
			await _new_game("hard")
		_fresh("hard")
	# Check an ordinary report's rows, Continue, and day resumption.
	var state: GameState = game.state
	state.waves.enabled = false
	state.clock.elapsed = float(state.data.balance("day_length")) - 0.25
	state.tick(0.25)
	state.clock.elapsed = float(state.data.balance("night_min_length")) - 0.25
	state.tick(0.25)
	await _frames()
	_check(current_scene.get_node("DawnReport").visible and state.clock.paused, "Night 1 dawn shows paused report")
	var lines: Array[Array] = DawnReportPanel.report_rows(state.last_dawn_report)
	var rows: Node = current_scene.get_node("DawnReport/Center/Panel/Margin/Content/Scroll/Lines")
	_check(rows.get_child_count() == lines.size() * 2, "Dawn Report displays the real NightLog/DawnRules lines")
	for i: int in range(lines.size()):
		_check(rows.get_child(i * 2).text == lines[i][0] and rows.get_child(i * 2 + 1).text == lines[i][1], "Dawn line " + str(i))
	current_scene.get_node("DawnReport/Center/Panel/Margin/Content/Buttons/Continue").pressed.emit()
	var before: float = state.clock.elapsed
	state.tick(0.25)
	_check(not current_scene.get_node("DawnReport").visible and state.clock.elapsed > before, "Continue closes report and resumes day")
	# Real layout regression at the game's 1280x720 design resolution.
	var dawn: DawnReportPanel = current_scene.get_node("DawnReport")
	dawn._show_report(load("res://dev/scenarios/dawn_report_long.gd").report())
	await _frames(12)
	var continue_button: Button = dawn.get_node(DawnReportPanel.CONTENT + "Buttons/Continue")
	var button_rect: Rect2 = continue_button.get_global_rect()
	var viewport_rect: Rect2 = root.get_visible_rect()
	_check(viewport_rect.size == Vector2(1280, 720), "Long-report test uses 1280x720")
	_check(viewport_rect.encloses(button_rect), "Long report Continue is fully on-screen")
	var panel_rect: Rect2 = dawn.get_node("Center/Panel").get_global_rect()
	_check(panel_rect.position.y >= DawnReportPanel.SCREEN_MARGIN and panel_rect.end.y <= 720.0 - DawnReportPanel.SCREEN_MARGIN,
		"Long report panel stays within vertical screen margins")
	var scroll: ScrollContainer = dawn.get_node(DawnReportPanel.CONTENT + "Scroll")
	var long_rows: GridContainer = scroll.get_node("Lines")
	_check(long_rows.size.y > scroll.size.y, "Long report rows overflow into a vertical scroll area")
	scroll.scroll_vertical = 10000
	await _frames()
	_check(scroll.scroll_vertical > 0 and viewport_rect.encloses(continue_button.get_global_rect()),
		"Scrolling reaches overflow and leaves Continue on-screen")
	dawn._show_report(state.last_dawn_report)
	await _frames(12)
	_check(scroll.scroll_vertical == 0 and is_equal_approx(scroll.size.y, long_rows.size.y),
		"Next normal report resets scrolling and returns to natural height")
	continue_button.pressed.emit()
	# Autosave at dawn 2, leave through Quit to Menu, then resume the same run.
	var saved_day: int = state.clock.day
	var saved_resources: Dictionary = {}
	for kind: String in ResourceStore.KINDS:
		saved_resources[kind] = state.resources.get_amount(kind)
	var saved_buildings: int = state.buildings.all().size()
	var saved_survivors: int = state.survivors.all().size()
	_check(saved_day == 2 and game.has_save(), "Dawn 2 autosaves a resumable run")
	_check(game.save_day() == 2, "Continue save identifies dawn 2")
	_check(state.difficulty == "hard", "Autosave stores hard difficulty")
	current_scene.get_node("PauseMenu").open()
	await _press("PauseMenu", "MainMenu")
	_check(current_scene.get_node("MainMenu").visible, "Quit to Menu exposes the save")
	var menu_continue: Button = current_scene.get_node("MainMenu" + BUTTONS + "Continue")
	_check(menu_continue.visible and menu_continue.text == "Continue (Day 2)", "Continue labels the saved day")
	await _press("MainMenu", "Continue")
	state = game.state
	_check(state.difficulty == "hard", "Continue restores saved hard difficulty")
	_check(state.clock.day == saved_day, "Continue restores day 2")
	for kind: String in ResourceStore.KINDS:
		_check(state.resources.get_amount(kind) == int(saved_resources[kind]), "Continue restores " + kind)
	_check(state.buildings.all().size() == saved_buildings, "Continue restores buildings")
	_check(state.survivors.all().size() == saved_survivors, "Continue restores survivors")
	AudioSettings.save_volumes(original_volumes)
	AudioSettings.apply(original_volumes)
	GameSettings.save_difficulty(original_difficulty)
	game.delete_save()
	game.save_path = Game.SAVE_PATH
	var report_path: String = ProjectSettings.globalize_path("res://../project/runs/T-028/a1/live_flow.json")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--flow-report="):
			report_path = arg.trim_prefix("--flow-report=")
	var file: FileAccess = FileAccess.open(report_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures}, "\t"))
	file.close()
	print("QA M4 FLOW: %d checks, %d failures" % [checks.size(), failures.size()])
	game.request_quit(0 if failures.is_empty() else 1)
