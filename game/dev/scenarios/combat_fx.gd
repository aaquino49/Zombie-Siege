extends RefCounted

const Defense: GDScript = preload("res://dev/scenarios/defense.gd")

static func setup(main: Node) -> void:
	Defense.setup(main)
	var state: GameState = Game.state
	var fx: CombatFx = main.get_node("World/CombatFx") as CombatFx
	fx.clear()
	var origin: Vector2i = state.map.command_center_origin()
	var east: int = origin.x + 5
	# Keep small ground-detail bushes clear of the staged decals and impact.
	var detail: TileMapLayer = main.get_node("World/GroundDetail") as TileMapLayer
	for y: int in range(origin.y - 3, origin.y + 4):
		for x: int in range(east + 2, east + 5):
			detail.erase_cell(Vector2i(x, y))
	# Three genuine lethal events leave both body variants and uid-picked stains.
	for i: int in range(3):
		var z: Zombie = state.spawn_zombie("walker", Grid.tile_to_world(Vector2i(east + 3, origin.y - 2 + i * 2)))
		state.damage_zombie(z, z.hp)
	state.clock.set_paused(false)
	fx._process(ZombieLayer.DEATH_SECONDS + 0.01)
	# Aim both real shooter types horizontally so the capture has integer pixels.
	var turret: Building = state.buildings.all_of_type("turret")[0]
	var guard: Survivor = state.survivors.all()[0]
	turret.aim = Vector2.RIGHT
	state.shot_fired.emit(turret.center_world(), turret.center_world() + Vector2(160, 0), true)
	state.shot_fired.emit(guard.pos, guard.pos + Vector2(200, 0), false)
	# A fresh lethal impact remains a clear burst, with its body still pending.
	var hit: Zombie = state.spawn_zombie("walker", Grid.tile_to_world(Vector2i(east + 2, origin.y - 1)))
	state.damage_zombie(hit, hit.hp)
	fx._process(0.005)
	state.clock.set_paused(true)
	main.get_node("World/YSort/Units").sync()
	main.get_node("World/YSort/Zombies").sync()
	main.get_node("World")._process(0.0)
	var camera: Camera2D = main.get_node("World/Camera2D") as Camera2D
	camera.zoom = Vector2.ONE
	camera.set_process(false)
	assert(fx._corpses.filter(func(s: Sprite2D) -> bool: return s.visible).size() == 3)
