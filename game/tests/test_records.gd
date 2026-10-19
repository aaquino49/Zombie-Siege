class_name TestRecords extends TestCase

var path: String

func before_each() -> void:
	path = temp_path("records", "cfg")
	Records.remove_file(path)

func after_each() -> void:
	Records.remove_file(path)

func test_first_submit_creates_difficulty_record() -> void:
	var beaten: Dictionary = Records.submit("normal", 23, false, 500.0, path)
	assert_true(bool(beaten["best_nights"]))
	assert_false(bool(beaten["fastest_win"]))
	assert_false(bool(beaten["first_win"]))
	assert_eq(Records.load_all(path), {"normal": {"best_nights": 23, "wins": 0, "fastest_win_s": 0}})

func test_worse_result_does_not_replace_best_nights() -> void:
	Records.submit("easy", 12, false, 0.0, path)
	var beaten: Dictionary = Records.submit("easy", 8, false, 0.0, path)
	assert_false(bool(beaten["best_nights"]))
	assert_eq(int(Records.load_all(path)["easy"]["best_nights"]), 12)

func test_first_and_fastest_win_records_are_kept_once_per_run() -> void:
	Records.submit("normal", 23, false, 0.0, path)
	var first: Dictionary = Records.submit("normal", 23, true, 2470.0, path)
	assert_true(bool(first["first_win"]))
	assert_true(bool(first["fastest_win"]))
	var next: Dictionary = Records.submit("normal", 24, true, 3000.0, path)
	assert_false(bool(next["first_win"]))
	assert_false(bool(next["fastest_win"]))
	var record: Dictionary = Records.load_all(path)["normal"]
	assert_eq(int(record["wins"]), 2)
	assert_eq(int(record["fastest_win_s"]), 2470)
	assert_eq(int(record["best_nights"]), 24)

func test_keep_fighting_then_loss_does_not_add_another_win() -> void:
	var data: GameData = GameData.load_default()
	var state := GameState.new(data, 1337, "normal")
	state.waves.enabled = false
	state.won = true
	state.game_over = true
	state.time_played = 2470.0
	state.clock.day = 21
	var victory := load("res://scenes/ui/victory.tscn").instantiate() as VictoryScreen
	victory.records_path = path
	victory.call("bind", state)
	assert_true(victory.visible, "Victory panel records its win")
	victory.call("_keep_fighting")
	state.clock.day = 22
	state.game_over = true
	state.lose_reason = "command_center"
	var game_over := load("res://scenes/ui/game_over.tscn").instantiate() as GameOverScreen
	game_over.records_path = path
	game_over.call("bind", state)
	var record: Dictionary = Records.load_all(path)["normal"]
	assert_eq(int(record["wins"]), 1, "Endless loss does not add a win")
	assert_eq(int(record["best_nights"]), 21, "Endless loss can improve nights")
	victory.free()
	game_over.free()
	state = null
	data = null

func test_corrupt_file_is_empty_and_submit_recovers() -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	file.store_string("not a valid config [\n{{{")
	file.close()
	assert_eq(Records.load_all(path), {})
	var beaten: Dictionary = Records.submit("hard", 9, false, 0.0, path)
	assert_true(bool(beaten["best_nights"]))
	assert_eq(int(Records.load_all(path)["hard"]["best_nights"]), 9)

func test_menu_line_lists_only_recorded_difficulties() -> void:
	assert_eq(Records.format_menu_line({}), "")
	var records := {"normal": {"best_nights": 23}, "hard": {"best_nights": 9}}
	assert_eq(Records.format_menu_line(records), "Best: Normal 23 · Hard 9 nights")

func test_new_record_lines_format_nights_fastest_and_first_win() -> void:
	var beaten := {"best_nights": true, "fastest_win": true, "first_win": true}
	assert_eq(Records.new_record_lines(beaten, "normal", 23, 2470.0),
		"New record: 23 nights (Normal)\nFastest win: 41:10\nFirst win: Normal")
