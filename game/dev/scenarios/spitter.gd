extends RefCounted
## Paused night-nine acid attack; T-165 supplies the live projectile view.

static func setup(main: Node) -> void:
	_setup(main, false)

static func setup_day(main: Node) -> void:
	_setup(main, true)

static func _setup(main: Node, daytime: bool) -> void:
	var state: GameState = Game.state
	state.waves.enabled = false
	var origin: Vector2i = state.map.command_center_origin()
	for y: int in range(origin.y - 5, origin.y + 7):
		for x: int in range(origin.x - 4, origin.x + 11):
			var tile := Vector2i(x, y)
			if state.map.occupant_at(tile) != WorldMap.Occupant.BUILDING:
				state.map.vacate(tile, Vector2i.ONE)
	for x: int in range(origin.x - 2, origin.x + 6):
		state.buildings.add("wooden_wall", Vector2i(x, origin.y - 3), true)
		state.buildings.add("wooden_wall", Vector2i(x, origin.y + 4), true)
	for y: int in range(origin.y - 2, origin.y + 4):
		state.buildings.add("wooden_wall", Vector2i(origin.x - 2, y), true)
		state.buildings.add("wooden_wall", Vector2i(origin.x + 5, y), true)
	var turret: Building = state.buildings.add("turret", origin + Vector2i(4, 0), true)
	var first: Zombie = state.spawn_zombie("spitter", Grid.tile_to_world(origin + Vector2i(7, 0)))
	state.spawn_zombie("spitter", Grid.tile_to_world(origin + Vector2i(7, 2)))
	var walker: Zombie = state.spawn_zombie("walker", Grid.tile_to_world(origin + Vector2i(8, 0)))
	state.clock.day = 9
	var phase: int = GameClock.Phase.DAY if daytime else GameClock.Phase.NIGHT
	state.clock.phase = phase
	state.clock.phase_changed.emit(phase, 9)
	state.clock.elapsed = PhaseBanner.BANNER_SECONDS + 1.0
	ZombieAI.tick(state, 0.1)
	walker.pos = Grid.tile_to_world(origin + Vector2i(8, 0))
	var zombie_layer: ZombieLayer = main.get_node("World/YSort/Zombies") as ZombieLayer
	zombie_layer.sync()
	var ranged: Dictionary = state.data.get_zombie("spitter")["ranged"]
	state.projectiles.launch(state, first.pos, turret, turret.origin, ranged)
	state.projectiles.tick(state, 0.5)
	var second: Zombie = state.zombies.all()[1]
	state.projectiles.launch(state, second.pos, turret, turret.origin, ranged)
	state.projectiles.tick(state, 0.8)
	if state.projectiles.globs.is_empty():
		state.projectiles.launch(state, second.pos, turret, turret.origin, ranged)
	state.acid_hit.emit(turret.center_world())
	main.get_node("World")._draw_props()
	main.get_node("World")._draw_ground_detail()
	var fx: CombatFx = main.get_node("World/CombatFx") as CombatFx
	state.clock.set_paused(true)
	fx._process(0.0)
	var world: Node = main.get_node("World")
	var building_nodes: Dictionary = world.get("_building_nodes")
	var turret_view: Node2D = building_nodes[turret.uid] as Node2D
	var spitter_view: AnimatedSprite2D = zombie_layer._active_sprites[first.uid] as AnimatedSprite2D
	fx._acid_splashes[0].global_position = turret_view.global_position
	fx._acid_globs[0].global_position = (spitter_view.global_position + turret_view.global_position) / 2.0
	var camera: Camera2D = main.get_node("World/Camera2D")
	camera.position = Grid.tile_to_world(origin + Vector2i(3, 0)) + Vector2(0, Grid.TILE / 2.0)
	camera.zoom = Vector2.ONE
	camera.set_process(false)
	fx.set_process(false)
