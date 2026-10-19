extends RefCounted

static func setup(main: Node) -> void:
	var game_obj: Object = main.get_node("/root/Game")
	var state: GameState = game_obj.get("state") if game_obj else null
	if state == null:
		return
	if "waves" in state and state.get("waves") != null:
		state.get("waves").enabled = false
	state.clock.set_paused(true)
	state.clock.day = 8
	state.clock.elapsed = 10.0
	state.resources.add("wood", 2000)
	state.resources.add("scrap", 2000)
	
	var o: Vector2i = state.map.command_center_origin()
	
	# Clear the central staging area of natural obstacles around CC
	for dy in range(-7, 10):
		for dx in range(-8, 9):
			var t := o + Vector2i(dx, dy)
			if state.map.occupant_at(t) in [WorldMap.Occupant.TREE, WorldMap.Occupant.ROCK, WorldMap.Occupant.SCRAP]:
				state.map.vacate(t, Vector2i.ONE)
				
	# 1. Place and finish one of each building type:
	# Shelter (2x2)
	state.try_place("shelter", o + Vector2i(-4, -3))
	# Farm (2x2)
	state.try_place("farm", o + Vector2i(3, -3))
	# Storage (2x2)
	state.try_place("storage", o + Vector2i(-4, 1))
	# Workshop (2x2)
	state.try_place("workshop", o + Vector2i(3, 1))
	# Lumber Yard (2x2)
	state.try_place("lumber_yard", o + Vector2i(-7, -1))
	# Radio Tower (2x2)
	state.try_place("radio_tower", o + Vector2i(6, -1))
	# Watchtower (1x1)
	state.try_place("watchtower", o + Vector2i(-1, -3))
	# Turret (1x1) with barrel facing sideways
	state.try_place("turret", o + Vector2i(1, -3))
	
	# Finish all placed buildings so far
	for b in state.buildings.blueprints():
		state.buildings.finish(b.uid)
		
	# Set turret aim facing sideways (right)
	for b in state.buildings.all_of_type("turret"):
		b.aim = Vector2.RIGHT
		
	# 2. Closed wall ring south of CC with corner, T-junction, gate, and reinforced segment
	# Top row (y = 4 relative to o)
	state.try_place("wooden_wall", o + Vector2i(-2, 4))
	state.try_place("gate", o + Vector2i(-1, 4))
	state.try_place("wooden_wall", o + Vector2i(0, 4)) # T-junction: meets middle vertical spur
	state.try_place("wooden_wall", o + Vector2i(1, 4)) # Will be upgraded to reinforced
	state.try_place("wooden_wall", o + Vector2i(2, 4))
	
	# Middle row (y = 5 relative to o)
	state.try_place("wooden_wall", o + Vector2i(-2, 5))
	state.try_place("wooden_wall", o + Vector2i(0, 5)) # Vertical divider spur
	state.try_place("wooden_wall", o + Vector2i(2, 5))
	
	# Bottom row (y = 6 relative to o)
	state.try_place("wooden_wall", o + Vector2i(-2, 6))
	state.try_place("wooden_wall", o + Vector2i(-1, 6))
	state.try_place("wooden_wall", o + Vector2i(0, 6)) # T-junction: meets middle vertical spur
	state.try_place("wooden_wall", o + Vector2i(1, 6))
	state.try_place("wooden_wall", o + Vector2i(2, 6))
	
	# Finish the wall ring
	for b in state.buildings.blueprints():
		state.buildings.finish(b.uid)
		
	# Upgrade (1, 4) to reinforced_wall and finish the replacement
	var wall_to_upgrade: Building = state.buildings.get_at(o + Vector2i(1, 4))
	if wall_to_upgrade:
		state.try_upgrade(wall_to_upgrade.uid)
		var reinf: Building = state.buildings.get_at(o + Vector2i(1, 4))
		if reinf:
			state.buildings.finish(reinf.uid)
		
	# 3. Blueprints: one unfinished 2x2 blueprint and one unfinished wall blueprint with progress
	state.try_place("shelter", o + Vector2i(-7, 3))
	state.try_place("wooden_wall", o + Vector2i(-1, 7))
	
	for b in state.buildings.blueprints():
		if b.type_id == "shelter":
			b.progress = b.build_time * 0.45
		elif b.type_id == "wooden_wall":
			b.progress = b.build_time * 0.60
			
	# 4. Y-sort demonstration: place a tree and rock directly south of buildings
	# Tree directly south of lumber_yard at (-7, -1) -> tree at (-7, 1)
	var tree_t := o + Vector2i(-7, 1)
	state.map._occupants[tree_t] = WorldMap.Occupant.TREE
	# Rock directly south of radio_tower at (6, -1) -> rock at (6, 1)
	var rock_t := o + Vector2i(6, 1)
	state.map._occupants[rock_t] = WorldMap.Occupant.ROCK
	
	# Redraw world props to render the added tree and rock
	var world_node := main.get_node("World")
	if world_node and world_node.has_method("_draw_props"):
		world_node._draw_props()
		
	# Frame camera on the base so northern buildings, ring, and unfinished blueprints are all visible
	var camera: Camera2D = main.get_node("World/Camera2D") as Camera2D
	if camera:
		camera.position = Grid.tile_to_world(o) + Vector2(0, 96.0)
		camera.zoom = Vector2(0.75, 0.75)
