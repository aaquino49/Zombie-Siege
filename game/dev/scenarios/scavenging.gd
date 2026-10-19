extends RefCounted
## Scavenging screenshot: day-3 morning with a selected survivor (Send button
## enabled), a second survivor walking to the edge, an away roster row and a
## fixed return toast. The toast uses the HUD API; the clock is untouched.

static func setup(main: Node) -> void:
	var state: GameState = Game.state
	state.waves.enabled = false
	state.clock.day = 3
	state.clock.phase = GameClock.Phase.DAY
	# Past the 4 s phase banner (which keys off elapsed) but still morning, so
	# the capture shows no banner and the Send button stays enabled.
	state.clock.elapsed = 5.0
	state.clock.set_paused(true)
	# Three visible runs would exceed the day-3 limit of one; the scenario
	# alone widens it so the selected survivor keeps an enabled button while
	# one runner is away and another is still walking out.
	state.data._expeditions["max_runs"] = 3

	var survivors: Array[Survivor] = state.survivors.all()
	for s: Survivor in survivors:
		state.set_job(s.uid, Survivor.Job.IDLE)

	state.expeditions.send(survivors[1].uid)
	state.survivors.tick(1000.0, state.pathfinder, state.map)
	state.expeditions.tick(state, 0.0)

	state.expeditions.send(survivors[2].uid)
	state.survivors.tick(2.0, state.pathfinder, state.map)
	state.expeditions.tick(state, 0.0)

	var selection: SelectionController = main.get_node("World/Selection")
	selection.select_survivor(survivors[0].uid)

	var roster: RosterPanel = main.get_node("RosterPanel")
	if not roster.is_open():
		roster.toggle()
	roster.refresh()

	var hud: CanvasLayer = main.get_node("HUD")
	hud.call("show_scavenge_toast", "Mara", {
		"loot": {"wood": 0, "scrap": 32, "food": 12, "ammo": 0},
		"hurt": false, "lost": false, "newcomer": false,
	})

	var origin: Vector2i = state.map.command_center_origin()
	var camera: Camera2D = main.get_node("World/Camera2D")
	camera.position = Grid.tile_to_world(origin) + Vector2(Grid.TILE / 2.0, Grid.TILE / 2.0)
	camera.zoom = Vector2.ONE
	camera.set_process(false)
