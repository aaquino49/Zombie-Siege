extends RefCounted

static func setup(main: Node) -> void:
	var state: GameState = Game.state
	state.clock.day = 20
	state.clock.elapsed = float(state.data.balance("day_length")) - 0.25
	state.tick(0.25)
	state.tick(0.25)
	state.clock.set_paused(true)
	var support: GDScript = preload("res://dev/scenarios/qa_m4_support.gd")
	var wave: Dictionary = state.data.wave_for_night(20)
	support.check(wave["walker"] == 128 and wave["runner"] == 68 and wave["brute"] == 20 and wave["sides"] == 4,
		"Final Horde doubles all counts and attacks four sides")
	var sides: Dictionary = {}
	for entry: Dictionary in state.waves._schedule:
		sides[entry["side"]] = true
	support.check(sides.size() == 4, "Actual wave schedule includes all four sides")
	var camera: Camera2D = main.get_node("World/Camera2D")
	camera.set_process(false)
	camera.position = state.buildings.all_of_type("command_center")[0].center_world()
	camera.zoom = Vector2.ONE * 0.5
