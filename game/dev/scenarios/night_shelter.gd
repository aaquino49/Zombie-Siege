extends RefCounted

static func setup(main: Node) -> void:
	Game.state.waves.enabled = false
	var state: GameState = Game.state
	var cc: Vector2i = state.map.command_center_origin()
	var placed: bool = false
	for radius: int in range(3, state.map.size()):
		for y: int in range(cc.y - radius, cc.y + radius + 1):
			for x: int in range(cc.x - radius, cc.x + radius + 1):
				var origin := Vector2i(x, y)
				if Placement.check(state, "shelter", origin) == Placement.Result.OK:
					state.buildings.add("shelter", origin, true)
					placed = true
					break
			if placed:
				break
		if placed:
			break
	state.set_job(state.survivors.all().back().uid, Survivor.Job.GUARD)
	state.clock.elapsed = float(state.data.balance("day_length")) - 1.0
	for i: int in range(600):
		state.tick(0.1)
		var inside: bool = true
		for s: Survivor in state.survivors.all():
			if s.job != Survivor.Job.GUARD and not s.sheltered:
				inside = false
		if inside:
			break
	state.clock.set_paused(true)
	var roster: RosterPanel = main.get_node("RosterPanel")
	if not roster.is_open():
		roster.toggle()
