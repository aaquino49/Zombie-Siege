extends RefCounted

static func setup(main: Node) -> void:
	var state: GameState = Game.state
	state.waves.enabled = false
	state.clock.day = 3
	state.clock.phase = GameClock.Phase.DAY
	state.clock.elapsed = 24.0
	state.map_seed = _seed_for_rain(state, 3)
	var cc: Building = state.buildings.all_of_type("command_center")[0]
	var farm_origin: Vector2i = _find_origin(state, "farm", cc.origin)
	if farm_origin == Vector2i(-1, -1):
		push_error("Weather rain scenario could not place farm")
		return
	var farm: Building = state.buildings.add("farm", farm_origin, true)
	var survivors: Array[Survivor] = state.survivors.all()
	for i: int in range(mini(2, survivors.size())):
		state.set_job(survivors[i].uid, Survivor.Job.FARMER)
	if survivors.size() > 2:
		state.set_job(survivors[2].uid, Survivor.Job.IDLE)
	for tick: int in range(500):
		if ProductionJob.workers_at(state, farm) >= mini(2, survivors.size()):
			break
		state.tick(0.1)
	state.clock.set_paused(true)
	var selection: SelectionController = main.get_node("World/Selection") as SelectionController
	selection.select_building(farm.uid)
	var camera: Camera2D = main.get_node("World/Camera2D") as Camera2D
	camera.position = farm.center_world()
	camera.zoom = Vector2.ONE
	var hud: Node = main.get_node("HUD")
	hud.call("_refresh_rain_tag")
	(main.get_node("HUD/PhaseBanner") as Control).hide()

static func _seed_for_rain(state: GameState, day: int) -> int:
	for seed: int in range(10000):
		if Weather.day_weather(state.data, seed, day) == "rain":
			return seed
	return 0

static func _find_origin(state: GameState, type_id: String, center: Vector2i) -> Vector2i:
	for radius: int in range(1, 12):
		for y: int in range(center.y - radius, center.y + radius + 1):
			for x: int in range(center.x - radius, center.x + radius + 1):
				var origin := Vector2i(x, y)
				if Placement.check(state, type_id, origin) == Placement.Result.OK:
					return origin
	return Vector2i(-1, -1)
