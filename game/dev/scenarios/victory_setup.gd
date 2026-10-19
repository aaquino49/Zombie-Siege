extends RefCounted
class_name VictorySetup

static func place_finished_tower(state: GameState) -> Building:
	var origin: Vector2i = state.map.command_center_origin()
	for y: int in range(origin.y - 4, origin.y + 6):
		for x: int in range(origin.x - 5, origin.x + 7):
			var tile: Vector2i = Vector2i(x, y)
			if state.map.occupant_at(tile) in [1, 2, 3]:
				state.map.vacate(tile, Vector2i.ONE)

	var last_result: int = Placement.check(state, "radio_tower", origin + Vector2i(-4, 0))
	var tower_pos: Vector2i = origin + Vector2i(-4, 0)
	if last_result != Placement.Result.OK:
		var map_size: int = state.map.size()
		for radius: int in range(1, map_size + 1):
			for y_offset: int in range(-radius, radius + 1):
				for x_offset: int in range(-radius, radius + 1):
					if maxi(absi(x_offset), absi(y_offset)) != radius:
						continue
					var candidate: Vector2i = origin + Vector2i(x_offset, y_offset)
					last_result = Placement.check(state, "radio_tower", candidate)
					if last_result == Placement.Result.OK:
						tower_pos = candidate
						break
				if last_result == Placement.Result.OK:
					break
			if last_result == Placement.Result.OK:
				break

	if last_result != Placement.Result.OK:
		var result_names: Array = Placement.Result.keys()
		push_error("Radio tower placement failed: %s" % str(result_names[last_result]))
		return null

	var place_result: int = state.try_place("radio_tower", tower_pos)
	if place_result != Placement.Result.OK:
		var result_names: Array = Placement.Result.keys()
		push_error("Radio tower placement failed: %s" % str(result_names[place_result]))
		return null
	var tower: Building = state.buildings.get_at(tower_pos)
	state.buildings.finish(tower.uid)
	return tower

static func trigger_win() -> void:
	var state: GameState = Game.state
	state.waves.enabled = false
	state.clock.day = 20
	state.resources.add("wood", 300)
	state.resources.add("scrap", 300)
	place_finished_tower(state)
	
	state.zombies_killed = 812
	state.time_played = 2400.0
	
	state.clock.phase = GameClock.Phase.NIGHT
	state.clock.elapsed = float(state.data.balance("night_min_length", 45))
	
	state.tick(0.1)
