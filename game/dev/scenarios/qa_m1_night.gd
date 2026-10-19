extends RefCounted
## Stable M1 night capture, using the configured simulation clock.

static func setup(main: Node) -> void:
	Game.state.waves.enabled = false
	preload("res://dev/scenarios/buildings_placed.gd").setup(main)
	var state: GameState = Game.state
	state.clock.advance(float(state.data.balance("day_length")) + 15.0)
	state.clock.set_paused(true)
	main.get_node("World/Camera2D").set_process(false)
	assert(state.clock.phase == GameClock.Phase.NIGHT)
