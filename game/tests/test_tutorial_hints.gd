class_name TestTutorialHints extends TestCase

var data: GameData
var state: GameState
var _settings_temp_path: String

func before_each() -> void:
	_settings_temp_path = temp_path("hint_settings", "cfg")
	remove_test_temp_file(_settings_temp_path)
	data = GameData.load_default()
	state = GameState.new(data, 1337)
	state.waves.enabled = false

func after_each() -> void:
	remove_test_temp_file(_settings_temp_path)
	data = null
	state = null

func test_welcome_fires_first_and_only_once() -> void:
	var hints := TutorialHints.new()
	var res := hints.check(state, 0.0)
	assert_eq(res, "welcome", "Welcome should fire first on day 1")
	var res2 := hints.check(state, 1.0)
	assert_ne(res2, "welcome", "Welcome must not fire twice")
	assert_true(hints.shown.has("welcome"), "Welcome must be marked shown")

func test_farm_fires_after_20s_and_prevented_by_blueprint() -> void:
	var hints := TutorialHints.new()
	var w := hints.check(state, 0.0)
	assert_eq(w, "welcome")
	
	var r1 := hints.check(state, 10.0)
	assert_eq(r1, "", "Farm should not fire before 20s daytime")
	
	var r2 := hints.check(state, 10.0)
	assert_eq(r2, "farm", "Farm should fire after >= 20s daytime with no farm")
	
	var r3 := hints.check(state, 1.0)
	assert_ne(r3, "farm", "Farm should not repeat")

	# Blueprint prevention check
	var hints_bp := TutorialHints.new()
	hints_bp.check(state, 0.0) # welcome
	var origin := state.map.command_center_origin() + Vector2i(4, 0)
	state.buildings.add("farm", origin, false)
	assert_gt(state.buildings.count_of("farm"), 0)
	
	var r_bp := hints_bp.check(state, 25.0)
	assert_ne(r_bp, "farm", "Farm blueprint must prevent farm hint")

func test_night_soon_fires_at_30s_to_nightfall() -> void:
	var hints := TutorialHints.new()
	hints.check(state, 0.0) # welcome
	# Build a farm so farm hint won't fire
	var origin := state.map.command_center_origin() + Vector2i(4, 0)
	state.buildings.add("farm", origin, true)

	var day_len: float = float(data.balance("day_length", 150))
	state.clock.elapsed = day_len - 35.0
	assert_gt(state.clock.time_left(), 30.0)
	var r1 := hints.check(state, 25.0)
	assert_eq(r1, "", "Night soon must not fire when > 30s left")

	state.clock.elapsed = day_len - 28.0
	assert_lt(state.clock.time_left(), 30.0)
	var r2 := hints.check(state, 0.0)
	assert_eq(r2, "night_soon", "Night soon should fire at <= 30s")

	var r3 := hints.check(state, 0.0)
	assert_ne(r3, "night_soon", "Night soon must not repeat")

func test_ammo_respects_unlock_day_and_conditions() -> void:
	var hints := TutorialHints.new()
	hints.shown["welcome"] = true
	hints.shown["farm"] = true
	hints.shown["night_soon"] = true

	var unlock_day: int = int(data.get_building("workshop").get("unlock_day", 2))
	state.resources.take("ammo", state.resources.get_amount("ammo"))
	assert_lt(state.resources.get_amount("ammo"), 30)

	state.clock.day = unlock_day - 1
	var r_early := hints.check(state, 0.0)
	assert_ne(r_early, "ammo", "Ammo hint must not fire before workshop unlock day")

	state.clock.day = unlock_day
	var r_unlock := hints.check(state, 0.0)
	assert_eq(r_unlock, "ammo", "Ammo hint should fire on workshop unlock day with ammo < 30 and no workshop")

	# Existing workshop prevents hint
	var hints2 := TutorialHints.new()
	hints2.shown["welcome"] = true
	hints2.shown["farm"] = true
	hints2.shown["night_soon"] = true
	state.buildings.add("workshop", state.map.command_center_origin() + Vector2i(4, 0), false)
	var r_has_ws := hints2.check(state, 0.0)
	assert_ne(r_has_ws, "ammo", "Existing workshop must prevent ammo hint")

func test_radio_respects_unlock_day() -> void:
	var hints := TutorialHints.new()
	hints.shown["welcome"] = true
	hints.shown["farm"] = true
	hints.shown["night_soon"] = true
	hints.shown["ammo"] = true
	hints.shown["hungry"] = true

	var unlock_day: int = int(data.get_building("radio_tower").get("unlock_day", 8))
	state.clock.day = unlock_day - 1
	var r_early := hints.check(state, 0.0)
	assert_ne(r_early, "radio", "Radio hint must not fire before radio unlock day")

	state.clock.day = unlock_day
	var r_unlock := hints.check(state, 0.0)
	assert_eq(r_unlock, "radio", "Radio hint should fire on unlock day")

	# Existing radio tower prevents hint
	var hints2 := TutorialHints.new()
	hints2.shown["welcome"] = true
	hints2.shown["farm"] = true
	hints2.shown["night_soon"] = true
	hints2.shown["ammo"] = true
	hints2.shown["hungry"] = true
	state.buildings.add("radio_tower", state.map.command_center_origin() + Vector2i(4, 0), false)
	var r_has_radio := hints2.check(state, 0.0)
	assert_ne(r_has_radio, "radio", "Existing radio tower must prevent radio hint")

func test_hungry_fires_when_survivor_hungry() -> void:
	var hints := TutorialHints.new()
	hints.shown["welcome"] = true
	hints.shown["farm"] = true
	hints.shown["night_soon"] = true
	hints.shown["ammo"] = true

	var r_not_hungry := hints.check(state, 0.0)
	assert_ne(r_not_hungry, "hungry", "Hungry hint must not fire when nobody is hungry")

	state.survivors.all()[0].hungry_days = 1
	var r_hungry := hints.check(state, 0.0)
	assert_eq(r_hungry, "hungry", "Hungry hint should fire when survivor is hungry")

	var r_repeat := hints.check(state, 0.0)
	assert_ne(r_repeat, "hungry", "Hungry hint must not repeat")

func test_spitter_hint_uses_forecast_and_fires_once_by_day() -> void:
	var hints := TutorialHints.new()
	hints.shown = {"welcome": true, "farm": true, "night_soon": true, "ammo": true, "scavenge": true, "hungry": true, "radio": true}
	state.difficulty = "normal"
	state.difficulty_multipliers = data.difficulty_config("normal")
	state.clock.phase = GameClock.Phase.DAY
	state.clock.day = 7
	assert_eq(int(WaveSpawner.forecast(data, 7, state.difficulty_multipliers)["spitter"]), 0)
	assert_ne(hints.check(state, 0.0), "spitters", "Normal forecast on day 7 has no spitters")

	state.clock.day = 8
	assert_gt(int(WaveSpawner.forecast(data, 8, state.difficulty_multipliers)["spitter"]), 0)
	assert_eq(hints.check(state, 0.0), "spitters", "Normal day 8 morning warns about tonight's spitters")
	assert_true(hints.shown.has("spitters"), "Spitter hint is marked shown when returned")
	assert_ne(hints.check(state, 0.0), "spitters", "Spitter hint only fires once")

func test_spitter_hint_waits_for_easy_forecast_and_never_fires_at_night() -> void:
	var hints := TutorialHints.new()
	hints.shown = {"welcome": true, "farm": true, "night_soon": true, "ammo": true, "scavenge": true, "hungry": true, "radio": true}
	state.difficulty = "easy"
	state.difficulty_multipliers = data.difficulty_config("easy")
	state.clock.phase = GameClock.Phase.DAY
	var first_spitter_day: int = 0
	for day: int in range(1, data.final_night() + 1):
		state.clock.day = day
		var forecast: Dictionary = WaveSpawner.forecast(data, day, state.difficulty_multipliers)
		var result: String = hints.check(state, 0.0)
		if int(forecast.get("spitter", 0)) > 0:
			first_spitter_day = day
			assert_eq(result, "spitters", "Easy hint fires on first forecast with spitters")
			break
		assert_ne(result, "spitters", "Easy hint waits while forecast has no spitters")
	assert_gt(first_spitter_day, 0, "Easy campaign has a forecast with spitters")
	assert_ne(hints.check(state, 0.0), "spitters", "Easy spitter hint only fires once")

	var night_hints := TutorialHints.new()
	night_hints.shown = {"welcome": true, "farm": true, "night_soon": true, "ammo": true, "scavenge": true, "hungry": true, "radio": true}
	state.clock.day = first_spitter_day
	state.clock.phase = GameClock.Phase.NIGHT
	assert_ne(night_hints.check(state, 0.0), "spitters", "Night phase never shows the morning hint")

func test_disabled_game_over_and_night_suppress_hints() -> void:
	var hints := TutorialHints.new()
	hints.enabled = false
	assert_eq(hints.check(state, 0.0), "", "Disabled hints must return empty")

	hints.enabled = true
	state.game_over = true
	assert_eq(hints.check(state, 0.0), "", "Game over must suppress hints")

	state.game_over = false
	state.clock.phase = GameClock.Phase.NIGHT
	assert_eq(hints.check(state, 0.0), "", "Night phase must suppress hints")

func test_priority_order_and_at_most_one_per_check() -> void:
	var hints := TutorialHints.new()
	state.clock.day = 1
	state.clock.phase = GameClock.Phase.DAY
	state.clock.elapsed = float(data.balance("day_length", 150)) - 20.0
	hints.day_time = 25.0
	state.survivors.all()[0].hungry_days = 1

	var h1 := hints.check(state, 0.0)
	assert_eq(h1, "welcome")
	var h2 := hints.check(state, 0.0)
	assert_eq(h2, "farm")
	var h3 := hints.check(state, 0.0)
	assert_eq(h3, "night_soon")
	var h4 := hints.check(state, 0.0)
	assert_eq(h4, "hungry")
	var h5 := hints.check(state, 0.0)
	assert_eq(h5, "")

func test_hint_settings_round_trip_keeps_audio_keys() -> void:
	var temp_path: String = _settings_temp_path

	var audio_vols := {"Master": 0.4, "SFX": 0.7, "Music": 0.9}
	AudioSettings.save_volumes(audio_vols, temp_path)

	assert_true(HintSettings.load_enabled(temp_path), "Default hints should be true")

	HintSettings.save_enabled(false, temp_path)
	assert_false(HintSettings.load_enabled(temp_path), "Hints should be false after save")

	var loaded_audio := AudioSettings.load_volumes(temp_path)
	assert_almost_eq(float(loaded_audio["Master"]), 0.4, 0.001)
	assert_almost_eq(float(loaded_audio["SFX"]), 0.7, 0.001)
	assert_almost_eq(float(loaded_audio["Music"]), 0.9, 0.001)

	HintSettings.save_enabled(true, temp_path)
	assert_true(HintSettings.load_enabled(temp_path), "Hints should be true after save")

	loaded_audio = AudioSettings.load_volumes(temp_path)
	assert_almost_eq(float(loaded_audio["Master"]), 0.4, 0.001)


func test_hint_texts_valid() -> void:
	for id: String in ["welcome", "farm", "night_soon", "ammo", "scavenge", "hungry", "radio", "spitters"]:
		var t := TutorialHints.text(id)
		assert_true(t.length() > 0, "Text for " + id + " must not be empty")

func test_spitter_hint_text_uses_zombie_data_range() -> void:
	var ranged: Dictionary = data.get_zombie("spitter")["ranged"]
	var range_tiles: int = int(ranged["range_tiles"])
	var text: String = TutorialHints.text("spitters", data)
	assert_true(text.contains("%d tiles" % range_tiles), "Spitter hint must include its configured range")

	ranged["range_tiles"] = 1
	assert_true(TutorialHints.text("spitters", data).contains("1 tile out"), "Singular range uses tile")
