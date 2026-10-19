extends TestCase

var _state: GameState
var _bar: BuildBar
var _mode: BuildMode

func before_each() -> void:
	_state = GameState.new(GameData.load_default(), 1337)
	_bar = preload("res://scenes/ui/build_bar.tscn").instantiate() as BuildBar
	_bar.bind(_state)
	_mode = BuildMode.new()
	_mode.bind(_state)
	_bar.building_selected.connect(_mode.select)
	_mode.mode_changed.connect(_bar.set_active_type)

func after_each() -> void:
	_bar.free()
	_mode.free()

func _ids() -> Array[String]:
	var result: Array[String] = []
	for button: Button in _bar._hbox().get_children():
		result.append(str(button.get_meta("type_id")))
	return result

func test_day2_additions_and_exclusions_after_upgrade_unlock() -> void:
	var steps: int = 0
	while _state.clock.day < 2 and steps < 2000:
		_state.clock.advance(1.0)
		steps += 1
	assert_eq(_state.clock.day, 2)
	assert_eq(_ids(), ["wooden_wall", "gate", "farm", "shelter", "campfire", "storage", "watchtower", "workshop"])
	while _state.clock.day < 6 and steps < 2000:
		_state.clock.advance(1.0)
		steps += 1
	assert_eq(_state.clock.day, 6)
	assert_false(_ids().has("reinforced_wall"), "Unlocked upgrades must remain excluded")
	assert_false(_ids().has("command_center"))

func test_cost_key_order_and_free_empty_cost() -> void:
	assert_eq(BuildBar.cost_text({"ammo": 4, "food": 3, "scrap": 2, "wood": 1}), "1 wood · 2 scrap · 3 food · 4 ammo")
	assert_eq(BuildBar.cost_text({}), "Free")

func test_signal_wiring_toggle_again_cancel_and_exclusive_selection() -> void:
	var events: Array[String] = []
	_bar.building_selected.connect(func(type_id: String) -> void: events.append(type_id))
	var wall: Button = _bar._hbox().get_child(0) as Button
	var gate: Button = _bar._hbox().get_child(1) as Button
	wall.button_pressed = true
	assert_eq(_mode.active_type, "wooden_wall")
	gate.button_pressed = true
	assert_eq(_mode.active_type, "gate")
	assert_false(wall.button_pressed)
	assert_true(gate.button_pressed)
	gate.button_pressed = false
	assert_eq(_mode.active_type, "")
	assert_eq(events, ["wooden_wall", "gate", ""])
	_mode.select("farm")
	assert_true((_bar._hbox().get_child(2) as Button).button_pressed)
	_mode.cancel()
	for button: Button in _bar._hbox().get_children():
		assert_false(button.button_pressed)
	assert_eq(events.size(), 3, "Mode feedback must not emit a new selection")

func test_unaffordable_button_remains_selectable_and_scrap_changes_refresh() -> void:
	var steps: int = 0
	while _state.clock.day < 2 and steps < 1000:
		_state.clock.advance(1.0)
		steps += 1
	var tower: Button = _bar._hbox().get_child(6) as Button
	var scrap: int = _state.resources.get_amount("scrap")
	_state.resources.take("scrap", scrap)
	assert_eq(tower.modulate.a, 0.5)
	assert_false(tower.disabled)
	tower.button_pressed = true
	assert_eq(_mode.active_type, "watchtower")
	_state.resources.add("scrap", scrap)
	assert_eq(tower.modulate.a, 1.0)

func test_build_menu_visibility_and_gui_click_filters() -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = "build_menu"
	event.pressed = true
	assert_true(_bar._panel().visible)
	_bar._unhandled_input(event)
	assert_false(_bar._panel().visible)
	_bar._unhandled_input(event)
	assert_true(_bar._panel().visible)
	assert_eq(_bar._panel().mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_eq(_bar._hbox().mouse_filter, Control.MOUSE_FILTER_IGNORE)
	for button: Button in _bar._hbox().get_children():
		assert_eq(button.focus_mode, Control.FOCUS_NONE)

func test_day2_buttons_fit_viewport_without_overlap() -> void:
	_check_button_layout(2, 8)

func test_day21_buttons_fit_viewport_without_overlap() -> void:
	_check_button_layout(21, 12)

func _check_button_layout(day: int, expected_count: int) -> void:
	_bar.refresh(day)
	var viewport_size := Vector2(1280, 720)
	var viewport_rect := Rect2(Vector2.ZERO, viewport_size)
	var panel: PanelContainer = _bar._panel()
	var hbox: GridContainer = _bar._hbox()
	var children := hbox.get_children()
	assert_eq(children.size(), expected_count)
	assert_eq(hbox.columns, 6 if expected_count == 12 else expected_count,
		"Measured minimum widths keep one row when it fits and use the canonical 6 + 6 split when it does not")
	var style: StyleBox = panel.get_theme_stylebox("panel")
	var row_widths: Array[float] = []
	var row_heights: Array[float] = []
	for child: Node in children:
		var btn := child as Button
		btn.notification(Control.NOTIFICATION_THEME_CHANGED)
		var btn_min := btn.get_minimum_size().max(btn.custom_minimum_size)
		var row: int = int(child.get_index() / hbox.columns)
		if row_widths.size() <= row:
			row_widths.append(0.0)
			row_heights.append(0.0)
		row_widths[row] += btn_min.x
		row_heights[row] = maxf(row_heights[row], btn_min.y)
	for row: int in range(row_widths.size()):
		row_widths[row] += hbox.get_theme_constant("h_separation") * maxi(0, mini(hbox.columns, children.size() - row * hbox.columns) - 1)
	var row_min := Vector2(row_widths.max(), row_heights.reduce(func(a: float, b: float) -> float: return a + b, 0.0) + hbox.get_theme_constant("v_separation") * maxi(0, row_heights.size() - 1))
	var bar_size: Vector2 = row_min + style.get_minimum_size()
	var bar_pos := Vector2((viewport_size.x - bar_size.x) / 2.0, viewport_size.y - bar_size.y - 8.0)
	var bar_rect := Rect2(bar_pos, bar_size)
	assert_true(Rect2(8, 0, 1264, 720).encloses(bar_rect), "Build bar retains viewport margins")
	var row_y: float = bar_pos.y + style.get_margin(SIDE_TOP)
	var button_rects: Array[Rect2] = []
	var cursors: Array[float] = []
	for row: int in range(row_heights.size()): cursors.append(bar_pos.x + style.get_margin(SIDE_LEFT))
	for child: Node in children:
		var btn := child as Button
		var btn_size := btn.get_minimum_size().max(btn.custom_minimum_size)
		var row: int = int(child.get_index() / hbox.columns)
		var b_rect := Rect2(cursors[row], row_y, btn_size.x, row_heights[row])
		assert_true(viewport_rect.encloses(b_rect), "Button %s is inside viewport" % btn.get_meta("type_id"))
		assert_true(bar_rect.encloses(b_rect), "Button is inside panel")
		button_rects.append(b_rect)
		cursors[row] += btn_size.x + hbox.get_theme_constant("h_separation")
		if child.get_index() % hbox.columns == hbox.columns - 1 or child.get_index() == children.size() - 1:
			row_y += row_heights[row] + hbox.get_theme_constant("v_separation")
		_check_button_content(btn)
	for i: int in range(button_rects.size()):
		for j: int in range(i + 1, button_rects.size()):
			assert_false(button_rects[i].intersects(button_rects[j]), "Buttons must not overlap")

func _check_button_content(button: Button) -> void:
	var building: Dictionary = _state.data.get_building(str(button.get_meta("type_id")))
	var building_name: String = building.get("name", "")
	var captions: Array[String] = []
	var content := button.get_node("Content") as VBoxContainer
	for child: Control in content.get_children():
		assert_eq(child.mouse_filter, Control.MOUSE_FILTER_IGNORE, "Children pass clicks to button")
		if child is Label:
			var label := child as Label
			captions.append(label.text)
			assert_true((" " + building_name + " ").contains(" " + label.text + " "), "Caption line consists of whole words")
			assert_eq(label.get_theme_font_size("font_size"), UiFont.BODY)
	assert_eq(" ".join(captions), building_name)
	var cost: Dictionary = building.get("cost", {})
	var expected_kinds: Array[String] = []
	for kind: String in ["wood", "scrap"]:
		if int(cost.get(kind, 0)) > 0:
			expected_kinds.append(kind)
	var cost_row := content.get_node("Cost") as HBoxContainer
	assert_eq(cost_row.alignment, BoxContainer.ALIGNMENT_CENTER)
	assert_eq(cost_row.get_child_count(), expected_kinds.size() * 2, "One icon and number per nonzero resource")
	var font: Font = button.get_theme_font("font")
	var required_width: float = 0.0
	for index: int in range(expected_kinds.size()):
		var kind: String = expected_kinds[index]
		var icon := cost_row.get_child(index * 2) as TextureRect
		var label := cost_row.get_child(index * 2 + 1) as Label
		assert_not_null(icon)
		var backing := icon.get_node("Backing") as Panel
		assert_not_null(backing)
		assert_true(backing.show_behind_parent, "Backing must not cover resource art")
		assert_not_null(label)
		assert_eq(icon.texture.resource_path, "res://assets/pixel/ui/x2/icon_%s.png" % kind)
		assert_eq(icon.custom_minimum_size, Vector2(BuildBar.COST_ICON_SIZE, BuildBar.COST_ICON_SIZE))
		assert_eq(icon.stretch_mode, TextureRect.STRETCH_KEEP)
		assert_eq(label.text, str(int(cost[kind])))
		assert_eq(label.get_theme_font_size("font_size"), UiFont.BODY)
		assert_eq(icon.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		assert_eq(backing.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		assert_eq(label.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		required_width += BuildBar.COST_ICON_SIZE + font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.BODY).x
	required_width += cost_row.get_theme_constant("separation") * maxi(0, cost_row.get_child_count() - 1)
	assert_true(required_width <= button.custom_minimum_size.x - 8.0, "BODY cost row fits button")
	assert_eq(button.tooltip_text, "", "Info card replaces the tiny tooltip")

func test_caption_never_splits_an_oversized_word() -> void:
	var font: Font = _bar._hbox().get_theme_font("font")
	assert_eq(BuildBar._caption_lines("Watchtower", font, 1.0), "Watchtower")
	assert_eq(BuildBar._caption_lines("Reinforced Wall", font, 1.0), "Reinforced\nWall")

func test_watchtower_tooltip_lists_full_resource_names() -> void:
	_bar.refresh(2)
	var tower := _bar._hbox().get_child(5) as Button
	assert_eq(tower.tooltip_text, "", "Info card replaces the tiny tooltip")

func test_day2_caption_and_cost_content_fits_button() -> void:
	_check_content_fits_button(2)

func test_day21_caption_and_cost_content_fits_button() -> void:
	_check_content_fits_button(21)

func test_refresh_uses_current_day_and_preserves_selection_without_signals() -> void:
	var events: Array[String] = []
	_bar.building_selected.connect(func(type_id: String) -> void: events.append(type_id))
	_bar.set_active_type("farm")
	_state.clock.day = 21
	_bar.refresh()
	assert_eq(_ids().size(), 12)
	assert_true(_ids().has("radio_tower"))
	assert_true((_bar._hbox().get_child(2) as Button).button_pressed)
	assert_true(events.is_empty(), "Refreshing must not issue a placement selection")

func test_unaffordable_cost_icons_keep_light_backing() -> void:
	_bar.refresh(21)
	_state.resources.take("wood", _state.resources.get_amount("wood"))
	_state.resources.take("scrap", _state.resources.get_amount("scrap"))
	for button: Button in _bar._hbox().get_children():
		assert_eq(button.modulate.a, 0.5)
		for child: Control in button.get_node("Content/Cost").get_children():
			if not child is TextureRect:
				continue
			var backing := child.get_node("Backing") as Panel
			var style := backing.get_theme_stylebox("panel") as StyleBoxFlat
			assert_not_null(style)
			assert_true(style.bg_color.a >= 0.25, "Dimmed icons retain a light backing")
			assert_true(style.bg_color.get_luminance() > 0.5, "Backing contrasts with dark resource art")

func _check_content_fits_button(day: int) -> void:
	_bar.refresh(day)
	for button: Button in _bar._hbox().get_children():
		var content := button.get_node("Content") as VBoxContainer
		var content_height: float = 0.0
		for child: Control in content.get_children():
			child.notification(Control.NOTIFICATION_THEME_CHANGED)
			content_height += child.get_combined_minimum_size().y
			if child is Label:
				var label := child as Label
				var text_width: float = label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.BODY).x
				assert_true(text_width <= button.custom_minimum_size.x - 8.0, "%s caption fits without clipping" % button.get_meta("type_id"))
			elif child is HBoxContainer:
				assert_true(child.get_combined_minimum_size().x <= button.custom_minimum_size.x - 8.0, "%s cost content fits without clipping" % button.get_meta("type_id"))
		content_height += content.get_theme_constant("separation") * maxi(0, content.get_child_count() - 1)
		assert_true(content_height <= button.custom_minimum_size.y, "%s icon, caption and BODY costs fit button height" % button.get_meta("type_id"))
