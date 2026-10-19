extends TestCase
## Observe requested paths without ever opening the player's real save.

class AutomatedGameSpy:
	extends "res://scripts/autoload/game.gd"

	var read_paths: Array[String] = []

	func _is_automated_run() -> bool:
		return true

	func _read_save(path: String) -> Dictionary:
		read_paths.append(path)
		return {}

	func _transition(_to_menu: bool, _fresh_seed: bool = false) -> void:
		pass

class CleanupGameSpy:
	extends "res://scripts/autoload/game.gd"

	var cleanup_path: String

	func _is_automated_run() -> bool:
		return true

	func _automated_save_path() -> String:
		return cleanup_path

var _automated_slot: String
var _injected_path: String

func before_each() -> void:
	_automated_slot = temp_path("automated_cleanup", "json")
	_injected_path = temp_path("injected_save", "json")
	_remove_save_and_sidecars(_automated_slot)
	_remove_save_and_sidecars(_injected_path)

func after_each() -> void:
	_remove_save_and_sidecars(_automated_slot)
	_remove_save_and_sidecars(_injected_path)

func _remove_save_and_sidecars(path: String) -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		remove_test_temp_file(path + suffix)

func test_automated_menu_queries_do_not_read_player_save() -> void:
	var game := AutomatedGameSpy.new()
	# Honor any automated-path redirection performed by the real autoload at startup.
	game.save_path = Game.save_path
	game.has_save()
	assert_false(game.read_paths.has(game.SAVE_PATH),
		"Headless/smoke menu must not probe the player's real save")
	game.read_paths.clear()
	game.save_day()
	assert_false(game.read_paths.has(game.SAVE_PATH),
		"Automated save-day query must not probe the player's real save")
	game.free()

func test_automated_continue_does_not_read_player_save() -> void:
	var game := AutomatedGameSpy.new()
	game.save_path = Game.save_path
	game.continue_game()
	assert_false(game.read_paths.has(game.SAVE_PATH),
		"Automated Continue must not probe the player's real save")
	game.free()

func test_automated_queries_allow_injected_save_paths() -> void:
	var game := AutomatedGameSpy.new()
	game.save_path = _injected_path
	game.has_save()
	game.save_day()
	game.continue_game()
	assert_eq(game.read_paths, [game.save_path, game.save_path, game.save_path],
		"Scenario/test saves must remain usable through the injected path")
	game.free()

func test_exit_cleans_automated_slot_and_sidecars_with_injected_path() -> void:
	var game := CleanupGameSpy.new()
	game.cleanup_path = _automated_slot
	game.save_path = _injected_path
	game.new_game(1337)
	assert_true(game.save_now({}, game._automated_save_path()))
	assert_true(game.save_now())
	for suffix: String in [game.SAVE_TEMP_SUFFIX, game.SAVE_BACKUP_SUFFIX]:
		var file: FileAccess = FileAccess.open(game._automated_save_path() + suffix, FileAccess.WRITE)
		file.store_string("disposable sidecar")
		file.close()
	game._exit_tree()
	for suffix: String in ["", game.SAVE_TEMP_SUFFIX, game.SAVE_BACKUP_SUFFIX]:
		assert_false(FileAccess.file_exists(game._automated_save_path() + suffix), "Exit removes process save and sidecars")
	assert_true(FileAccess.file_exists(game.save_path), "Exit cleanup stays scoped to the automated slot")
	game.free()
