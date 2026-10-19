extends TestCase
## Optional-field defaults, malformed saves and Continue's lack of event replay.

func test_partial_optional_fields_default_independently() -> void:
	var data := GameData.load_default()
	var state := GameState.new(data, 21502)
	var s: Survivor = state.survivors.all()[0]
	Morale.add_mood(state, s, "death", "Mara")
	s.breaking_days = 1
	s.refusing = true
	state.last_feast_day = 1
	var save: Dictionary = SaveGame.capture(state)
	for field: String in ["moods", "breaking_days", "refusing", "last_feast_day", "morale"]:
		var partial: Dictionary = save.duplicate(true)
		if field == "morale": partial.erase("morale")
		elif field == "last_feast_day": partial.morale.erase(field)
		else: partial.survivors[0].erase(field)
		var restored: GameState = SaveGame.restore(data, partial)
		assert_not_null(restored, field)
		if restored == null: continue
		var rs: Survivor = restored.survivors.get_by_uid(s.uid)
		assert_eq(rs.moods, [] as Array[Dictionary] if field == "moods" else s.moods, field)
		assert_eq(rs.breaking_days, 0 if field == "breaking_days" else 1, field)
		assert_eq(rs.refusing, field != "refusing", field)
		assert_eq(restored.last_feast_day, 0 if field in ["morale", "last_feast_day"] else 1, field)
		assert_false(rs.day_off)
		assert_false(rs.had_day_off)

func test_all_malformed_optional_save_fields_are_rejected() -> void:
	var data := GameData.load_default()
	var save: Dictionary = SaveGame.capture(GameState.new(data, 21503))
	for value: Variant in [null, [], "bad", false]:
		var bad: Dictionary = save.duplicate(true)
		bad.morale = value
		assert_eq(SaveGame.restore(data, bad), null, "morale container")
	for field: String in ["breaking_days", "refusing", "moods", "last_feast_day"]:
		var invalid: Array = [null, "bad", -1, 0.5, true]
		if field == "refusing": invalid = [null, 0, 1, "false", []]
		if field == "moods": invalid = [null, {}, "bad", true, [null], [{}]]
		if field == "last_feast_day": invalid.append(2)
		for value: Variant in invalid:
			var bad: Dictionary = save.duplicate(true)
			if field == "last_feast_day": bad.morale[field] = value
			else: bad.survivors[0][field] = value
			assert_eq(SaveGame.restore(data, bad), null, field + " rejects " + str(value))
	for field: String in ["id", "label", "value", "days"]:
		var invalid: Array = [null, false, []]
		if field == "value": invalid.append_array([-101,101,0.5,INF,NAN])
		if field == "days": invalid.append_array([0,-1,1.5,INF,NAN])
		for value: Variant in invalid:
			var bad: Dictionary = save.duplicate(true)
			var mood := {"id":"bed", "label":"Preserved", "value":5, "days":1}
			mood[field] = value
			bad.survivors[0].moods = [mood]
			assert_eq(SaveGame.restore(data, bad), null, "mood " + field)
		var missing: Dictionary = save.duplicate(true)
		var mood := {"id":"bed", "label":"Preserved", "value":5, "days":1}
		mood.erase(field)
		missing.survivors[0].moods = [mood]
		assert_eq(SaveGame.restore(data, missing), null, "missing mood " + field)

func test_continue_preserves_moods_without_aging_or_replaying_events() -> void:
	var data := GameData.load_default()
	var state := GameState.new(data, 21504)
	state.clock.day = 21
	state.endless = true
	state.won = true
	state.buildings.add("radio_tower", Vector2i(10,10), true)
	var s: Survivor = state.survivors.all()[0]
	s.moods = [
		{"id":"feast", "label":"Custom saved feast", "value":9, "days":1},
		{"id":"rescued", "label":"Rescue came", "value":20, "days":2}
	] as Array[Dictionary]
	s.day_off = true
	s.had_day_off = true
	Morale.recompute(state, s)
	var save: Dictionary = SaveGame.capture(state)
	assert_eq(int(save.version), 1)
	assert_false(save.survivors[0].has("morale"))
	var restored: GameState = SaveGame.restore(data, save)
	assert_not_null(restored)
	if restored == null: return
	var rs: Survivor = restored.survivors.get_by_uid(s.uid)
	assert_eq(rs.moods, s.moods)
	assert_eq(rs.morale, 79)
	assert_false(rs.day_off)
	assert_false(rs.had_day_off)
	assert_eq(restored.resources.get_amount("food"), state.resources.get_amount("food"))
	assert_eq(restored.survivors.count(), state.survivors.count())
	assert_eq(restored.rng.state, state.rng.state)
	assert_eq(restored.clock.elapsed, 0.0)
	assert_eq(restored.last_dawn_report, {})
