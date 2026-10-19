extends RefCounted

static func setup(main: Node) -> void:
	var state: GameState = Game.state
	state.difficulty = "normal"
	state.difficulty_multipliers = state.data.difficulty_config("normal")
	state.clock.day = 8
	state.clock.phase = GameClock.Phase.DAY
	state.clock.elapsed = 0.0
	state.clock.set_speed(1)
	main.get_node("HUD").call("_refresh_forecast")
	var hints: HintPanel = main.get_node_or_null("Hints") as HintPanel
	if hints:
		hints.set_enabled(true)
		hints.show_hint("spitters")
