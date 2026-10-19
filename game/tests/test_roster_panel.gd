extends "res://tests/test_case.gd"

const SelectionController = preload("res://scripts/world/selection_controller.gd")

func test_roster_panel() -> void:
	var data = preload("res://scripts/sim/game_data.gd").load_default()
	var state = GameState.new(data, 12345)
	
	var selection = preload("res://scripts/world/selection_controller.gd").new()
	selection.bind(state)
	
	var panel = preload("res://scenes/ui/roster_panel.tscn").instantiate()
	panel.bind(state, selection)
	
	assert_false(panel.is_open(), "starts closed")
	panel.toggle()
	assert_true(panel.is_open(), "toggle opens")
	
	assert_eq(panel._vbox.get_child_count(), 4, "4 rows initially")
	
	var s = state.survivors.add("Test", "blue", Vector2i(0, 0))
	assert_eq(panel._vbox.get_child_count(), 5, "adds row on survivor added")
	
	s.hungry_days = 1
	panel.refresh()
	var row = panel._vbox.get_child(4)
	assert_eq((row.get_child(2) as Label).text, "Idle · Hungry", "roster hunger suffix")
	s.hungry_days = 0
	panel.refresh()
	assert_eq((row.get_child(2) as Label).text, "Idle", "roster hunger suffix clears")
	var btn: Button = row.get_child(0)
	btn.pressed.emit()
	assert_eq(selection.selected_kind, "survivor", "selects survivor on press")
	assert_eq(selection.selected_uid, s.uid, "selects correct uid")
	
	var job_btn: OptionButton = row.get_child(1)
	job_btn.item_selected.emit(4)
	assert_eq(s.job, Survivor.Job.BUILDER, "changes job from roster")
	
	state.survivors.remove(s.uid)
	assert_eq(panel._vbox.get_child_count(), 4, "removes row")
	
	panel.free()
	selection.free()

func test_roster_height_follows_population_and_caps() -> void:
	var state: GameState = GameState.new(GameData.load_default(), 12345)
	var selection: SelectionController = SelectionController.new()
	selection.bind(state)
	var panel: RosterPanel = preload("res://scenes/ui/roster_panel.tscn").instantiate()
	panel.bind(state, selection)
	assert_eq(panel._scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED)
	var initial_height: float = panel._panel.size.y
	assert_lt(initial_height, 420.0, "four survivors hug their content")
	var added: Array[int] = []
	for i in range(20):
		added.append(state.survivors.add("Extra", "blue", Vector2i.ZERO).uid)
	assert_gt(panel._panel.size.y, initial_height, "roster grows with population")
	assert_almost_eq(panel._panel.size.y, 420.0, 0.01, "large roster height is capped")
	assert_eq(panel._scroll.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_AUTO, "extra rows scroll vertically")
	for uid in added:
		state.survivors.remove(uid)
	assert_almost_eq(panel._panel.size.y, initial_height, 0.01, "roster shrinks after departures")
	var row: HBoxContainer = panel._vbox.get_child(0)
	var activity: Label = row.get_child(2)
	assert_true(activity.clip_text)
	assert_eq(activity.size_flags_horizontal, Control.SIZE_EXPAND_FILL)
	var available_width: float = panel._panel.size.x - panel._panel.get_theme_stylebox("panel").get_minimum_size().x
	available_width -= (row.get_child(0) as Button).get_combined_minimum_size().x
	available_width -= (row.get_child(1) as OptionButton).get_combined_minimum_size().x
	available_width -= row.get_theme_constant("separation") * 2
	var long_activity_width: float = activity.get_theme_font("font").get_string_size("Harvesting \u00b7 Hungry", HORIZONTAL_ALIGNMENT_LEFT, -1, activity.get_theme_font_size("font_size")).x
	assert_true(available_width >= long_activity_width, "long activity fits alongside name and longest job")
	panel.free()
	selection.free()

func test_every_roster_index_preserves_job_and_gather_kind() -> void:
	var state := GameState.new(GameData.load_default(), 1337)
	var selection := SelectionController.new()
	selection.bind(state)
	var panel := preload("res://scenes/ui/roster_panel.tscn").instantiate() as RosterPanel
	panel.bind(state, selection)
	panel.toggle()
	var survivor: Survivor = state.survivors.all()[0]
	var jobs: Array[int] = [Survivor.Job.IDLE, Survivor.Job.GATHERER, Survivor.Job.GATHERER, Survivor.Job.FARMER, Survivor.Job.BUILDER, Survivor.Job.CRAFTER, Survivor.Job.GUARD, Survivor.Job.RESEARCHER]
	var labels: Array[String] = ["Idle", "Wood", "Scrap", "Farmer", "Builder", "Crafter", "Guard", "Research"]
	var button: OptionButton = panel._vbox.get_child(0).get_child(1)
	for index: int in range(jobs.size()):
		assert_eq(button.get_item_text(index), labels[index])
		button.item_selected.emit(index)
		assert_eq(survivor.job, jobs[index], "same job at index %d" % index)
		if index == 1 or index == 2:
			assert_eq(survivor.gather_kind, "wood" if index == 1 else "scrap")
		assert_eq(JobOptions.index_for(survivor), index)
		panel.refresh()
		assert_eq(button.selected, index)
		assert_eq(button.tooltip_text, JobOptions.LABELS[index])
	panel.free()
	selection.free()
