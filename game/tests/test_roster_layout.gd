extends TestCase
## T-177: the open roster stays clear of the forecast, toast lane, and build bar.

const STATUS_TEXTS: Array[String] = ["Walking", "Gathering wood \u00b7 Hungry", "Away till dusk"]
const SCREEN_SIZE := Vector2(1280.0, 720.0)

var _state: GameState
var _selection: SelectionController
var _roster: RosterPanel

func before_each() -> void:
	_state = GameState.new(GameData.load_default(), 1337)
	_state.waves.enabled = false
	_selection = SelectionController.new()
	_selection.bind(_state)
	_roster = (load("res://scenes/ui/roster_panel.tscn") as PackedScene).instantiate() as RosterPanel
	_roster.bind(_state, _selection)
	_roster.toggle()

func after_each() -> void:
	_roster.free()
	_selection.free()
	_state = null

func test_roster_fits_1280x720_hud_and_status_copy() -> void:
	var panel: PanelContainer = _roster.get_node("PanelContainer") as PanelContainer
	var panel_rect := Rect2(SCREEN_SIZE.x + panel.offset_left, panel.offset_top,
		panel.offset_right - panel.offset_left, _roster._panel.size.y)
	var hud: CanvasLayer = (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate() as CanvasLayer
	hud.call("_ensure_toast_box")
	var forecast_control: Control = hud.get_node("NightForecast") as Control
	var forecast := Rect2(forecast_control.offset_left, forecast_control.offset_top,
		SCREEN_SIZE.x + forecast_control.offset_right - forecast_control.offset_left,
		forecast_control.offset_bottom - forecast_control.offset_top)
	var toast_control: Control = hud.get_node("ToastLayer/ScavengeToasts") as Control
	var toast := Rect2(toast_control.offset_left, toast_control.offset_top,
		toast_control.offset_right - toast_control.offset_left, SCREEN_SIZE.y - toast_control.offset_top)
	assert_false(panel_rect.intersects(forecast), "roster must leave the night forecast readable")
	assert_false(panel_rect.intersects(toast), "roster must leave the scavenge toast lane clear")
	hud.free()

	var build_bar: BuildBar = (load("res://scenes/ui/build_bar.tscn") as PackedScene).instantiate() as BuildBar
	build_bar.bind(_state)
	var build_panel: PanelContainer = build_bar._panel()
	var build_height: float = build_panel.get_combined_minimum_size().y
	var build_rect := Rect2(0.0, SCREEN_SIZE.y - 8.0 - build_height, SCREEN_SIZE.x, build_height)
	assert_false(panel_rect.intersects(build_rect), "roster must end above the build bar")
	var capped_panel_rect := Rect2(panel_rect.position.x, panel_rect.position.y,
		panel_rect.size.x, RosterPanel.MAX_PANEL_HEIGHT)
	assert_false(capped_panel_rect.intersects(build_rect), "roster height cap stays above the build bar")

	var font: Font = load("res://assets/pixel/ui/font/siege_pixel_noliga.tres") as Font
	for row_node: Node in _roster._vbox.get_children():
		var row := row_node as HBoxContainer
		var status := row.get_child(2) as Label
		for status_text: String in STATUS_TEXTS:
			status.text = status_text
			var required_width: float = font.get_string_size(status_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.BODY).x
			assert_true(status.custom_minimum_size.x >= required_width,
				"status minimum width fits %s" % status_text)
		var required_row_width: float = row.get_combined_minimum_size().x
		var panel_content_width: float = panel_rect.size.x - panel.get_theme_stylebox("panel").get_minimum_size().x
		assert_true(required_row_width <= panel_content_width,
			"row child minimum widths fit without overlapping: %.1f <= %.1f" % [required_row_width, panel_content_width])
		assert_eq((row.get_child(3) as Button).text, "Scavenge", "short row action preserves status space")
	build_bar.free()

func test_full_roster_names_jobs_and_actions_fit_measured_widths() -> void:
	var names: Array = _state.data.balance("survivor_names")
	for survivor_name: String in names:
		_state.survivors.add(survivor_name, "blue", Vector2i.ZERO)
	var panel: PanelContainer = _roster._panel
	var content_width: float = 720.0 - panel.get_theme_stylebox("panel").get_minimum_size().x
	content_width -= _roster._scroll.get_v_scroll_bar().get_combined_minimum_size().x
	assert_eq(panel.size.y, RosterPanel.MAX_PANEL_HEIGHT, "full roster uses vertical scrolling")
	for row: HBoxContainer in _roster._vbox.get_children():
		var name_button: Button = row.get_child(0)
		var job_button: OptionButton = row.get_child(1)
		var font: Font = name_button.get_theme_font("font")
		assert_false(name_button.clip_text)
		assert_false(job_button.clip_text)
		assert_eq(name_button.get_theme_font_size("font_size"), UiFont.SMALL)
		assert_eq(job_button.get_theme_font_size("font_size"), UiFont.SMALL)
		for survivor_name: String in names:
			var width: float = font.get_string_size(survivor_name, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.SMALL).x
			width += name_button.get_theme_stylebox("normal").get_minimum_size().x
			assert_true(name_button.custom_minimum_size.x >= width, "name column fits " + survivor_name)
		for index: int in range(JobOptions.SHORT_LABELS.size()):
			job_button.select(index)
			var label: String = JobOptions.SHORT_LABELS[index]
			var width: float = job_button.get_theme_font("font").get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.SMALL).x
			width += job_button.get_theme_stylebox("normal").get_minimum_size().x + job_button.get_theme_icon("arrow").get_width()
			width += job_button.get_theme_constant("arrow_margin") + job_button.get_theme_constant("h_separation")
			assert_true(job_button.custom_minimum_size.x >= width, "job column fits " + label)
			assert_true(row.get_combined_minimum_size().x <= content_width, "all columns fit with a scrollbar for " + label)
		var status: Label = row.get_child(2)
		assert_true(status.clip_text)
		assert_eq(status.get_theme_font_size("font_size"), UiFont.BODY)
		for action_name: String in ["ScavengeButton", "DayOffButton"]:
			var action: Button = row.get_node(action_name)
			var required: float = action.get_theme_font("font").get_string_size(action.text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.SMALL).x
			required += action.get_theme_stylebox("normal").get_minimum_size().x
			assert_true(action.get_combined_minimum_size().x >= required, action_name + " fits its full text")
		assert_eq((row.get_node("MoodIcon") as TextureRect).custom_minimum_size, Vector2(32, 32))
		var number: Label = row.get_node("MoodNumber")
		var max_number_width: float = number.get_theme_font("font").get_string_size("100", HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.BODY).x
		assert_true(number.get_combined_minimum_size().x >= max_number_width, "mood column fits 100")

func test_full_roster_job_width_and_status_start_are_equal() -> void:
	# The suite is synchronous and off-tree. Use a separate Godot process so
	# this regression checks actual container sorting after real layout frames.
	var script_path: String = ProjectSettings.globalize_path("user://t228_roster_layout_%d.gd" % OS.get_process_id())
	var script := FileAccess.open(script_path, FileAccess.WRITE)
	assert_not_null(script)
	if script == null:
		return
	script.store_string("""extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	root.size = Vector2i(1280, 720)
	var test: Variant = load("res://tests/test_roster_layout.gd").new()
	test.before_each()
	test.prepare_full_roster()
	root.add_child(test._roster)
	for frame: int in range(4):
		await process_frame
	test.assert_rendered_roster_columns()
	root.remove_child(test._roster)
	test.after_each()
	for failure: String in test._failures:
		printerr(failure)
	print("ROSTER_LAYOUT_CHECK_COMPLETE")
	quit(0 if test._failures.is_empty() else 1)
""")
	script.close()
	var output: Array = []
	var result: int = OS.execute(OS.get_executable_path(), PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", script_path, "--", "--quit-frames=300"]), output, true)
	DirAccess.remove_absolute(script_path)
	var log_text: String = "".join(output)
	assert_eq(result, 0, "rendered roster alignment: " + log_text)
	assert_true(log_text.contains("ROSTER_LAYOUT_CHECK_COMPLETE"), "layout assertions completed: " + log_text)
	assert_false(log_text.contains("SCRIPT ERROR"), "layout probe has no script errors: " + log_text)

func prepare_full_roster() -> void:
	for survivor_name: String in _state.data.balance("survivor_names"):
		_state.survivors.add(survivor_name, "blue", Vector2i.ZERO)
	var survivors: Array[Survivor] = _state.survivors.all()
	for index: int in range(survivors.size()):
		JobOptions.apply(_state, survivors[index].uid, index % JobOptions.SHORT_LABELS.size())
	_roster.refresh()

func assert_rendered_roster_columns() -> void:
	var first_row: HBoxContainer = _roster._vbox.get_child(0)
	var expected_width: float = (first_row.get_child(1) as OptionButton).size.x
	var expected_x: float = (first_row.get_child(2) as Label).global_position.x
	assert_gt(expected_width, 0.0, "job column has been laid out")
	var labels_seen: Array[String] = []
	for row: HBoxContainer in _roster._vbox.get_children():
		var job: OptionButton = row.get_child(1)
		var status: Label = row.get_child(2)
		labels_seen.append(job.text)
		assert_eq(job.size.x, expected_width, "equal rendered job width for " + job.text)
		assert_eq(status.global_position.x, expected_x, "aligned status start for " + job.text)
		assert_true(job.size.x >= job.get_minimum_size().x, "full job label fits " + job.text)
		assert_true(row.size.x <= _roster._scroll.size.x, "row fits the 1280x720 panel")
	assert_has(labels_seen, "Idle")
	assert_has(labels_seen, "Research")

func test_status_tooltip_preserves_full_text_and_refreshes() -> void:
	var survivor: Survivor = _state.survivors.all()[0]
	var status: Label = _roster._vbox.get_child(0).get_child(2)
	survivor.away = true
	_roster.refresh()
	assert_eq(status.text, "Away till dusk")
	assert_eq(status.tooltip_text, "Away (back at nightfall)")
	survivor.away = false
	survivor.hungry_days = 1
	_roster.refresh()
	assert_eq(status.tooltip_text, RosterPanel.status_text(survivor, _state))
	assert_eq(status.text, status.tooltip_text)
