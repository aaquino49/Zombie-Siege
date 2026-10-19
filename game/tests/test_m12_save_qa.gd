extends TestCase
## T-221 final M12 release QA (save companion): dawn-save + Continue + Reload
## day round trip with partial research/bank, mood labels/expiry and Breaking
## refusal; old saves with neither key and each key independently; restore
## neutrality (no double healing, rewards, or record updates).

class ReloadService:
	extends "res://scripts/autoload/game.gd"
	func _transition(_to_menu: bool, _fresh_seed: bool = false) -> void:
		new_game(next_seed)

func _m12_state() -> GameState:
	var state := GameState.new(GameData.load_default(), 22107)
	state.clock.day = 6
	state.tech.choose("spotters")
	state.tech.add_points(12.0)
	state.tech.choose("")
	state.tech.add_points(4.5)
	var people: Array[Survivor] = state.survivors.all()
	Morale.add_mood(state, people[0], "feast")
	Morale.add_mood(state, people[1], "death", "Mara")
	# A genuine Breaking setup: real moods that recompute to 0 after restore,
	# since cached morale is never serialized (GDD §23.8).
	Morale.add_mood(state, people[2], "death", "Mara")
	Morale.add_mood(state, people[2], "death", "Zed")
	Morale.add_mood(state, people[2], "hungry")
	Morale.add_mood(state, people[2], "no_bed")
	Morale.add_mood(state, people[2], "rough_night")
	people[2].breaking_days = 1
	people[2].refusing = true
	people[3].hp = 20
	state.last_feast_day = 5
	return state

func test_dawn_save_roundtrip_with_partial_research_bank_moods_and_refusal() -> void:
	var data: GameData = GameData.load_default()
	var state: GameState = _m12_state()
	var hp_before: int = state.survivors.all()[3].hp
	var save: Dictionary = SaveGame.capture(state)
	var restored: GameState = SaveGame.restore(data, SaveGame.from_json(SaveGame.to_json(save)))
	assert_not_null(restored)
	assert_eq(restored.clock.day, 6)
	assert_eq(restored.tech.active, "", "Paused research stays paused")
	assert_almost_eq(float(restored.tech.progress.get("spotters", -1.0)), 12.0, 0.00001)
	assert_almost_eq(restored.tech.banked, 4.5, 0.00001)
	assert_eq(restored.last_feast_day, 5)
	var people: Array[Survivor] = restored.survivors.all()
	assert_true(_has_label(people[0], "Feast"))
	assert_true(_has_label(people[1], "Mara died"), "Stored {name} label survives the trip")
	assert_eq(people[2].breaking_days, 1)
	assert_true(people[2].refusing, "Breaking refusal round trips")
	assert_eq(people[2].morale, 5, "50 + Fresh start 10 - 12 - 12 - 15 - 10 - 6")
	assert_eq(str(Morale.band(restored, people[2]).get("id", "")), "breaking")
	assert_eq(people[3].hp, hp_before, "Restore never reheals")
	assert_true(restored.tech.done_today.is_empty(), "done_today is transient")
	for s: Survivor in people:
		for mood: Dictionary in s.moods:
			assert_true(int(mood.get("days", 0)) >= 1, "Moods are not re-aged on restore")

func _has_label(s: Survivor, label: String) -> bool:
	for mood: Dictionary in s.moods:
		if str(mood.get("label", "")) == label:
			return true
	return false

func test_old_saves_without_either_key_and_each_key_independently() -> void:
	var data: GameData = GameData.load_default()
	var save: Dictionary = SaveGame.capture(_m12_state())
	var old: Dictionary = save.duplicate(true)
	old.erase("morale")
	old.erase("tech")
	# A true pre-M12 save also lacks the per-survivor optional keys.
	for entry: Dictionary in old["survivors"]:
		entry.erase("moods")
		entry.erase("breaking_days")
		entry.erase("refusing")
	var old_restored: GameState = SaveGame.restore(data, old)
	assert_not_null(old_restored, "A pre-M12 save loads with defaults")
	assert_eq(old_restored.tech.active, "")
	assert_eq(old_restored.tech.done.size(), 0)
	assert_eq(old_restored.last_feast_day, 0)
	for s: Survivor in old_restored.survivors.all():
		assert_true(s.moods.is_empty(), "No moods means baseline morale")
		assert_eq(s.breaking_days, 0)
		assert_false(s.refusing)
	var morale_only: Dictionary = save.duplicate(true)
	morale_only.erase("tech")
	var m_restored: GameState = SaveGame.restore(data, morale_only)
	assert_not_null(m_restored, "A morale-only save is valid")
	assert_true(_has_label(m_restored.survivors.all()[0], "Feast"))
	assert_eq(m_restored.tech.done.size(), 0)
	var tech_only: Dictionary = save.duplicate(true)
	tech_only.erase("morale")
	var t_restored: GameState = SaveGame.restore(data, tech_only)
	assert_not_null(t_restored, "A tech-only save is valid")
	assert_almost_eq(float(t_restored.tech.progress.get("spotters", -1.0)), 12.0, 0.00001)
	assert_eq(t_restored.last_feast_day, 0)

func test_restore_never_completes_spends_or_replays() -> void:
	var data: GameData = GameData.load_default()
	var state := GameState.new(data, 22108)
	state.tech.done.append("camp_songs")
	state.tech.done.append("first_aid")
	state.survivors.all()[0].hp = 24
	state.tech.choose("spotters")
	state.tech.add_points(19.9)
	state.tech.choose("")
	state.tech.add_points(5.0)
	var restored: GameState = SaveGame.restore(data, SaveGame.capture(state))
	assert_not_null(restored)
	assert_eq(restored.survivors.all()[0].hp, 24, "No dawn heal on restore")
	assert_false(restored.tech.is_done("spotters"), "Near-complete research is not auto-completed")
	assert_eq(restored.tech.active, "")
	assert_almost_eq(float(restored.tech.progress.get("spotters", -1.0)), 19.9, 0.00001)
	assert_almost_eq(restored.tech.banked, 5.0, 0.00001, "Restore never spends the bank")
	assert_true(restored.tech.done_today.is_empty())
	# The next production command resumes the paused card and banks overflow.
	restored.tech.choose("spotters")
	assert_true(restored.tech.is_done("spotters"))
	assert_almost_eq(restored.tech.banked, 5.0 + 19.9 - 20.0, 0.0001)
	assert_eq(restored.tech.done_today, ["spotters"])

func test_continue_and_reload_day_roundtrip_with_m12_state() -> void:
	var service := ReloadService.new()
	service.save_path = temp_path("m12_reload", "json")
	service.new_game(1337, GameSettings.PATH, "normal")
	var colony: GameState = service.state
	colony.waves.enabled = false
	colony.tech.choose("better_tools")
	colony.tech.add_points(7.5)
	Morale.add_mood(colony, colony.survivors.all()[0], "feast")
	colony.clock.elapsed = float(colony.data.balance("day_length")) - 0.25
	colony.tick(0.25)
	colony.clock.elapsed = float(colony.data.balance("night_min_length")) - 0.25
	colony.tick(0.25)
	assert_eq(colony.clock.day, 2)
	assert_true(service.save_now({"hints": {"welcome": true}}))
	var expected: Dictionary = SaveGame.from_json(SaveGame.to_json(SaveGame.capture(colony, {"hints": {"welcome": true}})))
	colony.resources.spend({"wood": 20})
	colony.set_job(colony.survivors.all()[0].uid, Survivor.Job.GUARD)
	colony.tech.choose("spotters")
	colony.clock.elapsed = 30.0
	service.reload_day()
	var restored: Dictionary = SaveGame.from_json(SaveGame.to_json(SaveGame.capture(service.state, service.continued_extra)))
	assert_eq(restored, expected, "Resources, research, moods, RNG and hints round trip")
	assert_eq(service.state.map_seed, 1337)
	assert_eq(service.state.difficulty, "normal")
	assert_eq(service.state.clock.phase, GameClock.Phase.DAY)
	assert_eq(service.state.clock.elapsed, 0.0)
	assert_true(service.state.waves.enabled)
	service.continue_game()
	assert_eq(SaveGame.from_json(SaveGame.to_json(SaveGame.capture(service.state, service.continued_extra))), restored)
	service.delete_save()
	service.free()

func test_broken_and_old_version_saves_rejected_without_crash() -> void:
	var data: GameData = GameData.load_default()
	var save: Dictionary = SaveGame.capture(_m12_state())
	assert_eq(SaveGame.restore(data, {}), null)
	var missing_version: Dictionary = save.duplicate(true)
	missing_version.erase("version")
	assert_eq(SaveGame.restore(data, missing_version), null)
	var old_version: Dictionary = save.duplicate(true)
	old_version["version"] = 0
	assert_eq(SaveGame.restore(data, old_version), null)
	var service := ReloadService.new()
	service.save_path = temp_path("m12_broken", "json")
	service.new_game(1337, GameSettings.PATH, "normal")
	assert_true(service.save_now())
	service.delete_save()
	assert_false(FileAccess.file_exists(service.save_path), "Deletion clears the dawn autosave")
	service.free()
