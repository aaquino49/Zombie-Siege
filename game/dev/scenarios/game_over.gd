extends Node

static func setup(main: Node) -> void:
	var records_path := "user://t196_game_over_records.cfg"
	Records.remove_file(records_path)
	main.tree_exiting.connect(func() -> void: Records.remove_file(records_path), CONNECT_ONE_SHOT)
	(main.get_node("GameOverScreen") as GameOverScreen).records_path = records_path
	var state: GameState = Game.state
	state.waves.enabled = false
	state.clock.day = 6
	state.resources.add("wood", 300)
	state.resources.add("scrap", 300)
	var origin: Vector2i = state.map.command_center_origin()
	for y: int in range(origin.y - 4, origin.y + 6):
		for x: int in range(origin.x - 5, origin.x + 7):
			var tile := Vector2i(x, y)
			if state.map.occupant_at(tile) in [1, 2, 3]:
				state.map.vacate(tile, Vector2i.ONE)
	var types: Array[String] = ["farm", "shelter", "watchtower", "wooden_wall", "wooden_wall", "wooden_wall"]
	var offsets: Array[Vector2i] = [Vector2i(-4, 1), Vector2i(3, 2), Vector2i(3, -2), Vector2i(-1, -3), Vector2i(0, -3), Vector2i(1, -3)]
	for i: int in range(types.size()):
		var tile: Vector2i = origin + offsets[i]
		if state.try_place(types[i], tile) == Placement.Result.OK:
			state.buildings.finish(state.buildings.get_at(tile).uid)
	for s: Survivor in state.survivors.all():
		state.set_job(s.uid, Survivor.Job.IDLE)
	state.damage_survivor(state.survivors.all()[0], state.survivors.all()[0].hp)
	state.zombies_killed = 127
	state.time_played = 1085.0
	var cc: Building = state.buildings.all_of_type("command_center")[0]
	state.damage_building(cc, cc.hp)
	state.tick(0.01)
	var camera: Camera2D = main.get_node("World/Camera2D")
	camera.position = cc.center_world()
