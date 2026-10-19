extends RefCounted
## Shared QA setup: real seed/map, legal scanned placements, no terrain edits.

static func idle(state: GameState) -> void:
	for s: Survivor in state.survivors.all():
		state.set_job(s.uid, Survivor.Job.IDLE)

static func defended(state: GameState) -> Dictionary:
	idle(state)
	var day: int = state.clock.day
	# Fixture grants permit day-4 equipment on night 1; ammo stays at start stock.
	state.clock.day = 4
	state.resources.add("wood", 1000)
	state.resources.add("scrap", 1000)
	var cc: Building = state.buildings.all_of_type("command_center")[0]
	var ring: Array[Vector2i] = []
	for radius: int in range(2, 6):
		var candidate: Array[Vector2i] = []
		var valid: bool = true
		for y: int in range(cc.origin.y - radius, cc.origin.y + 2 + radius):
			for x: int in range(cc.origin.x - radius, cc.origin.x + 2 + radius):
				if x in [cc.origin.x - radius, cc.origin.x + 1 + radius] or y in [cc.origin.y - radius, cc.origin.y + 1 + radius]:
					var tile: Vector2i = Vector2i(x, y)
					candidate.append(tile)
					if Placement.check(state, "wooden_wall", tile) != Placement.Result.OK:
						valid = false
		if valid:
			ring = candidate
			break
	if ring.is_empty():
		state.clock.day = day
		return {"ok": false}
	var gate: Vector2i = Vector2i(cc.origin.x, ring[0].y)
	for tile: Vector2i in ring:
		var type_id: String = "gate" if tile == gate else "wooden_wall"
		if Placement.check(state, type_id, tile) != Placement.Result.OK:
			state.clock.day = day
			return {"ok": false}
		var wall: Building = state.buildings.add(type_id, tile, false)
		state.buildings.finish(wall.uid)
	var equipment: Array[Building] = []
	for type_id: String in ["watchtower", "turret", "turret"]:
		var placed: Building = null
		for y: int in range(ring[0].y + 1, ring[-1].y):
			for x: int in range(ring[0].x + 1, ring[-1].x):
				var tile: Vector2i = Vector2i(x, y)
				var occupied_by_person: bool = false
				for s: Survivor in state.survivors.all():
					if s.tile() == tile:
						occupied_by_person = true
				if placed == null and not occupied_by_person and Placement.check(state, type_id, tile) == Placement.Result.OK:
					placed = state.buildings.add(type_id, tile, false)
					state.buildings.finish(placed.uid)
		if placed == null:
			state.clock.day = day
			return {"ok": false}
		equipment.append(placed)
	var people: Array[Survivor] = state.survivors.all()
	state.set_job(people[0].uid, Survivor.Job.GUARD)
	state.set_job(people[1].uid, Survivor.Job.GUARD)
	for i: int in range(100):
		state.tick(0.1)
	state.clock.day = day
	return {"ok": true, "ring": ring, "gate": gate, "equipment": equipment}

static func nightfall(state: GameState, night: int) -> void:
	state.waves.enabled = true
	state.clock.day = night
	state.clock.elapsed = float(state.data.balance("day_length")) - 0.05
	state.tick(0.1)

static func run_night(state: GameState, cap: int = 3000) -> Dictionary:
	var start: float = state.time_played
	for i: int in range(cap):
		state.tick(0.1)
		if state.clock.phase == GameClock.Phase.DAY or state.game_over:
			break
	var cc: Building = state.buildings.all_of_type("command_center")[0]
	return {"day": state.clock.day, "phase": state.clock.phase,
		"kills": state.zombies_killed, "ammo": state.resources.get_amount("ammo"),
		"cc_hp": cc.hp, "lost": state.game_over, "survivors_lost": state.survivors_lost,
		"seconds": snappedf(state.time_played - start, 0.1),
		"remaining": state.hostiles_remaining(), "buildings_lost": state.buildings_lost}
