extends TestCase
## Release-level checks spanning the M9 features; live audio wiring is in qa_m9_endless.

class ReleaseGame:
	extends "res://scripts/autoload/game.gd"
	var settings_path: String
	func _transition(_to_menu: bool, _fresh_seed: bool = false) -> void:
		new_game(next_seed, settings_path)

var data: GameData
var state: GameState
var owned: Array[Node] = []

func before_each() -> void:
	data = GameData.load_default()
	state = GameState.new(data, 1337, "normal")
	state.waves.enabled = false

func after_each() -> void:
	for node: Node in owned:
		node.free()
	owned.clear()
	state = null
	data = null

func _win_and_continue() -> VictoryScreen:
	state.clock.day = 20
	state.resources.add("wood", 1000)
	state.resources.add("scrap", 1000)
	VictorySetup.place_finished_tower(state)
	var victory: VictoryScreen = load("res://scenes/ui/victory.tscn").instantiate()
	owned.append(victory)
	victory.bind(state)
	state.clock.phase = GameClock.Phase.NIGHT
	state.clock.elapsed = float(data.balance("night_min_length"))
	state.tick(0.1)
	assert_true(state.won and victory.visible)
	victory.get_node("Dim/Center/Panel/Margin/Content/Buttons/KeepFighting").pressed.emit()
	assert_true(state.endless and not state.game_over)
	assert_false(victory.visible or state.clock.locked or state.clock.paused)
	return victory

func test_keep_fighting_real_night22_cap_and_no_second_win() -> void:
	var wins: Array[int] = []
	state.game_won.connect(func() -> void: wins.append(1))
	var victory: VictoryScreen = _win_and_continue()
	state.clock.day = 22
	state.waves.enabled = true
	state.clock.elapsed = float(data.balance("day_length")) - 0.1
	state.tick(0.2)
	assert_eq(state.clock.phase, GameClock.Phase.NIGHT)
	assert_gt(state.zombies.count(), 0)
	var forecast: Dictionary = WaveSpawner.forecast(data, 22, state.difficulty_multipliers)
	assert_eq(state.hostiles_remaining(), int(forecast["walker"]) + int(forecast["runner"]) + int(forecast["brute"]) + int(forecast["spitter"]))
	assert_false("FINAL HORDE" in HudText.forecast_text(forecast))
	state.clock.elapsed = float(data.balance("night_max_length")) - 0.1
	state.tick(0.2)
	assert_eq(state.clock.day, 23)
	assert_eq(state.hostiles_remaining(), 0)
	assert_eq(wins, [1])
	assert_false(victory.visible or state.game_over)
	assert_eq(state.last_dawn_report["objective"], "Survive as long as you can (Endless, night 22)")

func test_file_continue_endless_then_loss_keeps_full_statistics() -> void:
	_win_and_continue()
	state.clock.day = 23
	state.zombies_killed = 456
	var service := ReleaseGame.new()
	owned.append(service)
	service.settings_path = temp_path("m9_settings", "cfg")
	service.save_path = temp_path("m9_endless", "json")
	service.state = state
	assert_true(service.save_now())
	service.continue_game()
	var restored: GameState = service.state
	assert_true(restored.won and restored.endless and restored.waves.enabled)
	assert_false(restored.game_over or restored.clock.locked or restored.clock.paused)
	assert_eq(restored.clock.day, 23)
	var screen: GameOverScreen = load("res://scenes/ui/game_over.tscn").instantiate()
	owned.append(screen)
	screen.bind(restored)
	var cc: Building = restored.buildings.all_of_type("command_center")[0]
	restored.damage_building(cc, cc.hp)
	restored.tick(0.0)
	assert_true(screen.visible and restored.game_over)
	assert_eq(restored.lose_reason, "command_center")
	assert_eq(int(restored.stats()["zombies_killed"]), 456)
	service.delete_save()

func test_rerolls_leave_sim_rng_untouched_start_changes_map_restart_keeps_it() -> void:
	var service := ReleaseGame.new()
	owned.append(service)
	service.settings_path = temp_path("m9_seed_settings", "cfg")
	service.state = state
	service.preview_seed = state.map_seed
	var rng_before: int = state.rng.state
	var waves_before: int = state.waves._rng.state
	for index: int in range(5):
		var previous: int = service.preview_seed
		assert_ne(service.reroll_seed(), previous)
	assert_eq(state.rng.state, rng_before)
	assert_eq(state.waves._rng.state, waves_before)
	var shown: int = service.preview_seed
	service.start_new_game("", shown)
	assert_eq(service.state.map_seed, shown)
	var changed: bool = false
	for y: int in range(state.map.size()):
		for x: int in range(state.map.size()):
			var tile := Vector2i(x, y)
			changed = changed or state.map.terrain_at(tile) != service.state.map.terrain_at(tile) or state.map.occupant_at(tile) != service.state.map.occupant_at(tile)
	assert_true(changed, "Rerolled seed changes the generated map")
	var first: Dictionary = SaveGame.capture(service.state)
	var before_map: WorldMap = service.state.map
	service.restart()
	var restarted: Dictionary = SaveGame.capture(service.state)
	assert_eq(restarted["nodes"], first["nodes"], "Restart keeps generated resource nodes")
	for y: int in range(state.map.size()):
		for x: int in range(state.map.size()):
			var tile := Vector2i(x, y)
			assert_eq(service.state.map.terrain_at(tile), before_map.terrain_at(tile))
	assert_eq(service.state.map_seed, shown)

func test_ghost_process_uses_real_placement_validity_and_moves_ring() -> void:
	state.clock.day = int(data.get_building("turret")["unlock_day"])
	var mode := BuildMode.new()
	owned.append(mode)
	mode.bind(state)
	state.resources.add("wood", 1000)
	state.resources.add("scrap", 1000)
	var origin: Vector2i = state.map.command_center_origin() + Vector2i(4, 0)
	state.map.vacate(origin, Vector2i.ONE)
	mode.select("turret")
	mode.preview_at(origin)
	mode._process(0.0)
	assert_eq(Placement.check(state, "turret", origin), Placement.Result.OK)
	assert_eq(mode._range_preview["color"], Color(0.2, 1.0, 0.35))
	assert_eq(mode._range_preview["center"], Grid.tile_to_world(origin))
	mode.preview_at(state.map.command_center_origin())
	mode._process(0.0)
	assert_eq(mode._range_preview["color"], Color(1.0, 0.2, 0.2))
	assert_eq(mode._range_preview["center"], Grid.tile_to_world(state.map.command_center_origin()))
	mode.cancel()
	mode._process(0.0)
	assert_true(mode._range_preview.is_empty())

func test_changed_data_drives_ghost_selection_and_info_for_all_defenders() -> void:
	# In-memory variation proves radii are not pinned to current balance numbers.
	data._buildings["turret"]["range_tiles"] = 6.25
	data._balance["guard_range_tiles"] = 4.0
	data._buildings["watchtower"]["guard_range_mult"] = 1.75
	var mode := BuildMode.new()
	var selection := SelectionController.new()
	var info: InfoPanel = load("res://scenes/ui/info_panel.tscn").instantiate()
	owned.append_array([info, selection, mode])
	mode.bind(state)
	selection.bind(state)
	info.bind(state, selection)
	var origin: Vector2i = state.map.command_center_origin() + Vector2i(4, 0)
	for type_id: String in ["turret", "watchtower"]:
		var building: Building = state.buildings.add(type_id, origin, true)
		selection.select_building(building.uid)
		var expected: float = 6.25 if type_id == "turret" else 7.0
		assert_eq(mode.range_preview_for(type_id, origin, true)["radius"], expected * Grid.TILE)
		assert_eq(selection.range_preview()["radius"], expected * Grid.TILE)
		info.refresh()
		assert_eq(info._range_label.text, "Range: 6.3 tiles" if type_id == "turret" else "Range: 7 tiles")
		if type_id == "watchtower":
			var guard: Survivor = state.survivors.all()[0]
			guard.job = Survivor.Job.GUARD
			guard.post_uid = building.uid
			guard.pos = building.center_world() + Vector2(20, 10)
			selection.select_survivor(guard.uid)
			assert_eq(selection.range_preview()["center"], building.center_world())
			assert_eq(selection.range_preview()["radius"], expected * Grid.TILE)
			guard.post_uid = 0
			guard.post_tile = origin
			assert_eq(selection.range_preview()["radius"], 4.0 * Grid.TILE)
		origin += Vector2i(0, 3)
