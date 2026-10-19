extends "res://tests/test_case.gd"

const SelectionController = preload("res://scripts/world/selection_controller.gd")

func test_selection() -> void:
	var data = preload("res://scripts/sim/game_data.gd").load_default()
	var state = GameState.new(data, 12345)
	
	var selection = preload("res://scripts/world/selection_controller.gd").new()
	selection.bind(state)
	
	var s = state.survivors.add("Test", "blue", Vector2i(1, 1))
	state.buildings.add("farm", Vector2i(3, 3), true)
	var b = state.buildings.all()[1] # 0 is command center
	
	selection.select_at_world(Vector2(100, 100))
	assert_eq(selection.selected_kind, "survivor", "selects survivor")
	assert_eq(selection.selected_uid, s.uid, "correct uid")
	
	selection.select_at_world(Vector2(3 * 64 + 32, 3 * 64 + 32))
	assert_eq(selection.selected_kind, "building", "selects building")
	assert_eq(selection.selected_uid, b.uid, "correct building uid")
	
	selection.select_at_world(Vector2(1000, 1000))
	assert_eq(selection.selected_kind, "", "clears on empty")
	
	selection.select_survivor(s.uid)
	state.survivors.remove(s.uid)
	assert_eq(selection.selected_kind, "", "clears when survivor removed")
	
	selection.select_building(b.uid)
	state.buildings.remove(b.uid)
	assert_eq(selection.selected_kind, "", "clears when building removed")
	
	selection.free()
