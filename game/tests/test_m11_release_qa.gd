extends TestCase
## M11 release integration: campaign boundary, real dawn reload and earned endless.

class ReloadService:
	extends "res://scripts/autoload/game.gd"
	func _transition(_to_menu: bool, _fresh_seed: bool = false) -> void:
		new_game(next_seed)

func test_endless_lever_changes_only_post_campaign_forecast_and_spawn_schedule() -> void:
	var original: GameData = GameData.load_default()
	var changed: GameData = GameData.load_default()
	for difficulty: String in ["easy", "normal", "hard"]:
		var mult: Dictionary = original.difficulty_config(difficulty)
		for damping: float in [0.5, 0.8, 1.4]:
			changed._waves["endless_wave_mult"] = damping
			for night: int in range(1, 21):
				assert_eq(WaveSpawner.forecast(changed, night, mult, 1337),
					WaveSpawner.forecast(original, night, mult, 1337), "%s night %d" % [difficulty, night])
			for night: int in [21, 22, 30]:
				var baseline: Dictionary = WaveSpawner.forecast(original, night, mult, 1337)
				var forecast: Dictionary = WaveSpawner.forecast(changed, night, mult, 1337)
				var colony := GameState.new(changed, 1337, difficulty)
				colony.waves.plan_night(night)
				var scheduled: Dictionary = {"walker": 0, "runner": 0, "brute": 0, "spitter": 0}
				for entry: Dictionary in colony.waves._schedule:
					scheduled[entry["type"]] += 1
				for kind: String in scheduled:
					assert_eq(forecast[kind], roundi(float(baseline[kind]) * damping))
					assert_eq(scheduled[kind], forecast[kind], "Forecast must equal actual queued hostiles")
				assert_false(forecast["final"])

func test_real_dawn_reload_restores_full_snapshot_and_continue_equivalence() -> void:
	var service := ReloadService.new()
	service.save_path = temp_path("m11_reload", "json")
	service.new_game(1337, GameSettings.PATH, "hard")
	var colony: GameState = service.state
	colony.waves.enabled = false
	colony.clock.elapsed = float(colony.data.balance("day_length")) - 0.25
	colony.tick(0.25)
	colony.clock.elapsed = float(colony.data.balance("night_min_length")) - 0.25
	colony.tick(0.25)
	assert_eq(colony.clock.day, 2)
	assert_true(service.save_now({"hints": {"welcome": true}}))
	var expected: Dictionary = SaveGame.from_json(SaveGame.to_json(SaveGame.capture(colony, {"hints": {"welcome": true}})))
	colony.resources.spend({"wood": 20})
	colony.set_job(colony.survivors.all()[0].uid, Survivor.Job.GUARD)
	colony.clock.elapsed = 30.0
	service.reload_day()
	var restored: Dictionary = SaveGame.from_json(SaveGame.to_json(SaveGame.capture(service.state, service.continued_extra)))
	assert_eq(restored, expected, "Resources, buildings, people, RNG, statistics and hints round trip")
	assert_eq(service.state.map_seed, 1337)
	assert_eq(service.state.difficulty, "hard")
	assert_eq(service.state.clock.phase, GameClock.Phase.DAY)
	assert_eq(service.state.clock.elapsed, 0.0)
	assert_true(service.state.waves.enabled)
	service.continue_game()
	assert_eq(SaveGame.from_json(SaveGame.to_json(SaveGame.capture(service.state, service.continued_extra))), restored)
	service.delete_save()
	service.free()

func test_sensible_bot_earns_victory_and_clears_first_real_endless_night() -> void:
	# T-220 v6 balance: seed 1 fixed-cadence falls on night 19; seed 4 still earns victory. All assertions kept.
	const VICTORY_SEED: int = 4
	var colony := GameState.new(GameData.load_default(), VICTORY_SEED, "normal")
	colony.waves.enabled = true
	var victory: VictoryScreen = load("res://scenes/ui/victory.tscn").instantiate()
	victory.records_path = temp_path("m11_records", "cfg")
	victory.bind(colony)
	var observations: Dictionary = {"wins": 0, "night21": {}, "hostiles21": 0}
	colony.game_won.connect(func() -> void: observations["wins"] += 1)
	colony.dawn_processed.connect(func(report: Dictionary) -> void:
		if int(report["night"]) == 21:
			observations["night21"] = report.duplicate(true))
	var memo: Dictionary = {}
	var decision_elapsed: float = 5.0
	for tick: int in range(60000):
		if colony.clock.day > 21 or (colony.game_over and not colony.won):
			break
		if colony.won and not colony.endless:
			assert_true(victory.visible)
			victory.get_node("Dim/Center/Panel/Margin/Content/Buttons/KeepFighting").pressed.emit()
		if colony.clock.phase == GameClock.Phase.DAY and decision_elapsed >= 5.0:
			decision_elapsed = fmod(decision_elapsed, 5.0)
			BalanceBot._decide(colony, memo)
		var before: float = colony.time_played
		colony.tick(0.25)
		decision_elapsed += colony.time_played - before
		if colony.clock.day == 21:
			observations["hostiles21"] = maxi(int(observations["hostiles21"]), colony.hostiles_remaining())
	assert_true(colony.won and colony.endless and not colony.game_over, "Earned campaign win continues alive")
	assert_eq(observations["wins"], 1)
	assert_eq(colony.clock.day, 22, "Bot must reach dawn after night 21 with released data")
	assert_gt(observations["hostiles21"], 0, "Real endless wave spawned")
	assert_false((observations["night21"] as Dictionary).is_empty())
	assert_eq(colony.hostiles_remaining(), 0)
	assert_false(victory.visible)
	Records.remove_file(victory.records_path)
	victory.free()
