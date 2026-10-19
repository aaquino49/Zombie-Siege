extends RefCounted
## Staged visual evidence for variant looks, north/south sorting, HP and selection.

static func setup(main: Node) -> void:
	var state: GameState = Game.state
	state.clock.set_paused(true)
	var cc: Building = state.buildings.all_of_type("command_center")[0]
	var center: Vector2 = cc.center_world()
	var all_survivors: Array[Survivor] = state.survivors.all().duplicate()
	for survivor: Survivor in all_survivors:
		state.survivors.remove(survivor.uid)
	var variants: Array = state.data.balance("survivor_variants")
	for index: int in range(variants.size()):
		var survivor: Survivor = state.survivors.add("Variant", variants[index], cc.origin)
		state.set_job(survivor.uid, Survivor.Job.IDLE)
		survivor.pos = center + Vector2((index - 3) * 84, 160)
		survivor.facing = Vector2.DOWN
	var north: Survivor = state.survivors.add("North", "blue", cc.origin)
	north.pos = center + Vector2(-30, -20)
	north.facing = Vector2.DOWN
	var south: Survivor = state.survivors.add("South", "soldier", cc.origin)
	south.pos = center + Vector2(30, 70)
	south.facing = Vector2.UP
	south.hp = south.max_hp / 2
	main.get_node("World/YSort/Units").sync()
	main.get_node("World/Selection").select_survivor(south.uid)
	var camera: Camera2D = main.get_node("World/Camera2D")
	camera.position = center
	camera.zoom = Vector2.ONE
	camera.set_process(false)
