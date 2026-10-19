extends TestCase

var _state: GameState
var _bar: BuildBar

func before_each() -> void:
	_state = GameState.new(GameData.load_default(), 1337)
	_bar = preload("res://scenes/ui/build_bar.tscn").instantiate() as BuildBar
	_bar.bind(_state)

func after_each() -> void:
	if _bar != null:
		_bar.free()
	_bar = null
	_state = null

func _placeable_unlock_count(day: int) -> int:
	var count: int = 0
	for type_id: String in _state.data.buildings_unlocked_on(day):
		if Placement.is_placeable_type(_state.data, type_id):
			count += 1
	return count

func test_refresh_if_stale_rebuilds_for_new_day_only_once() -> void:
	assert_eq(_bar._hbox().get_child_count(), _placeable_unlock_count(1),
		"Bind builds the day 1 bar")
	_state.clock.day = 9
	_bar.refresh_if_stale()
	assert_eq(_bar._hbox().get_child_count(), _placeable_unlock_count(9),
		"Stale bar rebuilds with all day 9 placeable buildings")
	var button_instances: Array[Button] = []
	for index: int in range(_bar._hbox().get_child_count()):
		var button: Button = _bar._hbox().get_child(index) as Button
		button_instances.append(button)
		if index < 9:
			var hotkey: Label = button.get_node("Hotkey") as Label
			assert_eq(hotkey.text, "F%d" % (index + 1), "Day 9 bound caption %d remains unchanged" % (index + 1))
		else:
			assert_true(button.get_node_or_null("Hotkey") == null,
				"Day 9 button %d has no unbound hotkey caption" % (index + 1))
	_bar.refresh_if_stale()
	assert_eq(_bar._hbox().get_child_count(), button_instances.size(), "Unchanged day keeps button count")
	for index: int in range(button_instances.size()):
		assert_eq(_bar._hbox().get_child(index), button_instances[index],
			"Unchanged day keeps button instance %d" % index)
