extends RefCounted
## Render all twenty nights with the existing public-command QA bot, then rescue.

static func setup(main: Node) -> void:
	var dev: Node = main.get_tree().root.get_node("DevTools")
	dev.set("_target_frames", 100000)
	await preload("res://dev/scenarios/qa_m4_support.gd").sensible_run(main, 20)
	var state: GameState = Game.state
	var support: GDScript = preload("res://dev/scenarios/qa_m4_support.gd")
	support.check(state.won and state.radio_tower_complete() and state.clock.day == 21,
		"T113 rendered twenty-night run reaches real victory")
	support.check(is_equal_approx(state.time_played, 2682.00), "T113 pacing matches T-136")
	support.check(main.get_node("World/RescueHelicopter").visible, "T113 natural rescue starts")
	await main.get_tree().create_timer(5.8).timeout
	support.check(main.get_node("VictoryScreen").visible, "T113 natural helicopter completion opens Victory")
	support.check(state.clock.paused and state.clock.locked, "T113 Victory locks clock")
	support.check(not main.get_node("GameOverScreen").visible, "T113 no Game Over during Victory")
	await main.get_tree().create_timer(0.35).timeout
	dev.set("_target_frames", int(dev.get("_frame")) + 3)
