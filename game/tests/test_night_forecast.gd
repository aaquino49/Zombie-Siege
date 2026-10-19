extends TestCase

func test_forecast_matches_scheduled_type_counts_for_all_difficulties() -> void:
	var data: GameData = GameData.load_default()
	for difficulty: String in ["easy", "normal", "hard"]:
		for night: int in [1, 4, 11, 20, 23]:
			var state: GameState = GameState.new(data, 1337, difficulty)
			var forecast: Dictionary = WaveSpawner.forecast(data, night, state.difficulty_multipliers)
			state.waves.plan_night(night)
			var scheduled: Dictionary = {"walker": 0, "runner": 0, "brute": 0, "spitter": 0}
			for entry: Dictionary in state.waves._schedule:
				scheduled[String(entry["type"])] += 1
			for type_id: String in ["walker", "runner", "brute", "spitter"]:
				assert_eq(int(forecast[type_id]), int(scheduled[type_id]), "%s night %d %s" % [difficulty, night, type_id])
			assert_eq(int(forecast["sides"]), int(data.wave_for_night(night)["sides"]))
			assert_eq(bool(forecast["final"]), night == data.final_night())

func test_forecast_text_formats_normal_and_final_horde() -> void:
	var data: GameData = GameData.load_default()
	var normal: Dictionary = WaveSpawner.forecast(data, 1, data.difficulty_config("normal"))
	var final: Dictionary = WaveSpawner.forecast(data, 20, data.difficulty_config("normal"))
	assert_eq(HudText.forecast_text(normal), "Tonight: 7 walkers · 1 side")
	var final_spitters: int = int(final["spitter"])
	var spitter_label: String = "spitter" if final_spitters == 1 else "spitters"
	assert_eq(HudText.forecast_text(final), "FINAL HORDE: 192 walkers · 102 runners · 30 brutes · %d %s · 4 sides" % [final_spitters, spitter_label])

func test_spitter_forecast_starts_on_night_eight_and_uses_scheduled_count() -> void:
	var data: GameData = GameData.load_default()
	for night: int in [7, 8, 13]:
		var forecast: Dictionary = WaveSpawner.forecast(data, night, data.difficulty_config("normal"))
		var count: int = int(forecast["spitter"])
		var text: String = HudText.forecast_text(forecast)
		assert_eq(count > 0, night >= 8)
		if night == 7:
			assert_false(text.contains("spitter"), "Night 7 has no spitters")
		else:
			var label: String = "spitter" if count == 1 else "spitters"
			assert_true(text.contains("%d %s" % [count, label]), "Forecast uses scheduled night %d count" % night)

func _bound_hud(state: GameState) -> CanvasLayer:
	var hud: CanvasLayer = (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate() as CanvasLayer
	hud.set("top_bar", hud.get_node("TopBar"))
	for kind: String in ResourceStore.KINDS:
		var box_path: String = "TopBar/Margin/HBox/Resources/%sBox" % kind.capitalize()
		hud.set(kind + "_icon", hud.get_node(box_path + "/Icon"))
		hud.set(kind + "_label", hud.get_node(box_path + "/Label"))
	hud.set("day_label", hud.get_node("TopBar/Margin/HBox/DayArea/DayLabel"))
	hud.set("time_label", hud.get_node("TopBar/Margin/HBox/ClockArea/TimeLabel"))
	for button_name: String in ["BtnPause", "Btn1x", "Btn2x", "Btn3x"]:
		hud.set("btn_" + button_name.to_lower().trim_prefix("btn"), hud.get_node("TopBar/Margin/HBox/ClockArea/SpeedButtons/" + button_name))
	hud.set("shelter_warning_label", hud.get_node("ShelterWarning"))
	hud.set("phase_icon", hud.get_node("TopBar/Margin/HBox/DayArea/PhaseIcon"))
	hud.set("night_forecast_panel", hud.get_node("NightForecast"))
	hud.set("night_forecast_label", hud.get_node("NightForecast/Label"))
	hud.call("_ready")
	hud.call("bind", state)
	return hud

func test_forecast_label_refreshes_on_bind_and_hides_at_night() -> void:
	var data: GameData = GameData.load_default()
	var state: GameState = GameState.new(data, 1337, "normal")
	var hud: CanvasLayer = _bound_hud(state)
	var panel: Control = hud.get_node("NightForecast") as Control
	var label: Label = hud.get_node("NightForecast/Label") as Label
	assert_true(panel.visible)
	assert_eq(label.text, "Tonight: 7 walkers · 1 side")
	assert_eq(label.get_theme_font_size("font_size"), UiFont.BODY)
	state.clock.day = 20
	hud.call("_refresh_forecast")
	assert_eq(label.text, HudText.forecast_text(WaveSpawner.forecast(data, 20, state.difficulty_multipliers)))
	state.clock.phase = GameClock.Phase.NIGHT
	state.clock.phase_changed.emit(GameClock.Phase.NIGHT, 20)
	assert_false(panel.visible)
	hud.free()

func test_forecast_midgame_bind_and_phase_refresh() -> void:
	var data: GameData = GameData.load_default()
	var state: GameState = GameState.new(data, 1337, "hard")
	state.clock.day = 20
	state.clock.elapsed = float(data.balance("day_length")) - 15.0
	var hud: CanvasLayer = _bound_hud(state)
	var panel: Control = hud.get_node("NightForecast") as Control
	var label: Label = hud.get_node("NightForecast/Label") as Label
	assert_true(panel.visible, "Continue during late day must show tonight's forecast")
	assert_eq(label.text, HudText.forecast_text(WaveSpawner.forecast(data, 20, state.difficulty_multipliers, state.map_seed)))
	assert_eq(label.get_theme_color("font_color"), Color(1.0, 0.3, 0.3), "Final forecast must be red")
	state.clock.phase = GameClock.Phase.NIGHT
	state.clock.phase_changed.emit(GameClock.Phase.NIGHT, 20)
	assert_false(panel.visible)
	state.clock.day = 21
	state.clock.phase = GameClock.Phase.DAY
	state.clock.elapsed = 0.0
	state.clock.phase_changed.emit(GameClock.Phase.DAY, 21)
	assert_true(panel.visible, "Dawn must restore the forecast")
	assert_eq(label.text, HudText.forecast_text(WaveSpawner.forecast(data, 21, state.difficulty_multipliers, state.map_seed)))
	assert_eq(label.get_theme_color("font_color"), MenuStyle.CREAM)
	hud.free()
	state.clock.phase = GameClock.Phase.NIGHT
	hud = _bound_hud(state)
	assert_false((hud.get_node("NightForecast") as Control).visible, "Continue during night must hide the forecast")
	hud.free()
