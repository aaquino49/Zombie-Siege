extends Node

var count: int = 0
var intervals: Array[float] = []
var sim_times: Array[float] = []
var previous: int = 0

static func setup(main: Node) -> void:
	var state: GameState = Game.state
	state.waves.enabled = false
	state.clock.day = 20
	state.clock.phase = GameClock.Phase.NIGHT
	state.clock.elapsed = 5.0
	state.clock.phase_changed.emit(GameClock.Phase.NIGHT, 20)
	state.clock.set_paused(true)
	var origin: Vector2i = state.map.command_center_origin()
	for i: int in range(250):
		var offset := Vector2i((i % 25) - 12, -12 - i / 25)
		state.spawn_zombie("spitter" if i < 15 else ["walker", "runner", "brute"][i % 3], Grid.tile_to_world(origin + offset))
	for i: int in range(26):
		state.survivors.add("QA%d" % i, "blue", origin + Vector2i(i % 8 - 4, i / 8 + 4))
	var camera: Camera2D = main.get_node("World/Camera2D")
	camera.position = Grid.tile_to_world(origin + Vector2i(0, -6))
	camera.zoom = Vector2(0.5, 0.5)
	camera.set_process(false)
	main.get_node("Hints").set_enabled(false)
	main.add_child(load("res://dev/scenarios/qa_m8_perf.gd").new())
	print("M8 PERF: 250 zombies including 15 spitters, 30 survivors; full simulation and rendered view updates")

func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	count += 1
	if count > 120:
		intervals.append((now - previous) / 1000.0)
	previous = now
	var started: int = Time.get_ticks_usec()
	Game.state.clock.set_paused(false)
	Game.state.tick(1.0 / 60.0)
	Game.state.clock.set_paused(true)
	if count > 120:
		sim_times.append((Time.get_ticks_usec() - started) / 1000.0)
	if count != 720:
		return
	intervals.sort()
	sim_times.sort()
	print("M8 PERF RESULT ", JSON.stringify({"samples": intervals.size(), "median_frame_ms": intervals[300],
		"p95_frame_ms": intervals[570], "max_frame_ms": intervals[-1],
		"median_sim_ms": sim_times[300], "p95_sim_ms": sim_times[570], "zombies_remaining": Game.state.zombies.count()}))
	set_process(false)
