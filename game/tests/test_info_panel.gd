extends "res://tests/test_case.gd"

const SelectionController = preload("res://scripts/world/selection_controller.gd")

func test_info_panel() -> void:
	var data = preload("res://scripts/sim/game_data.gd").load_default()
	var state = GameState.new(data, 12345)
	
	var selection = preload("res://scripts/world/selection_controller.gd").new()
	selection.bind(state)
	
	var panel = preload("res://scenes/ui/info_panel.tscn").instantiate()
	panel.bind(state, selection)
	panel.refresh()
	
	assert_false(panel.visible, "hidden initially")
	
	var s = state.survivors.add("Test", "blue", Vector2i(0, 0))
	s.name = "Test Survivor"
	s.hp = 20
	s.max_hp = 50
	selection.select_survivor(s.uid)
	panel.refresh()
	
	assert_true(panel.visible, "visible when survivor selected")
	assert_eq(panel._name_label.text, "Test Survivor", "name matches")
	assert_eq(panel._hp_label.text, "HP 20/50", "hp matches")
	
	s.hungry_days = 1
	panel.refresh()
	assert_eq(panel._activity_label.text, "Idle · Hungry", "hungry status is visible")
	s.hungry_days = 0
	panel.refresh()
	assert_eq(panel._activity_label.text, "Idle", "fed status clears suffix")

	panel._on_job_selected(4)
	assert_eq(s.job, Survivor.Job.BUILDER, "job changes via button")
	
	state.buildings.add("farm", Vector2i(0, 0), false)
	var b = state.buildings.all()[1]
	b.hp = 10
	b.max_hp = 100
	
	selection.select_building(b.uid)
	panel.refresh()
	assert_eq(panel._name_label.text, "Farm", "building name")
	assert_true(panel._cancel_btn.visible, "cancel btn visible for blueprint")
	
	panel._on_cancel_pressed()
	assert_eq(state.buildings.all().size(), 1, "building canceled")
	
	panel.free()
	selection.free()
