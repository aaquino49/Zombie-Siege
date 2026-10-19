extends RefCounted
## Clear day-8 capture with rendered geometry and real F-key routing checks.

static func setup(main: Node) -> void:
	preload("res://dev/scenarios/morale_ui.gd").setup(main)
	var state: GameState = Game.state
	state.clock.day = 8
	var roster: RosterPanel = main.get_node("RosterPanel")
	if roster.is_open(): roster.toggle()
	var bar: BuildBar = main.get_node("BuildBarLayer")
	bar.refresh(8)
	var tree: SceneTree = main.get_tree()
	for i: int in range(8): await tree.process_frame
	var panel: PanelContainer = bar.get_node("Panel")
	var grid: GridContainer = panel.get_node("HBox")
	var mode: BuildMode = main.get_node("World/BuildMode")
	var failures: Array[String] = []
	var expected: Array[String] = ["wooden_wall", "gate", "farm", "shelter", "campfire", "storage", "watchtower", "workshop", "lumber_yard"]
	for index: int in range(9):
		var event := InputEventKey.new()
		event.physical_keycode = KEY_F1 + index
		event.pressed = true
		main.get_viewport().push_input(event)
		if mode.active_type != expected[index]: failures.append("F%d selected %s" % [index + 1, mode.active_type])
		mode.cancel()
	var rect: Rect2 = panel.get_global_rect()
	var viewport: Rect2 = main.get_viewport().get_visible_rect()
	if grid.get_child_count() != 12: failures.append("Expected 12 buttons")
	if rect.size.y > 200.0: failures.append("Rendered bar exceeds 200px: %s" % rect.size.y)
	if not viewport.encloses(rect): failures.append("Bar outside viewport: %s" % rect)
	for child: Node in grid.get_children():
		var button: Button = child as Button
		if not rect.encloses(button.get_global_rect()): failures.append("Button outside panel: %s" % button.get_meta("type_id"))
	bar.show_info("radio_tower")
	for i: int in range(3): await tree.process_frame
	var card: Control = bar.get_node("BuildInfoCard")
	if card.get_global_rect().end.y > rect.position.y: failures.append("Info card overlaps bar")
	var initial_rect: Rect2 = rect
	var initial_columns: int = grid.columns
	if "--qa-resize" in OS.get_cmdline_user_args():
		mode.select("campfire")
		# canvas_items/expand gives this wide window a 1920x720 logical viewport.
		main.get_tree().root.size = Vector2i(1280, 480)
		for i: int in range(12): await tree.process_frame
		if grid.columns != 12: failures.append("Resize to wide viewport does not use one row")
		if bar._active_type != "campfire" or not bar._button_for("campfire").button_pressed:
			failures.append("Wide resize loses active Campfire")
		bar.refresh(8)
		for i: int in range(8): await tree.process_frame
		initial_rect = panel.get_global_rect()
		initial_columns = grid.columns
		main.get_tree().root.size = Vector2i(1280, 720)
		for i: int in range(12): await tree.process_frame
		rect = panel.get_global_rect()
		viewport = main.get_viewport().get_visible_rect()
		if grid.columns != 6: failures.append("Resize to 1280 does not split into six columns")
		if not viewport.encloses(rect): failures.append("Resized bar outside viewport: %s" % rect)
		if rect.size.y > 200.0: failures.append("Resized bar exceeds 200px")
		if bar._active_type != "campfire" or not bar._button_for("campfire").button_pressed:
			failures.append("Narrow resize loses active Campfire")
		for index: int in range(9):
			if str(grid.get_child(index).get_meta("type_id")) != expected[index]:
				failures.append("Resize changes canonical order at F%d" % (index + 1))
		if card.get_global_rect().end.y > rect.position.y: failures.append("Resized info card overlaps bar")
		mode.cancel()
		bar.hide_info()
	var report_path: String = ProjectSettings.globalize_path("res://../project/runs/T-217/a2/qa_day8_live.json")
	if "--qa-resize" in OS.get_cmdline_user_args():
		report_path = report_path.replace("qa_day8_live.json", "qa_day8_resize_live.json")
	var file: FileAccess = FileAccess.open(report_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"failures": failures, "initial_rect": str(initial_rect), "initial_columns": initial_columns, "bar_rect": str(rect), "columns": grid.columns, "button_count": grid.get_child_count()}, "\t"))
	file.close()
	print("T-217 live day8 QA: ", failures, " rect=", rect)
