extends TestCase
## T-013 / T-059: screenshot framing and signal-to-popup integration.

func test_gathering_scenario_keeps_harvesting_gatherers_in_view() -> void:
	var previous_state: GameState = Game.state
	var state: GameState = GameState.new(GameData.load_default(), 1337)
	Game.state = state
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	var camera: CameraController = main.get_node("World/Camera2D")
	camera.map_px = Vector2(state.map.size(), state.map.size()) * Grid.TILE
	var layer: FloatingTextLayer = main.get_node("World/FloatingText")
	layer.bind(state)
	var scenario: GDScript = load("res://dev/scenarios/gathering.gd")
	scenario.setup(main)
	assert_true(state.clock.paused)
	assert_gt(state.resources.get_amount("wood"), int(state.data.balance("start_wood")))
	# Apply the same clamp as CameraController._process, without a viewport.
	var viewport_size: Vector2 = Vector2(1280, 720)
	var center: Vector2 = CameraMath.clamp_position(camera.position, camera.zoom.x, viewport_size, camera.map_px)
	assert_eq(center, camera.position, "Framing must not be clamped to the map edge")
	assert_true(camera.zoom.x >= 0.6 and camera.zoom.x <= 1.0, "Popup needs a readable zoom")
	assert_eq(state.clock.day, 1)
	assert_eq(state.clock.phase, GameClock.Phase.DAY)
	var visible_world: Rect2 = Rect2(center - viewport_size / camera.zoom / 2.0, viewport_size / camera.zoom)
	var cc: Building = state.buildings.all_of_type("command_center")[0]
	var safe_world: Rect2 = visible_world.grow(-64.0 / camera.zoom.x)
	var bounds: Rect2 = Rect2(Vector2(cc.origin) * Grid.TILE, Vector2(cc.size) * Grid.TILE)
	assert_true(safe_world.encloses(bounds), "Full CC needs the capture margin")
	var sum_pos: Vector2 = Vector2.ZERO
	var count: int = 0
	for s: Survivor in state.survivors.all():
		if s.job == Survivor.Job.GATHERER and s.gather_kind == "wood":
			sum_pos += s.pos
			count += 1
			var sprite_rect: Rect2 = Rect2(s.pos - Vector2(24, 24), Vector2(48, 48))
			var tree_rect: Rect2 = Rect2(Vector2(s.work_tile) * Grid.TILE, Vector2(Grid.TILE, Grid.TILE))
			assert_true(safe_world.encloses(sprite_rect), "Gatherer needs the capture margin")
			assert_true(safe_world.encloses(tree_rect), "Tree needs the capture margin")
			bounds = bounds.merge(sprite_rect).merge(tree_rect)
			assert_eq(s.activity, Survivor.Activity.HARVESTING)
			assert_true(Grid.in_ring(s.tile(), s.work_tile, Vector2i.ONE))
			assert_true(visible_world.has_point(s.pos), "Gatherer %d at %s is outside capture %s" % [s.uid, s.pos, visible_world])
			assert_true(visible_world.has_point(Grid.tile_to_world(s.work_tile)), "Harvested tree must be in capture")
	assert_gt(count, 0)
	var expected_center: Vector2 = (cc.center_world() + sum_pos / float(count)) / 2.0
	assert_eq(camera.position, expected_center)
	if camera.zoom.x < 1.0:
		var larger_zoom: float = camera.zoom.x + 0.001
		var larger_safe: Rect2 = Rect2(center - (viewport_size / 2.0 - Vector2(64, 64)) / larger_zoom, (viewport_size - Vector2(128, 128)) / larger_zoom)
		assert_false(larger_safe.encloses(bounds), "Scenario must use the largest fitting zoom")
	var found_popup: bool = false
	for child: Node in layer.get_children():
		var label: Label = child as Label
		if label.visible and label.text == "+10 wood":
			found_popup = true
			assert_true(visible_world.encloses(Rect2(label.position, label.size)), "Popup must be visible")
			assert_true(label.get_theme_font_size("font_size") * camera.zoom.x >= 10.8)
	assert_true(found_popup, "Capture must contain the delivery popup")
	assert_false(layer.is_processing(), "Scenario popup must survive to frame 120")
	main.free()
	Game.state = previous_state

func test_gathering_scenario_gatherers_are_not_hidden_by_build_bar() -> void:
	var previous_state: GameState = Game.state
	var state: GameState = GameState.new(GameData.load_default(), 1337)
	Game.state = state
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	var scenario: GDScript = load("res://dev/scenarios/gathering.gd")
	scenario.setup(main)
	var camera: Camera2D = main.get_node("World/Camera2D")
	var bar: BuildBar = main.get_node("BuildBarLayer")
	bar.bind(state)
	var panel: PanelContainer = bar.get_node("Panel")
	var viewport_size: Vector2 = Vector2(1280, 720)
	# Containers outside the tree do not lay out, so resolve the anchored
	# bottom-center panel from its actual content minimum and scene offsets.
	var hbox: GridContainer = bar.get_node("Panel/HBox")
	var panel_size: Vector2 = panel.get_theme_stylebox("panel").get_minimum_size()
	var content_size: Vector2 = Vector2.ZERO
	for child: Node in hbox.get_children():
		var button: Button = child as Button
		content_size.x += button.custom_minimum_size.x
		content_size.y = maxf(content_size.y, button.custom_minimum_size.y)
	content_size.x += maxi(0, hbox.get_child_count() - 1) * hbox.get_theme_constant("separation")
	panel_size += content_size
	assert_gt(panel_size.x, 300.0, "Build bar must include its populated buttons")
	assert_gt(panel_size.y, 80.0)
	var panel_bottom: float = viewport_size.y + panel.offset_bottom
	var panel_rect: Rect2 = Rect2(Vector2(viewport_size.x / 2.0 - panel_size.x / 2.0, panel_bottom - panel_size.y), panel_size)
	for s: Survivor in state.survivors.all():
		if s.job == Survivor.Job.GATHERER and s.gather_kind == "wood":
			var screen_pos: Vector2 = (s.pos - camera.position) * camera.zoom + viewport_size / 2.0
			var sprite_rect: Rect2 = Rect2(screen_pos - Vector2(24, 24) * camera.zoom, Vector2(48, 48) * camera.zoom)
			assert_false(panel_rect.intersects(sprite_rect), "Wood gatherer %d at screen %s is hidden by build bar %s" % [s.uid, screen_pos, panel_rect])
	main.free()
	Game.state = previous_state

func test_delivery_signal_spawns_colored_offset_popup_and_reuses_labels() -> void:
	var state: GameState = GameState.new(GameData.load_default(), 1337)
	var layer: FloatingTextLayer = FloatingTextLayer.new()
	layer.bind(state)
	var pos: Vector2 = Vector2(100, 100)
	state.resource_delivered.emit("wood", 6, pos)
	assert_eq(layer.get_child_count(), 1)
	var label: Label = layer.get_child(0) as Label
	assert_eq(label.text, "+6 wood")
	assert_eq(label.get_theme_color("font_color"), Color.TAN)
	assert_eq(layer._active[0].pos, pos + Vector2(0, -40))
	layer.advance(0.6)
	assert_almost_eq(label.modulate.a, 0.5)
	assert_eq(layer._active[0].pos, pos + Vector2(0, -58))
	layer.advance(0.7)
	assert_false(label.visible)
	assert_eq(layer._pool.size(), 1)
	state.resource_delivered.emit("scrap", 2, pos)
	assert_eq(layer.get_child_count(), 1)
	assert_true(label.visible)
	assert_eq(label.text, "+2 scrap")
	assert_eq(label.get_theme_color("font_color"), Color.LIGHT_STEEL_BLUE)
	layer.free()

func test_invalid_kind_preserves_load_and_kind_change_banks_without_popup() -> void:
	var state: GameState = GameState.new(GameData.load_default(), 1337)
	var s: Survivor = state.survivors.all()[1]
	s.carry_kind = "wood"
	s.carry_amount = 6
	var initial_wood: int = state.resources.get_amount("wood")
	var emissions: Array[int] = [0]
	state.resource_delivered.connect(func(_kind: String, _amount: int, _pos: Vector2) -> void: emissions[0] += 1)
	assert_false(state.set_job(s.uid, Survivor.Job.GATHERER, "gold"))
	assert_eq(s.gather_kind, "wood")
	assert_eq(s.carry_amount, 6)
	assert_eq(state.resources.get_amount("wood"), initial_wood)
	assert_true(state.set_job(s.uid, Survivor.Job.GATHERER, "scrap"))
	assert_eq(s.gather_kind, "scrap")
	assert_eq(s.carry_amount, 0)
	assert_eq(state.resources.get_amount("wood"), initial_wood + 6)
	assert_eq(emissions[0], 0)

func test_same_job_and_kind_preserve_load_path_and_work() -> void:
	var state: GameState = GameState.new(GameData.load_default(), 1337)
	var s: Survivor = state.survivors.all()[1]
	state.set_job(s.uid, Survivor.Job.GATHERER, "wood")
	s.carry_kind = "wood"
	s.carry_amount = 6
	s.path.assign([Vector2i(20, 20), Vector2i(21, 20)])
	s.target = Vector2i(21, 20)
	s.work_tile = Vector2i(22, 20)
	s.work_uid = 42
	s.work_acc = 0.75
	s.job_timer = 0.5
	s.activity = Survivor.Activity.WALKING
	var initial_wood: int = state.resources.get_amount("wood")
	for kind: String in ["wood", ""]:
		assert_true(state.set_job(s.uid, Survivor.Job.GATHERER, kind))
		assert_eq(s.carry_amount, 6)
		assert_eq(s.carry_kind, "wood")
		assert_eq(state.resources.get_amount("wood"), initial_wood)
		assert_eq(s.path, [Vector2i(20, 20), Vector2i(21, 20)])
		assert_eq(s.target, Vector2i(21, 20))
		assert_eq(s.work_tile, Vector2i(22, 20))
		assert_eq(s.work_uid, 42)
		assert_eq(s.work_acc, 0.75)
		assert_eq(s.job_timer, 0.5)
		assert_eq(s.activity, Survivor.Activity.WALKING)

func test_delivery_uses_actual_storage_ring_even_when_cc_origin_is_as_close() -> void:
	var state: GameState = GameState.new(GameData.load_default(), 1337)
	var cc: Building = state.buildings.all_of_type("command_center")[0]
	var origin: Vector2i = cc.origin + Vector2i(-4, 0)
	state.map.vacate(origin - Vector2i.ONE, Vector2i(4, 4))
	var storage: Building = state.buildings.add("storage", origin, true)
	var s: Survivor = state.survivors.all()[1]
	s.pos = Grid.tile_to_world(origin + Vector2i(2, 1))
	assert_true(Grid.in_ring(s.tile(), storage.origin, storage.size))
	assert_false(Grid.in_ring(s.tile(), cc.origin, cc.size))
	assert_true(s.tile().distance_squared_to(cc.origin) <= s.tile().distance_squared_to(storage.origin))
	var emissions: Array[Vector2] = []
	state.resource_delivered.connect(func(_kind: String, _amount: int, pos: Vector2) -> void: emissions.append(pos))
	var initial_wood: int = state.resources.get_amount("wood")
	for activity: int in [Survivor.Activity.RETURNING, Survivor.Activity.IDLE]:
		if activity == Survivor.Activity.IDLE:
			s.pos = Grid.tile_to_world(origin + Vector2i(-1, 0))
		s.activity = activity
		s.path.clear()
		s.carry_kind = "wood"
		s.carry_amount = int(state.data.balance("carry_capacity", 10))
		GathererJob.tick(state, s, 0.1)
		assert_eq(s.carry_amount, 0)
		assert_eq(s.activity, Survivor.Activity.IDLE)
	assert_eq(emissions, [storage.center_world(), storage.center_world()])
	assert_eq(state.resources.get_amount("wood"), initial_wood + 2 * int(state.data.balance("carry_capacity", 10)))

func test_delivery_without_building_uses_survivor_world_position() -> void:
	var state: GameState = GameState.new(GameData.load_default(), 1337)
	var s: Survivor = state.survivors.all()[1]
	s.pos = Vector2(123.5, 456.25)
	s.carry_kind = "wood"
	s.carry_amount = 6
	var emissions: Array[Vector2] = []
	state.resource_delivered.connect(func(_kind: String, _amount: int, pos: Vector2) -> void: emissions.append(pos))
	GathererJob._do_deliver(state, s, null)
	assert_eq(emissions, [s.pos])
	assert_eq(s.carry_amount, 0)
