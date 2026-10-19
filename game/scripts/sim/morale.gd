class_name Morale extends RefCounted
## Pure rules for survivor morale; state mutations are explicit at call sites.

static func config(state: GameState) -> Dictionary:
	return state.data.morale_config()

static func band(state: GameState, s: Survivor) -> Dictionary:
	var bands: Array = config(state).get("bands", [])
	for item: Dictionary in bands:
		if s.morale >= int(item["min"]):
			return item
	return bands.back() if not bands.is_empty() else {"id":"steady","work_mult":1.0,"hit_chance":1.0}

static func work_mult(state: GameState, s: Survivor) -> float:
	return float(band(state, s).get("work_mult", 1.0))

static func hit_chance(state: GameState, s: Survivor) -> float:
	return float(band(state, s).get("hit_chance", 1.0))

static func recompute(state: GameState, s: Survivor) -> void:
	var total: int = int(config(state).get("baseline", 50))
	for mood: Dictionary in s.moods:
		total += int(mood.get("value", 0))
	s.morale = clampi(total, 0, 100)

static func add_mood(state: GameState, s: Survivor, id: String, name: String = "", value_override: int = -2147483648) -> bool:
	if s == null or not state.data.morale_config().has("moods"):
		return false
	var definitions: Dictionary = config(state)["moods"]
	if not definitions.has(id):
		return false
	var def: Dictionary = definitions[id]
	var label: String = str(def["label"])
	if label.contains("{name}"):
		label = label.replace("{name}", name)
	var mood_value: int = int(def["value"]) if value_override == -2147483648 else value_override
	var next: Dictionary = {"id":id,"label":label,"value":mood_value,"days":int(def["days"])}
	var indices: Array[int] = []
	for i: int in range(s.moods.size()):
		if str(s.moods[i].get("id", "")) == id:
			indices.append(i)
	if id == "bed" and _has_mood(s, "no_bed"):
		_remove_id(s, "no_bed")
	if id == "no_bed" and _has_mood(s, "bed"):
		_remove_id(s, "bed")
	if id == "quiet_night" and _has_mood(s, "rough_night"):
		_remove_id(s, "rough_night")
	if id == "rough_night" and _has_mood(s, "quiet_night"):
		_remove_id(s, "quiet_night")
	indices.clear()
	for i: int in range(s.moods.size()):
		if str(s.moods[i].get("id", "")) == id:
			indices.append(i)
	var limit: int = int(def.get("stack", 1))
	if indices.size() >= limit:
		s.moods.remove_at(indices[0])
	s.moods.append(next)
	recompute(state, s)
	return true

static func add_mood_all(state: GameState, id: String, name: String = "", except_uid: int = 0) -> void:
	for s: Survivor in state.survivors.all():
		if s.uid != except_uid:
			add_mood(state, s, id, name)

static func on_new_game(state: GameState) -> void:
	for s: Survivor in state.survivors.all():
		add_mood(state, s, "fresh_start")

static func on_arrived(state: GameState, s: Survivor) -> void:
	if s == null:
		return
	add_mood_all(state, "newcomers", "", s.uid)
	add_mood(state, s, "new_home")

static func on_survivor_lost(state: GameState, s: Survivor) -> void:
	if s != null:
		add_mood_all(state, "death", s.name, s.uid)

static func begin_dawn(state: GameState) -> void:
	var residents: Array[int] = []
	var sheltered: Dictionary = {}
	var duty: Dictionary = {}
	for s: Survivor in state.survivors.all():
		residents.append(s.uid)
		sheltered[s.uid] = s.sheltered
		duty[s.uid] = s.job == Survivor.Job.GUARD and not s.refusing and not s.day_off
		if s.day_off:
			s.had_day_off = true
		for i: int in range(s.moods.size() - 1, -1, -1):
			s.moods[i]["days"] = int(s.moods[i].get("days", 1)) - 1
			if int(s.moods[i]["days"]) <= 0:
				s.moods.remove_at(i)
		s.refusing = false
		s.day_off = false
		recompute(state, s)
	state.morale_snapshot = {"residents": residents, "sheltered": sheltered, "duty": duty}

static func end_dawn(state: GameState, report: Dictionary) -> void:
	for name: String in report.get("left", []):
		add_mood_all(state, "left", name)
	var snapshot: Dictionary = state.morale_snapshot
	var residents: Array = snapshot.get("residents", [])
	var duty: Dictionary = snapshot.get("duty", {})
	var sheltered: Dictionary = snapshot.get("sheltered", {})
	var surviving: Array[Survivor] = []
	for uid: int in residents:
		var s: Survivor = state.survivors.get_by_uid(uid)
		if s != null:
			surviving.append(s)
	surviving.sort_custom(func(a: Survivor, b: Survivor) -> bool: return a.uid < b.uid)
	var sleepers: Array[Survivor] = []
	for s: Survivor in surviving:
		if not bool(duty.get(s.uid, false)):
			sleepers.append(s)
	var beds: int = state.buildings.total_beds()
	for i: int in range(sleepers.size()):
		add_mood(state, sleepers[i], "bed" if i < beds else "no_bed")
	for s: Survivor in surviving:
		if bool(sheltered.get(s.uid, false)): add_mood(state, s, "sheltered")
	for s: Survivor in state.survivors.all():
		if s.hungry_days > 0: add_mood(state, s, "hungry")
		if s.hp * 2 < s.max_hp: add_mood(state, s, "hurt")
	var slots: int = int(config(state).get("campfire_slots", 6))
	var fires: int = 0
	for building: Building in state.buildings.all_of_type("campfire"):
		if building.complete: fires += 1
	var campfire_capacity: int = fires * slots
	var sorted_people: Array[Survivor] = state.survivors.all()
	sorted_people.sort_custom(func(a: Survivor, b: Survivor) -> bool: return a.uid < b.uid)
	var given: int = 0
	for person: Survivor in sorted_people:
		if given >= campfire_capacity: break
		if not _has_mood(person, "campfire"):
			var campfire: Dictionary = config(state).get("moods", {}).get("campfire", {})
			var base_value: int = int(campfire.get("value", 6))
			add_mood(state, person, "campfire", "", roundi(base_value * state.tech.mult("campfire_morale")))
			given += 1
	var rough: bool = int(report.get("cc_damage", 0)) > 0 or not (report.get("buildings_destroyed", []) as Array).is_empty()
	var scavenger_lost := false
	for item: Dictionary in report.get("scavenging", []):
		if bool(item.get("lost", false)): scavenger_lost = true
	if rough:
		for s: Survivor in surviving: add_mood(state, s, "rough_night")
	elif (report.get("survivors_killed", []) as Array).is_empty() and not scavenger_lost:
		for s: Survivor in surviving: add_mood(state, s, "quiet_night")
	for s: Survivor in state.survivors.all():
		if s.had_day_off: add_mood(state, s, "day_off")
		var completed_night: int = state.clock.day - 1
		if state.endless and completed_night > 20 and completed_night % int(config(state).get("endless_milestone_every", 5)) == 0:
			add_mood(state, s, "still_standing")
		s.had_day_off = false
		recompute(state, s)
	_apply_breaking(state, report)
	refresh_report(state, report)

static func _apply_breaking(state: GameState, report: Dictionary) -> void:
	var candidates: Array[Survivor] = []
	for s: Survivor in state.survivors.all():
		if str(band(state, s).get("id", "")) == "breaking":
			s.breaking_days += 1
			if s.breaking_days >= int(config(state).breaking.leave_after_dawns): candidates.append(s)
			s.refusing = true
			if s.job == Survivor.Job.GUARD: GuardJob.leave_post(state, s)
			_suspend(s)
		else:
			s.breaking_days = 0
			s.refusing = false
	candidates.sort_custom(func(a: Survivor, b: Survivor) -> bool:
		return a.morale < b.morale or (a.morale == b.morale and a.uid < b.uid))
	var limit: int = int(config(state).breaking.max_leavers_per_dawn)
	var left_morale: Array[String] = []
	for i: int in range(mini(limit, candidates.size())):
		var leaver: Survivor = candidates[i]
		left_morale.append(leaver.name)
		state.survivors.remove(leaver.uid)
		state.survivors_left += 1
		add_mood_all(state, "left", leaver.name)
		leaver.refusing = false
	for name: String in left_morale:
		var old: Array = report.get("left", [])
		old.append(name)
		report["left"] = old
		report["left_morale"] = left_morale

static func refresh_report(state: GameState, report: Dictionary) -> void:
	var bands := {"inspired":0,"steady":0,"low":0,"breaking":0}
	var refusing: Array[String] = []
	for s: Survivor in state.survivors.all():
		var id: String = str(band(state, s).get("id", "steady"))
		bands[id] = int(bands.get(id, 0)) + 1
		if s.refusing: refusing.append(s.name)
	refusing.sort()
	report["morale"] = {"bands":bands,"refusing":refusing,"left_morale":report.get("left_morale", [])}

static func feast_block_reason(state: GameState) -> String:
	if state.game_over: return "Game over"
	if state.clock.phase != GameClock.Phase.DAY: return "Night"
	var cooldown: int = int(config(state).feast.cooldown_days)
	if state.last_feast_day > 0 and state.clock.day < state.last_feast_day + cooldown:
		return "Next feast: day %d" % (state.last_feast_day + cooldown)
	var cost: int = int(config(state).feast.food_per_survivor) * state.survivors.count()
	var missing: int = cost - state.resources.get_amount("food")
	if missing > 0: return "Need %d food" % missing
	return ""

static func hold_feast(state: GameState) -> bool:
	if feast_block_reason(state) != "": return false
	var cost: int = int(config(state).feast.food_per_survivor) * state.survivors.count()
	state.resources.take("food", cost)
	state.last_feast_day = state.clock.day
	add_mood_all(state, "feast")
	return true

static func day_off_block_reason(state: GameState, s: Survivor) -> String:
	if state.game_over: return "Game over"
	if s == null or state.survivors.get_by_uid(s.uid) != s: return "Missing survivor"
	if state.clock.phase != GameClock.Phase.DAY or state.clock.elapsed >= float(state.data.balance("day_length")) * float(config(state).day_off_morning_fraction): return "Not morning"
	if s.away or state.expeditions.is_running(s): return "Away"
	if s.refusing: return "Refusing work"
	if s.day_off: return "Already off"
	return ""

static func give_day_off(state: GameState, uid: int) -> bool:
	var s: Survivor = state.survivors.get_by_uid(uid)
	if day_off_block_reason(state, s) != "": return false
	if s.job == Survivor.Job.GUARD: GuardJob.leave_post(state, s)
	s.day_off = true
	_suspend(s)
	return true

static func suspend(s: Survivor) -> void:
	_suspend(s)

static func _suspend(s: Survivor) -> void:
	s.path.clear()
	s.work_uid = 0
	s.work_acc = 0.0
	s.work_tile = Vector2i(-1, -1)
	s.activity = Survivor.Activity.IDLE

static func _has_mood(s: Survivor, id: String) -> bool:
	for mood: Dictionary in s.moods:
		if str(mood.get("id", "")) == id: return true
	return false

static func _remove_id(s: Survivor, id: String) -> void:
	for i: int in range(s.moods.size() - 1, -1, -1):
		if str(s.moods[i].get("id", "")) == id: s.moods.remove_at(i)
