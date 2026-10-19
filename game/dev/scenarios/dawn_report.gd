extends Node

static func setup(main: Node) -> void:
	var state: GameState = Game.state
	state.waves.enabled = false
	
	var origin: Vector2i = state.map.command_center_origin()
	for y: int in range(origin.y - 4, origin.y + 6):
		for x: int in range(origin.x - 5, origin.x + 7):
			var tile := Vector2i(x, y)
			if state.map.occupant_at(tile) in [1, 2, 3]:
				state.map.vacate(tile, Vector2i.ONE)
				
	state.clock.phase_changed.emit(GameClock.Phase.NIGHT, state.clock.day)
	state.clock.phase = GameClock.Phase.NIGHT
	
	var w1 = state.buildings.add("wooden_wall", origin + Vector2i(-1, 3), true)
	var w2 = state.buildings.add("wooden_wall", origin + Vector2i(0, 3), true)
	var w3 = state.buildings.add("wooden_wall", origin + Vector2i(1, 3), true)
	
	state.damage_building(w1, w1.hp)
	state.damage_building(w2, 60)
	
	var cc = state.buildings.all_of_type("command_center")[0]
	state.damage_building(cc, 40)
	
	if state.survivors.count() > 0:
		var s = state.survivors.all()[0]
		state.damage_survivor(s, s.hp)
		
	var spawn_pos = Vector2(origin) * Grid.TILE + Vector2(0, 100)
	for i in range(5):
		var z = state.spawn_zombie("walker", spawn_pos)
		state.damage_zombie(z, 9999)
		
	state.clock.elapsed = float(state.data.balance("night_min_length")) - 0.1
	state.tick(0.2)
	
	var cam = main.get_node("World/Camera2D") as Camera2D
	if cam:
		cam.position = cc.center_world()
