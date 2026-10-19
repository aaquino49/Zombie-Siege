class_name ProductionJob extends RefCounted

static func building_type_for(job: int) -> String:
	if job == Survivor.Job.FARMER:
		return "farm"
	elif job == Survivor.Job.CRAFTER:
		return "workshop"
	elif job == Survivor.Job.RESEARCHER:
		return "field_lab"
	return ""

static func workers_at(state: GameState, b: Building) -> int:
	var count := 0
	for s in state.survivors.all():
		if not s.away and not s.refusing and not s.day_off and s.work_uid == b.uid:
			if (b.type_id == "farm" and s.job == Survivor.Job.FARMER) or \
			   (b.type_id == "workshop" and s.job == Survivor.Job.CRAFTER) or \
			   (b.type_id == "field_lab" and s.job == Survivor.Job.RESEARCHER):
				count += 1
	return count

static func tick(state: GameState, s: Survivor, sim_dt: float) -> void:
	if s.work_uid != 0:
		var b: Building = state.buildings.get_by_uid(s.work_uid)
		if b == null or not b.complete:
			s.work_uid = 0
			s.path.clear()
			s.activity = Survivor.Activity.IDLE
			s.work_acc = 0.0
		elif s.activity == Survivor.Activity.IDLE:
			if Grid.in_ring(s.tile(), b.origin, b.size):
				if s.job == Survivor.Job.FARMER:
					s.activity = Survivor.Activity.FARMING
				elif s.job == Survivor.Job.CRAFTER:
					s.activity = Survivor.Activity.CRAFTING
				elif s.job == Survivor.Job.RESEARCHER:
					s.activity = Survivor.Activity.RESEARCHING
			else:
				var p: Array[Vector2i] = state.pathfinder.find_path_adjacent(s.tile(), b.origin, b.size)
				if not p.is_empty():
					s.path = p
					s.target = p.back()
					s.activity = Survivor.Activity.WALKING
				else:
					s.work_uid = 0

	var type_id: String = building_type_for(s.job)
	if type_id == "":
		return

	if s.work_uid == 0:
		if s.job_timer > 0.0:
			s.job_timer -= sim_dt
			return
			
		var candidates: Array[Building] = []
		for b in state.buildings.all():
			if b.type_id == type_id and b.complete:
				var b_data: Dictionary = state.data.get_building(b.type_id)
				var max_workers: int = int(b_data.get("workers", 0))
				if workers_at(state, b) < max_workers:
					candidates.append(b)
					
		if candidates.is_empty():
			s.job_timer = state.data.balance("job_retry_interval", 1.0)
			return
			
		candidates.sort_custom(func(a: Building, b: Building) -> bool:
			var c_a := a.center_world()
			var c_b := b.center_world()
			var d_a := s.pos.distance_squared_to(c_a)
			var d_b := s.pos.distance_squared_to(c_b)
			if d_a != d_b:
				return d_a < d_b
			return a.uid < b.uid
		)
		
		var found := false
		for i in range(mini(5, candidates.size())):
			var b: Building = candidates[i]
			if Grid.in_ring(s.tile(), b.origin, b.size):
				s.work_uid = b.uid
				if s.job == Survivor.Job.FARMER:
					s.activity = Survivor.Activity.FARMING
				elif s.job == Survivor.Job.CRAFTER:
					s.activity = Survivor.Activity.CRAFTING
				elif s.job == Survivor.Job.RESEARCHER:
					s.activity = Survivor.Activity.RESEARCHING
				found = true
				break
			else:
				var p: Array[Vector2i] = state.pathfinder.find_path_adjacent(s.tile(), b.origin, b.size)
				if not p.is_empty():
					s.path = p
					s.target = p.back()
					s.work_uid = b.uid
					s.activity = Survivor.Activity.WALKING
					found = true
					break
		
		if not found:
			s.job_timer = state.data.balance("job_retry_interval", 1.0)
			return

	if s.activity == Survivor.Activity.WALKING and not s.is_moving():
		var b: Building = state.buildings.get_by_uid(s.work_uid)
		if b != null and Grid.in_ring(s.tile(), b.origin, b.size):
			if s.job == Survivor.Job.FARMER:
				s.activity = Survivor.Activity.FARMING
			elif s.job == Survivor.Job.CRAFTER:
				s.activity = Survivor.Activity.CRAFTING
			elif s.job == Survivor.Job.RESEARCHER:
				s.activity = Survivor.Activity.RESEARCHING
		else:
			s.work_uid = 0
			s.activity = Survivor.Activity.IDLE
			s.work_acc = 0.0

	var b: Building = state.buildings.get_by_uid(s.work_uid)
	if b == null:
		return

	if s.job == Survivor.Job.RESEARCHER and s.activity == Survivor.Activity.RESEARCHING and state.clock.phase == GameClock.Phase.DAY:
		var day_length: float = float(state.data.balance("day_length"))
		var rp_per_day: float = float(state.data.tech_config()["rp_per_researcher_per_day"])
		state.tech.add_points(sim_dt * rp_per_day / day_length)
	elif s.job == Survivor.Job.FARMER and s.activity == Survivor.Activity.FARMING and state.clock.phase == GameClock.Phase.DAY:
		var b_data: Dictionary = state.data.get_building(type_id)
		var food_per_farmer := float(b_data.get("food_per_farmer", 3.0)) * state.tech.mult("farm_food")
		var day_length := float(state.data.balance("day_length", 150.0))
		var rain: Dictionary = state.data.weather_config().get("rain", {})
		var farm_mult: float = float(rain.get("farm_mult", 1.0)) if state.weather_day() == "rain" else 1.0
		s.work_acc += sim_dt * food_per_farmer * farm_mult / day_length
		if s.work_acc >= 1.0 - 0.0001:
			s.work_acc -= 1.0
			state.resources.add("food", 1)
			state.resource_delivered.emit("food", 1, b.center_world())

	elif s.job == Survivor.Job.CRAFTER and (s.activity == Survivor.Activity.CRAFTING or s.activity == Survivor.Activity.IDLE) and state.clock.phase == GameClock.Phase.DAY:
		var b_data: Dictionary = state.data.get_building(type_id)
		var craft_time := float(b_data.get("craft_time", 10.0))
		var ammo_per_scrap := int(b_data.get("ammo_per_scrap", 5)) + int(state.tech.bonus("ammo_per_scrap"))
		
		if state.resources.get_amount("scrap") >= 1:
			if s.activity == Survivor.Activity.IDLE:
				s.activity = Survivor.Activity.CRAFTING
			
			s.work_acc += sim_dt
			if s.work_acc >= craft_time:
				s.work_acc -= craft_time
				state.resources.take("scrap", 1)
				state.resources.add("ammo", ammo_per_scrap)
				state.resource_delivered.emit("ammo", ammo_per_scrap, b.center_world())
		else:
			s.activity = Survivor.Activity.IDLE
