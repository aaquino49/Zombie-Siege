extends RefCounted
## Reproduction evidence for the T-016 placement/evacuation bug.

static func setup(main: Node) -> void:
	Game.state.waves.enabled = false
	var fixture: GDScript = preload("res://dev/scenarios/qa_m2_colony_day3.gd")
	var state: GameState = Game.state
	var worker: Survivor = fixture.blocked_worker(state)
	# Run a whole day and forty night seconds: accessible CC beds are available.
	fixture.advance_to(state, 1, float(state.data.balance("day_length")) - 0.2)
	for tick: int in range(402):
		state.tick(0.1)
	fixture.show(main)
	(main.get_node("World/Selection") as SelectionController).select_survivor(worker.uid)
	(main.get_node("InfoPanel") as InfoPanel).refresh()
	print("T-016 BUG covered worker: tile=", worker.tile(), " passable=", state.map.is_passable(worker.tile()), " sheltered=", worker.sheltered, " activity=", Survivor.activity_label(worker.activity), " path=", worker.path)
