extends RefCounted

static func setup(main: Node) -> void:
	var state: GameState = Game.state
	
	state.clock.day = 2 # Unlock workshop
	
	var cc: Building = state.buildings.all_of_type("command_center")[0]
	var cc_origin := cc.origin
	
	var farm_origin := Vector2i(-1, -1)
	var workshop_origin := Vector2i(-1, -1)
	
	var scan_radius := 1
	while scan_radius < 20 and (farm_origin == Vector2i(-1, -1) or workshop_origin == Vector2i(-1, -1)):
		for x in range(-scan_radius, scan_radius + 1):
			for y in [-scan_radius, scan_radius]:
				var pos := cc_origin + Vector2i(x, y)
				if farm_origin == Vector2i(-1, -1) and Placement.check(state, "farm", pos) == Placement.Result.OK:
					farm_origin = pos
				elif workshop_origin == Vector2i(-1, -1) and pos != farm_origin and Placement.check(state, "workshop", pos) == Placement.Result.OK:
					workshop_origin = pos
			for py in range(-scan_radius + 1, scan_radius):
				for px in [-scan_radius, scan_radius]:
					var pos := cc_origin + Vector2i(px, py)
					if farm_origin == Vector2i(-1, -1) and Placement.check(state, "farm", pos) == Placement.Result.OK:
						farm_origin = pos
					elif workshop_origin == Vector2i(-1, -1) and pos != farm_origin and Placement.check(state, "workshop", pos) == Placement.Result.OK:
						workshop_origin = pos
		scan_radius += 1
		
	if farm_origin == Vector2i(-1, -1) or workshop_origin == Vector2i(-1, -1):
		push_error("Could not find valid origins for farm and workshop")
		return
		
	var farm: Building = state.buildings.add("farm", farm_origin, true)
	var workshop: Building = state.buildings.add("workshop", workshop_origin, true)
	
	state.resources.add("scrap", 20)
	
	var survivors := state.survivors.all()
	if survivors.size() >= 3:
		state.set_job(survivors[0].uid, Survivor.Job.FARMER)
		state.set_job(survivors[1].uid, Survivor.Job.FARMER)
		state.set_job(survivors[2].uid, Survivor.Job.CRAFTER)
		
	var ticks := 0
	var delivered_ammo := false
	var initial_ammo := state.resources.get_amount("ammo")
	
	while ticks < 1500:
		state.tick(0.1)
		ticks += 1
		if state.resources.get_amount("ammo") > initial_ammo:
			delivered_ammo = true
			
		if delivered_ammo:
			var all_working := true
			var farmer_count := 0
			var crafter_count := 0
			for s in state.survivors.all():
				if s.job == Survivor.Job.FARMER:
					farmer_count += 1
					if s.activity != Survivor.Activity.FARMING:
						all_working = false
				elif s.job == Survivor.Job.CRAFTER:
					crafter_count += 1
					if s.activity != Survivor.Activity.CRAFTING:
						all_working = false
			
			if all_working and farmer_count == 2 and crafter_count == 1:
				break
				
	state.clock.paused = true
	
	var sel: SelectionController = main.get_node("World/Selection") as SelectionController
	if sel:
		sel.select_building(farm.uid)
		
	var text_layer: FloatingTextLayer = main.get_node("World/FloatingText") as FloatingTextLayer
	if text_layer:
		text_layer.spawn("+5 ammo", workshop.center_world() + Vector2(0, -40), "ammo")
		text_layer.spawn("+1 food", farm.center_world() + Vector2(0, -40), "food")
		text_layer.set_process(false)
		
	var cam: Camera2D = main.get_node("World/Camera2D")
	if cam:
		cam.position = (farm.center_world() + workshop.center_world()) / 2.0
		cam.zoom = Vector2(1.0, 1.0)
