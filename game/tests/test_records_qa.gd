extends TestCase

var path: String

func before_each() -> void:
	path = temp_path("records_qa", "cfg")
	Records.remove_file(path)

func after_each() -> void:
	Records.remove_file(path)

func test_persistence_across_launches_and_difficulty_separation() -> void:
	var mode: String = ""
	var shared_path: String = path
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-records-mode="):
			mode = arg.trim_prefix("--qa-records-mode=")
		if arg.begins_with("--qa-records-path="):
			shared_path = arg.trim_prefix("--qa-records-path=")
	if mode == "write":
		Records.submit("easy", 12, false, 0.0, shared_path)
		Records.submit("normal", 23, true, 2470.0, shared_path)
		Records.submit("hard", 9, false, 0.0, shared_path)
		return
	if mode == "read":
		assert_eq(Records.load_all(shared_path), {
			"easy": {"best_nights": 12, "wins": 0, "fastest_win_s": 0},
			"normal": {"best_nights": 23, "wins": 1, "fastest_win_s": 2470},
			"hard": {"best_nights": 9, "wins": 0, "fastest_win_s": 0}})
		return
	var executable: String = OS.get_executable_path()
	var console: String = executable.get_basename() + "_console.exe"
	if FileAccess.file_exists(console):
		executable = console
	for child_mode: String in ["write", "read"]:
		var output: Array = []
		var args := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--script", "res://tests/run_tests.gd", "--",
			"--filter=test_persistence_across_launches_and_difficulty_separation",
			"--qa-records-mode=" + child_mode, "--qa-records-path=" + path])
		assert_eq(OS.execute(executable, args, output, true), 0, str(output))
		assert_true(str(output).contains("TESTS: 1 passed, 0 failed"), str(output))

func test_equal_results_are_quiet_and_faster_win_replaces_minimum() -> void:
	Records.submit("normal", 23, true, 2470.0, path)
	assert_eq(Records.submit("normal", 23, false, 3000.0, path),
		{"best_nights": false, "fastest_win": false, "first_win": false})
	assert_eq(Records.submit("normal", 23, true, 2400.0, path),
		{"best_nights": false, "fastest_win": true, "first_win": false})
	assert_eq(int(Records.load_all(path)["normal"]["fastest_win_s"]), 2400)

func test_victory_panel_counts_repeated_events_once_and_hides_unbeaten_lines() -> void:
	Records.submit("normal", 25, true, 2000.0, path)
	var state := GameState.new(GameData.load_default(), 1337, "normal")
	state.won = true
	state.game_over = true
	state.clock.day = 21
	state.time_played = 2470.0
	var screen := (load("res://scenes/ui/victory.tscn") as PackedScene).instantiate() as VictoryScreen
	screen.records_path = path
	screen.bind(state)
	var line := screen.get_node("Dim/Center/Panel/Margin/Content/RecordLine") as Label
	assert_false(line.visible, "A slower win below the nights record shows no extra line")
	assert_eq(line.text, "")
	state.game_won.emit()
	screen.call("_show_panel")
	assert_eq(int(Records.load_all(path)["normal"]["wins"]), 2, "One new win despite repeated events")
	screen.free()

func test_game_over_panel_shows_new_record_and_hides_tied_record() -> void:
	var state := GameState.new(GameData.load_default(), 1337, "hard")
	state.game_over = true
	state.lose_reason = "command_center"
	state.clock.day = 6
	for attempt: int in range(2):
		var screen := (load("res://scenes/ui/game_over.tscn") as PackedScene).instantiate() as GameOverScreen
		screen.records_path = path
		screen.bind(state)
		var line := screen.get_node("Dim/Center/Panel/Margin/Content/RecordLine") as Label
		assert_eq(line.visible, attempt == 0)
		assert_eq(line.text, "New record: 5 nights (Hard)" if attempt == 0 else "")
		screen.free()

func test_menu_record_label_hidden_when_missing_and_refreshed_when_present() -> void:
	var menu := (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate() as MainMenu
	menu.records_path = path
	menu.call("_refresh_records")
	var line := menu.get_node("Dim/Center/Panel/Margin/Content/BestRecords") as Label
	assert_false(line.visible)
	assert_eq(line.text, "")
	Records.submit("hard", 9, false, 0.0, path)
	menu.call("_refresh_records")
	assert_true(line.visible)
	assert_eq(line.text, "Best: Hard 9 nights")
	menu.free()

func test_automated_default_path_is_disposable() -> void:
	var resolved: String = Records._path_or_default(Records.PATH)
	assert_ne(resolved, Records.PATH, "Tests must not load or save the player's file")
	assert_eq(resolved, "user://automated_records_%d.cfg" % OS.get_process_id())
	assert_eq(Records._path_or_default(path), path, "Explicit temporary paths remain usable")
