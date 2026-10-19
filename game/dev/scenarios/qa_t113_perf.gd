extends Node
## Rendered final-night frame intervals after warmup, with the 250-zombie fixture.

var frames: int = 0
var previous_usec: int = 0
var samples: Array[float] = []

static func setup(main: Node) -> void:
	var fixture: String = "zombies_perf"
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--perf-fixture=final_night":
			fixture = "final_night"
	load("res://dev/scenarios/" + fixture + ".gd").setup(main)
	var state: GameState = Game.state
	state.clock.day = state.data.final_night()
	var origin: Vector2i = state.map.command_center_origin()
	if fixture == "zombies_perf":
		for i: int in range(4):
			state.buildings.add(["shelter", "watchtower", "turret", "radio_tower"][i], origin + Vector2i((i - 2) * 4, 4), true)
	var camera: Camera2D = main.get_node("World/Camera2D")
	camera.zoom = Vector2.ONE
	camera.set_process(false)
	print("T113 PERF fixture=", fixture, " night=", state.clock.day, " zombies=", state.zombies.count(), " zoom=", camera.zoom)
	main.add_child(load("res://dev/scenarios/qa_t113_perf.gd").new())

func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	frames += 1
	if frames > 120:
		samples.append(float(now - previous_usec) / 1000.0)
	previous_usec = now
	if frames != 720:
		return
	var total: float = 0.0
	for sample: float in samples:
		total += sample
	samples.sort()
	var result: Dictionary = {"samples": samples.size(), "mean_ms": total / samples.size(),
		"median_ms": samples[samples.size() / 2], "p95_ms": samples[int(samples.size() * 0.95)],
		"max_ms": samples[-1], "mean_fps": 1000.0 * samples.size() / total,
		"over_33_33_ms": samples.filter(func(ms: float) -> bool: return ms > 1000.0 / 30.0).size()}
	print("T113 PERF RESULT ", JSON.stringify(result))
	set_process(false)
