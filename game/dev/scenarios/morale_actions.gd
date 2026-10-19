extends RefCounted
## Morale player levers: the Command Center is selected so the Hold-a-feast
## button shows its total cost and exact sim disabled reason (on cooldown
## here), while the open roster shows a survivor on a day off. Day-5
## morning, paused, no zombies.

static func setup(main: Node) -> void:
	var state: GameState = Game.state
	state.waves.enabled = false
	state.clock.day = 5
	state.clock.phase = GameClock.Phase.DAY
	state.clock.elapsed = 5.0
	state.clock.set_paused(true)
	# Feast held on day 3: next allowed on day 6, so the button shows the
	# exact cooldown reason with its total cost.
	state.last_feast_day = 3

	var survivors: Array[Survivor] = state.survivors.all()
	Morale.give_day_off(state, survivors[0].uid)

	var cc: Building = state.buildings.all_of_type("command_center")[0]
	var selection: SelectionController = main.get_node("World/Selection")
	selection.select_building(cc.uid)

	var roster: RosterPanel = main.get_node("RosterPanel")
	if not roster.is_open():
		roster.toggle()
	roster.refresh()

	var origin: Vector2i = state.map.command_center_origin()
	var camera: Camera2D = main.get_node("World/Camera2D")
	camera.position = Grid.tile_to_world(origin) + Vector2(Grid.TILE / 2.0, Grid.TILE / 2.0)
	camera.zoom = Vector2.ONE
	camera.set_process(false)
	# Show the actual disabled tooltip in both required captures.
	for i: int in range(6): await main.get_tree().process_frame
	var feast: Button = main.get_node("InfoPanel/PanelContainer/VBoxContainer/FeastButton")
	var motion := InputEventMouseMotion.new()
	motion.position = feast.get_global_rect().get_center()
	motion.global_position = motion.position
	main.get_viewport().push_input(motion)
