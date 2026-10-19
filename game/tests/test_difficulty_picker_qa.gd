extends TestCase
## T-148: saved-run difficulty must take precedence over the next-game choice.

const CONTENT := "Dim/Center/Panel/Margin/Content/"

var _settings: String

class RestartFlowGame:
	extends "res://scripts/autoload/game.gd"
	var settings_path: String

	func _transition(_to_menu: bool, _fresh_seed: bool = false) -> void:
		new_game(next_seed, settings_path)

func before_each() -> void:
	_settings = temp_path("t148_difficulty_qa", "cfg")
	remove_test_temp_file(_settings)

func after_each() -> void:
	remove_test_temp_file(_settings)

func test_continue_uses_saved_difficulty_when_last_choice_differs() -> void:
	var data: GameData = GameData.load_default()
	var game: Node = load("res://scripts/autoload/game.gd").new()
	GameSettings.save_difficulty("easy", _settings)
	var saved: GameState = GameState.new(data, 1337, "hard")
	game.set("_pending_continue", SaveGame.from_json(SaveGame.to_json(SaveGame.capture(saved))))
	game.new_game(7331, _settings)
	assert_eq(game.state.difficulty, "hard", "Continue keeps the saved difficulty over the last new-game choice")
	assert_eq(game.state.difficulty_multipliers, data.difficulty_config("hard"))
	assert_eq(GameSettings.load_difficulty(_settings), "easy", "Continue does not overwrite the remembered choice")
	game.free()

func test_restart_uses_active_run_difficulty_without_changing_remembered_choice() -> void:
	var data: GameData = GameData.load_default()
	for pair: Array in [["easy", "hard"], ["hard", "easy"]]:
		var remembered: String = pair[0]
		var active: String = pair[1]
		var game: Node = RestartFlowGame.new()
		game.settings_path = _settings
		GameSettings.save_difficulty(remembered, _settings)
		game.state = GameState.new(data, 424242, active)
		game.next_seed = 1337
		game.restart()
		assert_eq(game.next_seed, 424242, "Restart synchronizes the seed from the active run")
		assert_eq(game.state.difficulty, active, "Restart carries the active run difficulty")
		assert_eq(game.state.map_seed, 424242, "Restart keeps the map seed")
		assert_eq(GameSettings.load_difficulty(_settings), remembered,
			"Restart leaves the remembered New Game difficulty untouched")
		assert_eq(game.get("_pending_restart_difficulty"), "", "Restart difficulty is consumed once")
		var pause: PauseMenu = load("res://scenes/ui/pause_menu.tscn").instantiate()
		pause.bind(game.state, null, null, null, null)
		assert_eq(pause.get_node(CONTENT + "Difficulty").text, "Seed 424242 · " + active.capitalize())
		pause.free()
		game.free()

func test_pause_and_end_screens_show_each_difficulty() -> void:
	var data: GameData = GameData.load_default()
	for difficulty: String in ["easy", "normal", "hard"]:
		var state: GameState = GameState.new(data, 1337, difficulty)
		var expected: String = "Difficulty: " + difficulty.capitalize()
		var pause: PauseMenu = load("res://scenes/ui/pause_menu.tscn").instantiate()
		pause.bind(state, null, null, null, null)
		assert_eq(pause.get_node(CONTENT + "Difficulty").text, "Seed 1337 · " + difficulty.capitalize())
		pause.free()
		state.game_over = true
		state.lose_reason = "command_center"
		var loss: GameOverScreen = load("res://scenes/ui/game_over.tscn").instantiate()
		loss.bind(state)
		assert_eq(loss.get_node(CONTENT + "Difficulty").text, expected)
		loss.free()
		state.won = true
		var victory: VictoryScreen = load("res://scenes/ui/victory.tscn").instantiate()
		victory.bind(state)
		assert_eq(victory.get_node(CONTENT + "Difficulty").text, expected)
		victory.free()

func test_restart_after_continue_resets_progress_and_consumes_run_override() -> void:
	var data: GameData = GameData.load_default()
	for pair: Array in [["easy", "hard"], ["hard", "easy"]]:
		var game: Node = RestartFlowGame.new()
		game.settings_path = _settings
		GameSettings.save_difficulty(pair[0], _settings)
		var saved: GameState = GameState.new(data, 424242, pair[1])
		saved.clock.day = 4
		saved.resources.add("wood", 999)
		saved.zombies_killed = 123
		game.set("_pending_continue", SaveGame.from_json(SaveGame.to_json(SaveGame.capture(saved))))
		game.new_game(7331, _settings)
		assert_eq(game.state.clock.day, 4, "Fixture actually restores saved progress")
		game.next_seed = 1337
		game.restart()
		var fresh: GameState = GameState.new(data, 424242, pair[1])
		assert_eq(game.state.difficulty, pair[1], "Continued run retains its difficulty on Restart")
		assert_eq(game.state.difficulty_multipliers, data.difficulty_config(pair[1]))
		assert_eq(game.state.map_seed, fresh.map_seed)
		assert_eq(game.state.clock.day, 1)
		assert_eq(game.state.zombies_killed, 0)
		assert_eq(game.state.resources.get_amount("wood"), fresh.resources.get_amount("wood"))
		assert_eq(GameSettings.load_difficulty(_settings), pair[0])
		game.new_game(7331, _settings)
		assert_eq(game.state.difficulty, pair[0], "Later New Game resolves the remembered choice")
		game.free()
