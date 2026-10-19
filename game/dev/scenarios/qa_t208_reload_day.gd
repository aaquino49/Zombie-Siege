extends RefCounted
## Bounded live QA: real dawn autosave, button activation, scene reload, and layout.

static func setup(main: Node) -> void:
	var tree: SceneTree = main.get_tree()
	var state: GameState = Game.state
	var menu: PauseMenu = main.get_node("PauseMenu")
	Game.delete_save()
	menu.open()
	_check(not menu.get_node(PauseMenu.CONTENT + "Buttons/ReloadDay").visible, "No save hides Reload day")
	menu.close()
	state.waves.enabled = false
	state.clock.elapsed = float(state.data.balance("day_length")) - 0.25
	state.tick(0.25)
	state.clock.elapsed = float(state.data.balance("night_min_length")) - 0.25
	state.tick(0.25)
	_check(state.clock.day == 2 and Game.has_save(), "Real dawn writes valid autosave")
	var file: FileAccess = FileAccess.open(Game._path_or_default(""), FileAccess.READ)
	var expected: Dictionary = SaveGame.from_json(file.get_as_text())
	file.close()
	main.get_node("DawnReport/Center/Panel/Margin/Content/Buttons/Continue").pressed.emit()
	state.resources.spend({"wood": 25, "food": 12})
	state.clock.elapsed = 30.0
	menu.open()
	_check(menu.get_node(PauseMenu.CONTENT + "Buttons/ReloadDay").visible, "Valid dawn shows Reload day")
	Game.screen_fade.instant = true
	menu.get_node(PauseMenu.CONTENT + "Buttons/ReloadDay").pressed.emit()
	await tree.scene_changed
	var actual: Dictionary = SaveGame.from_json(SaveGame.to_json(SaveGame.capture(Game.state, Game.continued_extra)))
	_check(actual == expected, "Button restores full dawn snapshot through real scene reload")
	_check(Game.state.clock.phase == GameClock.Phase.DAY and Game.state.clock.elapsed == 0.0, "Full daylight clock restored")
	_check(not tree.current_scene.get_node("MainMenu").visible, "Reload returns to gameplay")
	_check(Game.state.waves.enabled, "Reload enables wave processing")
	tree.current_scene.get_node("PauseMenu").open()
	print("T-208 LIVE QA COMPLETE")

static func _check(condition: bool, description: String) -> void:
	if condition:
		print("T-208 LIVE PASS: " + description)
	else:
		push_error("T-208 LIVE FAIL: " + description)
