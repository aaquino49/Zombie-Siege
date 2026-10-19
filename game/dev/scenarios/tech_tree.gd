extends RefCounted
## All four states, paused saved progress, an active bar and nonzero bank.

static func setup(main: Node) -> void:
	var state: GameState = Game.state
	state.waves.enabled = false
	state.clock.day = 6
	state.clock.phase = GameClock.Phase.DAY
	state.clock.elapsed = 5.0
	state.clock.set_paused(true)
	var lab: Building = state.buildings.add("field_lab", state.map.command_center_origin() + Vector2i(4, 0), true)
	var people: Array[Survivor] = state.survivors.all()
	for i: int in range(2):
		var s: Survivor = people[i]
		state.set_job(s.uid, Survivor.Job.RESEARCHER)
		s.pos = Grid.tile_to_world(lab.origin + Vector2i(-1, i))
		s.path.clear()
		s.work_uid = lab.uid
		s.activity = Survivor.Activity.RESEARCHING
		s.moods.clear()
		s.morale = 50
	state.tech.restore({"done": ["spotters"], "active": "oiled_turrets", "progress": {"oiled_turrets": 12.75, "better_tools": 7.5}, "banked": 4.75})
	# Restore is a fixture operation, not a player completion.
	main.get_node("HUD")._research_seen = {"spotters": true}
	main.get_node("TechTreeScreen").open()
	var camera: Camera2D = main.get_node("World/Camera2D")
	camera.position = state.buildings.all_of_type("command_center")[0].center_world()
	camera.zoom = Vector2.ONE
	camera.set_process(false)
