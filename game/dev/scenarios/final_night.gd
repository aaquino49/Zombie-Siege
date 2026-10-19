extends RefCounted

static func setup(main: Node) -> void:
	var state: GameState = Game.state
	state.clock.day = state.data.final_night()
	preload("res://dev/scenarios/night.gd").setup(main)
