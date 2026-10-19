extends TestCase

var _temp: String

class SaveServiceSpy:
	extends "res://scripts/autoload/game.gd"

	var reads: int = 0
	var transitions: int = 0
	var invalidate_pending: bool = false

	func _read_save(path: String) -> Dictionary:
		reads += 1
		return super._read_save(path)

	func _transition(_to_menu: bool, _fresh_seed: bool = false) -> void:
		transitions += 1
		if invalidate_pending:
			_pending_continue["day"] = 0
		new_game(next_seed)

class MenuSpy:
	extends "res://scripts/ui/main_menu.gd"

	var service: Node

	func _refresh_continue(_save_service: Node = Game) -> void:
		super._refresh_continue(service)

var _game: Node
var _old_path: String

func before_each() -> void:
	_temp = temp_path("savegame", "json")
	_old_path = Game.save_path
	Game.save_path = _temp
	Game.delete_save()
	_game = SaveServiceSpy.new()
	_game.save_path = _temp
	_game.new_game(1337)

func after_each() -> void:
	Game.save_path = _temp
	Game.delete_save()
	for suffix: String in ["", ".tmp", ".bak"]:
		remove_test_temp_file(_temp + suffix)
	Game.save_path = _old_path
	_game.free()
	_game = null

func test_save_day_extra_and_restore_data_with_injected_path() -> void:
	_game.state.clock.day = 3
	_game.state.resources.add("wood", 27)
	assert_true(_game.save_now({"hints": {"welcome": true}}, _temp))
	assert_true(_game.has_save(_temp))
	assert_eq(_game.save_day(_temp), 3)
	var file: FileAccess = FileAccess.open(_temp, FileAccess.READ)
	var saved: Dictionary = SaveGame.from_json(file.get_as_text())
	file.close()
	assert_eq(saved["extra"], {"hints": {"welcome": true}})
	var restored: GameState = SaveGame.restore(GameData.load_default(), saved)
	assert_eq(restored.clock.day, 3)
	assert_eq(restored.resources.get_amount("wood"), _game.state.resources.get_amount("wood"))
	assert_eq(restored.buildings.all().size(), _game.state.buildings.all().size())
	assert_eq(restored.survivors.all().size(), _game.state.survivors.all().size())
	_game.state.clock.day = 4
	assert_true(_game.save_now({}, _temp), "A later dawn atomically replaces the older save")
	assert_eq(_game.save_day(_temp), 4)

func test_corrupt_save_is_removed_without_crashing() -> void:
	var file: FileAccess = FileAccess.open(_temp, FileAccess.WRITE)
	file.store_string("not json{{{")
	file.close()
	assert_false(_game.has_save(_temp))
	assert_false(FileAccess.file_exists(_temp))
	assert_eq(_game.save_day(_temp), 0)
	var unsupported: Dictionary = SaveGame.capture(_game.state)
	unsupported["version"] = SaveGame.VERSION + 1
	file = FileAccess.open(_temp, FileAccess.WRITE)
	file.store_string(SaveGame.to_json(unsupported))
	file.close()
	assert_false(_game.has_save(_temp), "Unsupported save versions are removed")
	assert_false(FileAccess.file_exists(_temp))

func test_has_save_for_matches_current_run_identity() -> void:
	assert_false(_game.has_save_for(null, _temp), "A null run state cannot match a save")
	_game.state.clock.day = 3
	assert_true(_game.save_now({}, _temp))
	assert_true(_game.has_save_for(_game.state, _temp), "Matching seed, difficulty and day expose the save")
	var other_run: GameState = GameState.new(GameData.load_default(), 2468, _game.state.difficulty)
	other_run.clock.day = _game.state.clock.day
	assert_false(_game.has_save_for(other_run, _temp), "A different seed belongs to another run")

func test_main_menu_continue_visibility_label_and_terminal_cleanup() -> void:
	var menu: MainMenu = (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate() as MainMenu
	menu.bind(_game.state)
	menu.open(_game.state)
	var button: Button = menu.get_node("Dim/Center/Panel/Margin/Content/Buttons/Continue")
	assert_false(button.visible, "No Continue without a save")
	_game.state.clock.day = 5
	assert_true(_game.save_now({}, _temp))
	menu.open(_game.state)
	assert_true(button.visible, "Continue appears with a valid save")
	assert_eq(button.text, "Continue (Day 5)")
	var main_script: GDScript = load("res://scripts/main.gd")
	var main_node: Node = main_script.new()
	main_node._on_game_lost("survivors")
	assert_false(_game.has_save(_temp), "Game Over removes the save")
	assert_true(_game.save_now({}, _temp))
	main_node._on_game_won()
	assert_false(_game.has_save(_temp), "Victory removes the save")
	main_node.free()
	menu.free()

func test_vanished_save_between_menu_check_and_continue_starts_fresh() -> void:
	_game.state.clock.day = 5
	assert_true(_game.save_now({"hints": {"welcome": true}}, _temp))
	assert_true(_game.has_save(_temp))
	_game.delete_save(_temp)
	_game.next_seed = 2468
	_game.continue_game(_temp)
	_assert_fresh_continue()

func test_corrupted_save_between_menu_check_and_continue_starts_fresh() -> void:
	_game.state.clock.day = 5
	assert_true(_game.save_now({}, _temp))
	assert_true(_game.has_save(_temp))
	var file: FileAccess = FileAccess.open(_temp, FileAccess.WRITE)
	file.store_string("invalid json")
	file.close()
	_game.next_seed = 2468
	_game.continue_game(_temp)
	_assert_fresh_continue()

func test_failed_pending_restore_starts_fresh_and_discards_extra() -> void:
	_game.state.clock.day = 5
	assert_true(_game.save_now({"hints": {"welcome": true}}, _temp))
	assert_true(_game.has_save(_temp))
	_game.next_seed = 2468
	_game.invalidate_pending = true
	_game.continue_game(_temp)
	_assert_fresh_continue()

func test_reload_day_uses_continue_restore_path_exactly() -> void:
	_game.new_game(9182, GameSettings.PATH, "hard")
	_game.state.clock.day = 4
	_game.state.clock.elapsed = 123.0
	_game.state.resources.add("wood", 37)
	_game.state.resources.add("food", 19)
	_game.state.endless = true
	assert_true(_game.save_now({"hints": {"welcome": true}}, _temp))
	var saved_file: FileAccess = FileAccess.open(_temp, FileAccess.READ)
	var saved: Dictionary = SaveGame.from_json(saved_file.get_as_text())
	saved_file.close()
	_game.state.resources.spend({"wood": 25, "food": 12})
	_game.state.clock.day = 9
	_game.state.clock.phase = GameClock.Phase.NIGHT
	_game.state.endless = false
	_game.state.map_seed = 2468
	_game.state.difficulty = "easy"
	_game.next_seed = 2468
	_game.reload_day(_temp)
	assert_eq(_game.transitions, 1, "Reload uses the existing scene transition")
	assert_eq(_game.state.map_seed, 9182)
	assert_eq(_game.state.clock.day, 4)
	assert_eq(_game.state.difficulty, "hard")
	var restored_snapshot: Dictionary = SaveGame.from_json(SaveGame.to_json(
		SaveGame.capture(_game.state, _game.continued_extra)))
	assert_eq(restored_snapshot["resources"], saved["resources"])
	assert_eq(restored_snapshot["buildings"], saved["buildings"])
	assert_eq(restored_snapshot["survivors"], saved["survivors"])
	assert_eq(_game.state.clock.phase, GameClock.Phase.DAY)
	assert_eq(_game.state.clock.elapsed, 0.0, "Reload starts at full daylight")
	assert_true(_game.state.endless, "Saved endless handling remains the Continue behavior")
	assert_eq(_game.continued_extra, {"hints": {"welcome": true}})

func _assert_fresh_continue() -> void:
	assert_eq(_game.transitions, 1, "Continue still leaves the main menu")
	assert_not_null(_game.state)
	if _game.state == null:
		return
	assert_eq(_game.state.clock.day, 1)
	assert_eq(_game.state.map_seed, 2468)
	assert_eq(_game.state.clock.phase, GameClock.Phase.DAY)
	assert_true(_game.state.waves.enabled)
	assert_eq(_game.continued_extra, {}, "Failed Continue drops saved hints")
	assert_eq(_game._pending_continue, {})
	assert_false(FileAccess.file_exists(_temp))

func test_menu_open_reads_valid_save_once() -> void:
	_game.state.clock.day = 5
	assert_true(_game.save_now({}, _temp))
	_assert_menu_reads_once(true)

func test_menu_open_reads_missing_save_once() -> void:
	_assert_menu_reads_once(false)

func _assert_menu_reads_once(expected_visible: bool) -> void:
	var menu: MainMenu = (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate() as MainMenu
	menu.set_script(MenuSpy)
	menu.set("service", _game)
	menu.bind(_game.state)
	_game.reads = 0
	menu.open(_game.state)
	assert_eq(_game.reads, 1, "Opening the menu validates/parses the save only once")
	var button: Button = menu.get_node("Dim/Center/Panel/Margin/Content/Buttons/Continue")
	assert_eq(button.visible, expected_visible)
	assert_eq(button.text, "Continue (Day 5)" if expected_visible else "Continue")
	menu.free()
