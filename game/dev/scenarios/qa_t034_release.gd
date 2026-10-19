extends RefCounted
## T-034 live key routing and real pause settings persistence across scene reload.

const OUT: String = "res://../project/runs/T-034/a1/release_live.json"
const CONTENT: String = "Dim/Center/Panel/Margin/Content/"

static func setup(main: Node) -> void:
	var checks: Array[String] = []
	var failures: Array[String] = []
	var tree: SceneTree = main.get_tree()
	var existed: bool = FileAccess.file_exists(AudioSettings.PATH)
	var original: PackedByteArray = FileAccess.get_file_as_bytes(AudioSettings.PATH) if existed else PackedByteArray()
	Game.state.clock.set_paused(true)
	await tree.process_frame
	await tree.process_frame
	var bar: BuildBar = main.get_node("BuildBarLayer")
	var panel: PanelContainer = bar.get_node("Panel") as PanelContainer
	var before: bool = panel.visible
	_key(KEY_B)
	_check(panel.visible != before, "B toggles build bar", checks, failures)
	_key(KEY_B)
	_check(panel.visible == before, "Second B restores build bar", checks, failures)
	var roster: RosterPanel = main.get_node("RosterPanel")
	_key(KEY_R)
	_check(roster.is_open(), "R opens roster", checks, failures)
	_key(KEY_R)
	_check(not roster.is_open(), "Second R closes roster", checks, failures)
	var selection: SelectionController = main.get_node("World/Selection")
	var info: InfoPanel = main.get_node("InfoPanel")
	var person: Survivor = Game.state.survivors.all()[0]
	selection.select_at_world(person.pos)
	_check(selection.selected_uid == person.uid and info.visible, "Survivor selection opens info", checks, failures)
	info._job_btn.item_selected.emit(4)
	_check(person.job == Survivor.Job.BUILDER, "Info dropdown assigns builder", checks, failures)
	_key(KEY_ESCAPE)
	_check(selection.selected_kind == "" and not info.visible, "Esc clears selection", checks, failures)
	var cc: Building = Game.state.buildings.all_of_type("command_center")[0]
	# Keep survivors away to exercise building fallback in the real selection method.
	for survivor: Survivor in Game.state.survivors.all():
		survivor.pos = cc.center_world() + Vector2(200, 200)
	selection.select_at_world(cc.center_world())
	_check(selection.selected_kind == "building" and info._hp_label.text.begins_with("HP "),
		"Building selection displays HP", checks, failures)
	_key(KEY_ESCAPE)
	_key(KEY_ESCAPE)
	var menu: PauseMenu = main.get_node("PauseMenu")
	_check(menu.visible and Game.state.clock.locked, "Esc opens pause after selection cleared", checks, failures)
	var toggle: CheckButton = menu.get_node(CONTENT + "Volumes/HintsRow/Hints")
	toggle.button_pressed = true
	toggle.button_pressed = false
	_check(not HintSettings.load_enabled() and not main.get_node("Hints")._hints.enabled,
		"Pause Hints toggle saves and disables cards", checks, failures)
	var volumes: Dictionary = {"Master": 23.0, "SFX": 47.0, "Music": 61.0}
	for bus: String in volumes:
		menu.get_node(CONTENT + "Volumes/" + bus + "Row/" + bus).value = volumes[bus]
	menu.get_node(CONTENT + "Buttons/Restart").pressed.emit()
	main = null
	menu = null
	info = null
	selection = null
	person = null
	cc = null
	roster = null
	bar = null
	toggle = null
	for _i: int in range(5):
		await tree.process_frame
	main = tree.current_scene
	menu = main.get_node("PauseMenu")
	toggle = menu.get_node(CONTENT + "Volumes/HintsRow/Hints")
	_check(not toggle.button_pressed and not HintSettings.load_enabled(), "Hints preference survives Restart", checks, failures)
	for bus: String in volumes:
		var value: float = menu.get_node(CONTENT + "Volumes/" + bus + "Row/" + bus).value
		_check(is_equal_approx(value, float(volumes[bus])) and
			is_equal_approx(float(AudioSettings.load_volumes()[bus]), value / 100.0),
			bus + " slider and saved volume survive Restart", checks, failures)
	menu.open()
	toggle.button_pressed = true
	_check(HintSettings.load_enabled(), "Hints can be re-enabled without erasing audio", checks, failures)
	menu.close()
	# Restore the exact original user settings after testing the real persistence path.
	if existed:
		var restored: FileAccess = FileAccess.open(AudioSettings.PATH, FileAccess.WRITE)
		restored.store_buffer(original)
		restored.close()
	else:
		DirAccess.remove_absolute(AudioSettings.PATH)
	AudioSettings.apply(AudioSettings.load_volumes())
	var file: FileAccess = FileAccess.open(OUT, FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures}, "\t"))
	file.close()
	print("RELEASE LIVE: %d checks, %d failures" % [checks.size(), failures.size()])
	for failure: String in failures:
		push_error("Release QA: " + failure)

static func _key(keycode: int) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		event.keycode = keycode
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()

static func _check(condition: bool, label: String, checks: Array[String], failures: Array[String]) -> void:
	checks.append(label)
	if not condition:
		failures.append(label)
