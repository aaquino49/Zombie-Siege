extends RefCounted

static func setup(main: Node) -> void:
	var state: GameState = Game.state
	state.waves.enabled = false
	state.clock.day = 5
	state.clock.phase = GameClock.Phase.NIGHT
	state.clock.elapsed = 8.0
	state.map_seed = _seed_for_fog(state, 5)
	var cc: Building = state.buildings.all_of_type("command_center")[0]
	var turret_origin: Vector2i = _find_origin(state, "turret", cc.origin + Vector2i(5, 0))
	if turret_origin == Vector2i(-1, -1):
		push_error("Weather fog scenario could not place turret")
		return
	var turret: Building = state.buildings.add("turret", turret_origin, true)
	for i: int in range(5):
		var pos: Vector2 = turret.center_world() + Vector2(Grid.TILE * (2.3 + float(i % 2)), Grid.TILE * (float(i) - 2.0) * 0.55)
		state.spawn_zombie("walker", pos)
	state.clock.set_paused(true)
	var selection: SelectionController = main.get_node("World/Selection") as SelectionController
	selection.select_building(turret.uid)
	var camera: Camera2D = main.get_node("World/Camera2D") as Camera2D
	camera.position = turret.center_world() + Vector2(Grid.TILE * 1.5, 0.0)
	camera.zoom = Vector2.ONE
	(main.get_node("HUD/PhaseBanner") as Control).hide()

static func _seed_for_fog(state: GameState, night: int) -> int:
	for seed: int in range(10000):
		if Weather.night_weather(state.data, seed, night) == "fog":
			return seed
	return 0

static func _find_origin(state: GameState, type_id: String, center: Vector2i) -> Vector2i:
	for radius: int in range(0, 12):
		for y: int in range(center.y - radius, center.y + radius + 1):
			for x: int in range(center.x - radius, center.x + radius + 1):
				var origin := Vector2i(x, y)
				if state.map.occupant_at(origin) == WorldMap.Occupant.NONE:
					return origin
	return Vector2i(-1, -1)
