class_name Expeditions extends RefCounted
## Daily scavenging runs use an isolated RNG so the existing simulation stream is unchanged.

signal run_started(s: Survivor)
signal run_returned(s: Survivor, result: Dictionary)

var _state_ref: WeakRef
var _runs: Dictionary = {} # uid -> run state
var _sent_today: Dictionary = {} # day -> count
var _dawn_report: Array[Dictionary] = []

func _init(state: GameState) -> void:
	_state_ref = weakref(state)
	state.clock.phase_changed.connect(_on_phase_changed)

func can_send(s: Survivor) -> String:
	var state: GameState = _state_ref.get_ref() as GameState
	if state == null:
		return "dead"
	if s == null or s.hp <= 0 or state.survivors.get_by_uid(s.uid) != s:
		return "dead"
	if s.refusing or s.day_off:
		return "suspended"
	if state.clock.phase != GameClock.Phase.DAY or state.clock.elapsed >= float(state.data.balance("day_length")) * float(state.data.expeditions().get("morning_fraction", 0.4)):
		return "not morning"
	if s.job == Survivor.Job.GUARD:
		return "guard"
	if s.away or _runs.has(s.uid):
		return "already away"
	var config: Dictionary = state.data.expeditions()
	var max_runs: int = int(config.get("max_runs", 1))
	for from_day: String in config.get("max_runs_from_day", {}):
		if state.clock.day >= int(from_day):
			max_runs = maxi(max_runs, int(config["max_runs_from_day"][from_day]))
	if int(_sent_today.get(state.clock.day, 0)) >= max_runs:
		return "run limit"
	if s.sheltered or s.shelter_uid != 0:
		return "sheltered"
	return ""

func send(uid: int) -> bool:
	var state: GameState = _state_ref.get_ref() as GameState
	if state == null:
		return false
	var s: Survivor = state.survivors.get_by_uid(uid)
	if can_send(s) != "":
		return false
	var edge_tile: Vector2i = Vector2i(-1, -1)
	var edge_path: Array[Vector2i] = []
	var best_length: int = 2147483647
	var size: int = state.map.size()
	var candidates: Array[Vector2i] = []
	for i: int in range(size):
		for tile: Vector2i in [Vector2i(i, 0), Vector2i(size - 1, i), Vector2i(i, size - 1), Vector2i(0, i)]:
			if state.map.is_passable(tile):
				candidates.append(tile)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da: int = maxi(absi(a.x - s.tile().x), absi(a.y - s.tile().y))
		var db: int = maxi(absi(b.x - s.tile().x), absi(b.y - s.tile().y))
		return da < db or (da == db and (a.y < b.y or (a.y == b.y and a.x < b.x)))
	)
	for tile: Vector2i in candidates:
		var lower_bound: int = maxi(absi(tile.x - s.tile().x), absi(tile.y - s.tile().y))
		if lower_bound >= best_length:
			break
		var path: Array[Vector2i] = state.pathfinder.find_path(s.tile(), tile)
		if s.tile() == tile or not path.is_empty():
			best_length = path.size()
			edge_tile = tile
			edge_path = path
	if edge_tile == Vector2i(-1, -1):
		return false
	s.path = edge_path
	s.target = edge_tile
	s.work_uid = 0
	s.work_tile = Vector2i(-1, -1)
	s.activity = Survivor.Activity.WALKING
	_runs[uid] = {"day": state.clock.day, "status": "outbound", "edge": edge_tile}
	_sent_today[state.clock.day] = int(_sent_today.get(state.clock.day, 0)) + 1
	run_started.emit(s)
	if edge_path.is_empty():
		s.away = true
		(_runs[uid] as Dictionary)["status"] = "away"
	return true

func active() -> Array:
	var state: GameState = _state_ref.get_ref() as GameState
	var result: Array = []
	if state == null:
		return result
	for uid: int in _runs:
		var s: Survivor = state.survivors.get_by_uid(uid)
		if s != null:
			result.append(s)
	return result

func is_running(s: Survivor) -> bool:
	return s != null and _runs.has(s.uid)

func tick(state: GameState, _dt: float) -> void:
	for uid: int in _runs.keys():
		if not _runs.has(uid):
			continue
		var s: Survivor = state.survivors.get_by_uid(uid)
		if s == null:
			_runs.erase(uid)
			continue
		var run: Dictionary = _runs[uid]
		if run["status"] == "outbound" and not s.is_moving() and s.tile() == run["edge"]:
			s.away = true
			s.activity = Survivor.Activity.IDLE
			run["status"] = "away"
		elif run["status"] == "home" and not s.is_moving():
			s.activity = Survivor.Activity.IDLE
			_runs.erase(uid)

func take_dawn_report() -> Array[Dictionary]:
	var report: Array[Dictionary] = _dawn_report.duplicate(true)
	_dawn_report.clear()
	return report

func _on_phase_changed(phase: int, _day: int) -> void:
	if phase != GameClock.Phase.NIGHT:
		return
	var state: GameState = _state_ref.get_ref() as GameState
	if state == null:
		return
	for uid: int in _runs.keys():
		var s: Survivor = state.survivors.get_by_uid(uid)
		if s == null:
			_runs.erase(uid)
			continue
		var run: Dictionary = _runs[uid]
		if run["status"] == "outbound":
			_send_home(state, s, run)
		elif run["status"] == "away":
			_return_run(state, s, run)

func _send_home(state: GameState, s: Survivor, run: Dictionary) -> void:
	s.away = false
	var home: Vector2i = _free_cc_tile(state)
	if home == Vector2i(-1, -1):
		home = state.map.command_center_origin() + Vector2i(-1, 0)
	var path: Array[Vector2i] = state.pathfinder.find_path(s.tile(), home)
	if s.tile() == home:
		path = []
	s.target = home
	s.path = path
	s.activity = Survivor.Activity.WALKING if not path.is_empty() else Survivor.Activity.IDLE
	run["status"] = "home"
	run["cancelled"] = true

func _return_run(state: GameState, s: Survivor, run: Dictionary) -> void:
	var result: Dictionary = _roll_result(state, s, int(run["day"]))
	var home: Vector2i = _free_cc_tile(state)
	if home != Vector2i(-1, -1):
		s.pos = Grid.tile_to_world(home)
	s.path.clear()
	s.target = s.tile()
	s.away = false
	if bool(result["lost"]):
		s.loss_reason = "lost on a scavenging run"
		Morale.on_survivor_lost(state, s)
		state.survivors.remove(s.uid)
		state.survivors_lost += 1
	else:
		if not bool(result["hurt"]): Morale.add_mood(state, s, "scavenged")
		var loot: Dictionary = result["loot"]
		for kind: String in loot:
			state.resources.add(kind, int(loot[kind]))
		if bool(result["hurt"]):
			s.hp = maxi(1, s.hp / 2)
		if bool(result["newcomer"]) and state.buildings.total_beds() > state.survivors.count():
			_add_newcomer(state)
	_dawn_report.append({"name": s.name, "loot": result["loot"], "hurt": result["hurt"], "lost": result["lost"]})
	_runs.erase(s.uid)
	run_returned.emit(s, result)

func _roll_result(state: GameState, s: Survivor, day: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([state.map_seed, day, s.uid])
	var config: Dictionary = state.data.expeditions()
	var scale: float = 1.0 + float(config.get("loot_per_day", 0.02)) * float(day - 1)
	var loot: Dictionary = {}
	var ranges: Dictionary = config.get("loot", {})
	for kind: String in ["wood", "scrap", "food", "ammo"]:
		var bounds: Array = ranges.get(kind, [0, 0])
		loot[kind] = roundi(float(rng.randi_range(int(bounds[0]), int(bounds[1]))) * scale)
	var hurt_chance: float = minf(float(config.get("hurt_max", 0.3)), float(config.get("hurt_base", 0.1)) + float(config.get("hurt_per_day", 0.01)) * float(day - 1))
	var lost_chance: float = minf(float(config.get("lost_max", 0.12)), float(config.get("lost_base", 0.02)) + float(config.get("lost_per_day", 0.005)) * float(day - 1))
	var lost: bool = rng.randf() < lost_chance
	var hurt: bool = rng.randf() < hurt_chance
	var newcomer: bool = not lost and rng.randf() < float(config.get("newcomer_chance", 0.15)) and state.buildings.total_beds() > state.survivors.count()
	return {"loot": loot, "hurt": hurt, "lost": lost, "newcomer": newcomer}

func _free_cc_tile(state: GameState) -> Vector2i:
	var occupied: Dictionary = {}
	for survivor: Survivor in state.survivors.all():
		if not survivor.away:
			occupied[survivor.tile()] = true
	for tile: Vector2i in state.cc_ring_tiles():
		if state.map.is_passable(tile) and not occupied.has(tile):
			return tile
	return Vector2i(-1, -1)

func _add_newcomer(state: GameState) -> void:
	var tile: Vector2i = _free_cc_tile(state)
	if tile == Vector2i(-1, -1):
		return
	var uid: int = state.survivors.next_uid()
	var s: Survivor = state.survivors.add(DawnRules.free_name(state, uid), DawnRules.variant_for_uid(state, uid), tile)
	Morale.on_arrived(state, s)
