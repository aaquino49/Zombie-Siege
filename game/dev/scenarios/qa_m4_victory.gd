extends RefCounted

static func setup(main: Node) -> void:
	# The bot and natural helicopter arrival exceed the usual 120-frame capture.
	# Keep the bounded DevTools failsafe, but let this fixture set its own deadline.
	var dev: Node = main.get_tree().root.get_node("DevTools")
	dev.set("_target_frames", 100000)
	await preload("res://dev/scenarios/qa_m4_support.gd").sensible_run(main, 20)
	var state: GameState = Game.state
	var support: GDScript = preload("res://dev/scenarios/qa_m4_support.gd")
	support.check(state.won and state.radio_tower_complete() and state.clock.day == 21, "Full bot run reaches real win")
	support.check(not main.get_node("GameOverScreen").visible, "No Game Over on won game")
	support.check(main.get_node("World/RescueHelicopter").visible, "Real rescue helicopter starts")
	await main.get_tree().create_timer(1.8).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var path: String = ProjectSettings.globalize_path("res://../project/runs/T-028/a1/qa_m4_rescue.png")
		main.get_viewport().get_texture().get_image().save_png(path)
	await main.get_tree().create_timer(4.0).timeout
	support.check(main.get_node("VictoryScreen").visible, "Natural helicopter completion reveals Victory")
	support.check(state.clock.paused and state.clock.locked, "Victory locks clock")
	support.check(not main.get_node("GameOverScreen").visible, "Game Over stays hidden after rescue")
	# QA fixture only: retain the natural rescue timing, then advance screenshot deadline.
	# Allow the terminal panel's 0.3-second reveal to finish before capturing it.
	await main.get_tree().create_timer(0.35).timeout
	dev.set("_target_frames", int(dev.get("_frame")) + 3)
