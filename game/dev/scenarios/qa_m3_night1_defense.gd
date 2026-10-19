extends RefCounted

const Fixture: GDScript = preload("res://tests/night_sim_fixture.gd")

static func show(main: Node, center: Vector2) -> void:
	Game.state.clock.set_paused(true)
	var camera: Camera2D = main.get_node("World/Camera2D") as Camera2D
	camera.position = center + Vector2(0, Grid.TILE)
	camera.zoom = Vector2.ONE * 0.9
	camera.set_process(false)
	main.get_node("World/YSort/Units").sync()
	main.get_node("World/YSort/Zombies").sync()
	main.get_node("World")._process(0.0)

static func setup(main: Node) -> void:
	var state: GameState = Game.state
	assert(bool(Fixture.defended(state)["ok"]), "Legal defense fixture required")
	Fixture.nightfall(state, 1)
	var fired: Array[bool] = [false]
	var on_shot: Callable = func(_from: Vector2, _to: Vector2, turret: bool) -> void:
		if turret:
			fired[0] = true
	state.shot_fired.connect(on_shot)
	var fx: CombatFx = main.get_node("World/CombatFx") as CombatFx
	for i: int in range(3000):
		fx._process(0.1)
		state.tick(0.1)
		if fired[0] and state.zombies.count() >= 2:
			break
		fired[0] = false
	state.shot_fired.disconnect(on_shot)
	assert(fired[0], "Night-1 wave must reach firing turrets")
	var cc: Building = state.buildings.all_of_type("command_center")[0]
	show(main, cc.center_world())
	print("T-022 night1 fight: kills=", state.zombies_killed, " ammo=", state.resources.get_amount("ammo"), " night_seconds=", state.clock.elapsed)
