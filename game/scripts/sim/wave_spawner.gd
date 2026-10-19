class_name WaveSpawner extends RefCounted
## Own RNG and weak owner reference preserve seeded simulation and ownership.

var enabled: bool = false
var _state_ref: WeakRef
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _schedule: Array[Dictionary] = []

func _init(state: GameState) -> void:
	_state_ref = weakref(state)
	_rng.seed = state.map_seed + 3
	state.clock.phase_changed.connect(_on_phase_changed)

func _on_phase_changed(phase: int, day: int) -> void:
	if phase == GameClock.Phase.NIGHT:
		if enabled:
			plan_night(day)
	else:
		clear_pending()

func clear_pending() -> void:
	_schedule.clear()

func _shuffle(values: Array) -> void:
	for i: int in range(values.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var value: Variant = values[i]
		values[i] = values[j]
		values[j] = value

static func forecast(data: GameData, night: int, multipliers: Dictionary, map_seed: int = 0) -> Dictionary:
	var wave: Dictionary = data.wave_for_night(night)
	var wave_multiplier: float = float(multipliers.get("wave_size_mult", 1.0))
	var counts: Dictionary = {}
	for type_id: String in ["walker", "runner", "brute", "spitter"]:
		var base_count: int = int(wave[type_id])
		var scaled_count: int = roundi(float(base_count) * wave_multiplier)
		if base_count >= 1:
			scaled_count = maxi(1, scaled_count)
		# Endless damping uses nearest-integer rounding and never touches campaign nights.
		if night > data.final_night():
			scaled_count = roundi(float(scaled_count) * float(data.wave_value("endless_wave_mult", 1.0)))
		counts[type_id] = scaled_count
	counts["sides"] = clampi(int(wave["sides"]), 0, 4)
	counts["final"] = bool(wave["final"])
	counts["fog"] = Weather.night_weather(data, map_seed, night) == "fog"
	counts["range_delta_tiles"] = float(data.weather_config()["fog"]["range_delta_tiles"])
	return counts

func plan_night(n: int) -> void:
	_schedule.clear()
	var state: GameState = _state_ref.get_ref() as GameState
	if state == null:
		return
	var counts: Dictionary = forecast(state.data, n, state.difficulty_multipliers, state.map_seed)
	var sides: Array[int] = [0, 1, 2, 3]
	_shuffle(sides)
	var side_count: int = int(counts["sides"])
	if side_count == 0:
		return
	var types: Array[String] = []
	for type_id: String in ["walker", "runner", "brute", "spitter"]:
		var scaled_count: int = int(counts[type_id])
		for i: int in range(scaled_count):
			types.append(type_id)
	_shuffle(types)
	var window: float = float(state.data.balance("night_min_length")) * float(state.data.wave_value("spawn_window_fraction"))
	for i: int in range(types.size()):
		_schedule.append({"time": window * i / types.size(), "type": types[i], "side": sides[i % side_count]})

func pending() -> int:
	return _schedule.size()

func time_left(clock: GameClock) -> float:
	if not enabled or clock.phase != GameClock.Phase.NIGHT or _schedule.is_empty():
		return -1.0
	return maxf(0.0, float(_schedule[0]["time"]) - clock.elapsed)

func tick(state: GameState, _dt: float) -> void:
	if not enabled or state.clock.phase != GameClock.Phase.NIGHT:
		return
	while not _schedule.is_empty() and float(_schedule[0]["time"]) <= state.clock.elapsed:
		var entry: Dictionary = _schedule.pop_front()
		state.spawn_zombie(String(entry["type"]), spawn_point(int(entry["side"])))

func spawn_point(side: int) -> Vector2:
	var state: GameState = _state_ref.get_ref() as GameState
	if state == null:
		return Vector2.ZERO
	var size: int = state.map.size()
	var edge: Vector2i
	var outside: Vector2i
	for attempt: int in range(8):
		var along: int = _rng.randi_range(2, size - 3)
		match side:
			0:
				edge = Vector2i(along, 0)
				outside = Vector2i(along, -1)
			1:
				edge = Vector2i(size - 1, along)
				outside = Vector2i(size, along)
			2:
				edge = Vector2i(along, size - 1)
				outside = Vector2i(along, size)
			3:
				edge = Vector2i(0, along)
				outside = Vector2i(-1, along)
		if state.flow.distance(edge) >= 0:
			break
	var jitter: float = _rng.randf_range(-Grid.TILE / 4.0, Grid.TILE / 4.0)
	return Grid.tile_to_world(outside) + (Vector2(jitter, 0) if side % 2 == 0 else Vector2(0, jitter))
