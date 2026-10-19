extends TestCase
## T-230: use real layout frames; the normal test runner is synchronous.

const HINT_IDS: Array[String] = [
	"welcome", "farm", "night_soon", "ammo", "scavenge", "hungry", "radio",
	"spitters", "research", "morale",
]

func test_hint_card_layout_and_build_button_click() -> void:
	# Follow test_roster_layout's subprocess pattern without changing the runner.
	var script_path: String = ProjectSettings.globalize_path(temp_path("hint_layout", "gd"))
	var script := FileAccess.open(script_path, FileAccess.WRITE)
	assert_not_null(script)
	if script == null:
		return
	script.store_string("""extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	root.size = Vector2i(1280, 720)
	var test: Variant = load("res://tests/test_hint_panel_layout.gd").new()
	await test.check_rendered_layout(self)
	for failure: String in test._failures:
		printerr(failure)
	print("HINT_LAYOUT_CHECK_COMPLETE")
	root.get_node("Game").request_quit(0 if test._failures.is_empty() else 1)
""")
	script.close()
	var output: Array = []
	var result: int = OS.execute(OS.get_executable_path(), PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", script_path, "--", "--scenario=tutorial", "--quit-frames=300",
	]), output, true)
	DirAccess.remove_absolute(script_path)
	var log_text: String = "".join(output)
	assert_eq(result, 0, "rendered hint layout: " + log_text)
	assert_true(log_text.contains("HINT_LAYOUT_CHECK_COMPLETE"), "layout checks completed: " + log_text)
	assert_false(log_text.contains("SCRIPT ERROR"), "layout probe has no script errors: " + log_text)
	assert_false(log_text.contains("ERROR:"), "layout probe has no engine errors: " + log_text)

func check_rendered_layout(scene_tree: SceneTree) -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	scene_tree.root.add_child(main)
	scene_tree.current_scene = main
	await _settle(scene_tree)
	Game.state.clock.set_paused(true)
	Game.state.waves.enabled = false
	var hints: HintPanel = main.get_node("Hints")
	hints.set_process(false) # Keep manually selected cards stable during checks.
	var panel: Control = hints.get_node("PanelContainer")
	var label: Label = hints.get_node("PanelContainer/MarginContainer/VBoxContainer/HintLabel")
	var bar: BuildBar = main.get_node("BuildBarLayer")
	var bar_panel: Control = bar.get_node("Panel")
	assert_eq(scene_tree.root.get_visible_rect().size, Vector2(1280, 720), "1280x720 fixture")
	assert_eq(hints.current_hint(), "welcome", "tutorial scenario displays welcome")
	_check_card(hints, bar_panel, "welcome")
	assert_lt(panel.size.y, 250.0, "welcome card hugs its content")
	assert_almost_eq(panel.size.y, panel.get_combined_minimum_size().y, 0.01, "welcome has no stale empty height")
	var welcome_height: float = panel.size.y
	var top: float = panel.position.y
	var wall: Button = bar._button_for("wooden_wall")
	assert_not_null(wall)
	if wall == null:
		return
	assert_true(wall.is_visible_in_tree(), "F1 Wooden Wall is visible")
	assert_false(wall.disabled, "F1 Wooden Wall is enabled")
	assert_true(scene_tree.root.get_visible_rect().encloses(wall.get_global_rect()), "full F1 button is on screen")
	assert_false(panel.get_global_rect().intersects(wall.get_global_rect()), "welcome does not cover F1")
	var selected: Array[String] = []
	bar.building_selected.connect(func(id: String) -> void: selected.append(id))
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = wall.get_global_rect().get_center()
		click.global_position = click.position
		scene_tree.root.push_input(click, true)
		await scene_tree.process_frame
	assert_has(selected, "wooden_wall", "real mouse click reaches the F1 button while welcome shows")
	bar.set_active_type("")
	for id: String in HINT_IDS:
		hints.show_hint(id)
		await _settle(scene_tree)
		_check_card(hints, bar_panel, id)
		assert_almost_eq(panel.position.y, top, 0.01, id + " keeps top position")
		assert_true(label.get_line_count() <= label.max_lines_visible, id + " shipped text fits without clipping")
		assert_true(label.size.y >= label.get_line_count() * label.get_line_height(), id + " has height for every text line")
	# Exercise actual long -> short text replacement and the height safety cap.
	hints.show_hint("spitters")
	await _settle(scene_tree)
	assert_gt(panel.size.y, welcome_height, "longer shipped hint grows the card")
	hints.show_hint("welcome")
	await _settle(scene_tree)
	assert_almost_eq(panel.size.y, welcome_height, 0.01, "short hint clears stale height")
	label.text = TutorialHints.text("morale", Game.state.data).repeat(20)
	await _settle(scene_tree)
	_check_card(hints, bar_panel, "oversized hint")
	assert_true(label.get_line_count() > label.max_lines_visible, "oversized label is clipped to available height")
	var dismiss: Button = hints.get_node("PanelContainer/MarginContainer/VBoxContainer/BottomRow/GotItButton")
	assert_true(panel.get_global_rect().encloses(dismiss.get_global_rect()), "dismiss button remains within capped card")
	assert_almost_eq(panel.position.y, top, 0.01, "oversized hint keeps top position")
	hints.show_hint("welcome")
	await _settle(scene_tree)
	assert_almost_eq(panel.size.y, welcome_height, 0.01, "short card recovers after height cap")
	var hud: CanvasLayer = main.get_node("HUD")
	hud._position_toasts()
	assert_almost_eq(hud._toast_box.position.y, panel.position.y + panel.size.y + 8.0, 0.01, "toasts follow compact hint bottom")
	# Rebuilding into two rows raises the bar; every hint still clears it.
	Game.state.clock.day = 8
	bar.refresh()
	await _settle(scene_tree)
	for id: String in HINT_IDS:
		hints.show_hint(id)
		await _settle(scene_tree)
		_check_card(hints, bar_panel, "full bar: " + id)
	print("HINT_LAYOUT welcome_height=%.0f bar_top=%.0f" % [welcome_height, bar_panel.position.y])

func _settle(scene_tree: SceneTree) -> void:
	for frame: int in range(6):
		await scene_tree.process_frame

func _check_card(hints: HintPanel, bar_panel: Control, context: String) -> void:
	var panel: Control = hints.get_node("PanelContainer")
	var rect: Rect2 = panel.get_global_rect()
	assert_almost_eq(rect.position.x, 8.0, 0.01, context + " keeps left position")
	assert_almost_eq(rect.size.x, 380.0, 0.01, context + " keeps 380px width")
	assert_false(rect.intersects(bar_panel.get_global_rect()), context + " clears build bar")
	assert_true(rect.end.y <= bar_panel.get_global_rect().position.y - 8.0, context + " has at least 8px gap")
