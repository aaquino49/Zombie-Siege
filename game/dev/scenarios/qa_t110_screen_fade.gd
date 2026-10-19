extends SceneTree
## Bounded live transition check; use --max-fps 60 -- --quit-frames=900.

var failures: Array[String] = []
var game: Node

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, description: String) -> void:
	print("%s T-110: %s" % ["PASS" if condition else "FAIL", description])
	if not condition:
		failures.append(description)

func _settle() -> void:
	await create_timer(0.85, true).timeout
	_check(not game.transitioning and not paused, "Transition releases the tree")
	_check(game.screen_fade.rect.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and is_zero_approx(game.screen_fade.rect.color.a), "Transition releases input and clears black")

func _panel_reveal(overlay: String) -> void:
	var panel: Control = current_scene.get_node(overlay + "/Dim/Center/Panel")
	if DisplayServer.get_name() == "headless":
		_check(is_equal_approx(panel.modulate.a, 1.0), overlay + " is immediate headlessly")
	else:
		_check(is_zero_approx(panel.modulate.a), overlay + " starts transparent")
		await create_timer(0.12, true).timeout
		_check(panel.modulate.a > 0.0 and panel.modulate.a < 1.0, overlay + " reveals while tree is paused")
		await create_timer(0.3, true).timeout
		_check(is_equal_approx(panel.modulate.a, 1.0), overlay + " finishes opaque")

func _run() -> void:
	game = root.get_node("Game")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main = null
	for index: int in range(3):
		await process_frame
	game.screen_fade.instant = false
	var persistent: ScreenFade = game.screen_fade
	var old_state: WeakRef = weakref(game.state)
	game.start_new_game()
	_check(paused and game.transitioning, "New Game pauses tree for fade")
	_check(game.screen_fade.rect.mouse_filter == Control.MOUSE_FILTER_STOP, "Fade blocks input immediately")
	# A duplicate click during the transition cannot launch a second reload.
	game.quit_to_menu()
	await create_timer(0.12, true).timeout
	_check(game.screen_fade.rect.color.a > 0.0 and game.screen_fade.rect.color.a < 1.0,
		"Opacity advances while tree is paused")
	await _settle()
	_check(game.screen_fade == persistent, "Fade survives scene reload")
	_check(old_state.get_ref() == null, "Reload frees old state")
	_check(not current_scene.get_node("MainMenu").visible and not game.show_menu,
		"Duplicate action is ignored while New Game runs")
	var seed_value: int = game.next_seed
	current_scene.get_node("PauseMenu").open()
	paused = true
	current_scene.get_node("PauseMenu/Dim/Center/Panel/Margin/Content/Buttons/Restart").pressed.emit()
	await _settle()
	_check(game.next_seed == seed_value and not game.state.clock.paused, "Paused Restart preserves seed and resumes")
	current_scene.get_node("PauseMenu").open()
	current_scene.get_node("PauseMenu/Dim/Center/Panel/Margin/Content/Buttons/MainMenu").pressed.emit()
	await _settle()
	_check(current_scene.get_node("MainMenu").visible, "Quit to Menu fades to title")
	game.screen_fade.instant = true
	game.start_new_game()
	await process_frame
	await process_frame
	await process_frame
	game.screen_fade.instant = false
	var cc: Building = game.state.buildings.all_of_type("command_center")[0]
	paused = true
	game.state.damage_building(cc, cc.hp)
	game.state.tick(0.0)
	await _panel_reveal("GameOverScreen")
	current_scene.get_node("GameOverScreen/Dim/Center/Panel/Margin/Content/Buttons/Restart").pressed.emit()
	await _settle()
	_check(not game.state.game_over and not current_scene.get_node("GameOverScreen").visible,
		"Game Over Restart fades to a fresh game")
	var victory: Node = current_scene.get_node("VictoryScreen")
	game.state.won = true
	game.state.game_over = true
	paused = true
	victory._show_panel()
	victory = null
	await _panel_reveal("VictoryScreen")
	current_scene.get_node("VictoryScreen/Dim/Center/Panel/Margin/Content/Buttons/MainMenu").pressed.emit()
	await _settle()
	_check(current_scene.get_node("MainMenu").visible, "Victory Main Menu fades to title")
	print("T-110 FADE: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
