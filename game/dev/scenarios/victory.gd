extends Node

static func setup(main: Node) -> void:
	VictorySetup.trigger_win()
	var helicopter: RescueHelicopter = main.get_node("World/RescueHelicopter")
	if helicopter:
		helicopter.skip()
	await main.get_tree().process_frame
	var victory: VictoryScreen = main.get_node("VictoryScreen") as VictoryScreen
	victory.get_node("Dim/Center/Panel/Margin/Content/Buttons/KeepFighting").pressed.emit()
	# Show the colony after enduring night 22; the next forecast must be live.
	Game.state.clock.day = 23
	Game.state.clock.phase = GameClock.Phase.DAY
	Game.state.clock.elapsed = 0.0
	Game.state.waves.enabled = true
	main.get_node("DawnReport").visible = false
	main.get_node("HUD").call("_refresh_forecast")

	var bar: BuildBar = main.get_node("BuildBarLayer") as BuildBar
	bar.refresh()
	bar.set_active_type("watchtower")
	Game.state.resources.take("scrap", Game.state.resources.get_amount("scrap") - 15)
