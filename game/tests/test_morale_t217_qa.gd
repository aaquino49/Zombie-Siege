extends TestCase
## T-217 acceptance gaps: actual UI signals, changed balance and save extras.

var _state: GameState
var _selection: SelectionController
var _panel: InfoPanel
var _roster: RosterPanel

func before_each() -> void:
	_state = GameState.new(GameData.load_default(), 1337)
	_state.waves.enabled = false
	_state.clock.day = 5
	_state.clock.elapsed = 5.0
	_selection = SelectionController.new()
	_selection.bind(_state)

func after_each() -> void:
	if _panel != null: _panel.free()
	if _roster != null: _roster.free()
	_selection.free()
	_state = null

func _make_panel() -> void:
	_panel = load("res://scenes/ui/info_panel.tscn").instantiate() as InfoPanel
	_panel.set_script(ToastPanel)
	_panel.bind(_state, _selection)

func _make_roster() -> void:
	_roster = load("res://scenes/ui/roster_panel.tscn").instantiate() as RosterPanel
	_roster.bind(_state, _selection)
	_roster.toggle()

func test_feast_ui_uses_changed_cost_cooldown_and_success_only_toast() -> void:
	var config: Dictionary = _state.data.morale_config()
	config["feast"]["food_per_survivor"] = 3
	config["feast"]["cooldown_days"] = 4
	config["moods"]["feast"]["value"] = 17
	_make_panel()
	_selection.select_building(_state.buildings.all_of_type("command_center")[0].uid)
	var button: Button = _panel.get_node("PanelContainer/VBoxContainer/FeastButton")
	assert_eq(button.text, "Hold a feast (-12 food)")
	var food: int = _state.resources.get_amount("food")
	button.pressed.emit()
	assert_eq(_state.resources.get_amount("food"), food - 12)
	assert_eq(_panel.get("messages"), ["Feast! Everyone +17 morale"] as Array[String])
	assert_true(button.disabled)
	assert_eq(button.tooltip_text, "Next feast: day 9")
	button.pressed.emit()
	assert_eq(_panel.get("messages").size(), 1, "rejected re-click emits no toast")
	_state.last_feast_day = 0
	_state.clock.phase = GameClock.Phase.NIGHT
	_panel.refresh()
	assert_eq(button.tooltip_text, "Night")
	button.pressed.emit()
	assert_eq(_state.resources.get_amount("food"), food - 12)
	assert_eq(_panel.get("messages").size(), 1)

func test_info_day_off_rejects_night_late_morning_and_refusal_then_refreshes() -> void:
	_make_panel()
	var s: Survivor = _state.survivors.all()[0]
	_selection.select_survivor(s.uid)
	var button: Button = _panel.get_node("PanelContainer/VBoxContainer/SurvivorActions/DayOffButton")
	var cutoff: float = float(_state.data.balance("day_length")) * float(_state.data.morale_config()["day_off_morning_fraction"])
	for night: bool in [true, false]:
		_state.clock.phase = GameClock.Phase.NIGHT if night else GameClock.Phase.DAY
		_state.clock.elapsed = 5.0 if night else cutoff
		_panel.refresh()
		assert_true(button.disabled)
		assert_eq(button.tooltip_text, "Not morning")
		button.pressed.emit()
		assert_false(s.day_off)
	_state.clock.elapsed = 5.0
	s.refusing = true
	_panel.refresh()
	assert_true(button.disabled)
	assert_eq(button.tooltip_text, "Refusing work")
	button.pressed.emit()
	assert_false(s.day_off)
	s.refusing = false
	_panel.refresh()
	assert_false(button.disabled)
	button.pressed.emit()
	assert_true(s.day_off)
	assert_true(button.disabled)
	assert_eq(button.tooltip_text, "Already off")
	assert_eq(_panel.get_node("PanelContainer/VBoxContainer/ActivityLabel").text, "Day off")

func test_roster_day_off_signal_and_refusal_refresh() -> void:
	_make_roster()
	var s: Survivor = _state.survivors.all()[0]
	var row: Node = _roster.get_node("PanelContainer/VBox/ScrollContainer/Rows").get_child(0)
	var button: Button = row.get_node("DayOffButton")
	s.refusing = true
	_roster.refresh()
	assert_eq((row.get_child(2) as Label).text, "Refusing work")
	assert_true(button.disabled)
	button.pressed.emit()
	assert_false(s.day_off)
	s.refusing = false
	_roster.refresh()
	button.pressed.emit()
	assert_true(s.day_off)
	assert_eq((row.get_child(2) as Label).text, "Day off")
	assert_eq(button.tooltip_text, "Already off")
	assert_true((row.get_node("ScavengeButton") as Button).disabled)

func test_roster_existing_selection_jobs_and_scavenge_signals_work() -> void:
	_make_roster()
	var s: Survivor = _state.survivors.all()[0]
	var row: Node = _roster.get_node("PanelContainer/VBox/ScrollContainer/Rows").get_child(0)
	(row.get_child(0) as Button).pressed.emit()
	assert_eq(_selection.selected_uid, s.uid)
	var options: OptionButton = row.get_child(1)
	assert_eq(options.item_count, JobOptions.LABELS.size())
	for index: int in range(options.item_count):
		options.item_selected.emit(index)
		assert_eq(JobOptions.index_for(s), index)
	options.item_selected.emit(1)
	_roster.refresh()
	(row.get_node("ScavengeButton") as Button).pressed.emit()
	assert_true(_state.expeditions.is_running(s))
	assert_true(options.disabled)
	assert_eq((row.get_node("DayOffButton") as Button).tooltip_text, "Away")

func test_morale_seen_hint_survives_serialized_save_and_panel_restore() -> void:
	var hints: HintPanel = load("res://scenes/ui/hint_panel.tscn").instantiate() as HintPanel
	hints.bind(_state)
	hints.set_enabled(true)
	hints.set_shown({"welcome": true, "farm": true, "night_soon": true, "ammo": true, "scavenge": true, "hungry": true, "radio": true, "spitters": true})
	var s: Survivor = _state.survivors.all()[0]
	s.moods.clear()
	Morale.add_mood(_state, s, "hungry")
	assert_eq(hints._hints.check(_state, 0.0), "morale")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(SaveGame.capture(_state, {"hints": hints.get_shown()})))
	var restored: GameState = SaveGame.restore(_state.data, saved)
	assert_not_null(restored)
	if restored != null:
		hints.bind(restored)
		hints.set_enabled(true)
		hints.set_shown(saved["extra"]["hints"])
		assert_true(hints.get_shown().has("morale"))
		assert_eq(hints._hints.check(restored, 0.0), "")
	hints.free()

class ToastPanel extends InfoPanel:
	var messages: Array[String] = []
	func _toast(text: String) -> void:
		messages.append(text)
