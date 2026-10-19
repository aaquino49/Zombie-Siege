extends RefCounted

static func setup(main: Node) -> void:
	Game.state.waves.enabled = false
	var state: GameState = Game.state

	var max_iterations := 2000
	var i := 0
	while state.clock.day < 4 and i < max_iterations:
		state.clock.advance(1.0)
		i += 1

	state.clock.set_paused(true)
	# Turret costs 10 wood and 25 scrap: leave wood affordable, scrap 5 short.
	state.resources.add("wood", 200)
	state.resources.take("scrap", state.resources.get_amount("scrap"))
	state.resources.add("scrap", 20)
	(main.get_node("BuildBarLayer") as BuildBar).set_active_type("turret")
	# Dawn queues its report; dismiss it after that callback for a clear bar capture.
	(main.get_node("DawnReport") as DawnReportPanel).hide.call_deferred()
