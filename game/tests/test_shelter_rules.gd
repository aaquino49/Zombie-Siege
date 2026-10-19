extends TestCase

var state: GameState

func before_each() -> void:
	state = GameState.new(GameData.load_default(), 1337)
	for s: Survivor in state.survivors.all():
		state.set_job(s.uid, Survivor.Job.IDLE)

func _night() -> void:
	state.clock.phase = GameClock.Phase.NIGHT
	state.clock.elapsed = 0.0

func _ticks(count: int = 200) -> void:
	for i: int in range(count):
		state.tick(0.1)
		for s: Survivor in state.survivors.all():
			assert_true(state.map.is_passable(s.tile()), "survivor remains on passable ground")

func _shelter(complete: bool = true) -> Building:
	for y: int in range(18, 30):
		for x: int in range(18, 30):
			var origin := Vector2i(x, y)
			if Placement.check(state, "shelter", origin) == Placement.Result.OK:
				return state.buildings.add("shelter", origin, complete)
	return null

func _extras() -> void:
	for i: int in range(2):
		state.survivors.add("Extra %d" % i, "blue", state.cc_ring_tiles().back())

func test_nightfall_paths_shelters_banks_load_and_preserves_guard() -> void:
	var guard: Survivor = state.survivors.all().back()
	state.set_job(guard.uid, Survivor.Job.GUARD)
	var s: Survivor = state.survivors.all()[0]
	state.set_job(s.uid, Survivor.Job.GATHERER, "scrap")
	s.pos = Grid.tile_to_world(state.map.command_center_origin() + Vector2i(-4, 0))
	s.carry_kind = "wood"
	s.carry_amount = 3
	var wood: int = state.resources.get_amount("wood")
	var deliveries: Array[Vector2] = []
	state.resource_delivered.connect(func(_kind: String, _amount: int, p: Vector2) -> void: deliveries.append(p))
	state.clock.elapsed = float(state.data.balance("day_length")) - 0.1
	state.tick(0.1)
	state.tick(0.1)
	assert_gt(s.shelter_uid, 0)
	assert_true(s.is_moving())
	_ticks()
	for worker: Survivor in state.survivors.all():
		if worker != guard:
			assert_true(worker.sheltered)
			assert_eq(worker.activity, Survivor.Activity.SHELTERED)
			assert_true(worker.path.is_empty())
	assert_eq(state.resources.get_amount("wood"), wood + 3)
	assert_eq(s.carry_amount, 0)
	assert_eq(deliveries, [state.buildings.all_of_type("command_center")[0].center_world()])
	assert_eq(s.gather_kind, "scrap")
	assert_false(guard.sheltered)
	assert_eq(guard.tile(), guard.post_tile)
	assert_true(guard.post_tile in state.cc_ring_tiles())
	assert_eq(guard.activity, Survivor.Activity.GUARDING)

func test_cc_overflow_and_blueprint_excluded() -> void:
	_extras()
	var blueprint: Building = _shelter(false)
	_night()
	_ticks()
	var cc: Building = state.buildings.all_of_type("command_center")[0]
	assert_eq(ShelterRules.beds_held(state, cc), 6)
	assert_eq(ShelterRules.beds_held(state, blueprint), 0)
	for s: Survivor in state.survivors.all():
		assert_true(s.sheltered)

func test_nearest_free_beds_are_reserved_while_walking() -> void:
	_extras()
	var b: Building = _shelter()
	assert_not_null(b)
	for s: Survivor in state.survivors.all():
		s.pos = Grid.tile_to_world(b.origin + Vector2i.UP)
	_night()
	Jobs.tick(state, 0.1)
	var cc: Building = state.buildings.all_of_type("command_center")[0]
	assert_eq(ShelterRules.beds_held(state, b), 4)
	assert_eq(ShelterRules.beds_held(state, cc), 2)
	for i: int in range(6):
		var s: Survivor = state.survivors.all()[i]
		assert_eq(s.shelter_uid, b.uid if i < 4 else cc.uid)
	_ticks()
	for s: Survivor in state.survivors.all():
		assert_true(s.sheltered)

func test_dawn_release_sorted_ring_and_resume_gatherer_builder() -> void:
	var gatherer: Survivor = state.survivors.all()[0]
	var builder: Survivor = state.survivors.all()[1]
	state.set_job(gatherer.uid, Survivor.Job.GATHERER, "wood")
	state.set_job(builder.uid, Survivor.Job.BUILDER)
	var blueprint: Building = _shelter(false)
	_night()
	_ticks()
	state.clock.phase = GameClock.Phase.DAY
	state.clock.elapsed = 0.0
	for s: Survivor in state.survivors.all():
		ShelterRules.release(state, s)
		assert_false(s.sheltered)
		assert_eq(s.shelter_uid, 0)
		assert_eq(s.tile(), state.cc_ring_tiles()[0])
		assert_eq(s.activity, Survivor.Activity.IDLE)
		assert_eq(s.job_timer, 0.0)
	assert_eq(gatherer.job, Survivor.Job.GATHERER)
	assert_eq(gatherer.gather_kind, "wood")
	assert_eq(builder.job, Survivor.Job.BUILDER)
	_ticks(100)
	assert_gt(blueprint.progress, 0.0)
	assert_true(gatherer.activity == Survivor.Activity.HARVESTING or gatherer.carry_amount > 0)

func test_removed_shelter_releases_on_former_ring_then_cc() -> void:
	var b: Building = _shelter()
	var s: Survivor = state.survivors.all()[0]
	s.pos = Grid.tile_to_world(b.origin + Vector2i.UP)
	_night()
	Jobs.tick(state, 0.1)
	assert_true(s.sheltered)
	state.buildings.remove(b.uid)
	Jobs.tick(state, 0.1)
	assert_false(s.sheltered)
	assert_true(Grid.in_ring(s.tile(), b.origin, b.size))
	assert_true(state.map.is_passable(s.tile()))
	_ticks()
	assert_true(s.sheltered)
	assert_eq(s.shelter_uid, state.buildings.all_of_type("command_center")[0].uid)

func test_job_change_waits_inside_guard_releases_and_dawn_clears_travel() -> void:
	_night()
	Jobs.tick(state, 0.1)
	var s: Survivor = state.survivors.all()[0]
	state.set_job(s.uid, Survivor.Job.BUILDER)
	assert_true(s.sheltered)
	assert_eq(s.activity, Survivor.Activity.SHELTERED)
	state.set_job(s.uid, Survivor.Job.GUARD)
	Jobs.tick(state, 0.1)
	assert_false(s.sheltered)
	assert_eq(s.shelter_uid, 0)
	s.pos = Grid.tile_to_world(state.map.command_center_origin() + Vector2i(-4, 0))
	state.set_job(s.uid, Survivor.Job.IDLE)
	Jobs.tick(state, 0.1)
	assert_true(s.is_moving())
	state.clock.phase = GameClock.Phase.DAY
	Jobs.tick(state, 0.1)
	assert_eq(s.shelter_uid, 0)
	assert_true(s.path.is_empty())

func test_view_selection_roster_and_movement_exclude_sheltered() -> void:
	var selection := SelectionController.new()
	selection.bind(state)
	var s: Survivor = state.survivors.all()[0]
	selection.select_survivor(s.uid)
	_night()
	Jobs.tick(state, 0.1)
	var layer := SurvivorLayer.new()
	layer.bind(state)
	layer.sync()
	assert_false((layer._sprites[s.uid] as AnimatedSprite2D).visible)
	selection._process(0.0)
	assert_eq(selection.selected_kind, "")
	selection.select_at_world(s.pos)
	assert_eq(selection.selected_kind, "")
	var roster: RosterPanel = preload("res://scenes/ui/roster_panel.tscn").instantiate()
	roster.bind(state, selection)
	roster.toggle()
	roster.refresh()
	assert_eq((roster._vbox.get_child(0).get_child(2) as Label).text, "Sheltered")
	(roster._vbox.get_child(0).get_child(0) as Button).pressed.emit()
	assert_eq(selection.selected_kind, "")
	assert_false(state.order_move(s.uid, state.cc_ring_tiles().back()))
	var pos: Vector2 = s.pos
	s.path.append(state.cc_ring_tiles().back())
	state.survivors.tick(1.0, state.pathfinder, state.map)
	assert_eq(s.pos, pos)
	s.path.clear()
	roster.free()
	layer.free()
	selection.free()

func test_unreachable_ring_retries_then_arrives_after_opening() -> void:
	var cc: Building = state.buildings.all_of_type("command_center")[0]
	var ring: Array[Vector2i] = state.cc_ring_tiles()
	var walls: Array[Building] = []
	for t: Vector2i in ring:
		walls.append(state.buildings.add("wooden_wall", t, true))
	var s: Survivor = state.survivors.all()[0]
	s.pos = Grid.tile_to_world(cc.origin + Vector2i(-4, 0))
	_night()
	Jobs.tick(state, 0.1)
	assert_false(s.sheltered)
	assert_true(s.path.is_empty())
	assert_eq(s.activity, Survivor.Activity.IDLE)
	assert_gt(s.job_timer, 0.0)
	state.buildings.remove(walls[0].uid)
	Jobs.tick(state, 0.1)
	assert_true(s.path.is_empty(), "must respect retry interval")
	# Keep only the subject: the other starting survivors were boxed into wall tiles.
	for other: Survivor in state.survivors.all():
		if other != s:
			state.survivors.remove(other.uid)
	_ticks()
	assert_true(s.sheltered)

func test_equal_distance_uses_uid_and_incomplete_shelter_releases() -> void:
	var cc: Building = state.buildings.all_of_type("command_center")[0]
	var b: Building = _shelter()
	var s: Survivor = state.survivors.all()[0]
	s.pos = (cc.center_world() + b.center_world()) / 2.0
	assert_eq(ShelterRules.pick_shelter(state, s), cc)
	s.pos = Grid.tile_to_world(b.origin + Vector2i.UP)
	_night()
	Jobs.tick(state, 0.1)
	assert_true(s.sheltered)
	b.complete = false
	Jobs.tick(state, 0.1)
	assert_false(s.sheltered)
	assert_eq(s.shelter_uid, cc.uid)

func test_clock_dawn_releases_in_dispatch_and_old_job_retry_does_not_delay_night() -> void:
	var s: Survivor = state.survivors.all()[0]
	s.job_timer = 100.0
	_night()
	state.tick(0.1)
	assert_true(s.sheltered)
	state.clock.elapsed = float(state.data.balance("night_min_length")) - 0.1
	state.tick(0.2)
	assert_eq(state.clock.phase, GameClock.Phase.DAY)
	assert_false(s.sheltered)
	assert_eq(s.shelter_uid, 0)
	assert_eq(s.tile(), state.cc_ring_tiles()[0])

func test_daytime_job_retry_does_not_delay_nightfall_interruption_at_clock_boundary() -> void:
	var s: Survivor = state.survivors.all()[0]
	state.set_job(s.uid, Survivor.Job.GATHERER, "wood")
	s.pos = Grid.tile_to_world(state.map.command_center_origin() + Vector2i(-4, 0))
	s.job_timer = 100.0
	state.clock.elapsed = float(state.data.balance("day_length")) - 0.1
	state.tick(0.2)
	assert_eq(state.clock.phase, GameClock.Phase.NIGHT)
	assert_ne(s.shelter_uid, 0, "survivor picks shelter on first night tick despite daytime job_timer")
	assert_eq(s.job_timer, 0.0, "daytime job retry timer is cleared on nightfall")
	assert_eq(s.activity, Survivor.Activity.WALKING, "job state interrupted and walking to shelter")

func _wall_off(b: Building) -> Array[Building]:
	var walls: Array[Building] = []
	for y: int in range(b.origin.y - 1, b.origin.y + b.size.y + 1):
		for x: int in range(b.origin.x - 1, b.origin.x + b.size.x + 1):
			var t := Vector2i(x, y)
			if Grid.in_ring(t, b.origin, b.size) and state.map.is_passable(t):
				walls.append(state.buildings.add("wooden_wall", t, true))
	return walls

func test_walled_nearest_shelter_walks_to_second_reachable_shelter_at_nightfall() -> void:
	var s: Survivor = state.survivors.all()[0]
	for other: Survivor in state.survivors.all():
		if other != s:
			state.survivors.remove(other.uid)

	var b1: Building = _shelter()
	assert_not_null(b1)
	var b2: Building = null
	for y: int in range(18, 30):
		for x: int in range(18, 30):
			var origin := Vector2i(x, y)
			if Placement.check(state, "shelter", origin) == Placement.Result.OK:
				b2 = state.buildings.add("shelter", origin, true)
				break
		if b2 != null:
			break
	assert_not_null(b2)

	_wall_off(b1)
	s.pos = Grid.tile_to_world(b1.origin + Vector2i(-2, 0))
	assert_true(state.map.is_passable(s.tile()))
	assert_lt(s.pos.distance_squared_to(b1.center_world()), s.pos.distance_squared_to(b2.center_world()))

	_night()
	Jobs.tick(state, 0.1)
	assert_true(s.unreachable_shelters.has(b1.uid))
	assert_false(s.unreachable_shelters.has(b2.uid))
	assert_eq(s.shelter_uid, b2.uid)
	assert_eq(s.activity, Survivor.Activity.WALKING)

	_ticks(300)
	assert_true(s.sheltered)
	assert_eq(s.shelter_uid, b2.uid)

func test_no_reachable_shelter_stays_outside_and_warning_fires_once_per_night() -> void:
	var s: Survivor = state.survivors.all()[0]
	for other: Survivor in state.survivors.all():
		if other != s:
			state.survivors.remove(other.uid)

	var cc: Building = state.buildings.all_of_type("command_center")[0]
	_wall_off(cc)

	s.pos = Grid.tile_to_world(cc.origin + Vector2i(-4, 0))

	var warnings: Array[Survivor] = []
	state.survivor_unsheltered.connect(func(unsheltered_s: Survivor) -> void: warnings.append(unsheltered_s))

	_night()
	Jobs.tick(state, 0.1)

	assert_false(s.sheltered)
	assert_eq(s.activity, Survivor.Activity.IDLE)
	assert_gt(s.job_timer, 0.0)
	assert_eq(warnings.size(), 1)
	assert_eq(warnings[0], s)

	# Multiple ticks across multiple retry intervals
	for i: int in range(150):
		state.tick(0.1)

	assert_false(s.sheltered)
	assert_eq(warnings.size(), 1, "warning signal must only fire once per night")

func test_unreachable_shelter_exclusions_reset_at_next_night() -> void:
	var s: Survivor = state.survivors.all()[0]
	for other: Survivor in state.survivors.all():
		if other != s:
			state.survivors.remove(other.uid)

	var b1: Building = _shelter()
	assert_not_null(b1)
	var b2: Building = null
	for y: int in range(18, 30):
		for x: int in range(18, 30):
			var origin := Vector2i(x, y)
			if Placement.check(state, "shelter", origin) == Placement.Result.OK:
				b2 = state.buildings.add("shelter", origin, true)
				break
		if b2 != null:
			break
	assert_not_null(b2)

	var walls: Array[Building] = _wall_off(b1)
	s.pos = Grid.tile_to_world(b1.origin + Vector2i(-2, 0))
	assert_true(state.map.is_passable(s.tile()))

	_night()
	Jobs.tick(state, 0.1)
	assert_true(s.unreachable_shelters.has(b1.uid))
	_ticks(300)
	assert_true(s.sheltered)
	assert_eq(s.shelter_uid, b2.uid)
	assert_true(s.unreachable_shelters.has(b1.uid))

	# Advance to dawn
	state.clock.elapsed = float(state.data.balance("night_min_length")) - 0.1
	state.tick(0.2)
	assert_eq(state.clock.phase, GameClock.Phase.DAY)
	assert_false(s.sheltered)
	assert_true(s.unreachable_shelters.is_empty(), "exclusions reset at dawn")

	# Un-wall b1
	for w: Building in walls:
		state.buildings.remove(w.uid)

	# Night 2
	s.pos = Grid.tile_to_world(b1.origin + Vector2i(-2, 0))
	state.clock.elapsed = float(state.data.balance("day_length")) - 0.1
	state.tick(0.2)
	assert_eq(state.clock.phase, GameClock.Phase.NIGHT)
	_ticks(300)
	assert_true(s.sheltered)
	assert_eq(s.shelter_uid, b1.uid, "previously excluded shelter is chosen on next night when reachable")

func test_hud_shows_shelter_warning_and_auto_dismisses() -> void:
	var hud: CanvasLayer = (preload("res://scenes/ui/hud.tscn") as PackedScene).instantiate()
	hud.set("top_bar", hud.get_node("TopBar"))
	hud.set("food_icon", hud.get_node("TopBar/Margin/HBox/Resources/FoodBox/Icon"))
	hud.set("food_label", hud.get_node("TopBar/Margin/HBox/Resources/FoodBox/Label"))
	hud.set("wood_icon", hud.get_node("TopBar/Margin/HBox/Resources/WoodBox/Icon"))
	hud.set("wood_label", hud.get_node("TopBar/Margin/HBox/Resources/WoodBox/Label"))
	hud.set("scrap_icon", hud.get_node("TopBar/Margin/HBox/Resources/ScrapBox/Icon"))
	hud.set("scrap_label", hud.get_node("TopBar/Margin/HBox/Resources/ScrapBox/Label"))
	hud.set("ammo_icon", hud.get_node("TopBar/Margin/HBox/Resources/AmmoBox/Icon"))
	hud.set("ammo_label", hud.get_node("TopBar/Margin/HBox/Resources/AmmoBox/Label"))
	hud.set("day_label", hud.get_node("TopBar/Margin/HBox/DayArea/DayLabel"))
	hud.set("time_label", hud.get_node("TopBar/Margin/HBox/ClockArea/TimeLabel"))
	hud.set("btn_pause", hud.get_node("TopBar/Margin/HBox/ClockArea/SpeedButtons/BtnPause"))
	hud.set("btn_1x", hud.get_node("TopBar/Margin/HBox/ClockArea/SpeedButtons/Btn1x"))
	hud.set("btn_2x", hud.get_node("TopBar/Margin/HBox/ClockArea/SpeedButtons/Btn2x"))
	hud.set("btn_3x", hud.get_node("TopBar/Margin/HBox/ClockArea/SpeedButtons/Btn3x"))
	hud.set("shelter_warning_label", hud.get_node("ShelterWarning"))
	hud.bind(state)
	var label: Label = hud.get_node("ShelterWarning") as Label
	assert_not_null(label)
	assert_false(label.visible)

	var s: Survivor = state.survivors.all()[0]
	state.survivor_unsheltered.emit(s)
	assert_true(label.visible)
	assert_true(label.text.contains(s.name))
	assert_true(label.text.contains("can't reach shelter"))

	hud._process(5.1)
	assert_false(label.visible)
	hud.free()
