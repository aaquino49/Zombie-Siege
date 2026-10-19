extends TestCase

var _data: GameData
var _state: GameState
var _panel: HintPanel
var _settings_temp_path: String

func before_each() -> void:
	_settings_temp_path = temp_path("hint_qa_settings", "cfg")
	remove_test_temp_file(_settings_temp_path)
	_data = GameData.load_default()
	_state = GameState.new(_data, 1337)
	_state.waves.enabled = false

func after_each() -> void:
	if _panel:
		_panel.free()
	_panel = null
	_state = null
	_data = null
	remove_test_temp_file(_settings_temp_path)

func test_changed_unlock_data_and_late_hint_priority() -> void:
	_state.clock.elapsed = float(_data.balance("day_length")) * float(_data.expeditions().get("morning_fraction", 0.4))
	_data.get_building("workshop")["unlock_day"] = 5
	_data.get_building("radio_tower")["unlock_day"] = 5
	_state.resources.take("ammo", _state.resources.get_amount("ammo"))
	var hints := TutorialHints.new()
	_state.clock.day = 4
	assert_eq(hints.check(_state, 0.0), "", "Both unlock hints must use changed data")
	_state.clock.day = 5
	_state.survivors.all()[0].hungry_days = 1
	assert_eq(hints.check(_state, 0.0), "ammo", "Ammo takes priority over hunger and radio")
	assert_eq(hints.shown.size(), 1, "Only one hint is consumed by a check")
	assert_eq(hints.check(_state, 0.0), "hungry")
	assert_eq(hints.shown.size(), 2)
	assert_eq(hints.check(_state, 0.0), "radio")
	for _i: int in range(5):
		assert_eq(hints.check(_state, 1.0), "", "No late hint may repeat")

func test_ammo_threshold_and_completed_workshop_suppression() -> void:
	_state.clock.day = int(_data.get_building("workshop")["unlock_day"])
	_state.resources.take("ammo", _state.resources.get_amount("ammo"))
	_state.resources.add("ammo", 30)
	var hints := TutorialHints.new()
	hints.shown["scavenge"] = true
	assert_eq(hints.check(_state, 0.0), "", "30 ammo must not trigger the hint")
	_state.resources.take("ammo", 1)
	assert_eq(hints.check(_state, 0.0), "ammo", "29 ammo triggers the hint")
	_state.buildings.add("workshop", _state.map.command_center_origin() + Vector2i(4, 0), true)
	var suppressed := TutorialHints.new()
	suppressed.shown["scavenge"] = true
	assert_eq(suppressed.check(_state, 0.0), "", "Completed Workshop suppresses ammo hint")

func test_exact_night_threshold_and_day_one_only() -> void:
	var hints := TutorialHints.new()
	hints.shown["welcome"] = true
	_state.buildings.add("farm", _state.map.command_center_origin() + Vector2i(4, 0), true)
	_state.clock.elapsed = float(_data.balance("day_length")) - 30.001
	assert_eq(hints.check(_state, 20.0), "")
	_state.clock.elapsed = float(_data.balance("day_length")) - 30.0
	assert_eq(hints.check(_state, 0.0), "night_soon")
	_state.clock.day = 2
	_state.clock.elapsed = 0.0
	assert_eq(TutorialHints.new().check(_state, 25.0), "scavenge", "Day 2 teaches scavenging")
	var day_two := TutorialHints.new()
	day_two.shown["scavenge"] = true
	assert_eq(day_two.check(_state, 25.0), "", "Early-game hints are day 1 only")
	assert_almost_eq(hints.day_time, 20.0)
	hints.check(_state, 2.0)
	assert_almost_eq(hints.day_time, 2.0, 0.001, "Daytime counter resets on new day")

func test_blocked_checks_do_not_consume_eligible_hints() -> void:
	var hints := TutorialHints.new()
	_state.survivors.all()[0].hungry_days = 1
	hints.enabled = false
	assert_eq(hints.check(_state, 25.0), "")
	assert_true(hints.shown.is_empty())
	hints.enabled = true
	_state.game_over = true
	assert_eq(hints.check(_state, 0.0), "")
	assert_true(hints.shown.is_empty())
	_state.game_over = false
	_state.clock.phase = GameClock.Phase.NIGHT
	assert_eq(hints.check(_state, 10.0), "")
	assert_true(hints.shown.is_empty())
	_state.clock.phase = GameClock.Phase.DAY
	assert_eq(hints.check(_state, 0.0), "welcome")
	assert_eq(hints.check(_state, 0.0), "farm")
	assert_eq(hints.check(_state, 0.0), "hungry")
	assert_eq(hints.check(_state, 0.0), "")

func _make_panel() -> void:
	_panel = preload("res://scenes/ui/hint_panel.tscn").instantiate() as HintPanel
	_panel._ready()
	_panel.bind(_state)
	_panel.set_enabled(true)

func test_panel_queues_dismisses_and_times_out_without_pausing() -> void:
	_make_panel()
	_panel._process(0.0)
	assert_eq(_panel.current_hint(), "welcome")
	_panel._hints.day_time = 20.0
	_panel._process(0.0)
	assert_eq(_panel.current_hint(), "welcome")
	assert_eq(_panel._queue.size(), 1)
	var button: Button = _panel.get_node("PanelContainer/MarginContainer/VBoxContainer/BottomRow/GotItButton")
	button.pressed.emit()
	assert_eq(_panel.current_hint(), "farm")
	_panel._process(11.9)
	assert_true(_panel.is_showing())
	_panel._process(0.2)
	assert_false(_panel.is_showing())
	assert_false(_state.clock.paused, "Neither dismissal nor timeout pauses the game")

func test_panel_clock_scaling_pause_disable_and_fresh_bind() -> void:
	_make_panel()
	_state.clock.set_paused(true)
	_panel._process(30.0)
	assert_eq(_panel.current_hint(), "")
	assert_true(_panel._hints.shown.is_empty())
	_state.clock.set_speed(2)
	_panel._process(0.0)
	_panel._process(10.0)
	assert_has(_panel._hints.shown, "farm", "Checks use scaled clock delta")
	_panel.set_enabled(false)
	assert_false(_panel.is_showing())
	assert_true(_panel._queue.is_empty())
	_panel._process(30.0)
	assert_false(_panel.is_showing())
	_panel.bind(GameState.new(_data, 1337))
	_panel.set_enabled(true)
	_panel._process(0.0)
	assert_eq(_panel.current_hint(), "welcome", "A new binding starts fresh hints")

func test_settings_defaults_and_audio_saves_preserve_hints() -> void:
	var path: String = _settings_temp_path
	assert_true(HintSettings.load_enabled(path), "Missing settings default to enabled")
	HintSettings.save_enabled(false, path)
	AudioSettings.save_volumes({"Master": 0.25, "SFX": 0.5, "Music": 0.75}, path)
	assert_false(HintSettings.load_enabled(path), "Changing audio must preserve hint preference")
	HintSettings.save_enabled(true, path)
	assert_eq(AudioSettings.load_volumes(path), {"Master": 0.25, "SFX": 0.5, "Music": 0.75})
