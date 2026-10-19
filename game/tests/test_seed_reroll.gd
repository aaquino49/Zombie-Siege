extends TestCase

class SeedFlowGame:
	extends "res://scripts/autoload/game.gd"
	var settings_path: String

	func _transition(_to_menu: bool, _fresh_seed: bool = false) -> void:
		new_game(next_seed, settings_path)

var _settings_path: String

func before_each() -> void:
	_settings_path = temp_path("seed_reroll_settings", "cfg")
	remove_test_temp_file(_settings_path)

func after_each() -> void:
	remove_test_temp_file(_settings_path)

func test_reroll_changes_preview() -> void:
	var game: Node = load("res://scripts/autoload/game.gd").new()
	game.preview_seed = 12345
	var seed_a: int = game.reroll_seed()
	assert_ne(seed_a, 12345)
	assert_eq(game.preview_seed, seed_a)
	var seed_b: int = game.reroll_seed()
	assert_ne(seed_b, seed_a)
	game.free()

func test_same_preview_seed_generates_same_map_and_start_uses_preview() -> void:
	var data: GameData = GameData.load_default()
	var first: GameState = GameState.new(data, 24680)
	var second: GameState = GameState.new(data, 24680)
	_assert_maps_equal(first.map, second.map)
	var game: SeedFlowGame = SeedFlowGame.new()
	game.settings_path = _settings_path
	game.preview_seed = 24680
	game.start_new_game("", game.preview_seed)
	assert_eq(game.state.map_seed, 24680)
	_assert_maps_equal(first.map, game.state.map)
	game.free()

func test_restart_keeps_run_seed() -> void:
	var game: SeedFlowGame = SeedFlowGame.new()
	game.settings_path = _settings_path
	game.state = GameState.new(GameData.load_default(), 97531)
	game.restart()
	assert_eq(game.next_seed, 97531)
	assert_eq(game.state.map_seed, 97531)
	game.free()

func test_pause_line_shows_seed_and_difficulty() -> void:
	var state: GameState = GameState.new(GameData.load_default(), 86420, "hard")
	var pause: PauseMenu = load("res://scenes/ui/pause_menu.tscn").instantiate() as PauseMenu
	pause.bind(state, null, null, null, null)
	assert_eq(pause.get_node(PauseMenu.CONTENT + "Difficulty").text, "Seed 86420 · Hard")
	pause.free()

func _assert_maps_equal(left: WorldMap, right: WorldMap) -> void:
	assert_eq(left.size(), right.size())
	for x: int in range(left.size()):
		for y: int in range(left.size()):
			var tile := Vector2i(x, y)
			assert_eq(left.terrain_at(tile), right.terrain_at(tile), "Terrain differs at %s" % tile)
			assert_eq(left.occupant_at(tile), right.occupant_at(tile), "Occupant differs at %s" % tile)
			assert_eq(left.get_node_amount(tile), right.get_node_amount(tile), "Node amount differs at %s" % tile)
