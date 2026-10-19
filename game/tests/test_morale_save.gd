extends "res://tests/test_case.gd"

func test_optional_morale_fields_round_trip_and_defaults() -> void:
	var data := GameData.load_default()
	var state := GameState.new(data, 222)
	var s: Survivor = state.survivors.all()[0]
	Morale.add_mood(state, s, "feast")
	s.breaking_days = 1
	s.refusing = true
	state.last_feast_day = 1
	var save: Dictionary = SaveGame.capture(state)
	var restored := SaveGame.restore(data, save)
	assert_not_null(restored)
	var rs: Survivor = restored.survivors.get_by_uid(s.uid)
	assert_eq(rs.moods, s.moods)
	assert_eq(rs.morale, s.morale)
	assert_eq(rs.breaking_days, 1)
	assert_true(rs.refusing)
	assert_eq(restored.last_feast_day, 1)
	var old_save: Dictionary = save.duplicate(true)
	old_save.erase("morale")
	for entry: Dictionary in old_save.survivors:
		entry.erase("moods")
		entry.erase("breaking_days")
		entry.erase("refusing")
	var old_restored := SaveGame.restore(data, old_save)
	assert_not_null(old_restored)
	assert_eq(old_restored.survivors.all()[0].morale, 50)

func test_malformed_optional_moods_are_rejected() -> void:
	var data := GameData.load_default()
	var save: Dictionary = SaveGame.capture(GameState.new(data, 223))
	save.survivors[0]["moods"] = [{"id":"bed","label":"bad","value":1.5,"days":1}]
	assert_eq(SaveGame.restore(data, save), null)

func test_restore_drops_unknown_moods_and_keeps_newest_within_stack_cap() -> void:
	var data := GameData.load_default()
	var save: Dictionary = SaveGame.capture(GameState.new(data, 224))
	save.survivors[0]["moods"] = [
		{"id":"death","label":"A died","value":-12,"days":1},
		{"id":"unknown_event","label":"Unknown","value":4,"days":1},
		{"id":"death","label":"B died","value":-12,"days":2},
		{"id":"death","label":"C died","value":-12,"days":3}
	]
	var restored := SaveGame.restore(data, save)
	assert_not_null(restored)
	var survivor: Survivor = restored.survivors.get_by_uid(1)
	assert_eq(survivor.moods.size(), 2)
	assert_eq([survivor.moods[0].label, survivor.moods[1].label], ["B died", "C died"])
