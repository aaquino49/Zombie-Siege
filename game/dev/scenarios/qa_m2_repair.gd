extends RefCounted

static func setup(main: Node) -> void:
	Game.state.waves.enabled = false
	var fixture: GDScript = preload("res://dev/scenarios/qa_m2_colony_day3.gd")
	var state: GameState = Game.state
	# Shelter has a nonzero build time and a readable 2x2 damaged HP bar.
	var building: Building = fixture.place_complete(state, "shelter")
	building.hp = building.max_hp / 4
	for s: Survivor in state.survivors.all():
		state.set_job(s.uid, Survivor.Job.IDLE)
	var builder: Survivor = state.survivors.all()[0]
	state.set_job(builder.uid, Survivor.Job.BUILDER)
	var wood: int = state.resources.get_amount("wood")
	var cost: int = Construction.repair_cost(state.data, building)
	for tick: int in range(600):
		state.tick(0.1)
		if builder.activity == Survivor.Activity.REPAIRING and building.hp > building.max_hp / 4:
			break
	print("T-016 repair: hp=", building.hp, "/", building.max_hp, " wood=", wood, " -> ", state.resources.get_amount("wood"), " expected cost=", cost)
	fixture.show(main, building)
