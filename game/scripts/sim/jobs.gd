class_name Jobs extends RefCounted

static func tick(state: GameState, sim_dt: float) -> void:
	if sim_dt <= 0.0:
		return
	var hungry_speed: float = float(state.data.balance("food_hungry_speed"))
	for s in state.survivors.all():
		if s.away or state.expeditions.is_running(s):
			continue
		if s.refusing or s.day_off:
			if state.clock.phase == GameClock.Phase.NIGHT:
				if s.job == Survivor.Job.GUARD and (s.post_uid != 0 or s.post_tile != Vector2i(-1, -1) or s.on_tower):
					GuardJob.leave_post(state, s)
				ShelterRules.tick(state, s, sim_dt)
			else:
				s.activity = Survivor.Activity.IDLE
			continue
		var dt: float = sim_dt * (hungry_speed if s.is_hungry() else 1.0)
		if (s.sheltered or s.shelter_uid != 0) and (state.clock.phase == GameClock.Phase.DAY or s.job == Survivor.Job.GUARD):
			ShelterRules.release(state, s)
		if state.clock.phase == GameClock.Phase.NIGHT and s.job != Survivor.Job.GUARD:
			ShelterRules.tick(state, s, dt)
			continue
		if s.job in [Survivor.Job.BUILDER, Survivor.Job.GATHERER, Survivor.Job.FARMER, Survivor.Job.CRAFTER, Survivor.Job.RESEARCHER]:
			dt *= Morale.work_mult(state, s)
		match s.job:
			Survivor.Job.GUARD:
				GuardJob.tick(state, s, dt)
			Survivor.Job.BUILDER:
				BuilderJob.tick(state, s, dt)
			Survivor.Job.GATHERER:
				GathererJob.tick(state, s, dt)
			Survivor.Job.FARMER, Survivor.Job.CRAFTER, Survivor.Job.RESEARCHER:
				ProductionJob.tick(state, s, dt)
