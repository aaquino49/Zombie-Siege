extends RefCounted

static func setup(main: Node) -> void:
	var state: GameState = Game.state
	var cap: int = ceili(7.0 * (float(state.data.balance("day_length")) + 400.0) / 0.25)
	for tick_index: int in range(cap):
		if state.game_over:
			break
		state.tick(0.25)
	var support: GDScript = preload("res://dev/scenarios/qa_m4_support.gd")
	support.check(state.game_over and state.lose_reason == "command_center" and state.clock.day == 4,
		"Unmodified do-nothing game loses CC on night 4")
	support.check(main.get_node("GameOverScreen").visible and state.clock.locked,
		"CC loss shows real Game Over and locks clock")
