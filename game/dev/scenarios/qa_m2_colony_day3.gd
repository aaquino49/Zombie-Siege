extends RefCounted
## Shared deterministic M2 fixture and a day-three midday capture.

static func place_complete(state: GameState, type_id: String) -> Building:
	var cc: Vector2i = state.map.command_center_origin()
	for radius: int in range(2, 16):
		for y: int in range(cc.y - radius, cc.y + radius + 1):
			for x: int in range(cc.x - radius, cc.x + radius + 1):
				var origin := Vector2i(x, y)
				var occupied: bool = false
				var size_data: Array = state.data.get_building(type_id)["size"]
				var footprint := Rect2i(origin, Vector2i(int(size_data[0]), int(size_data[1])))
				for s: Survivor in state.survivors.all():
					occupied = occupied or footprint.has_point(s.tile())
				if not occupied and Placement.check(state, type_id, origin) == Placement.Result.OK:
					return state.buildings.add(type_id, origin, true)
	push_error("T-016 fixture could not place " + type_id)
	return null

static func plan(state: GameState) -> Array[Building]:
	var farm: Building = place_complete(state, "farm")
	var shelter: Building = place_complete(state, "shelter")
	var workers: Array[Survivor] = state.survivors.all()
	state.set_job(workers[0].uid, Survivor.Job.FARMER)
	state.set_job(workers[1].uid, Survivor.Job.FARMER)
	state.set_job(workers[2].uid, Survivor.Job.GATHERER, "wood")
	state.set_job(workers[3].uid, Survivor.Job.BUILDER)
	return [farm, shelter]

static func advance_to(state: GameState, day: int, elapsed: float = 0.0) -> void:
	for tick: int in range(8000):
		if state.clock.day == day and state.clock.phase == GameClock.Phase.DAY and state.clock.elapsed >= elapsed:
			return
		state.tick(0.1)
	push_error("T-016 fixture exceeded its bounded simulation loop")

static func show(main: Node, selected: Building = null) -> void:
	var state: GameState = Game.state
	state.clock.set_paused(true)
	var roster: RosterPanel = main.get_node("RosterPanel")
	if not roster.is_open():
		roster.toggle()
	roster.refresh()
	var selection: SelectionController = main.get_node("World/Selection")
	if selected != null:
		selection.select_building(selected.uid)
	var info: InfoPanel = main.get_node("InfoPanel")
	info.refresh()
	# Keep the CC and nearby colony clear of both side panels and the build bar.
	var camera: Camera2D = main.get_node("World/Camera2D")
	var cc: Building = state.buildings.all_of_type("command_center")[0]
	camera.zoom = Vector2.ONE
	camera.position = cc.center_world() + Vector2(56, 64)
	camera.set_process(false)
	print("T-016 capture: day=", state.clock.day, " population=", state.survivors.count(), " food=", state.resources.get_amount("food"), " dawn=", state.last_dawn_report)

static func setup(main: Node) -> void:
	Game.state.waves.enabled = false
	var fixtures: Array[Building] = plan(Game.state)
	advance_to(Game.state, 3, float(Game.state.data.balance("day_length")) / 2.0)
	show(main, fixtures[0])

static func blocked_worker(state: GameState) -> Survivor:
	# Native seed-1337 starting position: Frank stands on the CC's north ring.
	# This legal adjacent farm excludes Frank's tile, then the wall covers it.
	for s: Survivor in state.survivors.all():
		state.set_job(s.uid, Survivor.Job.IDLE)
	var origin: Vector2i = state.map.command_center_origin() + Vector2i(0, -3)
	state.buildings.add("farm", origin, true)
	var worker: Survivor = state.survivors.all()[1]
	state.set_job(worker.uid, Survivor.Job.FARMER)
	state.tick(0.1)
	state.try_place("wooden_wall", worker.tile())
	state.set_job(state.survivors.all()[0].uid, Survivor.Job.BUILDER)
	return worker
