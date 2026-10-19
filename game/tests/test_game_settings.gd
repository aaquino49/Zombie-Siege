extends TestCase

var _temp: String

func before_each() -> void:
	_temp = temp_path("settings", "cfg")
	remove_test_temp_file(_temp)

func after_each() -> void:
	remove_test_temp_file(_temp)

func test_all_settings_writers_preserve_each_others_keys() -> void:
	var volumes := {"Master": 0.37, "SFX": 0.25, "Music": 0.65}
	AudioSettings.save_volumes(volumes, _temp)
	HintSettings.save_enabled(false, _temp)
	GameSettings.save_window_mode("fullscreen", _temp)
	GameSettings.save_default_speed(3, _temp)
	assert_eq(AudioSettings.load_volumes(_temp), volumes)
	assert_false(HintSettings.load_enabled(_temp))
	AudioSettings.save_volumes({"Master": 0.5}, _temp)
	HintSettings.save_enabled(true, _temp)
	assert_eq(GameSettings.load_window_mode(_temp), "fullscreen")
	assert_eq(GameSettings.load_default_speed(_temp), 3)
	assert_eq(AudioSettings.load_volumes(_temp)["SFX"], 0.25)
	GameSettings.save_default_speed(2, _temp)
	assert_eq(GameSettings.load_window_mode(_temp), "fullscreen")
	assert_true(HintSettings.load_enabled(_temp))
	assert_eq(AudioSettings.load_volumes(_temp)["Master"], 0.5)
	GameSettings.save_window_mode("windowed", _temp)
	assert_eq(GameSettings.load_default_speed(_temp), 2)

func test_missing_invalid_and_out_of_range_settings() -> void:
	assert_eq(GameSettings.load_window_mode(_temp), "windowed")
	assert_eq(GameSettings.load_default_speed(_temp), 1)
	for value: Variant in [-20, 0, 1, 2, 3, 99, "bad", false, null]:
		GameSettings.save_default_speed(value, _temp)
		var expected: int = clampi(value, 1, 3) if value is int else 1
		assert_eq(GameSettings.load_default_speed(_temp), expected)
	GameSettings.save_window_mode("bad", _temp)
	assert_eq(GameSettings.load_window_mode(_temp), "windowed")
	var cfg := ConfigFile.new()
	cfg.set_value("display", "window_mode", 42)
	cfg.set_value("gameplay", "default_speed", "three")
	cfg.save(_temp)
	assert_eq(GameSettings.load_default_speed(_temp), 1)
	assert_eq(GameSettings.load_window_mode(_temp), "windowed")
	cfg.set_value("gameplay", "default_speed", 99)
	cfg.save(_temp)
	assert_eq(GameSettings.load_default_speed(_temp), 3)
	var file := FileAccess.open(_temp, FileAccess.WRITE)
	file.store_string("garbage content")
	file.close()
	assert_eq(GameSettings.load_default_speed(_temp), 1)
	assert_eq(GameSettings.load_window_mode(_temp), "windowed")
	GameSettings.apply_window_mode("fullscreen") # Headless no-op.

func test_screen_shake_setting_round_trip_and_preserves_keys() -> void:
	assert_true(GameSettings.load_screen_shake(_temp))
	GameSettings.save_window_mode("fullscreen", _temp)
	GameSettings.save_screen_shake(false, _temp)
	assert_false(GameSettings.load_screen_shake(_temp))
	assert_eq(GameSettings.load_window_mode(_temp), "fullscreen")
	GameSettings.save_default_speed(2, _temp)
	assert_false(GameSettings.load_screen_shake(_temp))
	GameSettings.save_screen_shake(true, _temp)
	assert_true(GameSettings.load_screen_shake(_temp))
	assert_eq(GameSettings.load_default_speed(_temp), 2)
	var cfg := ConfigFile.new()
	cfg.set_value("gameplay", "screen_shake", "yes")
	cfg.save(_temp)
	assert_true(GameSettings.load_screen_shake(_temp))

func test_difficulty_setting_defaults_validates_and_preserves_other_gameplay_keys() -> void:
	assert_eq(GameSettings.load_difficulty(_temp), "normal")
	GameSettings.save_default_speed(3, _temp)
	for difficulty: String in ["easy", "normal", "hard"]:
		GameSettings.save_difficulty(difficulty, _temp)
		assert_eq(GameSettings.load_difficulty(_temp), difficulty)
	assert_eq(GameSettings.load_default_speed(_temp), 3)
	GameSettings.save_difficulty("impossible", _temp)
	assert_eq(GameSettings.load_difficulty(_temp), "normal")
	var cfg := ConfigFile.new()
	cfg.set_value("gameplay", "difficulty", 4)
	cfg.save(_temp)
	assert_eq(GameSettings.load_difficulty(_temp), "normal")
func test_new_game_uses_saved_default_speed() -> void:
	var game: Node = load("res://scripts/autoload/game.gd").new()
	for speed: int in [1, 2, 3]:
		GameSettings.save_default_speed(speed, _temp)
		game.new_game(1337, _temp)
		assert_eq(game.state.clock.speed, speed, "Actual game initialization reads saved speed")
		assert_false(game.state.clock.paused)
		assert_false(game.state.clock.locked)
	game.free()

func test_new_game_uses_saved_difficulty_and_explicit_choice() -> void:
	var game: Node = load("res://scripts/autoload/game.gd").new()
	GameSettings.save_difficulty("hard", _temp)
	game.new_game(1337, _temp)
	assert_eq(game.state.difficulty, "hard")
	game.new_game(1337, _temp, "easy")
	assert_eq(game.state.difficulty, "easy")
	game.free()

func test_settings_back_preserves_pause_until_resume() -> void:
	var state := GameState.new(GameData.load_default(), 1337)
	var pause: PauseMenu = load("res://scenes/ui/pause_menu.tscn").instantiate()
	var settings: SettingsScreen = load("res://scenes/ui/settings_screen.tscn").instantiate()
	var build := BuildMode.new()
	var selection := SelectionController.new()
	var main_menu := CanvasLayer.new()
	var report := CanvasLayer.new()
	main_menu.visible = false
	report.visible = false
	pause.bind(state, build, selection, main_menu, report, null, settings)
	settings.bind()
	pause.open()
	pause.get_node(MenuScreen.CONTENT + "Buttons/Settings").pressed.emit()
	assert_true(settings.visible)
	assert_false(pause.visible)
	assert_true(state.clock.paused and state.clock.locked)
	settings.get_node(MenuScreen.CONTENT + "Buttons/Back").pressed.emit()
	assert_true(pause.visible)
	assert_false(settings.visible)
	assert_true(state.clock.paused and state.clock.locked)
	pause.close()
	assert_false(state.clock.paused or state.clock.locked)
	for node: Node in [pause, settings, build, selection, main_menu, report]:
		node.free()
