extends TestCase

var panel: DawnReportPanel
var state: GameState

func before_each() -> void:
	state = GameState.new(GameData.load_default(), 1337)
	panel = (load("res://scenes/ui/dawn_report.tscn") as PackedScene).instantiate() as DawnReportPanel
	panel.bind(state)

func after_each() -> void:
	panel.free()

func test_panel_flow() -> void:
	# Tick through night 1
	state.waves.enabled = false
	state.clock.phase_changed.emit(GameClock.Phase.NIGHT, state.clock.day)
	state.clock.phase = GameClock.Phase.NIGHT
	state.clock.elapsed = float(state.data.balance("night_min_length")) - 0.1
	state.tick(0.2)
	
	var report = state.last_dawn_report
	
	assert_false(panel.visible)
	panel._show_report(report)
	
	assert_true(panel.visible)
	assert_true(state.clock.paused)
	
	var title = panel.get_node("Center/Panel/Margin/Content/Title") as Label
	var subtitle = panel.get_node("Center/Panel/Margin/Content/Subtitle") as Label
	var lines = panel.get_node("Center/Panel/Margin/Content/Scroll/Lines") as Control
	
	assert_eq(title.text, "DAWN: DAY 2")
	assert_eq(subtitle.text, "Night 1 survived")
	
	var expected_lines = DawnReportPanel.report_rows(report)
	assert_eq(lines.get_child_count(), expected_lines.size() * 2)
	
	# _on_continue hides and unpauses
	panel._on_continue()
	assert_false(panel.visible)
	assert_false(state.clock.paused)

func test_clock_already_paused() -> void:
	state.waves.enabled = false
	state.clock.phase_changed.emit(GameClock.Phase.NIGHT, state.clock.day)
	state.clock.phase = GameClock.Phase.NIGHT
	state.clock.elapsed = float(state.data.balance("night_min_length")) - 0.1
	state.tick(0.2)
	
	var report = state.last_dawn_report
	
	state.clock.set_paused(true)
	panel._show_report(report)
	assert_true(panel.visible)
	assert_true(state.clock.paused)
	
	panel._on_continue()
	assert_false(panel.visible)
	assert_true(state.clock.paused) # Should stay paused

func test_no_stale_rows() -> void:
	state.waves.enabled = false
	state.clock.phase_changed.emit(GameClock.Phase.NIGHT, state.clock.day)
	state.clock.phase = GameClock.Phase.NIGHT
	state.clock.elapsed = float(state.data.balance("night_min_length")) - 0.1
	state.tick(0.2)
	
	var report1 = state.last_dawn_report
	
	state.clock.phase_changed.emit(GameClock.Phase.NIGHT, state.clock.day)
	state.clock.phase = GameClock.Phase.NIGHT
	state.clock.elapsed = float(state.data.balance("night_min_length")) - 0.1
	state.tick(0.2)
	
	var report2 = state.last_dawn_report
	
	panel._show_report(report1)
	panel._show_report(report2)
	
	var lines = panel.get_node("Center/Panel/Margin/Content/Scroll/Lines") as Control
	assert_eq(lines.get_child_count(), DawnReportPanel.report_rows(report2).size() * 2)

func test_hidden_with_game_over() -> void:
	state.game_over = true
	panel._show_report({"night": 1})
	assert_false(panel.visible)
	assert_false(state.clock.paused)

func test_dawn_processed_does_not_pause_synchronously() -> void:
	assert_false(state.clock.paused)
	state.dawn_processed.emit({"night": 1})
	assert_false(state.clock.paused) # Should be deferred

func test_continue_button_restores_clock() -> void:
	panel._show_report({"day": 2, "night": 1})
	var button: Button = panel.get_node("Center/Panel/Margin/Content/Buttons/Continue") as Button
	button.pressed.emit()
	assert_false(panel.visible)
	assert_false(state.clock.paused)

func test_replacement_rows_match_report_text_and_original_pause() -> void:
	var first: Dictionary = {"day": 2, "night": 1, "zombies_killed": 5,
		"food_eaten": 3, "unlocked": ["Storage", "Watchtower", "Workshop"]}
	var second: Dictionary = {"day": 3, "night": 2, "objective": "Next objective"}
	panel._show_report(first)
	panel._show_report(second)
	var rows: GridContainer = panel.get_node("Center/Panel/Margin/Content/Scroll/Lines") as GridContainer
	var expected: Array[Array] = DawnReportPanel.report_rows(second)
	assert_eq(rows.get_child_count(), expected.size() * 2)
	for i: int in range(expected.size()):
		assert_eq((rows.get_child(i * 2) as Label).text, expected[i][0])
		assert_eq((rows.get_child(i * 2 + 1) as Label).text, expected[i][1])
	panel._on_continue()
	assert_false(state.clock.paused, "Updating a visible panel preserves the original pause state")

func test_hidden_with_victory() -> void:
	state.game_over = true
	state.won = true
	panel._show_report({"day": 21, "night": 20})
	assert_false(panel.visible)
	assert_false(state.clock.paused)

func test_long_report_caps_rows_and_keeps_continue_outside_scroll() -> void:
	var fixture: GDScript = load("res://dev/scenarios/dawn_report_long.gd")
	var report: Dictionary = fixture.report()
	assert_eq(report.survivors_killed.size(), 6)
	assert_eq(report.buildings_destroyed.size(), 6)
	panel._show_report(report)
	var scroll: ScrollContainer = panel.get_node(DawnReportPanel.CONTENT + "Scroll")
	var lines: GridContainer = scroll.get_node("Lines")
	# Model the wrapped height; real viewport geometry is checked in qa_m4_menu_flow.
	lines.custom_minimum_size.y = 900.0
	panel.fit_lines_height(720.0)
	assert_lt(scroll.custom_minimum_size.y, 900.0, "Long rows are capped")
	assert_true(panel.get_node("Center/Panel").get_combined_minimum_size().y <= 672.0,
		"Panel reserves 24px margins above and below at 720px")
	assert_eq(scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED)
	var button: Button = panel.get_node(DawnReportPanel.CONTENT + "Buttons/Continue")
	assert_false(scroll.is_ancestor_of(button), "Continue stays outside the clipped rows")
	panel.fit_lines_height(600.0)
	assert_true(panel.get_node("Center/Panel").get_combined_minimum_size().y <= 552.0,
		"Cap adapts to smaller viewports")

func test_short_report_keeps_natural_height() -> void:
	panel._show_report({"day": 2, "night": 1, "zombies_killed": 5})
	panel.fit_lines_height(720.0)
	var scroll: ScrollContainer = panel.get_node(DawnReportPanel.CONTENT + "Scroll")
	var lines: GridContainer = scroll.get_node("Lines")
	assert_eq(scroll.custom_minimum_size.y, lines.get_combined_minimum_size().y,
		"Short reports do not reserve empty scroll space")
