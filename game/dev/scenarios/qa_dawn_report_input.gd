extends Node
## Live acceptance checks; run with --scenario=qa_dawn_report_input --quit-frames=120.

static func setup(main: Node) -> void:
	var state: GameState = Game.state
	var panel: DawnReportPanel = main.get_node("DawnReport") as DawnReportPanel
	var tree: SceneTree = main.get_tree()
	load("res://dev/scenarios/dawn_report.gd").setup(main)
	await tree.process_frame
	await tree.process_frame
	_check(panel.visible and state.clock.paused, "Real dawn shows the panel and pauses")
	var elapsed: float = state.clock.elapsed
	state.tick(1.0)
	_check(state.clock.elapsed == elapsed, "Clock remains frozen while report is open")
	var button: Button = panel.get_node("Center/Panel/Margin/Content/Buttons/Continue") as Button
	button.pressed.emit()
	_check(not panel.visible and not state.clock.paused, "Continue button closes and resumes")
	_next_dawn(state)
	_check(not state.clock.paused, "Second dawn signal does not pause synchronously")
	await tree.process_frame
	await tree.process_frame
	_check(panel.visible and state.clock.paused, "Second dawn shows another report")
	var title: Label = panel.get_node("Center/Panel/Margin/Content/Title") as Label
	_check(title.text == "DAWN: DAY 3", "Second dawn title is refreshed")
	_key(main, KEY_ENTER, true)
	_check(not panel.visible and not state.clock.paused, "Enter closes and resumes")
	_key(main, KEY_ENTER, false)
	state.clock.set_paused(true)
	panel._show_report(state.last_dawn_report)
	_key(main, KEY_SPACE, true)
	_check(not panel.visible and state.clock.paused, "Space preserves prior pause without HUD toggle")
	_key(main, KEY_SPACE, false)
	state.clock.set_paused(false)
	panel._show_report(state.last_dawn_report)
	_key(main, KEY_SPACE, true)
	_check(not panel.visible and not state.clock.paused, "Space resumes a previously running clock")
	_key(main, KEY_SPACE, false)
	var cc: Building = state.buildings.all_of_type("command_center")[0]
	state.damage_building(cc, cc.hp)
	_next_dawn(state)
	await tree.process_frame
	await tree.process_frame
	_check(state.game_over and not panel.visible, "Game Over at dawn suppresses deferred report")
	print("QA DawnReport: live input and repeated-dawn checks completed")

static func _next_dawn(state: GameState) -> void:
	state.clock.phase_changed.emit(GameClock.Phase.NIGHT, state.clock.day)
	state.clock.phase = GameClock.Phase.NIGHT
	state.clock.elapsed = float(state.data.balance("night_min_length")) - 0.1
	state.tick(0.2)

static func _key(main: Node, code: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	main.get_viewport().push_input(event)

static func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("QA DawnReport: " + message)
	else:
		print("QA PASS: " + message)
