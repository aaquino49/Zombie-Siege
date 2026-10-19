extends RefCounted

static func setup(_main: Node) -> void:
	var state: GameState = Game.state
	state.resources.add("wood", 100)
	var o: Vector2i = state.map.command_center_origin()
	
	state.try_place("shelter", o + Vector2i(3, -2))
	state.try_place("wooden_wall", o + Vector2i(-3, 3))
	state.try_place("wooden_wall", o + Vector2i(-2, 3))
	state.try_place("wooden_wall", o + Vector2i(-1, 3))
	
	var all_s := state.survivors.all()
	if all_s.size() > 0:
		state.set_job(all_s[0].uid, Survivor.Job.BUILDER)
	if all_s.size() > 1:
		state.set_job(all_s[1].uid, Survivor.Job.BUILDER)
		
	var shelter_b: Building = null
	for b in state.buildings.blueprints():
		if b.type_id == "shelter":
			shelter_b = b
			break
			
	var ticks := 0
	while ticks < 500:
		state.tick(0.1)
		ticks += 1
		
		var walls_complete := 0
		for b in state.buildings.all():
			if b.type_id == "wooden_wall" and b.complete:
				walls_complete += 1
				
		if walls_complete >= 1 and shelter_b != null and shelter_b.progress_ratio() >= 0.2 and shelter_b.progress_ratio() <= 0.8:
			break
			
	state.clock.paused = true
