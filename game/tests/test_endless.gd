extends TestCase

var data: GameData
var state: GameState
var won_count: int = 0
var lost_reasons: Array[String] = []

class EndlessContinueService:
	extends "res://scripts/autoload/game.gd"

	func _transition(_to_menu: bool, _fresh_seed: bool = false) -> void:
		new_game(next_seed)

class EndlessHints:
	extends Node

	func get_shown() -> Dictionary:
		return {"welcome": true}

func before_each() -> void:
	data = GameData.load_default()
	state = GameState.new(data, 186)
	state.waves.enabled = false
	won_count = 0
	lost_reasons.clear()
	state.game_won.connect(func() -> void: won_count += 1)
	state.game_lost.connect(func(reason: String) -> void: lost_reasons.append(reason))

func after_each() -> void:
	data = null
	state = null

func _place_tower() -> void:
	var origin: Vector2i = state.map.command_center_origin()
	state.clock.day = 8
	for y: int in range(origin.y - 4, origin.y + 6):
		for x: int in range(origin.x - 5, origin.x + 7):
			var tile := Vector2i(x, y)
			if state.map.occupant_at(tile) in [1, 2, 3]:
				state.map.vacate(tile, Vector2i.ONE)
	state.resources.add("wood", 1000)
	state.resources.add("scrap", 1000)
	var place: Vector2i = origin + Vector2i(-4, 0)
	var result: int = Placement.check(state, "radio_tower", place)
	if result != Placement.Result.OK:
		for radius: int in range(1, state.map.size() + 1):
			for y_offset: int in range(-radius, radius + 1):
				for x_offset: int in range(-radius, radius + 1):
					if maxi(absi(x_offset), absi(y_offset)) != radius:
						continue
					var candidate := origin + Vector2i(x_offset, y_offset)
					result = Placement.check(state, "radio_tower", candidate)
					if result == Placement.Result.OK:
						place = candidate
						break
				if result == Placement.Result.OK:
					break
			if result == Placement.Result.OK:
				break
	assert_eq(result, Placement.Result.OK, "Should find valid radio tower placement")
	assert_eq(state.try_place("radio_tower", place), Placement.Result.OK)
	var tower: Building = state.buildings.get_at(place)
	assert_true(tower != null, "Tower blueprint exists")
	state.buildings.finish(tower.uid)

func _advance_to_dawn(day: int) -> void:
	state.clock.day = day - 1
	state.clock.phase = GameClock.Phase.NIGHT
	state.clock.elapsed = float(data.balance("night_min_length", 45)) - 0.1
	state.tick(0.2)

func _continue_endless() -> void:
	state.endless = true
	state.game_over = false
	state.clock.locked = false
	state.clock.set_paused(false)

func test_dawn_21_win_then_endless_waves_without_second_win() -> void:
	_place_tower()
	_advance_to_dawn(21)
	assert_true(state.won, "Dawn 21 records the original win")
	assert_eq(won_count, 1, "Original win emits once")
	_continue_endless()
	state.waves.enabled = true
	state.clock.day = 22
	state.clock.phase = GameClock.Phase.DAY
	state.clock.elapsed = 0.0
	state.clock.phase_changed.emit(GameClock.Phase.NIGHT, 22)
	state.tick(0.1)
	assert_gt(state.hostiles_remaining(), 0, "Night 22 schedules and spawns its base-formula wave")
	assert_false(bool(data.wave_for_night(22).get("final", true)), "Night 22 is not a final horde")
	state.waves.enabled = false
	for day: int in range(23, 26):
		_advance_to_dawn(day)
	assert_eq(won_count, 1, "Endless mode never emits a second victory through dawn 25")
	assert_true(state.won, "Endless run retains the original won statistic")
	assert_false(state.game_over, "Endless run remains live after later dawns")

func test_loss_after_endless_win_emits_game_lost_with_stats() -> void:
	_place_tower()
	_advance_to_dawn(21)
	_continue_endless()
	state.clock.day = 22
	state.zombies_killed = 123
	state.cc_destroyed = true
	for survivor: Survivor in state.survivors.all().duplicate():
		state.survivors.remove(survivor.uid)
	state.tick(0.1)
	assert_eq(lost_reasons, ["command_center"], "Later loss emits Game Over reason")
	assert_true(state.game_over, "Later loss ends endless mode")
	assert_true(state.won, "Loss does not erase that the run won once")
	assert_eq(int(state.stats()["zombies_killed"]), 123, "Game Over stats remain intact")

func test_endless_save_round_trip_preserves_won_run_and_endless_flag() -> void:
	_place_tower()
	_advance_to_dawn(21)
	_continue_endless()
	state.clock.day = 22
	state.clock.phase = GameClock.Phase.DAY
	var saved: Dictionary = SaveGame.capture(state)
	assert_false(saved.is_empty(), "Endless won run can be autosaved at dawn")
	assert_true(bool(saved.get("endless", false)), "Save includes endless flag")
	var restored: GameState = SaveGame.restore(data, SaveGame.from_json(SaveGame.to_json(saved)))
	assert_true(restored.endless, "Continue restores endless mode")
	assert_true(restored.won, "Continue retains original win statistics")
	assert_false(restored.game_over, "Continue resumes live game")
	var helicopter := RescueHelicopter.new()
	helicopter.bind(restored, null)
	assert_false(helicopter.visible, "Continue does not replay rescue fly-in")
	helicopter.free()

func test_keep_fighting_button_resumes_and_hides_victory() -> void:
	var victory: VictoryScreen = (load("res://scenes/ui/victory.tscn") as PackedScene).instantiate() as VictoryScreen
	victory.bind(state)
	state.won = true
	state.game_over = true
	state.clock.locked = true
	state.clock.set_paused(true)
	victory.visible = true
	var content: Node = victory.get_node("Dim/Center/Panel/Margin/Content")
	var keep_button: Button = content.get_node("Buttons/KeepFighting") as Button
	assert_eq(keep_button.text, "Keep fighting")
	keep_button.pressed.emit()
	assert_true(state.endless, "Button enables endless mode")
	assert_true(state.won, "Button retains won state")
	assert_false(state.game_over, "Button clears terminal lock")
	assert_false(state.clock.locked or state.clock.paused, "Button resumes the clock")
	assert_false(victory.visible, "Button hides victory panel")
	victory.free()

func test_endless_objective_names_current_night() -> void:
	assert_eq(DawnReport.objective_text(23, 20, "complete", 8, true),
		"Survive as long as you can (Endless, night 22)")

func test_endless_actual_nights_spawn_and_reach_cleared_or_capped_dawn() -> void:
	_place_tower()
	state.resources.add("food", 10000)
	var victory: VictoryScreen = (load("res://scenes/ui/victory.tscn") as PackedScene).instantiate() as VictoryScreen
	victory.bind(state)
	_advance_to_dawn(21)
	assert_true(victory.visible)
	victory.get_node("Dim/Center/Panel/Margin/Content/Buttons/KeepFighting").pressed.emit()
	state.waves.enabled = true
	for night: int in range(21, 25):
		assert_eq(state.clock.day, night)
		state.clock.elapsed = float(data.balance("day_length")) - 0.1
		state.tick(0.2)
		assert_eq(state.clock.phase, GameClock.Phase.NIGHT, "Enter the real night phase")
		assert_gt(state.zombies.count(), 0, "A zombie actually spawned")
		var wave: Dictionary = data.wave_for_night(night)
		var total: int = 0
		for type_id: String in ["walker", "runner", "brute", "spitter"]:
			total += int(wave[type_id])
		assert_eq(state.hostiles_remaining(), total, "Normal difficulty uses base-formula counts")
		assert_false(bool(wave["final"]))
		assert_true(HudText.forecast_text(WaveSpawner.forecast(data, night, state.difficulty_multipliers)).begins_with("Tonight: "))
		if night % 2 == 1:
			state.waves.clear_pending()
			for zombie: Zombie in state.zombies.all().duplicate():
				state.damage_zombie(zombie, zombie.hp)
			state.clock.elapsed = float(data.balance("night_min_length")) - 0.1
		else:
			state.clock.elapsed = float(data.balance("night_max_length")) - 0.1
		state.tick(0.2)
		assert_eq(state.clock.phase, GameClock.Phase.DAY, "Both cleared and capped nights end normally")
		assert_eq(state.clock.day, night + 1)
		assert_eq(state.hostiles_remaining(), 0, "Dawn removes hostiles and pending waves")
		assert_false(state.game_over or state.clock.paused or state.clock.locked)
		assert_false(victory.visible)
		assert_eq(state.last_dawn_report["objective"], "Survive as long as you can (Endless, night %d)" % night)
	assert_eq(won_count, 1, "Only the original win fires through real dawn 25")
	victory.free()

func test_restored_endless_loss_shows_game_over_reason_and_full_stats() -> void:
	_place_tower()
	_advance_to_dawn(21)
	_continue_endless()
	state.clock.day = 22
	state.zombies_killed = 123
	state.survivors_lost = 2
	state.buildings_built = 9
	state.time_played = 125.0
	var restored: GameState = SaveGame.restore(data, SaveGame.from_json(SaveGame.to_json(SaveGame.capture(state))))
	assert_not_null(restored)
	if restored == null:
		return
	var victory: VictoryScreen = (load("res://scenes/ui/victory.tscn") as PackedScene).instantiate() as VictoryScreen
	var game_over: GameOverScreen = (load("res://scenes/ui/game_over.tscn") as PackedScene).instantiate() as GameOverScreen
	victory.bind(restored)
	game_over.bind(restored)
	assert_false(victory.visible or game_over.visible, "Continue opens neither terminal panel")
	var cc: Building = restored.buildings.all_of_type("command_center")[0]
	restored.damage_building(cc, cc.hp)
	restored.tick(0.0)
	assert_true(game_over.visible)
	assert_false(victory.visible)
	assert_true(restored.clock.paused and restored.clock.locked)
	var content: Node = game_over.get_node("Dim/Center/Panel/Margin/Content")
	assert_eq(content.get_node("Reason").text, "The Command Center was destroyed.")
	var stats: Node = content.get_node("Stats")
	assert_eq(stats.get_child_count(), 10)
	var expected: Array[Array] = GameOverScreen.stat_rows(restored.stats())
	for index: int in range(expected.size()):
		assert_eq(stats.get_child(index * 2).text, expected[index][0])
		assert_eq(stats.get_child(index * 2 + 1).text, expected[index][1])
	assert_eq(restored.zombies_killed, 123)
	assert_eq(restored.buildings_built, 9)
	assert_eq(restored.survivors_lost, 2)
	victory.free()
	game_over.free()

func test_endless_next_dawn_autosave_continue_and_restart_service() -> void:
	var old_state: GameState = Game.state
	var old_path: String = Game.save_path
	var save_path: String = temp_path("endless_qa", "json")
	Game.state = state
	Game.save_path = save_path
	var main_node: Node = (load("res://scripts/main.gd") as GDScript).new()
	var hints := EndlessHints.new()
	hints.name = "Hints"
	main_node.add_child(hints)
	state.game_won.connect(main_node._on_game_won)
	state.dawn_processed.connect(main_node._on_dawn_processed)
	assert_true(Game.save_now(), "Pre-win save exists")
	_place_tower()
	_advance_to_dawn(21)
	assert_false(FileAccess.file_exists(save_path), "Original victory deletes the old slot")
	_continue_endless()
	state.clock.phase = GameClock.Phase.DAY
	_advance_to_dawn(22)
	assert_true(FileAccess.file_exists(save_path), "Next endless dawn autosaves")
	var service := EndlessContinueService.new()
	service.save_path = save_path
	assert_true(service.has_save())
	service.continue_game()
	assert_true(service.state.endless and service.state.won)
	assert_false(service.state.game_over or service.state.clock.locked or service.state.clock.paused)
	assert_true(service.state.waves.enabled)
	assert_eq(service.state.clock.day, 22)
	assert_eq(service.continued_extra.get("hints"), {"welcome": true})
	service.restart()
	assert_false(service.state.endless or service.state.won, "Restart creates a fresh non-endless run")
	service.new_game(186)
	assert_false(service.state.endless, "New game also resets endless")
	service.delete_save()
	service.free()
	main_node.free()
	Game.state = old_state
	Game.save_path = old_path
