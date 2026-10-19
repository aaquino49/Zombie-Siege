class_name BuilderJob extends RefCounted

static func tick(state: GameState, s: Survivor, sim_dt: float) -> void:
	if s.work_uid != 0:
		var b: Building = state.buildings.get_by_uid(s.work_uid)
		var clear := false
		if b == null:
			clear = true
		elif s.activity == Survivor.Activity.WALKING or s.activity == Survivor.Activity.BUILDING:
			if b.complete:
				clear = true
		elif s.activity == Survivor.Activity.REPAIRING:
			if not b.is_damaged():
				clear = true
		if clear:
			s.work_uid = 0
			s.path.clear()
			s.activity = Survivor.Activity.IDLE
			s.work_acc = 0.0

	if s.work_uid == 0:
		if s.job_timer > 0.0:
			s.job_timer -= sim_dt
			return
			
		var candidates: Array[Building] = state.buildings.blueprints()
		if candidates.is_empty() and state.clock.phase == GameClock.Phase.DAY:
			var damaged: Array[Building] = state.buildings.damaged()
			for b in damaged:
				var r_cost := Construction.repair_cost(state.data, b)
				if state.resources.get_amount("wood") >= r_cost:
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
				s.activity = Survivor.Activity.BUILDING if not b.complete else Survivor.Activity.REPAIRING
				if s.activity == Survivor.Activity.REPAIRING:
					var r_cost := Construction.repair_cost(state.data, b)
					if state.resources.get_amount("wood") >= r_cost:
						state.resources.take("wood", r_cost)
					else:
						s.work_uid = 0
						s.activity = Survivor.Activity.IDLE
						continue
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
			if not b.complete:
				s.activity = Survivor.Activity.BUILDING
			else:
				s.activity = Survivor.Activity.REPAIRING
				var r_cost := Construction.repair_cost(state.data, b)
				if state.resources.get_amount("wood") >= r_cost:
					state.resources.take("wood", r_cost)
				else:
					s.work_uid = 0
					s.activity = Survivor.Activity.IDLE
		else:
			s.work_uid = 0
			s.activity = Survivor.Activity.IDLE
			s.work_acc = 0.0

	if s.activity == Survivor.Activity.BUILDING:
		var b: Building = state.buildings.get_by_uid(s.work_uid)
		if b != null:
			b.progress += sim_dt
			if b.progress >= b.build_time:
				state.buildings.finish(b.uid)
				s.work_uid = 0
				s.job_timer = 0.0
				s.activity = Survivor.Activity.IDLE

	elif s.activity == Survivor.Activity.REPAIRING:
		var b: Building = state.buildings.get_by_uid(s.work_uid)
		if b != null:
			var repair_time_fraction := float(state.data.balance("repair_time_fraction", 0.5))
			var repair_duration := b.build_time * repair_time_fraction
			if repair_duration <= 0.0:
				b.hp = b.max_hp
				s.work_uid = 0
				s.job_timer = 0.0
				s.activity = Survivor.Activity.IDLE
				return
			s.work_acc += sim_dt * b.max_hp / repair_duration
			if s.work_acc >= 1.0:
				var whole := floori(s.work_acc)
				b.hp += whole
				s.work_acc -= whole
				if b.hp >= b.max_hp:
					b.hp = b.max_hp
					s.work_uid = 0
					s.job_timer = 0.0
					s.activity = Survivor.Activity.IDLE
