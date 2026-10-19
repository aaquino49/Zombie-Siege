extends Node

static func setup(main: Node) -> void:
	Game.state.waves.enabled = false
	var state: GameState = Game.state
	state.clock.elapsed = state.data.balance("day_length", 30.0) - 0.05
	
	var origin: Vector2i = state.map.command_center_origin()
	
	# Box of walls around CC
	var right_wall_x: int = origin.x + 5
	for x: int in range(origin.x - 2, right_wall_x + 1):
		state.buildings.add("wooden_wall", Vector2i(x, origin.y - 3), true)
		state.buildings.add("wooden_wall", Vector2i(x, origin.y + 4), true)
	for y: int in range(origin.y - 2, origin.y + 4):
		state.buildings.add("wooden_wall", Vector2i(origin.x - 2, y), true)
		state.buildings.add("wooden_wall", Vector2i(right_wall_x, y), true)
		
	# Let the phase banner finish before composing the paused attack.
	while state.clock.phase != GameClock.Phase.NIGHT:
		state.tick(0.1)
	state.tick(PhaseBanner.BANNER_SECONDS + 0.1 - state.clock.elapsed)

	# Three staggered ranks: no shared spawn points, and the faster runner
	# and larger brute have their own front-row space beside the wall.
	for column: int in range(3):
		for row: int in range(4):
			var type_id: String = "walker"
			if column == 0 and row == 0:
				type_id = "runner"
			elif column == 0 and row == 3:
				type_id = "brute"
			var tile := Vector2i(right_wall_x + 1 + column * 2, origin.y - 1)
			var spawn_pos: Vector2 = Grid.tile_to_world(tile) + Vector2(0, row * Grid.TILE * 1.5)
			var z: Zombie = state.spawn_zombie(type_id, spawn_pos)
	
	for i: int in range(600):
		state.tick(0.1)
		var damaged: bool = false
		for b: Building in state.buildings.all():
			if b.hp < b.max_hp and b.type_id == "wooden_wall":
				damaged = true
		if damaged:
			var attacking: bool = false
			for z: Zombie in state.zombies.all():
				var target: Building = state.buildings.get_by_uid(z.target_building_uid)
				if target != null and target.type_id == "wooden_wall":
					attacking = true
			if attacking:
				break
				
	state.clock.set_paused(true)
	
	var camera: Camera2D = main.get_node("World/Camera2D")
	camera.position = Grid.tile_to_world(Vector2i(right_wall_x - 2, origin.y)) + Vector2(0, Grid.TILE / 2.0)
