extends RefCounted

static func setup(_main: Node) -> void:
	Game.state.waves.enabled = false
	if not Game.state or not Game.state.clock:
		return
		
	Game.state.clock.advance(150.0 + 45.0 + 50.0)
	Game.state.clock.set_paused(true)
