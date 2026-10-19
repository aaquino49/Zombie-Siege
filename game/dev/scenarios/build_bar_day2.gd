extends RefCounted

static func setup(main: Node2D) -> void:
	Game.state.waves.enabled = false
	var state: GameState = Game.state
	
	var max_iterations := 1000
	var i := 0
	while state.clock.day < 2 and i < max_iterations:
		state.clock.advance(1.0)
		i += 1

	state.clock.set_paused(true)
	state.resources.take("scrap", state.resources.get_amount("scrap"))
	(main.get_node("BuildBarLayer") as BuildBar).set_active_type("farm")
	# Dawn queues its report; dismiss it after that callback for a clear bar capture.
	(main.get_node("DawnReport") as DawnReportPanel).hide.call_deferred()
