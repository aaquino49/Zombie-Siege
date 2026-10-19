extends RefCounted

static func setup(main: Node) -> void:
	var state: GameState = Game.state
	if state:
		state.waves.enabled = true
		for _i in range(30):
			state.tick(0.1)
	var hints: HintPanel = main.get_node_or_null("Hints")
	if hints:
		hints.set_enabled(true)
		hints.show_hint("welcome")
