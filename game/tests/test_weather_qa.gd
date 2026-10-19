extends TestCase
## T-193 acceptance gaps: eligible RNG rolls, configurable effects and live fire.

func test_eligible_weather_and_forecasts_preserve_game_rng() -> void:
	var state: GameState = GameState.new(GameData.load_default(), 1337)
	var before: int = state.rng.state
	for day: int in range(1, 41):
		state.clock.day = day
		assert_eq(state.weather_day(), Weather.day_weather(state.data, state.map_seed, day))
		assert_eq(state.weather_night(), Weather.night_weather(state.data, state.map_seed, day))
		WaveSpawner.forecast(state.data, day, state.difficulty_multipliers, state.map_seed)
	assert_eq(state.rng.state, before, "Eligible rolls and forecast must preserve the shared RNG")

func test_forecast_uses_seed_and_weather_for_normal_and_endless_nights() -> void:
	var data: GameData = GameData.load_default()
	var fog_count: int = 0
	var endless_fog_count: int = 0
	for seed: int in range(1, 51):
		for night: int in range(1, 41):
			var forecast: Dictionary = WaveSpawner.forecast(data, night, {}, seed)
			var fog: bool = Weather.night_weather(data, seed, night) == "fog"
			assert_eq(forecast["fog"], fog)
			assert_eq(HudText.forecast_text(forecast).contains(" · Fog: range −1"), fog)
			if fog:
				fog_count += 1
				if night > data.final_night():
					endless_fog_count += 1
	assert_gt(fog_count, 0)
	assert_gt(endless_fog_count, 0, "Endless nights must still roll fog")

func test_weather_roll_rules_follow_configured_values() -> void:
	var data: GameData = GameData.load_default()
	var rain: Dictionary = data.weather_config()["rain"]
	var fog: Dictionary = data.weather_config()["fog"]
	rain["first_day"] = 7
	rain["chance"] = 1.0
	fog["first_night"] = 8
	fog["chance"] = 1.0
	assert_eq(Weather.day_weather(data, 1337, 6), "clear")
	assert_eq(Weather.day_weather(data, 1337, 7), "rain")
	assert_eq(Weather.night_weather(data, 1337, 7), "clear")
	assert_eq(Weather.night_weather(data, 1337, 8), "fog")
	assert_eq(Weather.night_weather(data, 1337, 9), "clear")
	assert_eq(Weather.night_weather(data, 1337, data.final_night()), "clear")
	fog["no_repeat"] = false
	fog["never_final"] = false
	assert_eq(Weather.night_weather(data, 1337, 9), "fog")
	assert_eq(Weather.night_weather(data, 1337, data.final_night()), "fog")
	rain["chance"] = 0.0
	fog["chance"] = 0.0
	assert_eq(Weather.day_weather(data, 1337, 7), "clear")
	assert_eq(Weather.night_weather(data, 1337, 8), "clear")

func test_rain_accumulation_uses_configured_multiplier() -> void:
	var data: GameData = GameData.load_default()
	data.weather_config()["rain"]["chance"] = 1.0
	data.weather_config()["rain"]["farm_mult"] = 2.25
	var state: GameState = GameState.new(data, 1337)
	state.clock.day = 2
	var farm: Building = state.buildings.add("farm", state.map.command_center_origin() + Vector2i(-3, 3), true)
	var worker: Survivor = state.survivors.all()[0]
	worker.job = Survivor.Job.FARMER
	worker.work_uid = farm.uid
	worker.activity = Survivor.Activity.FARMING
	ProductionJob.tick(state, worker, 0.1)
	assert_almost_eq(worker.work_acc, 0.1 * float(data.get_building("farm")["food_per_farmer"]) / float(data.balance("day_length")) * 2.25)

func test_ranges_and_forecast_follow_data_delta_and_minimum() -> void:
	var data: GameData = GameData.load_default()
	data.weather_config()["fog"]["chance"] = 1.0
	data.weather_config()["fog"]["range_delta_tiles"] = -2.0
	var state: GameState = GameState.new(data, 1337)
	state.clock.day = 5
	state.clock.phase = GameClock.Phase.NIGHT
	var guard: Survivor = state.survivors.all()[0]
	var tower: Building = state.buildings.add("watchtower", state.map.command_center_origin() + Vector2i(3, 0), true)
	var base: float = float(data.balance("guard_range_tiles"))
	assert_eq(GuardJob.effective_range_px(state, guard), (base - 2.0) * Grid.TILE)
	guard.on_tower = true
	assert_eq(GuardJob.effective_range_px(state, guard, tower), (base * float(data.get_building("watchtower")["guard_range_mult"]) - 2.0) * Grid.TILE)
	assert_eq(Combat.turret_range_px(state), (float(data.get_building("turret")["range_tiles"]) - 2.0) * Grid.TILE)
	assert_true(HudText.forecast_text(WaveSpawner.forecast(data, 5, {}, 1337)).ends_with("Fog: range −2"))
	data.weather_config()["fog"]["range_delta_tiles"] = -100.0
	assert_eq(Combat.turret_range_px(state), float(Grid.TILE))
	assert_eq(GuardJob.effective_range_px(state, guard, tower), float(Grid.TILE))
	guard.on_tower = false
	assert_eq(GuardJob.effective_range_px(state, guard), float(Grid.TILE))
	state.clock.phase = GameClock.Phase.DAY
	assert_eq(GuardJob.effective_range_px(state, guard), base * Grid.TILE)
	assert_eq(Combat.turret_range_px(state), float(data.get_building("turret")["range_tiles"]) * Grid.TILE)

func test_fog_limits_actual_turret_ground_guard_and_tower_guard_fire() -> void:
	for kind: String in ["turret", "ground", "tower"]:
		var data: GameData = GameData.load_default()
		data.weather_config()["fog"]["chance"] = 1.0
		var state: GameState = GameState.new(data, 1337)
		state.clock.day = 5
		state.clock.phase = GameClock.Phase.NIGHT
		var guard: Survivor = state.survivors.all()[0]
		var base: float = float(data.balance("guard_range_tiles")) * Grid.TILE
		var from: Vector2 = guard.pos
		if kind == "turret":
			var turret: Building = state.buildings.add("turret", state.map.command_center_origin() + Vector2i(3, 0), true)
			from = turret.center_world()
			base = float(data.get_building("turret")["range_tiles"]) * Grid.TILE
		else:
			guard.job = Survivor.Job.GUARD
			guard.activity = Survivor.Activity.GUARDING
			guard.path.clear()
			guard.post_tile = guard.tile()
			guard.post_check_timer = 100.0
			if kind == "tower":
				var tower: Building = state.buildings.add("watchtower", state.map.command_center_origin() + Vector2i(3, 0), true)
				guard.on_tower = true
				guard.post_uid = tower.uid
				guard.post_building = tower
				guard.pos = tower.center_world()
				from = guard.pos
				base *= float(data.get_building("watchtower")["guard_range_mult"])
		var target: Zombie = state.spawn_zombie("brute", from + Vector2(base - 0.5 * Grid.TILE, 0.0))
		var hp_before: int = target.hp
		if kind == "turret":
			Combat.tick_turrets(state, float(data.get_building("turret")["fire_interval"]))
		else:
			GuardJob.tick(state, guard, float(data.balance("guard_fire_interval")))
		assert_eq(target.hp, hp_before, kind + " must not hit beyond fog range")
		data.weather_config()["fog"]["chance"] = 0.0
		if kind == "turret":
			Combat.tick_turrets(state, 0.01)
		else:
			GuardJob.tick(state, guard, 0.01)
		assert_lt(target.hp, hp_before, kind + " must hit the same target on a clear night")
