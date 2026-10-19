extends TestCase

func test_tech_round_trip_old_partial_and_optional_fields() -> void:
	var data: GameData = GameData.load_default()
	var state := GameState.new(data, 912)
	state.tech.choose("spotters")
	state.tech.add_points(6.375)
	state.tech.add_points(2.125)
	var save: Dictionary = SaveGame.capture(state)
	var restored: GameState = SaveGame.restore(data, save)
	assert_not_null(restored)
	assert_almost_eq(float(restored.tech.progress.spotters), 8.5)
	assert_eq(restored.tech.active, "spotters")
	var old: Dictionary = save.duplicate(true)
	old.erase("tech")
	var old_restored: GameState = SaveGame.restore(data, old)
	assert_not_null(old_restored)
	assert_eq(old_restored.tech.done.size(), 0)
	assert_eq(old_restored.tech.active, "")
	var tech_only: Dictionary = save.duplicate(true)
	tech_only.erase("morale")
	var tech_restored: GameState = SaveGame.restore(data, tech_only)
	assert_not_null(tech_restored)
	assert_almost_eq(float(tech_restored.tech.progress.spotters), 8.5)
	var morale_only: Dictionary = save.duplicate(true)
	morale_only.erase("tech")
	assert_not_null(SaveGame.restore(data, morale_only), "A morale-only optional save is valid")

func test_malformed_optional_tech_is_rejected_and_unknown_ids_normalize() -> void:
	var data: GameData = GameData.load_default()
	var save: Dictionary = SaveGame.capture(GameState.new(data, 913))
	for malformed: Dictionary in [
		{"done":"spotters"}, {"active":2}, {"progress":[]},
		{"banked":-1.0}, {"progress":{"spotters":INF}}
	]:
		var copy: Dictionary = save.duplicate(true)
		copy["tech"] = malformed
		assert_eq(SaveGame.restore(data, copy), null)
	var odd: Dictionary = save.duplicate(true)
	odd["tech"] = {"done":["missing","oiled_turrets","spotters","spotters"],"active":"oiled_turrets","progress":{"unknown":2.0,"spotters":1.0},"banked":2.75}
	var restored: GameState = SaveGame.restore(data, odd)
	assert_not_null(restored)
	assert_true(restored.tech.is_done("spotters"))
	assert_true(restored.tech.is_done("oiled_turrets"), "valid prerequisite chain deduplicates in config order")
	assert_eq(restored.tech.active, "")
	assert_false(restored.tech.progress.has("spotters"))
	assert_almost_eq(restored.tech.banked, 2.75)
	var locked: Dictionary = save.duplicate(true)
	locked["tech"] = {"done":["oiled_turrets"],"active":"oiled_turrets","progress":{"oiled_turrets":1.0},"banked":0.0}
	var normalized: GameState = SaveGame.restore(data, locked)
	assert_not_null(normalized)
	assert_false(normalized.tech.is_done("oiled_turrets"), "upgrade missing its prerequisite is discarded")
	assert_eq(normalized.tech.active, "")
	assert_false(normalized.tech.progress.has("oiled_turrets"))

func test_partial_progress_for_valid_available_upgrade_is_clamped() -> void:
	var data: GameData = GameData.load_default()
	var save: Dictionary = SaveGame.capture(GameState.new(data, 914))
	save["tech"] = {"done":["spotters"],"active":"oiled_turrets","progress":{"oiled_turrets":500.0},"banked":0.125}
	var restored: GameState = SaveGame.restore(data, save)
	assert_not_null(restored)
	assert_true(restored.tech.is_done("oiled_turrets"))
	assert_eq(restored.tech.active, "")
	assert_eq(restored.tech.progress.size(), 0)

func test_json_round_trip_preserves_researcher_effects_paused_progress_and_fractional_bank() -> void:
	var data: GameData = GameData.load_default()
	var state: GameState = GameState.new(data, 915)
	state.survivors.all()[0].job = Survivor.Job.RESEARCHER
	state.tech.done.append("camp_songs")
	state.tech.choose("better_tools")
	state.tech.add_points(6.375)
	state.tech.choose("")
	state.tech.add_points(2.125)
	var encoded: String = JSON.stringify(SaveGame.capture(state))
	var parsed: Variant = JSON.parse_string(encoded)
	assert_true(parsed is Dictionary)
	var restored: GameState = SaveGame.restore(data, parsed)
	assert_not_null(restored)
	assert_eq(restored.survivors.all()[0].job, Survivor.Job.RESEARCHER)
	assert_true(restored.tech.is_done("camp_songs"))
	assert_eq(restored.tech.mult("campfire_morale"), 1.5)
	assert_eq(restored.tech.active, "")
	assert_almost_eq(float(restored.tech.progress.better_tools), 6.375)
	assert_almost_eq(restored.tech.banked, 2.125)
	assert_true(restored.tech.done_today.is_empty(), "JSON restore never replays the completion journal")

func test_missing_optional_tech_fields_default_independently_and_first_night_uses_bunk_beds() -> void:
	var data: GameData = GameData.load_default()
	var save: Dictionary = SaveGame.capture(GameState.new(data, 916))
	for missing: String in ["done", "active", "progress", "banked"]:
		var partial: Dictionary = {"done": [], "active": "", "progress": {}, "banked": 0.0}
		partial.erase(missing)
		var copy: Dictionary = save.duplicate(true)
		copy["tech"] = partial
		assert_not_null(SaveGame.restore(data, copy), "Missing optional tech field %s defaults" % missing)
	var old_without_either: Dictionary = save.duplicate(true)
	old_without_either.erase("tech")
	old_without_either.erase("morale")
	assert_not_null(SaveGame.restore(data, old_without_either))
	var bunk_save: Dictionary = save.duplicate(true)
	bunk_save["tech"] = {"done": ["spotters", "oiled_turrets", "reinforced_frames", "better_tools", "crop_rotation", "ammo_press", "camp_songs", "first_aid", "bunk_beds"], "active": "", "progress": {}, "banked": 0.0}
	var bunked: GameState = SaveGame.restore(data, bunk_save)
	assert_not_null(bunked)
	assert_eq(bunked.buildings.total_beds(), 4, "CC keeps four beds while Bunk Beds is restored immediately")
	var shelter: Building = bunked.buildings.add("shelter", bunked.map.command_center_origin() + Vector2i(5, 0), true)
	assert_eq(bunked.buildings.beds_for(shelter), 6, "First night capacity sees the restored upgrade")

func test_each_malformed_present_optional_field_rejects_without_coercion() -> void:
	var data: GameData = GameData.load_default()
	var save: Dictionary = SaveGame.capture(GameState.new(data, 917))
	var cases: Array[Dictionary] = [
		{"done": "spotters"}, {"done": [true]}, {"active": 2}, {"progress": []},
		{"progress": {"spotters": "3"}}, {"progress": {"spotters": -1.0}},
		{"progress": {"spotters": INF}}, {"banked": false}, {"banked": -0.1}, {"banked": NAN}
	]
	for malformed: Dictionary in cases:
		var copy: Dictionary = save.duplicate(true)
		copy["tech"] = malformed
		assert_eq(SaveGame.restore(data, copy), null, "Malformed present tech field is rejected: %s" % malformed)
