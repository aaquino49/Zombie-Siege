extends "res://tests/test_case.gd"

var _hud: CanvasLayer
var _state: GameState
var _selection: SelectionController
var _camera: CameraController
var _overlay_root: Node

func before_each() -> void:
	_state = GameState.new(GameData.load_default(), 1337)
	_hud = load("res://scenes/ui/hud.tscn").instantiate() as CanvasLayer
	_hud.set("top_bar", _hud.get_node("TopBar"))
	for kind: String in ResourceStore.KINDS:
		var box: String = "TopBar/Margin/HBox/Resources/%sBox" % kind.capitalize()
		_hud.set(kind + "_icon", _hud.get_node(box + "/Icon"))
		_hud.set(kind + "_label", _hud.get_node(box + "/Label"))
	_hud.set("day_label", _hud.get_node("TopBar/Margin/HBox/DayArea/DayLabel"))
	_hud.set("idle_button", _hud.get_node("TopBar/Margin/HBox/DayArea/IdleButton"))
	_hud.set("time_label", _hud.get_node("TopBar/Margin/HBox/ClockArea/TimeLabel"))
	for speed: String in ["pause", "1x", "2x", "3x"]:
		_hud.set("btn_" + speed, _hud.get_node("TopBar/Margin/HBox/ClockArea/SpeedButtons/Btn" + speed.capitalize()))
	_hud.call("_ready")
	_hud.call("bind", _state)
	_selection = SelectionController.new()
	_selection.bind(_state)
	_camera = CameraController.new()
	_hud.set("_selection", _selection)
	_hud.set("_camera", _camera)
	_overlay_root = Node.new()
	_hud.set("_overlay_root", _overlay_root)

func after_each() -> void:
	_hud.free()
	_selection.free()
	_camera.free()
	_overlay_root.free()
	_state = null

func test_idle_count_excludes_other_jobs_and_away_survivors() -> void:
	for survivor: Survivor in _state.survivors.all():
		survivor.job = Survivor.Job.BUILDER
	var guard: Survivor = _state.survivors.add("Guard", "blue", Vector2i(6, 5))
	var idle: Survivor = _state.survivors.add("Idle", "blue", Vector2i(5, 5))
	var worker: Survivor = _state.survivors.add("Worker", "blue", Vector2i(7, 5))
	var scavenger: Survivor = _state.survivors.add("Scavenger", "blue", Vector2i(8, 5))
	idle.job = Survivor.Job.IDLE
	guard.job = Survivor.Job.GUARD
	worker.job = Survivor.Job.BUILDER
	scavenger.job = Survivor.Job.IDLE
	scavenger.away = true
	_hud.call("_refresh_ammo_warning")
	var button: Button = _hud.get("idle_button")
	assert_eq(button.get_theme_font_size("font_size"), UiFont.BODY)
	assert_true(button.visible)
	assert_eq(button.text, "Idle: 1")
	_state.clock.phase = GameClock.Phase.NIGHT
	_hud.call("_refresh_idle_button")
	assert_false(button.visible, "Idle button hides at night")
	_state.clock.phase = GameClock.Phase.DAY
	idle.job = Survivor.Job.GUARD
	_hud.call("_refresh_ammo_warning")
	assert_false(button.visible, "Idle button hides when no survivors are idle")

func test_button_and_i_cycle_idle_survivors_and_center_camera() -> void:
	for survivor: Survivor in _state.survivors.all():
		survivor.job = Survivor.Job.BUILDER
	var first: Survivor = _state.survivors.add("First", "blue", Vector2i(5, 5))
	var second: Survivor = _state.survivors.add("Second", "blue", Vector2i(7, 6))
	first.job = Survivor.Job.IDLE
	second.job = Survivor.Job.IDLE
	_hud.call("_refresh_ammo_warning")
	(_hud.get("idle_button") as Button).pressed.emit()
	assert_eq(_selection.selected_uid, first.uid)
	assert_eq(_camera.position, first.pos)
	(_hud.get("idle_button") as Button).pressed.emit()
	assert_eq(_selection.selected_uid, second.uid)
	assert_eq(_camera.position, second.pos)
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_I
	key.pressed = true
	_hud.call("_unhandled_input", key)
	assert_eq(_selection.selected_uid, first.uid, "I cycles and wraps to the first idle survivor")
	assert_eq(_camera.position, first.pos)

func test_select_idle_action_maps_to_i() -> void:
	assert_true(InputMap.has_action("select_idle"))
	var events: Array[InputEvent] = InputMap.action_get_events("select_idle")
	assert_eq(events.size(), 1)
	assert_true(events[0] is InputEventKey)
	assert_eq((events[0] as InputEventKey).physical_keycode, KEY_I)

func test_pause_canvas_layer_blocks_click_and_i_until_hidden() -> void:
	for survivor: Survivor in _state.survivors.all():
		survivor.job = Survivor.Job.BUILDER
	var first: Survivor = _state.survivors.add("First", "blue", Vector2i(5, 5))
	var second: Survivor = _state.survivors.add("Second", "blue", Vector2i(7, 6))
	first.job = Survivor.Job.IDLE
	second.job = Survivor.Job.IDLE
	_hud.call("_refresh_ammo_warning")
	_selection.select_survivor(second.uid)
	_camera.position = Vector2(123.0, 456.0)
	var pause_menu: CanvasLayer = CanvasLayer.new()
	pause_menu.name = "PauseMenu"
	pause_menu.visible = true
	_overlay_root.add_child(pause_menu)

	_hud.call("select_next_idle")
	assert_eq(_selection.selected_uid, second.uid, "Visible CanvasLayer blocks button selection")
	assert_eq(_camera.position, Vector2(123.0, 456.0), "Visible CanvasLayer blocks camera movement")
	_send_i_key()
	assert_eq(_selection.selected_uid, second.uid, "Visible CanvasLayer blocks I selection")
	assert_eq(_camera.position, Vector2(123.0, 456.0), "Visible CanvasLayer blocks I camera movement")

	pause_menu.visible = false
	_hud.call("select_next_idle")
	assert_eq(_selection.selected_uid, first.uid, "Button works again after overlay hides")
	assert_eq(_camera.position, first.pos, "Button recentres after overlay hides")
	_send_i_key()
	assert_eq(_selection.selected_uid, second.uid, "I works again after overlay hides")
	assert_eq(_camera.position, second.pos, "I recentres after overlay hides")

func _send_i_key() -> void:
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_I
	key.pressed = true
	_hud.call("_unhandled_input", key)
