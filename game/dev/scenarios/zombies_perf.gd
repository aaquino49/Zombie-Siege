extends Node

static func setup(main: Node) -> void:
	Game.state.waves.enabled = false
	var state: GameState = Game.state
	state.clock.elapsed = state.data.balance("day_length", 30.0) - 0.05
	
	var origin: Vector2i = state.map.command_center_origin()
	var map_size: int = state.map.size()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1337
	
	for i: int in range(250):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(10.0, 30.0)
		var pos: Vector2i = origin + Vector2i(int(cos(angle) * dist), int(sin(angle) * dist))
		pos.x = clampi(pos.x, 0, map_size - 1)
		pos.y = clampi(pos.y, 0, map_size - 1)
		state.spawn_zombie("walker", Grid.tile_to_world(pos))
	
	var start_time: int = Time.get_ticks_usec()
	var ticks: int = int(3.0 / 0.1)
	for i: int in range(ticks):
		state.tick(0.1)

	var end_time: int = Time.get_ticks_usec()
	var elapsed_ms: float = (end_time - start_time) / 1000.0
	var avg_ms: float = elapsed_ms / ticks
	print("Average sim ms per tick: ", avg_ms)

	# Finish the phase banner before freezing the crowd for capture.
	state.tick(PhaseBanner.BANNER_SECONDS + 0.1 - state.clock.elapsed)
	state.clock.set_paused(true)
	
	var camera: Camera2D = main.get_node("World/Camera2D")
	camera.position = Grid.tile_to_world(origin)
	camera.zoom = Vector2(0.5, 0.5)
