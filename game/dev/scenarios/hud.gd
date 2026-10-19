extends RefCounted

static func setup(_main: Node) -> void:
	if not Game.state or not Game.state.resources:
		return
		
	var store: ResourceStore = Game.state.resources
	Game.state.clock.set_paused(true)
	var idle_count: int = 0
	for survivor: Survivor in Game.state.survivors.all():
		if survivor.away:
			continue
		if idle_count == 0:
			survivor.job = Survivor.Job.IDLE
			idle_count += 1
		else:
			survivor.job = Survivor.Job.BUILDER
	store.add("wood", 1250 - store.get_amount("wood"))
	store.add("food", 93) # 30 + 93 = 123
	store.take("scrap", 15) # 15 - 15 = 0
