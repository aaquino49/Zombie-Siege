extends RefCounted

static func setup(main: Node) -> void:
	Game.state.waves.enabled = false
	var state: GameState = Game.state
	state.clock.day = 6
	state.clock.elapsed = PhaseBanner.BANNER_SECONDS
	state.resources.add("scrap", 20)
	var origin: Vector2i = state.map.command_center_origin() + Vector2i(-1, 4)
	var walls: Array[Building] = []
	for i: int in range(4):
		walls.append(state.buildings.add("wooden_wall", origin + Vector2i(i, 0), true))
	state.try_upgrade(walls[1].uid)
	var upgrade: Building = state.buildings.get_at(walls[1].origin)
	var ticks: int = 0
	while upgrade.progress_ratio() < 0.3 and ticks < 600:
		state.tick(0.1)
		ticks += 1
	var selection: SelectionController = main.get_node("World/Selection") as SelectionController
	selection.select_building(walls[2].uid)
	state.clock.set_paused(true)
	var camera: Camera2D = main.get_node("World/Camera2D") as Camera2D
	camera.position += Vector2(0, Grid.TILE * 2.0)
	var build_bar: BuildBar = main.get_node("BuildBarLayer") as BuildBar
	build_bar.refresh()
