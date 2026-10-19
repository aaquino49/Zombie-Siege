extends TestCase

var _world: Node2D
var _state: GameState
var _bm: BuildMode
var _events: Array = []

func before_each() -> void:
	_state = GameState.new(GameData.load_default(), 1337)
	# Placement/cost tests need a free six-tile drag lane and 2x2 shelter
	# footprint, independent of the seeded resource layout outside the clearing.
	var lane: Vector2i = _state.map.command_center_origin() + Vector2i(0, -4)
	for t: Vector2i in Grid.rect_tiles(lane, Vector2i(6, 2)):
		_state.map.vacate(t, Vector2i.ONE)
		_state.map._node_amounts.erase(t)
	assert_true(_state.map.is_free(lane, Vector2i(6, 2)))
	var scene: PackedScene = load("res://scenes/world/world.tscn")
	_world = scene.instantiate() as Node2D
	_world.set("ground", _world.get_node("Ground"))
	_world.set("props", _world.get_node("YSort/Props"))
	_world.set("buildings", _world.get_node("YSort/Buildings"))
	_world.set("camera", _world.get_node("Camera2D"))
	_world.call("_ready")
	_world.call("bind", _state)

	_bm = _world.get_node("BuildMode") as BuildMode
	_bm.bind(_state)
	_events.clear()
	_bm.mode_changed.connect(func(t: String) -> void: _events.append(t))

func after_each() -> void:
	_world.free()
	_state = null
	_bm = null

func test_select_sets_active_type_and_emits_signal() -> void:
	_bm.select("wooden_wall")
	assert_eq(_bm.active_type, "wooden_wall")
	assert_eq(_events.size(), 1)
	assert_eq(_events[0], "wooden_wall")

func test_free_tile_ghost_is_visible_and_green() -> void:
	_state.resources.add("wood", 100) # Give enough resources for wooden_wall
	_bm.select("wooden_wall")
	var t := _state.map.command_center_origin() + Vector2i(0, -4)
	_bm.preview_at(t)
	_bm._process(0.0)
	var s: Sprite2D = _bm._ghost_sprites[0]
	assert_true(s.visible)
	assert_eq(s.modulate, Color(0.4, 1, 0.4, 0.6))
	assert_eq(s.position, Vector2(t) * Grid.TILE + Vector2(32, 64))

func test_shelter_on_cc_ghost_is_red_and_aligned() -> void:
	_bm.select("shelter")
	var cc_origin := _state.map.command_center_origin()
	_bm.preview_at(cc_origin)
	_bm._process(0.0)
	var s: Sprite2D = _bm._ghost_sprites[0]
	assert_true(s.visible)
	assert_eq(s.modulate, Color(1.0, 0.35, 0.35, 0.6))
	assert_eq(s.position, Vector2(cc_origin) * Grid.TILE + Vector2(64, 128))

func test_cancel_hides_ghosts_and_clears_active_type() -> void:
	_bm.select("shelter")
	_bm.preview_at(_state.map.command_center_origin())
	_bm._process(0.0)
	_bm.cancel()
	assert_eq(_bm.active_type, "")
	assert_eq(_events.size(), 2)
	assert_eq(_events[1], "")
	for s in _bm._ghost_sprites: assert_false(s.visible)
	for r in _bm._ghost_rects: assert_false(r.visible)
	for l in _bm._ghost_labels: assert_false(l.visible)

func test_select_empty_string_cancels() -> void:
	_bm.select("shelter")
	_bm.preview_at(_state.map.command_center_origin())
	_bm._process(0.0)
	_bm.select("")
	assert_eq(_bm.active_type, "")
	for s in _bm._ghost_sprites: assert_false(s.visible)

func test_place_at_free_tile_consumes_cost_and_cancels() -> void:
	_state.resources.add("wood", 100)
	_bm.select("shelter")
	var t := _state.map.command_center_origin() + Vector2i(0, -4)
	var start_wood: int = _state.resources.get_amount("wood")
	var start_buildings: int = _state.buildings.all().size()
	var res: int = _bm.place_at(t, false)
	assert_eq(res, Placement.Result.OK)
	var cost: int = _state.data.get_building("shelter")["cost"]["wood"]
	assert_eq(_state.resources.get_amount("wood"), start_wood - cost)
	assert_eq(_state.buildings.all().size(), start_buildings + 1)
	assert_eq(_bm.active_type, "")

func test_place_at_keep_mode() -> void:
	_state.resources.add("wood", 100)
	_bm.select("shelter")
	var t := _state.map.command_center_origin() + Vector2i(0, -4)
	var res: int = _bm.place_at(t, true)
	assert_eq(res, Placement.Result.OK)
	assert_eq(_bm.active_type, "shelter")

func test_place_at_cc_fails_and_spends_nothing() -> void:
	_state.resources.add("wood", 100)
	_bm.select("shelter")
	var start_wood: int = _state.resources.get_amount("wood")
	var res: int = _bm.place_at(_state.map.command_center_origin(), false)
	assert_ne(res, Placement.Result.OK)
	assert_eq(_state.resources.get_amount("wood"), start_wood)

func test_drag_wall_stops_when_wood_runs_out() -> void:
	_state.resources.take("wood", _state.resources.get_amount("wood"))
	_state.resources.add("wood", 15)
	var a := _state.map.command_center_origin() + Vector2i(0, -4)
	_bm.select("wooden_wall")
	_bm.begin_drag(a)
	var placed: int = _bm.end_drag(a + Vector2i(5, 0), false)
	assert_eq(placed, 3)
	assert_eq(_state.map.occupant_at(a), WorldMap.Occupant.BUILDING)
	assert_eq(_state.map.occupant_at(a + Vector2i(1, 0)), WorldMap.Occupant.BUILDING)
	assert_eq(_state.map.occupant_at(a + Vector2i(2, 0)), WorldMap.Occupant.BUILDING)
	assert_ne(_state.map.occupant_at(a + Vector2i(3, 0)), WorldMap.Occupant.BUILDING)
	assert_eq(_bm.active_type, "")

func test_drag_preview_pooling() -> void:
	var a := _state.map.command_center_origin() + Vector2i(0, -4)
	_state.resources.add("wood", 100) # Give enough wood so the walls are OK
	_bm.select("wooden_wall")
	_bm.begin_drag(a)
	_bm.preview_at(a + Vector2i(4, 0))
	_bm._process(0.0)
	var pool_size: int = _bm._ghost_sprites.size()
	var visible_count: int = 0
	for s in _bm._ghost_sprites:
		if s.visible:
			visible_count += 1
	assert_eq(visible_count, 5)
	
	_bm._process(0.0)
	assert_eq(_bm._ghost_sprites.size(), pool_size)

func test_drag_skips_blocked_tiles_and_places_remaining_free_tiles() -> void:
	var a: Vector2i = _state.map.command_center_origin() + Vector2i(0, -4)
	assert_eq(_state.try_place("wooden_wall", a + Vector2i(1, 0)), Placement.Result.OK)
	var initial_wood: int = _state.resources.get_amount("wood")
	var cost: int = int(_state.data.get_building("wooden_wall")["cost"]["wood"])
	_bm.select("wooden_wall")
	_bm.begin_drag(a)
	var placed: int = _bm.end_drag(a + Vector2i(3, 0), true)
	assert_eq(placed, 3, "A blocked tile must be skipped; free tiles beyond it must still be placed")
	assert_eq(_state.buildings.count_of("wooden_wall"), 4)
	assert_eq(_state.resources.get_amount("wood"), initial_wood - cost * 3)
	assert_eq(_bm.active_type, "wooden_wall")
	assert_false(_bm._is_dragging)
	for i: int in range(4):
		assert_not_null(_state.buildings.get_at(a + Vector2i(i, 0)))

func test_drag_preview_marks_unaffordable_tail_red_and_places_first_three() -> void:
	_state.resources.take("wood", _state.resources.get_amount("wood") - 15)
	var a: Vector2i = _state.map.command_center_origin() + Vector2i(0, -4)
	_bm.select("wooden_wall")
	_bm.begin_drag(a)
	_bm.preview_at(a + Vector2i(5, 0))
	_bm._process(0.0)
	assert_eq(_bm._ghost_sprites.size(), 6)
	for i: int in range(6):
		var sprite: Sprite2D = _bm._ghost_sprites[i]
		assert_true(sprite.visible)
		assert_eq(sprite.position, Grid.tile_to_world(a + Vector2i(i, 0)) + Vector2(0, 32))
		assert_eq(sprite.modulate, Color(0.4, 1, 0.4, 0.6) if i < 3 else Color(1, 0.35, 0.35, 0.6))
		assert_eq(_bm._ghost_labels[i].visible, i >= 3)
		if i >= 3:
			assert_eq(_bm._ghost_labels[i].text, Placement.result_text(Placement.Result.UNAFFORDABLE))
	assert_eq(_bm.end_drag(a + Vector2i(5, 0), false), 3)
	assert_eq(_state.buildings.count_of("wooden_wall"), 3)
	assert_eq(_state.resources.get_amount("wood"), 0)
	for i: int in range(6):
		var building: Building = _state.buildings.get_at(a + Vector2i(i, 0))
		if i < 3:
			assert_not_null(building)
			if building != null:
				assert_eq(building.type_id, "wooden_wall")
		else:
			assert_eq(building, null)

func test_invalid_shelter_matches_command_center_footprint_and_label() -> void:
	var origin: Vector2i = _state.map.command_center_origin()
	var cc: Building = _state.buildings.get_at(origin)
	_bm.select("shelter")
	_bm.preview_at(origin)
	_bm._process(0.0)
	var sprite: Sprite2D = _bm._ghost_sprites[0]
	assert_eq(sprite.position, cc.center_world() + Vector2(0, 64))
	assert_eq(sprite.scale, Vector2(Grid.PIXEL_SCALE, Grid.PIXEL_SCALE))
	var drawn_bottom: float = sprite.position.y + (sprite.offset.y + sprite.texture.get_height() / 2.0) * sprite.scale.y
	var footprint_bottom: float = Vector2(origin).y * Grid.TILE + float(cc.size.y) * Grid.TILE
	assert_almost_eq(drawn_bottom, footprint_bottom, 0.01)
	assert_true(_bm._ghost_labels[0].visible)
	assert_eq(_bm._ghost_labels[0].text, Placement.result_text(Placement.Result.BLOCKED))
	assert_eq(_bm._ghost_labels[0].get_theme_color("font_color"), Color(1, 0.2, 0.2))

func test_select_empty_cancels_entire_drag_pool_and_emits_signal() -> void:
	var a: Vector2i = _state.map.command_center_origin()
	_bm.select("wooden_wall")
	_bm.begin_drag(a)
	_bm.preview_at(a + Vector2i(4, 0))
	_bm._process(0.0)
	var pool_size: int = _bm._ghost_sprites.size()
	_bm.select("")
	assert_eq(_events, ["wooden_wall", ""])
	assert_eq(_bm.active_type, "")
	assert_false(_bm._is_dragging)
	assert_false(_bm._is_preview_pinned)
	_bm._process(0.0)
	assert_eq(_bm._ghost_sprites.size(), pool_size)
	for sprite: Sprite2D in _bm._ghost_sprites:
		assert_false(sprite.visible)
	for rect: ColorRect in _bm._ghost_rects:
		assert_false(rect.visible)
	for label: Label in _bm._ghost_labels:
		assert_false(label.visible)

func test_unbound_handlers_and_detached_hover_need_no_viewport() -> void:
	_bm.bind(null)
	_bm.select("wooden_wall")
	_bm._process(0.0)
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	_bm._unhandled_input(event)
	assert_eq(_bm._get_hovered_tile(), _bm._preview_origin)
	_bm.bind(_state)
	var a: Vector2i = _state.map.command_center_origin() + Vector2i(0, -4)
	_bm.preview_at(a)
	_bm.select("wooden_wall")
	assert_false(_bm._is_preview_pinned)
	assert_eq(_bm._get_hovered_tile(), a)

func test_drag_preview_skips_blocked_tile_in_cost_budget() -> void:
	var a: Vector2i = _state.map.command_center_origin() + Vector2i(0, -4)
	assert_eq(_state.try_place("wooden_wall", a + Vector2i(1, 0)), Placement.Result.OK)
	var cost: int = int(_state.data.get_building("wooden_wall")["cost"]["wood"])
	_state.resources.take("wood", _state.resources.get_amount("wood") - cost * 3)
	_bm.select("wooden_wall")
	_bm.begin_drag(a)
	_bm.preview_at(a + Vector2i(4, 0))
	_bm._process(0.0)
	for i: int in range(5):
		var expected_ok: bool = i == 0 or i == 2 or i == 3
		assert_eq(_bm._ghost_sprites[i].modulate, Color(0.4, 1, 0.4, 0.6) if expected_ok else Color(1, 0.35, 0.35, 0.6))
	assert_eq(_bm._ghost_labels[1].text, Placement.result_text(Placement.Result.BLOCKED))
	assert_eq(_bm._ghost_labels[4].text, Placement.result_text(Placement.Result.UNAFFORDABLE))
	assert_eq(_state.resources.get_amount("wood"), cost * 3, "Preview must not spend resources")
	assert_eq(_bm.end_drag(a + Vector2i(4, 0), true), 3)
	assert_eq(_state.resources.get_amount("wood"), 0)
	assert_not_null(_state.buildings.get_at(a + Vector2i(3, 0)))
	assert_eq(_state.buildings.get_at(a + Vector2i(4, 0)), null)
