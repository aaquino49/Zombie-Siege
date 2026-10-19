extends TestCase
## T-034 release regressions: seeded weather balance and all tutorial cards in one game.

const FULL_RUN: GDScript = preload("res://tests/test_full_run_qa.gd")

func test_seed_1337_full_run_matches_forecast_aware_bot_pacing() -> void:
	var result: Dictionary = FULL_RUN._full()
	assert_false(result["won"], "T-220 v6 still survives through night 20; wall 200 shortens the run by ~8 s")
	assert_eq(result["reason"], "")
	assert_eq(result["day"] - 1, 20)
	assert_almost_eq(float(result["time"]), 2479.25, 1.0,
		"Seed 1337 v6 fixture includes morale and research decisions")
	print("BOT_PACING seed=1337 seconds=%.2f target=2479.25 (T-220 v6 balance)" % float(result["time"]))

func test_all_eight_hint_cards_display_once_in_one_game() -> void:
	var state := GameState.new(GameData.load_default(), 1337)
	state.waves.enabled = false
	var panel: HintPanel = preload("res://scenes/ui/hint_panel.tscn").instantiate()
	panel._ready()
	panel.bind(state)
	panel.set_enabled(true)
	var dismissed: Array[String] = []
	var button: Button = panel.get_node("PanelContainer/MarginContainer/VBoxContainer/BottomRow/GotItButton")
	panel._process(0.0)
	dismissed.append(panel.current_hint())
	button.pressed.emit()
	panel._process(20.0)
	dismissed.append(panel.current_hint())
	button.pressed.emit()
	state.clock.elapsed = float(state.data.balance("day_length")) - 30.0
	panel._process(0.0)
	dismissed.append(panel.current_hint())
	button.pressed.emit()
	state.clock.day = 2
	state.clock.elapsed = 0.0
	panel._process(0.0)
	dismissed.append(panel.current_hint())
	button.pressed.emit()
	state.clock.day = int(state.data.get_building("radio_tower")["unlock_day"])
	state.resources.take("ammo", state.resources.get_amount("ammo"))
	state.survivors.all()[0].hungry_days = 1
	for _i: int in range(4):
		panel._process(0.0)
		dismissed.append(panel.current_hint())
		button.pressed.emit()
	assert_eq(dismissed, ["welcome", "farm", "night_soon", "scavenge", "ammo", "hungry", "radio", "spitters"])
	for _i: int in range(10):
		panel._process(1.0)
		assert_false(panel.is_showing(), "Dismissed eligible cards must never repeat")
	assert_eq(panel._hints.shown.size(), 8)
	assert_false(state.clock.paused, "Tutorial never pauses the simulation")
	panel.free()
