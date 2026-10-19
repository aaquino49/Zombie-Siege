class_name BalanceBotM12 extends RefCounted
## Public-command policy and observations for morale and research.

const RESEARCH_ORDER: Array[String] = ["camp_songs", "spotters", "better_tools",
	"crop_rotation", "first_aid", "oiled_turrets", "ammo_press", "reinforced_frames", "bunk_beds"]

static func useful(state: GameState, person: Survivor) -> bool:
	return person.hp > 0 and not person.refusing and not person.day_off and not person.away and not state.expeditions.is_running(person)

static func roster(state: GameState) -> Array[Survivor]:
	var people: Array[Survivor] = []
	for person: Survivor in state.survivors.all():
		if useful(state, person): people.append(person)
	people.sort_custom(func(a: Survivor, b: Survivor) -> bool: return a.uid < b.uid)
	return people

static func ammo_target(day: int) -> int:
	return 40 + 20 * day + (60 * (day - 16) if day >= 17 else 0)

static func choose_research(state: GameState) -> void:
	if state.tech.active != "": return
	for id: String in RESEARCH_ORDER:
		if state.tech.available(id):
			state.tech.choose(id)
			return

static func morale_commands(state: GameState, memo: Dictionary) -> void:
	var population: int = state.survivors.count()
	var food: int = state.resources.get_amount("food")
	var cost: int = int(state.data.morale_config().feast.food_per_survivor) * population
	var total: int = 0
	var living: int = 0
	for person: Survivor in state.survivors.all():
		if person.hp > 0:
			total += person.morale
			living += 1
	if living > 0 and float(total) / living < 40.0 and food - cost >= 2 * population and Morale.feast_block_reason(state) == "":
		Morale.hold_feast(state)
	var people: Array[Survivor] = roster(state)
	if people.size() < 7 or int(memo.get("day_off_day", 0)) == state.clock.day: return
	people.sort_custom(func(a: Survivor, b: Survivor) -> bool:
		return a.morale < b.morale if a.morale != b.morale else a.uid < b.uid)
	for person: Survivor in people:
		if person.morale >= 20: break
		if person.job == Survivor.Job.GUARD or protected_worker(state, person, people): continue
		if Morale.day_off_block_reason(state, person) == "" and Morale.give_day_off(state, person.uid):
			memo["day_off_day"] = state.clock.day
			return

static func protected_worker(state: GameState, person: Survivor, people: Array[Survivor]) -> bool:
	var same: int = 0
	for other: Survivor in people:
		if other.job == person.job and (person.job != Survivor.Job.GATHERER or other.gather_kind == "wood"):
			same += 1
	if person.job in [Survivor.Job.BUILDER, Survivor.Job.CRAFTER] and same <= 1: return true
	if person.job == Survivor.Job.GATHERER and person.gather_kind == "wood" and same <= 1: return true
	return person.job == Survivor.Job.FARMER and state.resources.get_amount("food") < 2 * state.survivors.count()

static func optional_build(state: GameState, memo: Dictionary) -> bool:
	if state.buildings.blueprints().size() >= 2: return false
	var population: int = state.survivors.count()
	var slots: int = int(state.data.morale_config().campfire_slots)
	if state.clock.day >= maxi(2, int(state.data.get_building("campfire").unlock_day)) and state.buildings.count_of("campfire") * slots < population and can_spend(state, "campfire", 30, 0):
		if BalanceBot._place_inside(state, memo, "campfire") == Placement.Result.OK: return true
	if state.clock.day >= maxi(4, int(state.data.get_building("field_lab").unlock_day)) and population >= 6 and state.buildings.count_of("field_lab") == 0:
		for type_id: String in ["farm", "workshop", "campfire"]:
			if BalanceBot._complete_count(state, type_id) == 0: return false
		if can_spend(state, "field_lab", 60, 30):
			return BalanceBot._place_inside(state, memo, "field_lab") == Placement.Result.OK
	return false

static func can_spend(state: GameState, type_id: String, wood_floor: int, scrap_floor: int) -> bool:
	var reserve: Dictionary = {"wood": wood_floor, "scrap": scrap_floor}
	if state.clock.day >= int(state.data.get_building("radio_tower").unlock_day) and state.buildings.count_of("radio_tower") == 0:
		var radio_cost: Dictionary = state.data.get_building("radio_tower").cost
		for kind: String in reserve: reserve[kind] = int(reserve[kind]) + int(radio_cost.get(kind, 0))
	var cost: Dictionary = state.data.get_building(type_id).cost
	for kind: String in reserve:
		if state.resources.get_amount(kind) - int(cost.get(kind, 0)) < int(reserve[kind]): return false
	return true

static func jobs(state: GameState) -> void:
	var people: Array[Survivor] = roster(state)
	var open_bp: int = 0
	for b: Building in state.buildings.blueprints():
		if b.type_id not in ["wooden_wall", "gate", "reinforced_wall"]: open_bp += 1
	for b: Building in state.buildings.damaged():
		if b.hp * 2 < b.max_hp: open_bp += 1
	var posts: int = BalanceBot._complete_count(state, "watchtower") * int(state.data.get_building("watchtower").workers)
	var plan: Dictionary = BalanceBot.job_plan(state.clock.day, people.size(), state.resources.get_amount("ammo"), state.resources.get_amount("food"), BalanceBot._complete_count(state, "farm"), BalanceBot._complete_count(state, "workshop") > 0, open_bp, state.resources.get_amount("wood"), posts, state.resources.get_amount("scrap"), BalanceBot._scrap_reserve(state), BalanceBot._fog_forecast(state) and state.clock.time_left() <= 5.0)
	var research: int = 0
	var population: int = state.survivors.count()
	if BalanceBot._complete_count(state, "field_lab") > 0 and people.size() >= 6 and state.resources.get_amount("food") >= 2 * population:
		research = 1
		if people.size() >= 10 and state.resources.get_amount("food") >= 3 * population and state.resources.get_amount("ammo") >= ammo_target(state.clock.day): research = 2
		research = mini(research, int(state.data.get_building("field_lab").workers))
		research = mini(research, maxi(0, int(plan.gatherers) - 1))
	var assigned: Dictionary = {}
	# Keep essential incumbents out of the guard promotion pool.
	var protected: Dictionary = {}
	for person: Survivor in people:
		if protected_worker(state, person, people): protected[person.uid] = true
	for person: Survivor in people:
		if person.job == Survivor.Job.GATHERER and person.gather_kind == "wood":
			protected[person.uid] = true
			break
	var guards: Array[Survivor] = people.duplicate()
	guards.sort_custom(func(a: Survivor, b: Survivor) -> bool:
		if protected.has(a.uid) != protected.has(b.uid): return not protected.has(a.uid)
		return a.morale > b.morale if a.morale != b.morale else a.uid < b.uid)
	var guard_count: int = 0
	for person: Survivor in guards:
		if guard_count >= int(plan.guards): break
		if protected.has(person.uid): continue
		assigned[person.uid] = Survivor.Job.GUARD
		guard_count += 1
	for pair: Array in [[Survivor.Job.BUILDER, plan.builders], [Survivor.Job.CRAFTER, plan.crafters], [Survivor.Job.FARMER, plan.farmers], [Survivor.Job.RESEARCHER, research]]:
		var candidates: Array[Survivor] = people.duplicate()
		candidates.sort_custom(func(a: Survivor, b: Survivor) -> bool:
			if (a.job == int(pair[0])) != (b.job == int(pair[0])): return a.job == int(pair[0])
			return a.uid < b.uid)
		var count: int = 0
		for person: Survivor in candidates:
			if count >= int(pair[1]): break
			if assigned.has(person.uid): continue
			if person.job != int(pair[0]) and protected.has(person.uid):
				var needed: bool = person.job == Survivor.Job.GATHERER
				needed = needed or (person.job == Survivor.Job.BUILDER and int(plan.builders) > 0)
				needed = needed or (person.job == Survivor.Job.CRAFTER and int(plan.crafters) > 0)
				needed = needed or (person.job == Survivor.Job.FARMER and int(plan.farmers) > 0)
				if needed: continue
			# Researchers take only spare gatherers (or retain an incumbent).
			if int(pair[0]) == Survivor.Job.RESEARCHER and (person.job not in [Survivor.Job.GATHERER, Survivor.Job.RESEARCHER] or protected.has(person.uid)): continue
			assigned[person.uid] = int(pair[0])
			count += 1
	var gatherers: int = 0
	var gather_total: int = people.size() - assigned.size()
	for person: Survivor in people:
		var job: int = int(assigned.get(person.uid, Survivor.Job.GATHERER))
		var kind: String = ""
		if job == Survivor.Job.GATHERER:
			kind = "scrap" if (gatherers + int(state.clock.day >= 8)) % 2 == 1 and gather_total > 1 else "wood"
			gatherers += 1
		state.set_job(person.uid, job, kind)

static func working_researchers(state: GameState) -> int:
	if state.clock.phase != GameClock.Phase.DAY: return 0
	var researchers: int = 0
	for person: Survivor in state.survivors.all():
		if useful(state, person) and person.job == Survivor.Job.RESEARCHER and person.activity == Survivor.Activity.RESEARCHING and not person.sheltered and not person.is_moving():
			var lab: Building = state.buildings.get_by_uid(person.work_uid)
			if lab and lab.complete and lab.type_id == "field_lab" and Grid.in_ring(person.tile(), lab.origin, lab.size): researchers += 1
	return researchers

static func measurements(state: GameState, report: Dictionary, end: String) -> Dictionary:
	var total: int = 0
	var minimum: int = 100
	var living: int = 0
	var refusing: int = 0
	for person: Survivor in state.survivors.all():
		if person.hp <= 0: continue
		living += 1
		total += person.morale
		minimum = mini(minimum, person.morale)
		refusing += int(person.refusing)

	return {"morale_mean": float(total) / living if living > 0 else 0.0,
		"morale_min": minimum if living > 0 else 0, "morale_refusing": refusing,
		"morale_left": (report.get("left_morale", []) as Array).size() if end == "dawn" and living > 0 else 0,
		"research_done": state.tech.done.size(), "research_active": state.tech.active,
		"research_progress": float(state.tech.progress.get(state.tech.active, 0.0)),
		"research_banked": state.tech.banked, "researchers": working_researchers(state),
		"cc_damage": int(report.get("cc_damage", 0))}
