extends RefCounted

const Fixture: GDScript = preload("res://tests/night_sim_fixture.gd")
const View: GDScript = preload("res://dev/scenarios/qa_m3_night1_defense.gd")

static func setup(main: Node) -> void:
	var state: GameState = Game.state
	var base: Dictionary = Fixture.defended(state)
	assert(bool(base["ok"]))
	Fixture.idle(state)
	state.resources.take("ammo", state.resources.get_amount("ammo"))
	Fixture.nightfall(state, 11)
	var cc: Building = state.buildings.all_of_type("command_center")[0]
	# Night 11 is the first balanced wave with brutes. Compose one of each type beside the
	# scanned enclosure: natural runners arrive long before the slow brute.
	for i: int in range(300):
		state.tick(0.1)
		if state.waves.pending() == 0:
			break
	assert(state.waves.pending() == 0 and not state.game_over)
	var ring: Array[Vector2i] = base["ring"]
	var row: int = 0
	for type_id: String in ["walker", "runner", "brute"]:
		var chosen: Zombie = null
		for z: Zombie in state.zombies.all():
			if chosen == null and z.type_id == type_id:
				chosen = z
		assert(chosen != null, "Real scheduled wave must contain " + type_id)
		var placed: bool = false
		for x: int in range(ring[-1].x + 1, ring[-1].x + 5):
			var tile: Vector2i = Vector2i(x, cc.origin.y - 1 + row)
			if not placed and state.map.is_passable(tile):
				chosen.pos = Grid.tile_to_world(tile)
				chosen.attack_timer = 0.0
				placed = true
		assert(placed, "Scanned readable zombie staging tile must be free")
		row += 2
	for i: int in range(15):
		state.tick(0.1)
	View.show(main, cc.center_world())
	main.get_node("World/Camera2D").zoom = Vector2.ONE
	print("T-022 mixed wave: zombies=", state.zombies.count(), " elapsed=", state.clock.elapsed, " buildings_lost=", state.buildings_lost)
