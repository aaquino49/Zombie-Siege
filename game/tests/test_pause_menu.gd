extends TestCase

var _state: GameState
var _menu: PauseMenu
var _build: BuildMode
var _selection: SelectionController
var _main_menu: CanvasLayer
var _report: CanvasLayer
var _settings_temp_path: String
var _save_temp_path: String
var _old_save_path: String
var _old_game_state: GameState

func before_each() -> void:
	_settings_temp_path = temp_path("pause_settings", "cfg")
	_save_temp_path = temp_path("pause_save", "json")
	_old_save_path = Game.save_path
	_old_game_state = Game.state
	Game.save_path = _save_temp_path
	Game.delete_save()
	remove_test_temp_file(_settings_temp_path)
	_state = GameState.new(GameData.load_default(), 1337)
	_state.waves.enabled = false
	_menu = preload("res://scenes/ui/pause_menu.tscn").instantiate() as PauseMenu
	_build = BuildMode.new()
	_build.bind(_state)
	_selection = SelectionController.new()
	_selection.bind(_state)
	_main_menu = CanvasLayer.new()
	_main_menu.visible = false
	_report = CanvasLayer.new()
	_report.visible = false
	_menu.bind(_state, _build, _selection, _main_menu, _report)

func after_each() -> void:
	_menu.free()
	_build.free()
	_selection.free()
	_main_menu.free()
	_report.free()
	_state = null
	remove_test_temp_file(_settings_temp_path)
	Game.delete_save(_save_temp_path)
	for suffix: String in ["", ".tmp", ".bak"]:
		remove_test_temp_file(_save_temp_path + suffix)
	Game.save_path = _old_save_path
	Game.state = _old_game_state

func test_can_open_truth_table() -> void:
	assert_true(PauseMenu.can_open(false, false, false, false, false))
	assert_false(PauseMenu.can_open(true, false, false, false, false))
	assert_false(PauseMenu.can_open(false, true, false, false, false))
	assert_false(PauseMenu.can_open(false, false, true, false, false))
	assert_false(PauseMenu.can_open(false, false, false, true, false))
	assert_false(PauseMenu.can_open(false, false, false, false, true))

func test_to_db() -> void:
	assert_eq(AudioSettings.to_db(0.0), -80.0)
	assert_eq(AudioSettings.to_db(1.0), 0.0)
	assert_almost_eq(AudioSettings.to_db(0.5), -6.0206, 0.01)
	assert_eq(AudioSettings.to_db(-1.0), -80.0)
	assert_eq(AudioSettings.to_db(2.0), 0.0)

func test_esc_respects_bound_blockers() -> void:
	var event := InputEventAction.new()
	event.action = "cancel"
	event.pressed = true
	for blocker: String in ["game_over", "victory", "main_menu", "dawn_report", "build", "selection"]:
		_state.game_over = blocker in ["game_over", "victory"]
		_state.won = blocker == "victory"
		_main_menu.visible = blocker == "main_menu"
		_report.visible = blocker == "dawn_report"
		_build.active_type = "wooden_wall" if blocker == "build" else ""
		_selection.selected_kind = "building" if blocker == "selection" else ""
		_menu._unhandled_input(event)
		assert_false(_menu.visible, "Esc must defer to " + blocker)
		assert_false(_state.clock.paused, "Blocked Esc must not change pause state")
		assert_false(_state.clock.locked, "Blocked Esc must not lock the clock")

func test_settings_round_trip_missing_and_corrupt() -> void:
	var path: String = _settings_temp_path
	var defaults := {"Master": 0.8, "SFX": 0.8, "Music": 0.8}
	assert_eq(AudioSettings.load_volumes(path), defaults)
	var volumes := {"Master": 0.5, "SFX": 0.2, "Music": 1.0}
	AudioSettings.save_volumes(volumes, path)
	assert_eq(AudioSettings.load_volumes(path), volumes)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("garbage content")
	file.close()
	assert_eq(AudioSettings.load_volumes(path), defaults)

func test_pause_restore_and_locked_controls() -> void:
	_state.clock.set_speed(2)
	_menu.open()
	assert_true(_menu.visible)
	assert_true(_state.clock.paused)
	assert_true(_state.clock.locked)
	var elapsed := _state.clock.elapsed
	_state.tick(10.0)
	assert_eq(_state.clock.elapsed, elapsed, "Open menu freezes time")
	_state.clock.toggle_pause()
	for speed: int in [1, 2, 3]:
		_state.clock.set_speed(speed)
	assert_true(_state.clock.paused)
	assert_eq(_state.clock.speed, 2)
	_menu.close()
	assert_false(_menu.visible)
	assert_false(_state.clock.paused)
	assert_false(_state.clock.locked)
	assert_eq(_state.clock.speed, 2)
	_state.clock.set_paused(true)
	_menu.open()
	_menu.open()
	var resume: Button = _menu.get_node(PauseMenu.CONTENT + "Buttons/Resume")
	resume.pressed.emit()
	assert_true(_state.clock.paused, "Resume restores an already paused clock")
	assert_false(_state.clock.locked)
	assert_false(_menu.visible)

func test_bind_wires_buttons_and_settings_loads_sliders() -> void:
	assert_false(_menu.visible)
	var restart: Button = _menu.get_node(PauseMenu.CONTENT + "Buttons/Restart")
	var main_menu: Button = _menu.get_node(PauseMenu.CONTENT + "Buttons/MainMenu")
	assert_true(restart.pressed.is_connected(Callable(_menu, "_restart")))
	assert_true(main_menu.pressed.is_connected(Callable(_menu, "_main_menu_pressed")))
	var reload: Button = _menu.get_node(PauseMenu.CONTENT + "Buttons/ReloadDay")
	assert_eq(reload.text, "Reload day")
	assert_true(reload.pressed.is_connected(Callable(_menu, "_reload_day")))
	assert_false(reload.visible)
	assert_not_null(_menu.get_node(PauseMenu.CONTENT + "Buttons/Settings"))
	assert_false(_menu.has_node(PauseMenu.CONTENT + "Volumes"))
	assert_eq(_menu.get_node(PauseMenu.CONTENT + "Difficulty").text, "Seed 1337 · Normal")
	var settings: SettingsScreen = load("res://scenes/ui/settings_screen.tscn").instantiate()
	settings.bind()
	var saved := AudioSettings.load_volumes()
	for bus: String in AudioSettings.BUSES:
		var slider: HSlider = settings.get_node(MenuScreen.CONTENT + "Volumes/" + bus + "Row/" + bus)
		assert_almost_eq(slider.value, roundf(float(saved[bus]) * 100.0), 0.01)
		assert_eq(slider.value_changed.get_connections().size(), 1)
	settings.free()
	var how_to_play: HowToPlay = (load("res://scenes/ui/how_to_play.tscn") as PackedScene).instantiate() as HowToPlay
	assert_true(str(how_to_play.get_node(MenuScreen.CONTENT + "Scroll/Sections/Tips").text).contains("Reload day in the pause menu"))
	how_to_play.free()

func test_reload_day_button_visibility_tracks_valid_and_bad_saves() -> void:
	var reload: Button = _menu.get_node(PauseMenu.CONTENT + "Buttons/ReloadDay")
	_menu.open()
	assert_false(reload.visible, "No dawn save before the first dawn")
	_menu.close()
	var file: FileAccess = FileAccess.open(_save_temp_path, FileAccess.WRITE)
	file.store_string("not json{{{")
	file.close()
	_menu.open()
	assert_false(reload.visible, "Broken save hides Reload day")
	assert_false(FileAccess.file_exists(_save_temp_path), "Broken save is safely removed by existing validation")
	_menu.close()
	var unsupported: Dictionary = SaveGame.capture(_state)
	unsupported["version"] = SaveGame.VERSION + 1
	file = FileAccess.open(_save_temp_path, FileAccess.WRITE)
	file.store_string(SaveGame.to_json(unsupported))
	file.close()
	_menu.open()
	assert_false(reload.visible, "Old-version save hides Reload day")
	_menu.close()
	unsupported["version"] = SaveGame.VERSION - 1
	file = FileAccess.open(_save_temp_path, FileAccess.WRITE)
	file.store_string(SaveGame.to_json(unsupported))
	file.close()
	_menu.open()
	assert_false(reload.visible, "Previous save format hides Reload day")
	_menu.close()
	Game.state = GameState.new(GameData.load_default(), 81723, "hard")
	Game.state.clock.day = 4
	assert_true(Game.save_now({}, _save_temp_path))
	_menu.open()
	assert_false(reload.visible, "A save from another run hides Reload day")
	_menu.close()
	Game.state = _state
	_state.clock.day = 2
	assert_true(Game.save_now({}, _save_temp_path))
	_menu.open()
	assert_true(reload.visible, "A save matching the current run and day shows Reload day")
	_menu.close()
	_state.clock.day = 4
	assert_true(Game.save_now({}, _save_temp_path))
	_state.clock.day = 1
	_menu.open()
	assert_false(reload.visible, "Restarting on day 1 hides a same-run day 4 save")
	_menu.close()
	Game.state = GameState.new(GameData.load_default(), 1337, "hard")
	Game.state.clock.day = 1
	assert_true(Game.save_now({}, _save_temp_path))
	_menu.open()
	assert_false(reload.visible, "A save with a different difficulty hides Reload day")
	_menu.close()
	Game.state = null

func test_apply_bus_volume_and_mute() -> void:
	var saved: Array[Dictionary] = []
	for bus: String in AudioSettings.BUSES:
		var index := AudioServer.get_bus_index(bus)
		assert_true(index >= 0, "Configured audio bus exists")
		if index < 0:
			return
		saved.append({"index": index, "db": AudioServer.get_bus_volume_db(index),
			"mute": AudioServer.is_bus_mute(index)})
	AudioSettings.apply({"Master": 0.0, "SFX": 0.5, "Music": 1.0})
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")))
	assert_almost_eq(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")), -6.0206, 0.01)
	assert_almost_eq(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")), 0.0, 0.01)
	AudioSettings.apply({"Master": 0.8})
	assert_false(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")))
	for entry: Dictionary in saved:
		AudioServer.set_bus_volume_db(entry["index"], entry["db"])
		AudioServer.set_bus_mute(entry["index"], entry["mute"])

func test_blocks_action_consumed_set() -> void:
	var blocked_actions: Array[String] = [
		"pause",
		"speed_1",
		"speed_2",
		"speed_3",
		"build_menu",
		"roster",
	]
	for action: String in blocked_actions:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = true
		assert_true(PauseMenu.blocks_action(event), "Should block pressed " + action)
		event.pressed = false
		assert_true(PauseMenu.blocks_action(event), "Should block released " + action)

	var allowed_actions: Array[String] = [
		"cancel",
		"cam_left",
		"cam_right",
		"cam_up",
		"cam_down",
		"zoom_in",
		"zoom_out",
	]
	for action: String in allowed_actions:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = true
		assert_false(PauseMenu.blocks_action(event), "Should not block " + action)

	assert_false(PauseMenu.blocks_action(null), "Null event should not be blocked")
	
	# Verify _input does not crash off-tree when visible and handles blocked actions safely
	var test_event := InputEventAction.new()
	test_event.action = "build_menu"
	test_event.pressed = true
	assert_false(_menu.visible)
	_menu._input(test_event)
	_menu.open()
	assert_true(_menu.visible)
	_menu._input(test_event)
	_menu.close()
