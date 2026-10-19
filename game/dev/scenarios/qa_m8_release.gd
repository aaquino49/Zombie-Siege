extends RefCounted

static func setup(main: Node) -> void:
	var dev: Node = main.get_tree().root.get_node("DevTools")
	dev.set("_target_frames", 100000)
	Game.state.difficulty = "normal"
	Game.state.difficulty_multipliers = Game.state.data.difficulty_config("normal")
	Game.state.clock.set_speed(1)
	main.get_node("Hints").set_enabled(false)
	await preload("res://dev/scenarios/qa_m4_support.gd").sensible_run(main, 20)
	var state: GameState = Game.state
	var support: GDScript = preload("res://dev/scenarios/qa_m4_support.gd")
	support.check(state.won and state.clock.day == 21 and state.radio_tower_complete(), "M8 Normal rendered 20-night victory")
	support.check(is_equal_approx(state.time_played, 2681.25), "M8 pacing 2681.25 seconds")
	await main.get_tree().create_timer(6.0).timeout
	support.check(main.get_node("VictoryScreen").visible, "M8 natural helicopter opens Victory")
	dev.set("_target_frames", int(dev.get("_frame")) + 3)
