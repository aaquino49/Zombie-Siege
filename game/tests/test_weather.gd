extends TestCase

func test_weather_is_deterministic_and_obeys_day_and_night_limits() -> void:
	var data: GameData = GameData.load_default()
	for seed: int in range(1, 51):
		for day: int in range(1, 41):
			assert_eq(Weather.day_weather(data, seed, day), Weather.day_weather(data, seed, day))
			if day < int(data.weather_config()["rain"]["first_day"]):
				assert_eq(Weather.day_weather(data, seed, day), "clear")
			var weather: String = Weather.night_weather(data, seed, day)
			assert_eq(weather, Weather.night_weather(data, seed, day))
			if day < int(data.weather_config()["fog"]["first_night"]) or day == data.final_night():
				assert_ne(weather, "fog", "No fog on night %d, seed %d" % [day, seed])
			if weather == "fog" and day > 1:
				assert_ne(Weather.night_weather(data, seed, day - 1), "fog", "No consecutive fog nights")

func test_night_weather_matches_previous_recursive_rolls() -> void:
	var data: GameData = GameData.load_default()
	for seed: int in range(1, 51):
		for night: int in range(1, 61):
			assert_eq(Weather.night_weather(data, seed, night), _old_recursive_night_weather(data, seed, night), "Night %d, seed %d" % [night, seed])
	for night: int in range(1, 61):
		assert_eq(Weather.night_weather(data, 1337, night), _old_recursive_night_weather(data, 1337, night), "Night %d, seed 1337" % night)

func test_state_weather_night_cache_invalidates_on_config_and_day_changes() -> void:
	var data: GameData = GameData.load_default()
	var state: GameState = GameState.new(data, 1337)
	state.clock.day = 5
	data.weather_config()["fog"]["chance"] = 0.0
	assert_eq(state.weather_night(), "clear")
	data.weather_config()["fog"]["chance"] = 1.0
	data.weather_config()["fog"]["no_repeat"] = false
	assert_eq(state.weather_night(), "fog", "Config mutation must invalidate the cached result")
	state.clock.day = 1
	assert_eq(state.weather_night(), "clear", "Day change must invalidate the cached result")

func _old_recursive_night_weather(data: GameData, map_seed: int, night: int) -> String:
	var fog: Dictionary = data.weather_config().get("fog", {})
	if night < int(fog["first_night"]):
		return "clear"
	if bool(fog["never_final"]) and night == data.final_night():
		return "clear"
	if bool(fog["no_repeat"]) and night > 1 and _old_recursive_night_weather(data, map_seed, night - 1) == "fog":
		return "clear"
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([map_seed, night, "fog"])
	return "fog" if rng.randf() < float(fog["chance"]) else "clear"

func test_weather_rates_match_data_chances() -> void:
	var data: GameData = GameData.load_default()
	var rain_count: int = 0
	var fog_count: int = 0
	for seed: int in range(1, 2001):
		if Weather.day_weather(data, seed, 2) == "rain":
			rain_count += 1
		if Weather.night_weather(data, seed, 5) == "fog":
			fog_count += 1
	var rain_rate: float = float(rain_count) / 2000.0
	var fog_rate: float = float(fog_count) / 2000.0
	assert_true(absf(rain_rate - float(data.weather_config()["rain"]["chance"])) <= 0.04, "Rain rate %f" % rain_rate)
	assert_true(absf(fog_rate - float(data.weather_config()["fog"]["chance"])) <= 0.04, "Fog rate %f" % fog_rate)

func test_weather_does_not_consume_game_rng() -> void:
	var state: GameState = GameState.new(GameData.load_default(), 442)
	var before: int = state.rng.state
	Weather.day_weather(state.data, state.map_seed, state.clock.day)
	Weather.night_weather(state.data, state.map_seed, state.clock.day)
	assert_eq(state.rng.state, before)

func test_farm_rain_bonus_and_weather_range_delta() -> void:
	var data: GameData = GameData.load_default()
	var rain_seed: int = 1
	while Weather.day_weather(data, rain_seed, 2) != "rain":
		rain_seed += 1
	var clear_seed: int = rain_seed
	while Weather.day_weather(data, clear_seed, 2) != "clear":
		clear_seed += 1
	var clear_state: GameState = GameState.new(data, clear_seed)
	var rain_state: GameState = GameState.new(data, rain_seed)
	for pair: Array in [[clear_state, 8], [rain_state, 12]]:
		var state: GameState = pair[0]
		state.clock.day = 2
		state.clock.phase = GameClock.Phase.DAY
		var farm: Building = state.buildings.add("farm", state.map.command_center_origin() + Vector2i(-3, 3), true)
		var worker: Survivor = state.survivors.all()[0]
		worker.job = Survivor.Job.FARMER
		worker.work_uid = farm.uid
		worker.activity = Survivor.Activity.FARMING
		var initial_food: int = state.resources.get_amount("food")
		var ticks: int = ceili(float(state.data.balance("day_length")) * 10.0)
		for i: int in range(ticks):
			ProductionJob.tick(state, worker, 0.1)
		assert_eq(state.resources.get_amount("food") - initial_food, int(pair[1]))
	var fog_state: GameState = GameState.new(data, 1)
	fog_state.clock.day = 5
	fog_state.clock.phase = GameClock.Phase.NIGHT
	while fog_state.weather_night() != "fog":
		fog_state.map_seed += 1
	assert_eq(Weather.range_delta_px(fog_state), float(data.weather_config()["fog"]["range_delta_tiles"]) * Grid.TILE)
	var guard: Survivor = fog_state.survivors.all()[0]
	var tower: Building = fog_state.buildings.add("watchtower", fog_state.map.command_center_origin() + Vector2i(3, 0), true)
	guard.on_tower = true
	var tower_base: float = float(data.balance("guard_range_tiles")) * float(data.get_building("watchtower")["guard_range_mult"])
	assert_eq(Combat.turret_range_px(fog_state), (float(data.get_building("turret")["range_tiles"]) - 1.0) * Grid.TILE)
	assert_eq(GuardJob.effective_range_px(fog_state, guard, tower), (tower_base - 1.0) * Grid.TILE)
	fog_state.clock.phase = GameClock.Phase.DAY
	assert_eq(Weather.range_delta_px(fog_state), 0.0)

func test_forecast_text_shows_fog_only_before_final_horde() -> void:
	var normal: Dictionary = {"walker": 1, "sides": 1, "final": false, "fog": true, "range_delta_tiles": -1.0}
	var clear: Dictionary = {"walker": 1, "sides": 1, "final": false, "fog": false, "range_delta_tiles": -1.0}
	var final: Dictionary = {"walker": 1, "sides": 1, "final": true, "fog": true, "range_delta_tiles": -1.0}
	assert_true(HudText.forecast_text(normal).ends_with("Fog: range −1"))
	assert_false(HudText.forecast_text(clear).contains("Fog:"))
	assert_false(HudText.forecast_text(final).contains("Fog:"))
