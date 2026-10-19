class_name DawnRules extends RefCounted
## The clock calls this once at each dawn, after incrementing its day.

static func process(state: GameState) -> Dictionary:
	var food_eaten: int = _eat(state)
	var left: Array[String] = _leave(state)
	var hungry: Array[String] = []
	for s: Survivor in state.survivors.all():
		if s.is_hungry():
			hungry.append(s.name)
	var arrived: Array[String] = _newcomers(state)
	return {"day": state.clock.day, "food_eaten": food_eaten,
		"hungry": hungry, "left": left, "arrived": arrived}

static func _eat(state: GameState) -> int:
	var need: int = roundi(float(state.data.balance("food_eat_per_survivor")) * float(state.difficulty_multipliers.get("food_eaten_mult", 1.0)))
	var eaten: int = 0
	var survivors: Array[Survivor] = state.survivors.all()
	survivors.sort_custom(func(a: Survivor, b: Survivor) -> bool:
		if a.hungry_days != b.hungry_days:
			return a.hungry_days > b.hungry_days
		return a.uid < b.uid)
	for s: Survivor in survivors:
		if state.resources.get_amount("food") >= need:
			state.resources.take("food", need)
			eaten += need
			s.hungry_days = 0
		else:
			s.hungry_days += 1
	return eaten

static func _leave(state: GameState) -> Array[String]:
	var left: Array[String] = []
	var leave_days: int = int(state.data.balance("food_hungry_leave_days"))
	for s: Survivor in state.survivors.all():
		if s.hungry_days >= leave_days:
			left.append(s.name)
			state.survivors.remove(s.uid)
			state.survivors_left += 1
	return left

static func _newcomers(state: GameState) -> Array[String]:
	var arrived: Array[String] = []
	var pop: int = state.survivors.count()
	var beds: int = state.buildings.total_beds()
	var threshold: int = int(state.data.balance("food_newcomers_threshold"))
	if pop == 0 or beds <= pop or state.resources.get_amount("food") < threshold * pop:
		return arrived
	var ring: Array[Vector2i] = state.cc_ring_tiles()
	if ring.is_empty():
		return arrived
	var n: int = mini(beds - pop, state.rng.randi_range(
		int(state.data.balance("food_newcomers_min")), int(state.data.balance("food_newcomers_max"))))
	for i: int in range(n):
		var occupied: Dictionary = {}
		for living: Survivor in state.survivors.all():
			occupied[living.tile()] = true
		var tile: Vector2i = ring[0]
		for candidate: Vector2i in ring:
			if not occupied.has(candidate):
				tile = candidate
				break
		# Configure through the store so addition signals see the final name/variant.
		var uid: int = state.survivors.next_uid()
		var s: Survivor = state.survivors.add(free_name(state, uid), variant_for_uid(state, uid), tile)
		Morale.on_arrived(state, s)
		arrived.append(s.name)
	return arrived

static func free_name(state: GameState, uid: int) -> String:
	var used: Dictionary = {}
	for s: Survivor in state.survivors.all():
		used[s.name] = true
	var names: Array = state.data.balance("survivor_names")
	for candidate: String in names:
		if not used.has(candidate):
			return candidate
	return "Survivor %d" % uid

static func variant_for_uid(state: GameState, uid: int) -> String:
	var variants: Array = state.data.balance("survivor_variants", ["blue"])
	return str(variants[(uid - 1) % variants.size()]) if not variants.is_empty() else "blue"
