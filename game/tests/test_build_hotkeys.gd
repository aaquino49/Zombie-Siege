extends TestCase

var _state: GameState
var _bar: BuildBar
var _selections: Array[String]

func before_each() -> void:
	_state = GameState.new(GameData.load_default(), 1337)
	_bar = preload("res://scenes/ui/build_bar.tscn").instantiate() as BuildBar
	_bar.bind(_state)
	_selections = []
	_bar.building_selected.connect(func(type_id: String) -> void: _selections.append(type_id))

func after_each() -> void:
	if _bar != null:
		_bar.free()
	_bar = null
	_state = null

func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	return event

func test_f3_selects_third_button_and_again_cancels() -> void:
	var third_button := _bar._hbox().get_child(2) as Button
	assert_eq((third_button.get_node("Hotkey") as Label).text, "F3", "Third button displays F3")
	assert_eq(BuildInfoCard.lines_for(_state.data, _state.resources, "farm", "F3")[0], "[F3] Farm",
		"Info card prefixes the building name with its hotkey")
	_bar._unhandled_input(_key(KEY_F3))
	assert_eq(_selections, ["farm"], "F3 picks the third day-1 build button")
	assert_true(third_button.button_pressed, "Third button enters selected state")

	_bar._unhandled_input(_key(KEY_F3))
	assert_eq(_selections, ["farm", ""], "F3 toggles the active button off")
	assert_false(third_button.button_pressed, "Second F3 cancels selection")

func test_f9_without_ninth_button_does_nothing() -> void:
	_bar._unhandled_input(_key(KEY_F9))
	assert_eq(_selections.size(), 0, "F9 has no day-1 button to select")

func test_day_eight_tenth_button_and_info_card_have_no_unbound_hotkey() -> void:
	_bar.refresh(8)
	var buttons: Array[Node] = _bar._hbox().get_children()
	assert_eq(buttons.size(), 12, "Day 8 has twelve build buttons after Field Lab unlock")
	for index: int in range(9):
		var button: Button = buttons[index] as Button
		var hotkey: Label = button.get_node("Hotkey") as Label
		assert_eq(hotkey.text, "F%d" % (index + 1), "Bound caption %d remains unchanged" % (index + 1))
	var tenth_button: Button = buttons[9] as Button
	assert_true(tenth_button.get_node_or_null("Hotkey") == null, "Tenth button has no unbound hotkey caption")
	assert_eq(_bar._hotkey_for_type("radio_tower"), "", "Radio Tower has no unbound hotkey")
	_bar.show_info("radio_tower")
	var name_label: Label = _bar._card().get_node("VBox/Name") as Label
	assert_eq(name_label.text, "Radio Tower", "Radio Tower info title has no key prefix")

func test_hotkey_does_nothing_while_pause_menu_locks_clock() -> void:
	_state.clock.locked = true
	_state.clock.set_paused(true)
	_bar._unhandled_input(_key(KEY_F3))
	assert_eq(_selections.size(), 0, "Pause menu lock blocks build hotkeys")
	assert_false((_bar._hbox().get_child(2) as Button).button_pressed)

func test_number_keys_remain_speed_actions_and_do_not_select_buildings() -> void:
	var codes: Array[Key] = [KEY_1, KEY_2, KEY_3]
	for index: int in range(codes.size()):
		var event := _key(codes[index])
		assert_true(event.is_action_pressed("speed_%d" % (index + 1)), "Number key remains mapped to speed")
		_bar._unhandled_input(event)
	assert_eq(_selections.size(), 0, "Speed keys do not select a build button")
