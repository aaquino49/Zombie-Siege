extends RefCounted

static func setup(main: Node) -> void:
	Game.state.waves.enabled = false
	var state: GameState = Game.state
	var need: int = int(state.data.balance("food_eat_per_survivor"))
	state.resources.take("food", state.resources.get_amount("food") - 2 * need)
	var day_length: float = float(state.data.balance("day_length"))
	var night_length: float = float(state.data.balance("night_min_length"))
	state.clock.advance(day_length + night_length)
	state.clock.set_paused(true)
	var roster: RosterPanel = main.get_node("RosterPanel")
	if not roster.is_open():
		roster.toggle()
	var selection: SelectionController = main.get_node("World/Selection")
	for s: Survivor in state.survivors.all():
		if s.is_hungry():
			selection.select_survivor(s.uid)
			break
