extends RefCounted

static func setup(main: Node) -> void:
	var state: GameState = Game.state
	state.difficulty = "normal"
	state.difficulty_multipliers = state.data.difficulty_config("normal")
	state.clock.day = 11
	state.clock.phase = GameClock.Phase.DAY
	state.clock.elapsed = 0.0
	state.clock.set_speed(1)
	for seed: int in range(1, 10000):
		if Weather.night_weather(state.data, seed, 11) == "fog":
			state.map_seed = seed
			break
	main.get_node("HUD").call("_refresh_forecast")
