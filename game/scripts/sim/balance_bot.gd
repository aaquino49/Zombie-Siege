class_name BalanceBot extends RefCounted
## Scripted public-command player; measurements never influence decisions.

const VERSION: String = "4.0"
const COLUMNS: Array[String] = ["seed", "strategy", "night", "cc_hp_pct", "survivors",
	"beds", "food", "wood", "scrap", "ammo", "kills", "lost", "buildings_destroyed",
	"buildings", "radio_tower", "end", "dusk_ammo", "dusk_wood", "dusk_scrap",
	"guards", "turrets", "cc_min_hp_pct", "scav_sent", "scav_hurt", "scav_lost",
	"morale_mean", "morale_min", "morale_refusing", "morale_left", "research_done",
	"research_active", "research_progress", "research_banked", "researchers", "cc_damage", "day_researchers"]

static func run(map_seed: int, strategy: String, nights: int, step: float = 0.25,
		on_dawn: Callable = Callable(), difficulty: String = "normal") -> Dictionary:
	assert(strategy in ["none", "sensible", "scavenger"])
	assert(nights >= 0 and step > 0.0)
	var started: int = Time.get_ticks_msec()
	var state := GameState.new(GameData.load_default(), map_seed, difficulty)
	state.waves.enabled = true
	var rows: Array[Dictionary] = []
	var memo: Dictionary = {}
	var scavenging: Dictionary = {"runs": 0, "sent": 0, "sent_by_day": {}, "hurt": 0, "lost": 0,
		"loot": {"wood": 0, "scrap": 0, "food": 0, "ammo": 0}}
	# Mutable locals let the dawn closure read the latest measurements.
	var night: Dictionary = {"dusk_ammo": 0, "dusk_wood": 0, "dusk_scrap": 0,
		"guards": 0, "turrets": 0, "cc_min_hp_pct": _cc_pct(state), "day_researchers": 0}
	var min_cc_hp_pct: float = _cc_pct(state)
	# A weak reference avoids a state -> signal -> state ownership cycle.
	var state_ref: WeakRef = weakref(state)
	state.dawn_processed.connect(func(report: Dictionary) -> void:
		var current: GameState = state_ref.get_ref() as GameState
		night["cc_min_hp_pct"] = minf(float(night["cc_min_hp_pct"]), _cc_pct(current))
		rows.append(_row(current, strategy, report, night, "dawn"))
		night["day_researchers"] = 0
		for run: Dictionary in report.get("scavenging", []):
			scavenging["runs"] = int(scavenging["runs"]) + 1
			if bool(run.get("hurt", false)):
				scavenging["hurt"] = int(scavenging["hurt"]) + 1
			if bool(run.get("lost", false)):
				scavenging["lost"] = int(scavenging["lost"]) + 1
			var loot: Dictionary = run.get("loot", {})
			for kind: String in scavenging["loot"]:
				(scavenging["loot"] as Dictionary)[kind] = int((scavenging["loot"] as Dictionary)[kind]) + int(loot.get(kind, 0))
		if on_dawn.is_valid():
			on_dawn.call(current, memo))
	var cap: int = ceili((nights + 1) * (float(state.data.balance("day_length")) + 400.0) / step)
	var decide_acc: float = 5.0
	for tick_index: int in range(cap):
		if state.game_over or state.clock.day > nights:
			break
		if strategy != "none" and state.clock.phase == GameClock.Phase.DAY and decide_acc >= 5.0:
			decide_acc = fmod(decide_acc, 5.0)
			if strategy in ["sensible", "scavenger"]:
				_decide(state, memo)
			if strategy == "scavenger":
				if _send_scavenger(state):
					scavenging["sent"] = int(scavenging["sent"]) + 1
					var sent_by_day: Dictionary = scavenging["sent_by_day"]
					sent_by_day[state.clock.day] = int(sent_by_day.get(state.clock.day, 0)) + 1
		_sample_day_researchers(state, night)
		var before: float = state.time_played
		var phase_before: int = state.clock.phase
		state.tick(step)
		var cc_pct: float = _cc_pct(state)
		min_cc_hp_pct = minf(min_cc_hp_pct, cc_pct)
		if phase_before == GameClock.Phase.DAY and state.clock.phase == GameClock.Phase.NIGHT:
			for kind: String in ["ammo", "wood", "scrap"]:
				night["dusk_" + kind] = state.resources.get_amount(kind)
			night["guards"] = 0
			for person: Survivor in state.survivors.all():
				if person.job == Survivor.Job.GUARD and BalanceBotM12.useful(state, person):
					night["guards"] += 1
			night["turrets"] = _complete_count(state, "turret")
			night["cc_min_hp_pct"] = cc_pct
		elif phase_before == GameClock.Phase.NIGHT:
			night["cc_min_hp_pct"] = minf(float(night["cc_min_hp_pct"]), cc_pct)
		decide_acc += state.time_played - before
	var outcome: String = "survived"
	if state.won:
		outcome = "won"
	elif state.game_over:
		outcome = "lost_cc" if state.lose_reason == "command_center" else "lost_survivors"
		var report: Dictionary = state.night_log.summary(state)
		report["night"] = state.clock.day
		rows.append(_row(state, strategy, report, night, "loss"))
	return {"seed": map_seed, "strategy": strategy, "outcome": outcome,
		"nights_survived": state.clock.day - 1, "cc_hp_pct": _cc_pct(state),
		"rows": rows, "ms": Time.get_ticks_msec() - started, "sim_seconds": state.time_played,
		"scavenging": scavenging,
		"min_cc_hp_pct": min_cc_hp_pct,
		"capped": not state.game_over and state.clock.day <= nights}

static func _sample_day_researchers(state: GameState, night: Dictionary) -> void:
	# Sample before every tick, including the last DAY tick before sheltering.
	if state.clock.phase == GameClock.Phase.DAY:
		night["day_researchers"] = maxi(int(night["day_researchers"]), BalanceBotM12.working_researchers(state))

static func _cc_pct(state: GameState) -> float:
	var centers: Array[Building] = state.buildings.all_of_type("command_center")
	return 0.0 if centers.is_empty() else 100.0 * centers[0].hp / centers[0].max_hp

static func _row(state: GameState, strategy: String, report: Dictionary,
		night: Dictionary, end: String) -> Dictionary:
	var row: Dictionary = {"seed": state.map_seed, "strategy": strategy, "night": report["night"],
		"cc_hp_pct": _cc_pct(state), "survivors": state.survivors.count(),
		"beds": state.buildings.total_beds(), "food": state.resources.get_amount("food"),
		"wood": state.resources.get_amount("wood"), "scrap": state.resources.get_amount("scrap"),
		"ammo": state.resources.get_amount("ammo"), "kills": report["zombies_killed"],
		"lost": (report["survivors_killed"] as Array).size(),
		"buildings_destroyed": (report["buildings_destroyed"] as Array).size(),
		"buildings": state.buildings.all().size(), "radio_tower": int(state.radio_tower_complete()),
		"end": end, "dusk_ammo": night["dusk_ammo"], "dusk_wood": night["dusk_wood"],
		"dusk_scrap": night["dusk_scrap"], "guards": night["guards"], "turrets": night["turrets"],
		"cc_min_hp_pct": night["cc_min_hp_pct"],
		"scav_sent": _scav_count(report, "sent"), "scav_hurt": _scav_count(report, "hurt"),
		"scav_lost": _scav_count(report, "lost")}

	row.merge(BalanceBotM12.measurements(state, report, end))
	row["day_researchers"] = night["day_researchers"]
	return row

static func _scav_count(report: Dictionary, key: String) -> int:
	var count: int = 0
	for run: Dictionary in report.get("scavenging", []):
		if key == "sent" or bool(run.get(key, false)):
			count += 1
	return count

static func _send_scavenger(state: GameState) -> bool:
	var people: Array[Survivor] = BalanceBotM12.roster(state)
	var candidates: Array[Survivor] = []
	for person: Survivor in people:
		if state.expeditions.can_send(person) == "" and person.job != Survivor.Job.RESEARCHER and not BalanceBotM12.protected_worker(state, person, people):
			candidates.append(person)
	candidates.sort_custom(func(a: Survivor, b: Survivor) -> bool:
		if (a.job == Survivor.Job.GATHERER) != (b.job == Survivor.Job.GATHERER): return a.job == Survivor.Job.GATHERER
		if (a.job == Survivor.Job.FARMER) != (b.job == Survivor.Job.FARMER): return a.job == Survivor.Job.FARMER
		if a.job == Survivor.Job.GATHERER and a.hp != b.hp: return a.hp > b.hp
		return a.uid < b.uid)
	for person: Survivor in candidates:
		if state.expeditions.send(person.uid): return true
	return false

static func to_csv(rows: Array) -> String:
	var lines: PackedStringArray = [",".join(COLUMNS)]
	for row: Dictionary in rows:
		var values: PackedStringArray = []
		for column: String in COLUMNS:
			values.append("%.2f" % float(row[column]) if column in ["morale_mean", "research_progress", "research_banked"] else str(row[column]))
		lines.append(",".join(values))
	return "\n".join(lines) + "\n"

static func _plan_ring(state: GameState, memo: Dictionary) -> void:
	var origin: Vector2i = state.map.command_center_origin()
	var ring: Array[Vector2i] = []
	for radius: int in range(6, 10):
		var candidate: Array[Vector2i] = []
		var valid: bool = true
		for y: int in range(origin.y - radius, origin.y + 2 + radius):
			for x: int in range(origin.x - radius, origin.x + 2 + radius):
				if x in [origin.x - radius, origin.x + 1 + radius] or y in [origin.y - radius, origin.y + 1 + radius]:
					var tile := Vector2i(x, y)
					candidate.append(tile)
					if Placement.check(state, "wooden_wall", tile) not in [Placement.Result.OK, Placement.Result.UNAFFORDABLE, Placement.Result.BLOCKED]:
						valid = false
		if valid:
			ring = candidate
			break
	memo["ring"] = ring
	memo["gate"] = Vector2i(origin.x, ring[0].y) if not ring.is_empty() else Vector2i(-1, -1)
	memo["placed"] = {}
	# Precompute a stable scan by distance from the CC footprint, then y/x.
	var interior: Array[Vector2i] = []
	if not ring.is_empty():
		for y: int in range(ring[0].y + 1, ring[-1].y):
			for x: int in range(ring[0].x + 1, ring[-1].x):
				interior.append(Vector2i(x, y))
	interior.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da: int = maxi(maxi(origin.x - a.x, a.x - origin.x - 1), maxi(origin.y - a.y, a.y - origin.y - 1))
		var db: int = maxi(maxi(origin.x - b.x, b.x - origin.x - 1), maxi(origin.y - b.y, b.y - origin.y - 1))
		return da < db if da != db else (a.y < b.y or (a.y == b.y and a.x < b.x)))
	memo["interior"] = interior

static func _place_inside(state: GameState, memo: Dictionary, type_id: String) -> int:
	var size_data: Array = state.data.get_building(type_id).get("size", [1, 1])
	var size := Vector2i(int(size_data[0]), int(size_data[1]))
	var cc_ring: Array[Vector2i] = state.cc_ring_tiles()
	var fog_limited_defense: bool = _fog_forecast(state) and type_id in ["turret", "watchtower"]
	for origin: Vector2i in memo["interior"]:
		var allowed: bool = true
		for tile: Vector2i in Grid.rect_tiles(origin, size):
			if not memo["interior"].has(tile) or cc_ring.has(tile):
				allowed = false
		if allowed:
			if fog_limited_defense and not _within_fog_approach_range(state, type_id, origin):
				continue
			var check: int = Placement.check(state, type_id, origin)
			if check == Placement.Result.UNAFFORDABLE:
				return check
			if check == Placement.Result.OK:
				return state.try_place(type_id, origin)
	return Placement.Result.BLOCKED

static func job_plan(day: int, survivors: int, ammo: int, food: int,
		complete_farms: int, workshop_complete: bool, open_blueprints: int,
		wood: int = 100, watchtower_posts: int = 0, scrap: int = 0,
		scrap_reserve: int = 100, fog_forecast: bool = false) -> Dictionary:
	var day_cap: int = 1 if day < 4 else (2 if day < 8 else (3 if day < 12 else 999))
	var target_guards: int = clampi(ceili(survivors / 4.0), 1, day_cap)
	var guard_cap: int = maxi(1, watchtower_posts + 1)
	target_guards = mini(target_guards, guard_cap)
	var guards: int = mini(target_guards, maxi(0, survivors - 2))
	if fog_forecast:
		guards = mini(guards + 1, maxi(0, survivors - 2))
	var remaining: int = survivors - guards
	var builders: int = mini(2 if open_blueprints >= 2 and survivors >= 7 and day >= 8 else 1, remaining)
	remaining -= builders
	var target_ammo: int = 40 + 20 * day + (60 * (day - 16) if day >= 17 else 0)
	var crafting_limit: int = target_ammo * 2
	var crafters: int = mini(1 if workshop_complete and ammo < crafting_limit and (ammo < target_ammo or scrap > scrap_reserve) else 0, remaining)
	remaining -= crafters
	var farmers: int = 0
	if complete_farms > 0 and food < 4 * survivors:
		farmers = mini(mini(ceili(survivors / 3.0), 2 * complete_farms), remaining)
	var gatherers: int = remaining - farmers
	if wood < 20 and survivors > 0 and gatherers == 0:
		gatherers = 1
		if farmers > 0:
			farmers -= 1
		elif crafters > 0:
			crafters -= 1
		elif builders > 0:
			builders -= 1
	return {"guards": guards, "builders": builders, "crafters": crafters,
		"farmers": farmers, "gatherers": gatherers}

static func _complete_count(state: GameState, type_id: String) -> int:
	var count: int = 0
	for building: Building in state.buildings.all_of_type(type_id):
		if building.complete:
			count += 1
	return count

static func _jobs(state: GameState) -> void:
	BalanceBotM12.jobs(state)

static func _decide(state: GameState, memo: Dictionary) -> void:
	if not memo.has("ring"):
		_plan_ring(state, memo)
	BalanceBotM12.morale_commands(state, memo)
	BalanceBotM12.choose_research(state)
	_jobs(state)
	if state.radio_tower_complete():
		memo["radio_tower_ever_complete"] = true
	var complete_farms: int = _complete_count(state, "farm")
	var previous_farm_count: int = int(memo.get("max_complete_farms", complete_farms))
	memo["max_complete_farms"] = maxi(previous_farm_count, complete_farms)
	var has_farm_blueprint: bool = false
	for b: Building in state.buildings.blueprints():
		if b.type_id == "farm":
			has_farm_blueprint = true
			break
	var farm_rebuild_needed: bool = (complete_farms < previous_farm_count) or (complete_farms == 0 and state.clock.day > 2)
	if farm_rebuild_needed and not has_farm_blueprint:
		if state.buildings.blueprints().size() >= 2:
			_cancel_unstarted_lower_priority(state)
		if state.buildings.blueprints().size() >= 2:
			return
		var rebuild_result: int = _place_inside(state, memo, "farm")
		if rebuild_result == Placement.Result.OK:
			return
		if rebuild_result == Placement.Result.UNAFFORDABLE:
			return
	var radio_unlock: int = int(state.data.get_building("radio_tower").get("unlock_day", 8))
	var radio_lost: bool = bool(memo.get("radio_tower_ever_complete", false)) and state.buildings.count_of("radio_tower") == 0
	if radio_lost:
		if state.buildings.blueprints().size() >= 2:
			_cancel_unstarted_ring_repair(state, memo)
		if state.buildings.blueprints().size() >= 2:
			_cancel_unstarted_lower_priority(state)
		if state.buildings.blueprints().size() >= 2:
			return
		var radio_result: int = _place_inside(state, memo, "radio_tower")
		if radio_result == Placement.Result.OK or radio_result == Placement.Result.UNAFFORDABLE:
			return
	while state.buildings.blueprints().size() < 2:
		complete_farms = _complete_count(state, "farm")
		var food_per_farmer: int = int(state.data.get_building("farm").get("food_per_farmer", 8))
		var survivors_count: int = state.survivors.count()
		var farm_blueprints: int = 0
		for b: Building in state.buildings.blueprints():
			if b.type_id == "farm":
				farm_blueprints += 1
		var farmers_count: int = 0
		for person: Survivor in state.survivors.all():
			if person.job == Survivor.Job.FARMER and BalanceBotM12.useful(state, person):
				farmers_count += 1
		var planned_farms: int = complete_farms + farm_blueprints
		var projected_food: int = planned_farms * 2 * food_per_farmer - survivors_count
		var completed_farms_staffed: bool = farmers_count >= complete_farms * 2
		var second_farm_needed: bool = planned_farms > 0 and projected_food < 0 and (completed_farms_staffed or farm_blueprints > 0)
		if second_farm_needed:
			if state.buildings.blueprints().size() >= 2:
				_cancel_unstarted_lower_priority(state)
			if state.buildings.blueprints().size() >= 2:
				return
			var res: int = _place_inside(state, memo, "farm")
			if res == Placement.Result.UNAFFORDABLE:
				return
			if res == Placement.Result.OK:
				continue
		var replaced: bool = false
		# Only tiles previously built are replacements; terrain blockers are skipped.
		for tile: Vector2i in memo["ring"]:
			if memo["placed"].has(tile) and state.buildings.get_at(tile) == null:
				var type_id: String = "gate" if tile == memo["gate"] else "wooden_wall"
				if state.try_place(type_id, tile) == Placement.Result.OK:
					replaced = true
					break
				return
		if replaced:
			continue
		var tower_placed: bool = state.buildings.count_of("radio_tower") > 0
		var population: int = state.survivors.count()
		var food: int = state.resources.get_amount("food")
		var wanted: Array[String] = []
		if state.buildings.count_of("workshop") == 0:
			wanted.append("workshop")
		if state.buildings.count_of("watchtower") < (4 if state.clock.day >= 12 else (2 if state.clock.day >= 6 else 1)):
			wanted.append("watchtower")
		if (state.buildings.count_of("farm") == 0 and (state.clock.day >= 3 or food < 5 * population)) or (tower_placed and state.buildings.count_of("farm") < 2 and food < 3 * population):
			wanted.append("farm")
		if population >= state.buildings.total_beds() and state.buildings.blueprints().filter(func(b: Building) -> bool: return b.type_id == "shelter").is_empty():
			wanted.append("shelter")
		if state.buildings.count_of("lumber_yard") == 0:
			wanted.append("lumber_yard")
		if state.clock.day >= 4 and state.buildings.count_of("turret") < (8 if tower_placed else 4):
			wanted.append("turret")
		var placed: bool = false
		for type_id: String in wanted:
			if state.clock.day < int(state.data.get_building(type_id)["unlock_day"]):
				continue
			var result: int = _place_inside(state, memo, type_id)
			if result == Placement.Result.UNAFFORDABLE:
				return
			if result == Placement.Result.OK:
				placed = true
				break
		if placed:
			continue
		# Keep v3.2 farm, forecast defenses and perimeter repairs ahead of optional spending.
		if BalanceBotM12.optional_build(state, memo):
			return
		if state.clock.day >= maxi(8, radio_unlock) and state.buildings.count_of("radio_tower") == 0:
			if _place_inside(state, memo, "radio_tower") != Placement.Result.OK:
				return
			continue
		var wall_pending: bool = false
		for tile: Vector2i in memo["ring"]:
			if not memo["placed"].has(tile):
				var type_id: String = "gate" if tile == memo["gate"] else "wooden_wall"
				var check: int = Placement.check(state, type_id, tile)
				if check == Placement.Result.BLOCKED:
					continue
				wall_pending = true
				if state.try_place(type_id, tile) != Placement.Result.OK:
					return
				memo["placed"][tile] = true
				break
		if wall_pending:
			continue
		if tower_placed and state.resources.get_amount("wood") > 80 and state.clock.day >= int(state.data.get_building("reinforced_wall")["unlock_day"]):
			var upgraded: bool = false
			for tile: Vector2i in memo["ring"]:
				var wall: Building = state.buildings.get_at(tile)
				if wall != null and wall.type_id == "wooden_wall" and state.try_upgrade(wall.uid) == Placement.Result.OK:
					upgraded = true
					break
			if upgraded:
				continue
		return

static func _fog_forecast(state: GameState) -> bool:
	var forecast: Dictionary = WaveSpawner.forecast(state.data, state.clock.day,
		state.difficulty_multipliers, state.map_seed)
	return bool(forecast.get("fog", false))

static func _within_fog_approach_range(state: GameState, type_id: String, origin: Vector2i) -> bool:
	var stats: Dictionary = state.data.get_building(type_id)
	var range_tiles: float
	if type_id == "watchtower":
		range_tiles = float(state.data.balance("guard_range_tiles")) * float(stats.get("guard_range_mult", 1.0))
	else:
		range_tiles = float(stats.get("range_tiles", 0.0))
	var fog: Dictionary = state.data.weather_config().get("fog", {})
	range_tiles += float(fog.get("range_delta_tiles", 0.0))
	var range_px: float = maxf(float(Grid.TILE), range_tiles * Grid.TILE)
	var cc_origin: Vector2i = state.map.command_center_origin()
	var cc_min: Vector2 = Vector2(cc_origin * Grid.TILE)
	var cc_max: Vector2 = Vector2((cc_origin + Vector2i(2, 2)) * Grid.TILE)
	var building_size: Array = stats.get("size", [1, 1])
	var center: Vector2 = Vector2((origin * 2 + Vector2i(int(building_size[0]), int(building_size[1]))) * Grid.TILE / 2)
	var closest_approach: Vector2 = Vector2(clampf(center.x, cc_min.x, cc_max.x), clampf(center.y, cc_min.y, cc_max.y))
	return center.distance_to(closest_approach) <= range_px

static func _cancel_unstarted_lower_priority(state: GameState) -> bool:
	# Preserve work already underway; free only a lower-priority, untouched blueprint.
	for b: Building in state.buildings.blueprints():
		if b.progress <= 0.0 and b.type_id != "farm":
			return state.cancel_building(b.uid)
	return false

static func _cancel_unstarted_ring_repair(state: GameState, memo: Dictionary) -> bool:
	# A rebuilt Radio Tower outranks untouched perimeter replacements after farm recovery.
	for b: Building in state.buildings.blueprints():
		if b.progress <= 0.0 and b.type_id in ["wooden_wall", "gate"] and memo["placed"].has(b.origin):
			return state.cancel_building(b.uid)
	return false

static func _scrap_reserve(state: GameState) -> int:
	var candidates: Array[String] = []
	if state.clock.day >= int(state.data.get_building("radio_tower").get("unlock_day", 8)) and state.buildings.count_of("radio_tower") == 0:
		candidates.append("radio_tower")
	if state.buildings.count_of("turret") < (8 if state.buildings.count_of("radio_tower") > 0 else 4):
		candidates.append("turret")
	if state.buildings.count_of("watchtower") < (2 if state.clock.day >= 6 else 1):
		candidates.append("watchtower")
	if state.buildings.count_of("workshop") == 0:
		candidates.append("workshop")
	if candidates.is_empty():
		return 100
	var cost: Dictionary = state.data.get_building(candidates[0]).get("cost", {})
	return 100 + int(cost.get("scrap", 0))
