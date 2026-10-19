class_name SaveGame extends RefCounted
## Pure-sim dawn snapshot: GameState <-> JSON-safe Dictionary. No nodes, no file I/O.

const VERSION := 1

static func capture(state: GameState, extra: Dictionary = {}) -> Dictionary:
	if state.game_over or (state.won and not state.endless):
		push_warning("SaveGame.capture: refuses after game over")
		return {}
	if state.zombies.count() > 0:
		push_warning("SaveGame.capture: refuses with zombies alive")
		return {}
	if state.clock.phase != GameClock.Phase.DAY:
		push_warning("SaveGame.capture: refuses at night")
		return {}
	var resources: Dictionary = {}
	for kind: String in ResourceStore.KINDS:
		resources[kind] = state.resources.get_amount(kind)
	var buildings: Array = []
	for b: Building in state.buildings.all():
		buildings.append({
			"uid": b.uid,
			"type_id": b.type_id,
			"origin": [b.origin.x, b.origin.y],
			"hp": b.hp,
			"complete": b.complete,
			"progress": b.progress,
			"upgraded_from": b.upgraded_from,
		})
	var people: Array[Survivor] = state.survivors.all()
	people.sort_custom(func(a: Survivor, b: Survivor) -> bool: return a.uid < b.uid)
	var survivors: Array = []
	for s: Survivor in people:
		var t: Vector2i = s.tile()
		survivors.append({
			"uid": s.uid,
			"name": s.name,
			"variant": s.variant,
			"hp": s.hp,
			"max_hp": s.max_hp,
			"job": Survivor.job_label(s.job).to_lower(),
			"gather_kind": s.gather_kind,
			"hungry_days": s.hungry_days,
			"tile": [t.x, t.y],
			"moods": s.moods.duplicate(true),
			"breaking_days": s.breaking_days,
			"refusing": s.refusing,
		})
	var save: Dictionary = {
		"version": VERSION,
		"map_seed": state.map_seed,
		"difficulty": state.difficulty,
		"day": state.clock.day,
		"endless": state.endless,
		"won": state.won,
		"resources": resources,
		"buildings": buildings,
		"buildings_next_uid": state.buildings.next_uid(),
		"survivors": survivors,
		"survivors_next_uid": state.survivors.next_uid(),
		"morale": {"last_feast_day": state.last_feast_day},
		"tech": state.tech.capture(),
		"nodes": state.map.export_nodes(),
		"stats": {
			"zombies_killed": state.zombies_killed,
			"survivors_lost": state.survivors_lost,
			"buildings_lost": state.buildings_lost,
			"buildings_built": state.buildings_built,
			"survivors_left": state.survivors_left,
			"time_played": state.time_played,
		},
		# JSON numbers are IEEE-754 doubles; store 64-bit RNG state as decimal text
		# so a round trip cannot change the next deterministic random value.
		"rng_state": str(state.rng.state),
		"extra": extra.duplicate(true),
	}
	return save

static func restore(data: GameData, save: Dictionary) -> GameState:
	if save.is_empty() or int(save.get("version", -1)) != VERSION:
		push_warning("SaveGame.restore: wrong or missing version")
		return null
	if not _validate(data, save):
		push_warning("SaveGame.restore: malformed save data")
		return null
	var map_seed: int = int(save["map_seed"])
	var saved_difficulty: String = str(save.get("difficulty", "normal"))
	var state := GameState.new(data, map_seed, saved_difficulty)
	state.tech.restore(save.get("tech", {}))
	for s: Survivor in state.survivors.all().duplicate():
		state.survivors.remove(s.uid)
	for b: Building in state.buildings.all().duplicate():
		state.buildings.remove(b.uid)
	state.map.import_nodes(save["nodes"] as Array)
	for e in (save["buildings"] as Array):
		var entry: Dictionary = e
		var type_id: String = str(entry["type_id"])
		var b_data: Dictionary = data.get_building(type_id)
		var origin_arr: Array = entry["origin"]
		var origin := Vector2i(int(origin_arr[0]), int(origin_arr[1]))
		var b := Building.new()
		b.uid = int(entry["uid"])
		b.type_id = type_id
		b.origin = origin
		var sz: Array = b_data.get("size", [1, 1])
		b.size = Vector2i(int(sz[0]), int(sz[1]))
		b.max_hp = int(b_data.get("hp", 100))
		b.hp = int(entry["hp"])
		b.complete = bool(entry["complete"])
		b.build_time = float(b_data.get("build_time", 0.0))
		b.progress = float(entry["progress"])
		b.upgraded_from = str(entry.get("upgraded_from", ""))
		state.buildings.restore(b)
	state.buildings.set_next_uid(int(save["buildings_next_uid"]))
	for e in (save["survivors"] as Array):
		var entry: Dictionary = e
		var tile_arr: Array = entry["tile"]
		var wanted := Vector2i(int(tile_arr[0]), int(tile_arr[1]))
		var spot: Vector2i = _nearest_passable(state, wanted)
		var s := Survivor.new()
		s.uid = int(entry["uid"])
		s.name = str(entry["name"])
		s.variant = str(entry["variant"])
		s.max_hp = int(entry["max_hp"])
		s.hp = int(entry["hp"])
		s.job = Survivor.job_from_name(str(entry["job"]))
		s.gather_kind = str(entry.get("gather_kind", "wood"))
		s.hungry_days = int(entry.get("hungry_days", 0))
		s.moods = [] as Array[Dictionary]
		var definitions: Dictionary = data.morale_config().get("moods", {})
		for raw_mood: Dictionary in entry.get("moods", []):
			var id: String = str(raw_mood.get("id", ""))
			if not definitions.has(id):
				push_warning("SaveGame.restore: unknown mood '%s' dropped" % id)
				continue
			s.moods.append({"id":id,"label":str(raw_mood.label),"value":int(raw_mood.value),"days":int(raw_mood.days)})
			var cap: int = int(definitions[id].stack)
			var matching: Array[int] = []
			for i: int in range(s.moods.size()):
				if str(s.moods[i].id) == id: matching.append(i)
			if matching.size() > cap: s.moods.remove_at(matching[0])
		s.breaking_days = int(entry.get("breaking_days", 0))
		s.refusing = bool(entry.get("refusing", false))
		s.day_off = false
		s.had_day_off = false
		s.pos = Grid.tile_to_world(spot)
		s.path = [] as Array[Vector2i]
		s.target = spot
		s.sheltered = false
		s.shelter_uid = 0
		s.shelter_building = null
		s.on_tower = false
		s.post_uid = 0
		s.work_uid = 0
		s.work_acc = 0.0
		s.job_timer = 0.0
		s.carry_kind = ""
		s.carry_amount = 0
		s.work_tile = Vector2i(-1, -1)
		s.activity = Survivor.Activity.IDLE
		state.survivors.restore(s)
	state.survivors.set_next_uid(int(save["survivors_next_uid"]))
	var res: Dictionary = save["resources"]
	for kind: String in ResourceStore.KINDS:
		var current: int = state.resources.get_amount(kind)
		var target: int = int(res.get(kind, current))
		if target > current:
			state.resources.add(kind, target - current)
		elif target < current:
			state.resources.take(kind, current - target)
	state.clock.day = int(save["day"])
	state.last_feast_day = int((save.get("morale", {}) as Dictionary).get("last_feast_day", 0))
	state.endless = bool(save.get("endless", false))
	state.won = bool(save.get("won", false))
	state.clock.phase = GameClock.Phase.DAY
	state.clock.elapsed = 0.0
	state.clock.paused = false
	var stats: Dictionary = save["stats"]
	state.zombies_killed = int(stats["zombies_killed"])
	state.survivors_lost = int(stats["survivors_lost"])
	state.buildings_lost = int(stats["buildings_lost"])
	state.buildings_built = int(stats["buildings_built"])
	state.survivors_left = int(stats["survivors_left"])
	state.time_played = float(stats["time_played"])
	state.rng.state = String(save["rng_state"]).to_int()
	for restored: Survivor in state.survivors.all(): Morale.recompute(state, restored)
	state.flow.rebuild()
	return state

static func to_json(save: Dictionary) -> String:
	return JSON.stringify(save)

static func from_json(text: String) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return {}
	if typeof(parser.data) != TYPE_DICTIONARY:
		return {}
	return parser.data as Dictionary

static func _nearest_passable(state: GameState, wanted: Vector2i) -> Vector2i:
	if Grid.in_bounds(wanted, state.map.size()):
		var solid: bool = not state.map.is_passable(wanted)
		if state.map.building_at(wanted) == "gate":
			solid = false
		if not solid:
			return wanted
	var queue: Array[Vector2i] = [wanted]
	var visited: Dictionary = {wanted: true}
	while not queue.is_empty():
		var curr: Vector2i = queue.pop_front()
		if Grid.in_bounds(curr, state.map.size()):
			var curr_solid: bool = not state.map.is_passable(curr)
			if state.map.building_at(curr) == "gate":
				curr_solid = false
			if not curr_solid:
				return curr
		for d in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
			var n: Vector2i = curr + d
			if not visited.has(n):
				visited[n] = true
				queue.append(n)
	return wanted

static func _is_number(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT

static func _is_integer(v: Variant) -> bool:
	return _is_number(v) and is_finite(float(v)) and floorf(float(v)) == float(v)

static func _validate(data: GameData, save: Dictionary) -> bool:
	if not _is_number(save.get("map_seed", null)):
		return false
	if not _is_number(save.get("day", null)):
		return false
	if int(save["day"]) < 1:
		return false
	if typeof(save.get("resources", null)) != TYPE_DICTIONARY:
		return false
	var res: Dictionary = save["resources"]
	for kind: String in ResourceStore.KINDS:
		if not _is_number(res.get(kind, null)):
			return false
	if typeof(save.get("buildings", null)) != TYPE_ARRAY:
		return false
	if not _is_number(save.get("buildings_next_uid", null)):
		return false
	if typeof(save.get("survivors", null)) != TYPE_ARRAY:
		return false
	if not _is_number(save.get("survivors_next_uid", null)):
		return false
	if typeof(save.get("nodes", null)) != TYPE_ARRAY:
		return false
	if typeof(save.get("stats", null)) != TYPE_DICTIONARY:
		return false
	var stats: Dictionary = save["stats"]
	for key: String in ["zombies_killed", "survivors_lost", "buildings_lost", "buildings_built", "survivors_left", "time_played"]:
		if not _is_number(stats.get(key, null)):
			return false
	var rng_state: Variant = save.get("rng_state", null)
	if typeof(rng_state) != TYPE_STRING or not (rng_state as String).is_valid_int():
		return false
	if typeof(save.get("extra", {})) != TYPE_DICTIONARY:
		return false
	if save.has("morale"):
		if typeof(save.morale) != TYPE_DICTIONARY: return false
		if save.morale.has("last_feast_day") and (not _is_integer(save.morale.last_feast_day) or int(save.morale.last_feast_day) < 0 or int(save.morale.last_feast_day) > int(save.day)): return false
	if save.has("tech"):
		if typeof(save.tech) != TYPE_DICTIONARY: return false
		var tech: Dictionary = save.tech
		if tech.has("done"):
			if typeof(tech.done) != TYPE_ARRAY: return false
			for id: Variant in tech.done:
				if typeof(id) != TYPE_STRING: return false
		if tech.has("active") and typeof(tech.active) != TYPE_STRING: return false
		if tech.has("progress"):
			if typeof(tech.progress) != TYPE_DICTIONARY: return false
			for id: Variant in tech.progress:
				var value: Variant = tech.progress[id]
				if typeof(id) != TYPE_STRING or not _is_number(value) or not is_finite(float(value)) or float(value) < 0.0: return false
		if tech.has("banked") and (not _is_number(tech.banked) or not is_finite(float(tech.banked)) or float(tech.banked) < 0.0): return false
	for e in (save["buildings"] as Array):
		if typeof(e) != TYPE_DICTIONARY:
			return false
		var entry: Dictionary = e
		for key: String in ["uid", "type_id", "origin", "hp", "complete", "progress"]:
			if not entry.has(key):
				return false
		if not _is_number(entry["uid"]) or typeof(entry["type_id"]) != TYPE_STRING:
			return false
		if not data.building_ids().has(str(entry["type_id"])):
			return false
		if typeof(entry["origin"]) != TYPE_ARRAY or (entry["origin"] as Array).size() != 2:
			return false
		if not _is_number((entry["origin"] as Array)[0]) or not _is_number((entry["origin"] as Array)[1]):
			return false
		if not _is_number(entry["hp"]) or not _is_number(entry["progress"]):
			return false
		if typeof(entry["complete"]) != TYPE_BOOL:
			return false
	for e in (save["survivors"] as Array):
		if typeof(e) != TYPE_DICTIONARY:
			return false
		var entry: Dictionary = e
		for key: String in ["uid", "name", "variant", "hp", "max_hp", "job", "tile"]:
			if not entry.has(key):
				return false
		if not _is_number(entry["uid"]) or not _is_number(entry["hp"]) or not _is_number(entry["max_hp"]):
			return false
		if typeof(entry["name"]) != TYPE_STRING or typeof(entry["variant"]) != TYPE_STRING:
			return false
		if typeof(entry["job"]) != TYPE_STRING:
			return false
		if typeof(entry["tile"]) != TYPE_ARRAY or (entry["tile"] as Array).size() != 2:
			return false
		if not _is_number((entry["tile"] as Array)[0]) or not _is_number((entry["tile"] as Array)[1]):
			return false
		if entry.has("moods"):
			if typeof(entry.moods) != TYPE_ARRAY: return false
			for mood: Variant in entry.moods:
				if typeof(mood) != TYPE_DICTIONARY: return false
				for key: String in ["id", "label", "value", "days"]:
					if not mood.has(key): return false
				if typeof(mood.id) != TYPE_STRING or typeof(mood.label) != TYPE_STRING: return false
				if not _is_integer(mood.value) or int(mood.value) < -100 or int(mood.value) > 100: return false
				if not _is_integer(mood.days) or int(mood.days) < 1: return false
		if entry.has("breaking_days") and (not _is_integer(entry.breaking_days) or int(entry.breaking_days) < 0): return false
		if entry.has("refusing") and typeof(entry.refusing) != TYPE_BOOL: return false
	for e in (save["nodes"] as Array):
		if typeof(e) != TYPE_DICTIONARY:
			return false
		var entry: Dictionary = e
		if typeof(entry.get("tile", null)) != TYPE_ARRAY or (entry["tile"] as Array).size() != 2:
			return false
		if not _is_number((entry["tile"] as Array)[0]) or not _is_number((entry["tile"] as Array)[1]):
			return false
		if not _is_number(entry.get("occupant", null)) or not _is_number(entry.get("amount", null)):
			return false
	return true
