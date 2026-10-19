extends Node

const SAVE_PATH := "user://t146_continue_flow.json"

func run(main: Node) -> void:
	Game.save_path = SAVE_PATH
	Game.delete_save()
	var state: GameState = Game.state
	state.waves.enabled = false
	state.clock.elapsed = float(state.data.balance("day_length")) - 0.25
	state.tick(0.25)
	state.clock.elapsed = float(state.data.balance("night_min_length")) - 0.25
	state.tick(0.25)
	await _frames(3)
	var checks: Array[String] = []
	var failures: Array[String] = []
	_check(checks, failures, state.clock.day == 2 and Game.has_save(), "Dawn 2 wrote an autosave")
	_check(checks, failures, Game.save_day() == 2, "Continue save labels Day 2")
	var expected: Dictionary = SaveGame.capture(state, {"hints": main.get_node("Hints").get_shown()})
	main.get_node("DawnReport/Center/Panel/Margin/Content/Buttons/Continue").pressed.emit()
	main.get_node("PauseMenu").open()
	main.get_node("PauseMenu/Dim/Center/Panel/Margin/Content/Buttons/MainMenu").pressed.emit()
	await get_tree().scene_changed
	var fresh_menu_scene: Node = get_tree().current_scene
	fresh_menu_scene.get_node("MainMenu").open(Game.state)
	await _frames(30)
	var menu: Node = get_tree().current_scene.get_node("MainMenu")
	var continue_button: Button = menu.get_node("Dim/Center/Panel/Margin/Content/Buttons/Continue")
	_check(checks, failures, menu.visible and continue_button.visible and continue_button.text == "Continue (Day 2)",
		"Quit to Menu shows Continue (Day 2)")
	continue_button.pressed.emit()
	await get_tree().scene_changed
	var resumed: GameState = Game.state
	_check(checks, failures, resumed.clock.day == 2, "Continue restores Day 2")
	var actual: Dictionary = SaveGame.capture(resumed, {"hints": get_tree().current_scene.get_node("Hints").get_shown()})
	_check(checks, failures, actual == expected,
		"Continue restores resources, buildings, survivors, and hints")
	_check(checks, failures, resumed.waves.enabled, "Continued run resumes wave processing")
	Game.delete_save()
	Game.save_path = Game.SAVE_PATH
	print("T-146 LIVE FLOW: %d checks, %d failures" % [checks.size(), failures.size()])
	for failure: String in failures:
		push_error(failure)
	Game.request_quit(0 if failures.is_empty() else 1)

func _frames(count: int) -> void:
	for i: int in range(count):
		await get_tree().process_frame

func _check(checks: Array[String], failures: Array[String], condition: bool, description: String) -> void:
	checks.append(description)
	if condition:
		print("T-146 FLOW PASS: " + description)
	else:
		failures.append(description)
		print("T-146 FLOW FAIL: " + description)
