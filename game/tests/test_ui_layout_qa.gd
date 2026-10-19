extends "res://tests/test_case.gd"
## T-067: exercise dawn rebuilding and each button without a viewport.

const Selection = preload("res://scripts/world/selection_controller.gd")

func test_full_build_bar_after_dawn_clears_selected_farm_and_hud() -> void:
	var state: GameState = GameState.new(GameData.load_default(), 12345)
	var bar: BuildBar = preload("res://scenes/ui/build_bar.tscn").instantiate()
	var info: InfoPanel = preload("res://scenes/ui/info_panel.tscn").instantiate()
	var hud: CanvasLayer = preload("res://scenes/ui/hud.tscn").instantiate()
	var roster: RosterPanel = preload("res://scenes/ui/roster_panel.tscn").instantiate()
	var selection: SelectionController = Selection.new()
	selection.bind(state)
	bar.bind(state)
	info.bind(state, selection)
	var farm: Building = state.buildings.add("farm", Vector2i(0, 0), true)
	selection.select_building(farm.uid)
	info.refresh()
	assert_true(info.visible, "Farm info is selected and visible")
	state.clock.day = 8
	state.clock.dawn.emit(8)
	var viewport_size := Vector2(1280, 720)
	var viewport_rect := Rect2(Vector2.ZERO, viewport_size)
	var bar_panel: PanelContainer = bar.get_node("Panel")
	var hbox: GridContainer = bar.get_node("Panel/HBox")
	var row_widths: Array[float] = []
	var row_heights: Array[float] = []
	for child: Node in hbox.get_children():
		# Off-tree nodes miss theme propagation. Refresh it and query intrinsic
		# minima directly to bypass combined minima cached before font overrides.
		child.notification(Control.NOTIFICATION_THEME_CHANGED)
		var button_min: Vector2 = (child as Button).get_minimum_size().max((child as Button).custom_minimum_size)
		var row: int = int(child.get_index() / hbox.columns)
		if row_widths.size() <= row:
			row_widths.append(0.0)
			row_heights.append(0.0)
		row_widths[row] += button_min.x
		row_heights[row] = maxf(row_heights[row], button_min.y)
	for row: int in range(row_widths.size()):
		row_widths[row] += hbox.get_theme_constant("h_separation") * maxi(0, mini(hbox.columns, hbox.get_child_count() - row * hbox.columns) - 1)
	var total_height: float = row_heights.reduce(func(a: float, b: float) -> float: return a + b, 0.0) + hbox.get_theme_constant("v_separation") * maxi(0, row_heights.size() - 1)
	var row_min := Vector2(row_widths.max(), total_height)
	var style: StyleBox = bar_panel.get_theme_stylebox("panel")
	var bar_rect: Rect2 = _anchored_rect(bar_panel, viewport_size, row_min + style.get_minimum_size())
	BuildBar.position_above_bar(info.get_node("PanelContainer") as Control, viewport_size.y, bar_rect.position.y)
	var info_rect: Rect2 = _anchored_rect(info.get_node("PanelContainer"), viewport_size)
	assert_false(bar_rect.intersects(info_rect), "Selected farm clears rebuilt full bar")
	assert_almost_eq(bar_rect.position.y - info_rect.end.y, 8.0, 0.01, "Info panel is 8px above bar")
	assert_true(Rect2(8, 0, 1264, 720).encloses(bar_rect), "Full bar retains 8px side margins: %s" % bar_rect)
	assert_false(info_rect.intersects(_anchored_rect(hud.get_node("TopBar"), viewport_size)), "Farm info clears real TopBar")
	assert_false(info_rect.intersects(_anchored_rect(roster.get_node("ToggleButton"), viewport_size)), "Farm info clears real roster toggle")
	assert_false(info_rect.intersects(_anchored_rect(roster.get_node("PanelContainer"), viewport_size)), "Farm info clears roster panel")
	var expected: Array[String] = []
	for type_id: String in state.data.buildings_unlocked_on(8):
		if Placement.is_placeable_type(state.data, type_id):
			expected.append(type_id)
	assert_eq(hbox.get_child_count(), expected.size(), "Every unlocked placeable has a button after dawn")
	# Synchronous off-tree containers have no sort frame. Evaluate the HBox's
	# minimum-width row from actual button minima, separation and panel margins.
	var cursors: Array[float] = []
	for _row: int in range(row_heights.size()): cursors.append(bar_rect.position.x + style.get_margin(SIDE_LEFT))
	var row_y: float = bar_rect.position.y + style.get_margin(SIDE_TOP)
	for child: Node in hbox.get_children():
		var button: Button = child as Button
		var type_id: String = button.get_meta("type_id")
		assert_has(expected, type_id, "Button is an unlocked placeable")
		expected.erase(type_id)
		var row: int = int(child.get_index() / hbox.columns)
		var button_rect := Rect2(cursors[row], row_y, button.get_minimum_size().max(button.custom_minimum_size).x, row_heights[row])
		assert_true(viewport_rect.encloses(button_rect), "%s button is fully inside viewport" % type_id)
		assert_true(bar_rect.encloses(button_rect), "%s button is inside build panel" % type_id)
		cursors[row] += button_rect.size.x + hbox.get_theme_constant("h_separation")
		if child.get_index() % hbox.columns == hbox.columns - 1 or child.get_index() == hbox.get_child_count() - 1:
			row_y += row_heights[row] + hbox.get_theme_constant("v_separation")
	assert_true(expected.is_empty(), "All placeable types accounted for")
	bar.free()
	info.free()
	hud.free()
	roster.free()
	selection.free()

func _anchored_rect(control: Control, parent_size: Vector2, minimum: Vector2 = Vector2.ZERO) -> Rect2:
	var start := Vector2(parent_size.x * control.anchor_left + control.offset_left,
		parent_size.y * control.anchor_top + control.offset_top)
	var end := Vector2(parent_size.x * control.anchor_right + control.offset_right,
		parent_size.y * control.anchor_bottom + control.offset_bottom)
	var requested: Vector2 = end - start
	var actual: Vector2 = requested.max(minimum.max(control.get_combined_minimum_size()))
	var growth: Vector2 = actual - requested
	if control.grow_horizontal == Control.GROW_DIRECTION_BEGIN:
		start.x -= growth.x
	elif control.grow_horizontal == Control.GROW_DIRECTION_BOTH:
		start.x -= growth.x / 2.0
	if control.grow_vertical == Control.GROW_DIRECTION_BEGIN:
		start.y -= growth.y
	elif control.grow_vertical == Control.GROW_DIRECTION_BOTH:
		start.y -= growth.y / 2.0
	return Rect2(start, actual)
