extends "res://tests/test_case.gd"

const SelectionController = preload("res://scripts/world/selection_controller.gd")

func test_ui_layout_for_T067() -> void:
	var data: GameData = preload("res://scripts/sim/game_data.gd").load_default()
	var state: GameState = GameState.new(data, 12345)

	# Unlock all buildings by setting clock day high
	state.clock.day = 100

	# Instantiate BuildBar and grab its Panel
	var build_bar: BuildBar = (load("res://scenes/ui/build_bar.tscn") as PackedScene).instantiate() as BuildBar
	var bb_panel: Control = build_bar.get_node("Panel") as Control

	# Instantiate InfoPanel and grab its PanelContainer
	var info_panel: InfoPanel = (load("res://scenes/ui/info_panel.tscn") as PackedScene).instantiate() as InfoPanel
	var ip_panel: Control = info_panel.get_node("PanelContainer") as Control

	# Evaluate anchors against a 1280x720 rect without reparenting
	var screen_size: Vector2 = Vector2(1280, 720)

	# Bind state (this rebuilds buttons in BuildBar)
	build_bar.bind(state)

	var selection: SelectionController = SelectionController.new()
	selection.bind(state)
	info_panel.bind(state, selection)

	# Select a survivor to populate InfoPanel so it sets minimum sizes
	var s: Survivor = state.survivors.add("Test", "blue", Vector2i(0, 0))
	selection.select_survivor(s.uid)
	info_panel.refresh()

	# Off-tree containers have no layout frame; use their combined minimum sizes.
	bb_panel.size = bb_panel.get_combined_minimum_size()
	ip_panel.size = ip_panel.get_combined_minimum_size()

	# Evaluate anchors and offsets against the target viewport.
	var bb_rect: Rect2 = _compute_rect(bb_panel, screen_size)
	var ip_rect: Rect2 = _compute_rect(ip_panel, screen_size)

	assert_false(bb_rect.intersects(ip_rect), "InfoPanel intersects BuildBar")

	var screen_rect: Rect2 = Rect2(0, 0, 1280, 720)
	assert_true(screen_rect.encloses(bb_rect), "BuildBar panel fully inside screen")

	# Check the build row's minimum width with panel margins.
	var bb_hbox: GridContainer = bb_panel.get_node("HBox") as GridContainer
	var hbox_min: Vector2 = bb_hbox.get_combined_minimum_size()
	assert_true(hbox_min.x + 16 <= 1280, "BuildBar width fits in 1280")

	var top_bar_rect: Rect2 = Rect2(0, 0, 1280, 48)
	assert_false(ip_rect.intersects(top_bar_rect), "InfoPanel intersects TopBar")

	var survivors_btn_rect: Rect2 = Rect2(8, 56, 120, 32)
	assert_false(ip_rect.intersects(survivors_btn_rect), "InfoPanel intersects Survivors button")

	build_bar.free()
	info_panel.free()
	selection.free()

func _compute_rect(ctrl: Control, parent_size: Vector2) -> Rect2:
	# Compute position from anchors and offsets
	var left: float = parent_size.x * ctrl.anchor_left + ctrl.offset_left
	var top: float = parent_size.y * ctrl.anchor_top + ctrl.offset_top
	var right: float = parent_size.x * ctrl.anchor_right + ctrl.offset_right
	var bottom: float = parent_size.y * ctrl.anchor_bottom + ctrl.offset_bottom

	# Expand undersized bounds in the control's configured growth direction.
	var min_size: Vector2 = ctrl.get_combined_minimum_size()
	var rect: Rect2 = Rect2(left, top, right - left, bottom - top)

	if rect.size.x < min_size.x:
		var d: float = min_size.x - rect.size.x
		if ctrl.grow_horizontal == Control.GROW_DIRECTION_BEGIN: # 0
			rect.position.x -= d
			rect.size.x = min_size.x
		elif ctrl.grow_horizontal == Control.GROW_DIRECTION_BOTH: # 2
			rect.position.x -= d / 2.0
			rect.size.x = min_size.x
		else: # 1 (END)
			rect.size.x = min_size.x

	if rect.size.y < min_size.y:
		var d: float = min_size.y - rect.size.y
		if ctrl.grow_vertical == Control.GROW_DIRECTION_BEGIN: # 0
			rect.position.y -= d
			rect.size.y = min_size.y
		elif ctrl.grow_vertical == Control.GROW_DIRECTION_BOTH: # 2
			rect.position.y -= d / 2.0
			rect.size.y = min_size.y
		else: # 1
			rect.size.y = min_size.y

	return rect
