extends RefCounted

static func setup(main: Node) -> void:
	preload("res://dev/scenarios/buildings_placed.gd").setup(main)
	var state: GameState = main.get_node("/root/Game").state if main.has_node("/root/Game") else Game.state
	
	var cc_origin: Vector2i = state.map.command_center_origin()
	var start_tile: Vector2i = cc_origin + Vector2i(-3, 0)
	var target_tile: Vector2i = cc_origin + Vector2i(-8, 0)
	
	# Make sure start and route are free without breaking CC or buildings
	for i: int in range(-3, -9, -1):
		var t: Vector2i = cc_origin + Vector2i(i, 0)
		if not state.map.is_passable(t):
			state.map.vacate(t, Vector2i(1, 1))
			
	var survivors = state.survivors.all()
	for s_i in survivors:
		state.set_job(s_i.uid, Survivor.Job.IDLE)
		
	var s: Survivor = survivors[0]
	s.pos = Grid.tile_to_world(start_tile)
	
	var success: bool = state.order_move(s.uid, target_tile)
	if not success:
		push_warning("Failed to order survivor to move")
	
	for i: int in range(15):
		state.tick(0.1)
