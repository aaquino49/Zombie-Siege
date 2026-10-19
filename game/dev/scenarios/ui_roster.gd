class_name ScenarioUiRoster extends RefCounted

static func setup(main: Node2D) -> void:
	preload("res://dev/scenarios/construction.gd").setup(main)
	
	var roster: RosterPanel = main.get_node("RosterPanel")
	if not roster.is_open():
		roster.toggle()
		
	var selection: SelectionController = main.get_node("World/Selection")
	var survivors: Array[Survivor] = Game.state.survivors.all()
	if survivors.size() >= 4:
		Game.state.set_job(survivors[0].uid, Survivor.Job.BUILDER)
		Game.state.set_job(survivors[1].uid, Survivor.Job.GATHERER, "wood")
		Game.state.set_job(survivors[2].uid, Survivor.Job.GATHERER, "wood")
		Game.state.set_job(survivors[3].uid, Survivor.Job.GATHERER, "scrap")
		
	if survivors.size() > 0:
		var builder: Survivor = null
		for s in survivors:
			if s.job == Survivor.Job.BUILDER:
				builder = s
				break
		if builder:
			selection.select_survivor(builder.uid)
		else:
			selection.select_survivor(survivors[0].uid)
			
	Game.state.clock.set_paused(true)
