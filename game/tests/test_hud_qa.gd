extends TestCase
## The synchronous runner initializes onready references without frame polling.

var _hud: CanvasLayer
var _state: GameState

func before_each() -> void:
	_state = GameState.new(GameData.load_default(), 1337)
	var scene: PackedScene = load("res://scenes/ui/hud.tscn")
	_hud = scene.instantiate() as CanvasLayer
	_hud.set("top_bar", _hud.get_node("TopBar"))
	for kind: String in ResourceStore.KINDS:
		var box_path: String = "TopBar/Margin/HBox/Resources/%sBox" % kind.capitalize()
		_hud.set(kind + "_icon", _hud.get_node(box_path + "/Icon"))
		_hud.set(kind + "_label", _hud.get_node(box_path + "/Label"))
	_hud.set("day_label", _hud.get_node("TopBar/Margin/HBox/DayArea/DayLabel"))
	_hud.set("time_label", _hud.get_node("TopBar/Margin/HBox/ClockArea/TimeLabel"))
	_hud.set("btn_pause", _hud.get_node("TopBar/Margin/HBox/ClockArea/SpeedButtons/BtnPause"))
	_hud.set("btn_1x", _hud.get_node("TopBar/Margin/HBox/ClockArea/SpeedButtons/Btn1x"))
	_hud.set("btn_2x", _hud.get_node("TopBar/Margin/HBox/ClockArea/SpeedButtons/Btn2x"))
	_hud.set("btn_3x", _hud.get_node("TopBar/Margin/HBox/ClockArea/SpeedButtons/Btn3x"))
	_hud.call("_ready")
	_hud.call("bind", _state)

func after_each() -> void:
	_hud.free()
	_state = null

func test_binding_and_signal_mutations_update_labels_synchronously() -> void:
	for kind: String in ResourceStore.KINDS:
		var label: Label = _hud.get(kind + "_label") as Label
		assert_eq(label.text, str(_state.resources.get_amount(kind)))
	_state.resources.add("food", 93)
	_state.resources.take("scrap", 15)
	assert_eq((_hud.get("food_label") as Label).text, "123")
	assert_eq((_hud.get("wood_label") as Label).text, "60")
	assert_eq((_hud.get("scrap_label") as Label).text, "0")
	assert_eq((_hud.get("ammo_label") as Label).text, "40")
	assert_eq((_hud.get("day_label") as Label).text, "Day 1")
	assert_true(_state.resources.spend({"wood": 5}))
	assert_eq((_hud.get("wood_label") as Label).text, "55")
	_state.resources.refund({"wood": 5}, 0.5)
	assert_eq((_hud.get("wood_label") as Label).text, "57")

func test_bar_assets_layout_and_mouse_filters() -> void:
	var bar: NinePatchRect = _hud.get_node("TopBar") as NinePatchRect
	assert_not_null(bar.texture)
	assert_almost_eq(bar.anchor_right, 1.0)
	assert_almost_eq(bar.offset_bottom, 48.0)
	assert_eq(bar.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_true(_hud.get_node("TopBar/Margin/HBox/ClockArea") is HBoxContainer)
	for kind: String in ResourceStore.KINDS:
		var icon: TextureRect = _hud.get(kind + "_icon") as TextureRect
		var label: Label = _hud.get(kind + "_label") as Label
		assert_not_null(icon.texture)
		assert_eq(icon.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		assert_eq(label.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		assert_true(label.label_settings.font_size >= 18)
		assert_true(label.label_settings.outline_size > 0)

func test_clock_labels_follow_dawn_phase_and_rounded_seconds() -> void:
	_hud.call("_process", 0.0)
	assert_eq((_hud.get("time_label") as Label).text, "Nightfall in 1:10")
	_state.clock.advance(0.1)
	_hud.call("_process", 0.0)
	assert_eq((_hud.get("time_label") as Label).text, "Nightfall in 1:10")
	_state.clock.advance(69.9)
	_hud.call("_process", 0.0)
	assert_eq((_hud.get("time_label") as Label).text, "Night – dawn in 0:40")
	_state.clock.advance(40.0 + 50.0)
	_state.clock.set_paused(true)
	_hud.call("_process", 0.0)
	assert_eq((_hud.get("day_label") as Label).text, "Day 2")
	assert_eq((_hud.get("time_label") as Label).text, "Nightfall in 0:20")
	assert_true((_hud.get("btn_pause") as Button).button_pressed)

func test_day_label_refreshes_direct_clock_changes_without_dawn() -> void:
	var label: Label = _hud.get("day_label") as Label
	var food: int = _state.resources.get_amount("food")
	_state.clock.set_paused(true)
	_hud.call("_process", 0.0)
	assert_eq(label.text, "Day 1")
	_state.clock.day = 2
	_hud.call("_process", 0.0)
	assert_eq(label.text, "Day 2", "Paused HUD refreshes direct changes without dawn")
	assert_eq(_state.resources.get_amount("food"), food)
	assert_true(_state.last_dawn_report.is_empty())
	_state.clock.day = 7
	_hud.call("_process", 0.0)
	assert_eq(label.text, "Day 7")
	_hud.call("_process", 0.0)
	assert_eq(label.text, "Day 7")

func test_clock_keys_and_button_group_follow_sim_state() -> void:
	var buttons: Array[Button] = [
		_hud.get("btn_pause"), _hud.get("btn_1x"),
		_hud.get("btn_2x"), _hud.get("btn_3x")]
	for button: Button in buttons:
		assert_eq(button.focus_mode, Control.FOCUS_NONE)
		assert_not_null(button.icon)
		assert_eq(button.button_group, buttons[0].button_group)
		assert_false(button.button_group.allow_unpress)
	for speed: int in [3, 2, 1]:
		var key: InputEventKey = InputEventKey.new()
		key.physical_keycode = KEY_1 + speed - 1
		key.pressed = true
		_hud.call("_unhandled_input", key)
		assert_eq(_state.clock.speed, speed)
		assert_false(_state.clock.paused)
		_assert_selected_button(buttons, speed)
	var space: InputEventKey = InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	space.pressed = true
	_hud.call("_unhandled_input", space)
	assert_true(_state.clock.paused)
	_assert_selected_button(buttons, 0)
	_hud.call("_unhandled_input", space)
	assert_false(_state.clock.paused)
	_assert_selected_button(buttons, 1)
	buttons[0].pressed.emit()
	assert_true(_state.clock.paused)
	for speed: int in [2, 3, 1]:
		buttons[speed].pressed.emit()
		assert_eq(_state.clock.speed, speed)
		assert_false(_state.clock.paused)
		_assert_selected_button(buttons, speed)

func _assert_selected_button(buttons: Array[Button], selected: int) -> void:
	for index: int in range(buttons.size()):
		assert_eq(buttons[index].button_pressed, index == selected,
			"Exactly the active clock control must be selected")

func test_speed_buttons_keep_contrasting_pressed_style_while_hovered() -> void:
	var shared_style: StyleBox = null
	for property: String in ["btn_pause", "btn_1x", "btn_2x", "btn_3x"]:
		var button: Button = _hud.get(property) as Button
		var pressed: StyleBox = button.get_theme_stylebox("pressed")
		var normal: StyleBox = button.get_theme_stylebox("normal")
		assert_not_null(pressed)
		assert_not_null(normal)
		if pressed == null or normal == null:
			continue
		assert_ne(pressed, normal, "Active clock control must have a distinct pressed style")
		assert_eq(button.get_theme_stylebox("hover_pressed"), pressed,
			"Hovering must preserve the active clock highlight")
		if shared_style == null:
			shared_style = pressed
		assert_eq(pressed, shared_style, "All four clock controls must share the highlight")

func test_speed_button_foregrounds_contrast_and_margins_preserve_layout() -> void:
	for property: String in ["btn_pause", "btn_1x", "btn_2x", "btn_3x"]:
		var button: Button = _hud.get(property) as Button
		var normal: StyleBox = button.get_theme_stylebox("normal")
		var pressed: StyleBox = button.get_theme_stylebox("pressed")
		assert_not_null(pressed)
		assert_not_null(normal)
		if pressed == null or normal == null:
			continue
		for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			assert_almost_eq(pressed.get_content_margin(side), normal.get_content_margin(side),
				0.001, "Active controls must preserve normal layout margins")

class HostileState extends GameState:
	var hostile_count: int = 0

	func hostiles_remaining() -> int:
		return hostile_count

func test_night_text_refreshes_hostile_changes_within_same_second() -> void:
	var state: HostileState = HostileState.new(GameData.load_default(), 1337)
	_hud.call("bind", state)
	state.clock.phase = GameClock.Phase.NIGHT
	state.clock.elapsed = 1.5
	_hud.call("_process", 0.0)
	assert_eq((_hud.get("time_label") as Label).text, "Night – dawn in 0:39")
	state.hostile_count = 7
	_hud.call("_process", 0.0)
	assert_eq((_hud.get("time_label") as Label).text, "Night – 7 zombies left")
	state.hostile_count = 6
	_hud.call("_process", 0.0)
	assert_eq((_hud.get("time_label") as Label).text, "Night – 6 zombies left")
	state.hostile_count = 0
	state.clock.elapsed = 60.0
	_hud.call("_process", 0.0)
	assert_eq((_hud.get("time_label") as Label).text, "Night – dawn in 0:00")

func test_ammo_warning_tracks_guards_completed_turrets_and_restock() -> void:
	var warning: Label = _hud.get_node("TopBar/Margin/HBox/Resources/AmmoBox/AmmoWarning") as Label
	var ammo: Label = _hud.get("ammo_label") as Label
	_state.resources.take("ammo", _state.resources.get_amount("ammo"))
	# Start without guards (the default start jobs include one since T-027).
	for s: Survivor in _state.survivors.all():
		if s.job == Survivor.Job.GUARD:
			s.job = Survivor.Job.BUILDER
	_hud.call("_process", 0.0)
	assert_false(warning.visible)
	var guard: Survivor = _state.survivors.all()[0]
	guard.job = Survivor.Job.GUARD
	_hud.call("_process", 0.0)
	assert_true(warning.visible)
	assert_eq(ammo.modulate, Color("#e0451b"))
	_state.resources.add("ammo", 1)
	_hud.call("_process", 0.0)
	assert_false(warning.visible)
	assert_eq(ammo.modulate, Color.WHITE)
	guard.job = Survivor.Job.BUILDER
	_state.resources.take("ammo", 1)
	var b: Building = _state.buildings.add("turret", _state.map.command_center_origin() + Vector2i(3, -2), false)
	_hud.call("_process", 0.0)
	assert_false(warning.visible)
	_state.buildings.finish(b.uid)
	_hud.call("_process", 0.0)
	assert_true(warning.visible)
	_state.buildings.remove(b.uid)
	_hud.call("_process", 0.0)
	assert_false(warning.visible)
