extends RefCounted

static func setup(main: Node) -> void:
	var state: GameState = Game.state
	if "waves" in state and state.get("waves") != null:
		state.get("waves").enabled = false
	var origin: Vector2i = state.map.command_center_origin()
	var east: int = origin.x + 5
	# Clear the staged area of natural obstacles, preserving the CC.
	for y: int in range(origin.y - 4, origin.y + 6):
		for x: int in range(origin.x - 3, east + 5):
			var t := Vector2i(x, y)
			if state.map.occupant_at(t) in [1, 2, 3]:
				state.map.vacate(t, Vector2i.ONE)
	for x: int in range(origin.x - 2, east + 1):
		state.buildings.add("wooden_wall", Vector2i(x, origin.y - 3), true)
		state.buildings.add("wooden_wall", Vector2i(x, origin.y + 4), true)
	for y: int in range(origin.y - 2, origin.y + 4):
		state.buildings.add("wooden_wall", Vector2i(origin.x - 2, y), true)
		state.buildings.add("wooden_wall", Vector2i(east, y), true)
	state.buildings.add("watchtower", origin + Vector2i(3, -1), true)
	state.buildings.add("turret", origin + Vector2i(4, 1), true)
	state.buildings.add("turret", origin + Vector2i(3, 3), true)
	var guards: Array[Survivor] = state.survivors.all()
	for s: Survivor in guards:
		state.set_job(s.uid, Survivor.Job.IDLE)
	state.set_job(guards[0].uid, Survivor.Job.GUARD)
	state.set_job(guards[1].uid, Survivor.Job.GUARD)
	for i: int in range(100):
		state.tick(0.1)
	# Keep the showcase in daylight so the range preview remains easy to read.
	main.get_node("World")._draw_props()
	main.get_node("World")._draw_ground_detail()
	for column: int in range(2):
		for row: int in range(5):
			state.spawn_zombie(["walker", "runner", "brute"][row % 3], Grid.tile_to_world(Vector2i(east + 1 + column, origin.y - 2 + row)))
	for i: int in range(120):
		state.tick(0.1)
		var damaged: bool = false
		for z: Zombie in state.zombies.all():
			if z.hp < z.max_hp:
				damaged = true
		if state.zombies_killed >= 2 and state.zombies.count() >= 3 and damaged:
			break
	# Keep a reinforcement of any type the turrets killed before the capture.
	var present: Dictionary = {}
	for z: Zombie in state.zombies.all():
		present[z.type_id] = true
		if z.type_id == "runner":
			# Keep the small runner clear of the decorative bush at the wall.
			z.pos = Grid.tile_to_world(Vector2i(east + 1, origin.y + 3))
	for type_id: String in ZombieLayer.TYPES:
		if not present.has(type_id):
			state.spawn_zombie(type_id, Grid.tile_to_world(Vector2i(east + 1, origin.y + 3)))
	ZombieAI.tick(state, 0.01)
	var selected_turret: Building = state.buildings.all_of_type("turret")[0]
	(main.get_node("World/Selection") as SelectionController).select_building(selected_turret.uid)
	state.clock.set_paused(true)
	var camera: Camera2D = main.get_node("World/Camera2D")
	camera.position = Grid.tile_to_world(Vector2i(east - 2, origin.y)) + Vector2(0, Grid.TILE / 2.0)

	camera.set_process(false)
