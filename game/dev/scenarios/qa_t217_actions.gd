extends RefCounted
## Bounded live GUI clicks, including the production HUD toast path.

static func setup(main: Node) -> void:
	preload("res://dev/scenarios/morale_ui.gd").setup(main)
	var state: GameState = Game.state
	var tree: SceneTree = main.get_tree()
	var selection: SelectionController = main.get_node("World/Selection")
	var info: InfoPanel = main.get_node("InfoPanel")
	var roster: RosterPanel = main.get_node("RosterPanel")
	var hud: Node = main.get_node("HUD")
	var failures: Array[String] = []
	state.resources.add("food", 100)
	selection.select_building(state.buildings.all_of_type("command_center")[0].uid)
	for i: int in range(6): await tree.process_frame
	var feast: Button = info.get_node("PanelContainer/VBoxContainer/FeastButton")
	var food: int = state.resources.get_amount("food")
	_click(main, feast.get_global_rect().get_center())
	_check(state.last_feast_day == 5, "GUI Feast click must reach the sim", failures)
	_check(state.resources.get_amount("food") == food - InfoPanel.feast_cost(state), "Feast must spend total cost", failures)
	var active: Array = hud.get("_active_toasts")
	_check(active.size() == 1, "Successful Feast emits one live toast", failures)
	if not active.is_empty():
		var toast: PanelContainer = active[0]["panel"]
		_check((toast.get_child(0) as Label).text == ScavengeToast.feast_text(state), "Toast uses the configured value", failures)
	_click(main, feast.get_global_rect().get_center())
	_check(state.resources.get_amount("food") == food - InfoPanel.feast_cost(state), "Disabled re-click spends nothing", failures)
	_check((hud.get("_active_toasts") as Array).size() == 1, "Disabled re-click adds no toast", failures)
	state.last_feast_day = 0
	state.clock.phase = GameClock.Phase.NIGHT
	info.refresh()
	_click(main, feast.get_global_rect().get_center())
	_check(state.last_feast_day == 0 and feast.tooltip_text == "Night", "Night Feast rejected with sim reason", failures)
	state.clock.phase = GameClock.Phase.DAY
	state.last_feast_day = 5
	var s: Survivor = state.survivors.all()[1]
	selection.select_survivor(s.uid)
	for i: int in range(6): await tree.process_frame
	var off: Button = info.get_node("PanelContainer/VBoxContainer/SurvivorActions/DayOffButton")
	var scavenge: Button = info.get_node("PanelContainer/VBoxContainer/SurvivorActions/ScavengeButton")
	_check(is_equal_approx(off.get_global_rect().position.y, scavenge.get_global_rect().position.y), "Day off sits beside Send scavenging", failures)
	var survivor_rect: Rect2 = (info.get_node("PanelContainer") as Control).get_global_rect()
	_click(main, off.get_global_rect().get_center())
	_check(s.day_off and off.disabled and off.tooltip_text == "Already off", "GUI Info Day off click refreshes reason", failures)
	var rows: Node = roster.get_node("PanelContainer/VBox/ScrollContainer/Rows")
	var other: Survivor = state.survivors.all()[0]
	other.refusing = true
	roster.refresh()
	var row: Node = rows.get_child(0)
	var roster_off: Button = row.get_node("DayOffButton")
	_click(main, roster_off.get_global_rect().get_center())
	_check(not other.day_off and roster_off.tooltip_text == "Refusing work", "GUI roster refuses invalid day off", failures)
	other.refusing = false
	roster.refresh()
	_click(main, roster_off.get_global_rect().get_center())
	_check(other.day_off and (row.get_child(2) as Label).text == "Day off", "GUI roster Day off click refreshes status", failures)
	var report: DawnReportPanel = main.get_node("DawnReport")
	report._show_report({"day": 5, "night": 4, "morale": {"bands": {"inspired": 1, "steady": 1, "low": 1, "breaking": 1}, "refusing": [other.name], "left_morale": []}})
	var texts: Array[String] = []
	for entry: Dictionary in hud.get("_active_toasts"):
		texts.append(((entry["panel"] as PanelContainer).get_child(0) as Label).text)
	_check(texts.count(ScavengeToast.refusal_text(other.name)) == 1, "Dawn emits one refusal toast per survivor", failures)
	for i: int in range(3): await tree.process_frame
	report.visible = false
	selection.select_building(state.buildings.all_of_type("command_center")[0].uid)
	for i: int in range(6): await tree.process_frame
	var command_rect: Rect2 = (info.get_node("PanelContainer") as Control).get_global_rect()
	_check(command_rect.size.y < survivor_rect.size.y, "Command Center panel shrinks after survivor selection", failures)
	var toast_rects: Array[String] = []
	for entry: Dictionary in hud.get("_active_toasts"):
		var toast_rect: Rect2 = (entry["panel"] as Control).get_global_rect()
		toast_rects.append(str(toast_rect))
		_check(not command_rect.intersects(toast_rect), "Command Center panel leaves every toast visible", failures)
	var motion := InputEventMouseMotion.new()
	motion.position = feast.get_global_rect().get_center()
	motion.global_position = motion.position
	main.get_viewport().push_input(motion)
	var path: String = ProjectSettings.globalize_path("res://../project/runs/T-217/a2/qa_actions_live.json")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"failures": failures, "toast_texts": texts, "toast_rects": toast_rects, "survivor_rect": str(survivor_rect), "command_rect": str(command_rect)}, "\t"))
	file.close()
	print("T-217 live actions QA: ", failures)

static func _click(main: Node, position: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = position
		event.global_position = position
		main.get_viewport().push_input(event)

static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition: failures.append(message)
