extends TestCase

var _state: GameState
var _view: NightLights

func before_each() -> void:
	_state = GameState.new(GameData.load_default(), 1337)
	_state.waves.enabled = false
	_view = NightLights.new()
	_view.bind(_state)

func after_each() -> void:
	_view.free()
	_state = null

func test_energy_by_phase_and_clamped_edges() -> void:
	assert_almost_eq(NightLights.energy_for(GameClock.Phase.DAY, 20.0, 50.0, 1), 0.0)
	assert_almost_eq(NightLights.energy_for(GameClock.Phase.DAY, 20.0, 50.0, 20), 0.0)
	assert_almost_eq(NightLights.energy_for(GameClock.Phase.NIGHT, 0.0, 40.0, 1), 1.0)
	assert_almost_eq(NightLights.energy_for(GameClock.Phase.NIGHT, 300.0, 0.0, 20), 1.0)
	assert_almost_eq(NightLights.energy_for(GameClock.Phase.DAY, 0.0, 70.0, 1), 0.0)
	assert_almost_eq(NightLights.energy_for(GameClock.Phase.DAY, 70.0, -2.0, 1), 1.0)
	assert_almost_eq(NightLights.energy_for(GameClock.Phase.DAY, -2.0, 70.0, 2), 1.0)

func test_dusk_monotonic_and_matching_tint_ramp() -> void:
	var previous: float = 0.0
	for step: int in range(13):
		var left: float = DayNightTint.DUSK_SECONDS - step
		var energy: float = NightLights.energy_for(GameClock.Phase.DAY, 70.0 - left, left, 1)
		assert_true(energy >= previous)
		assert_almost_eq(energy, step / DayNightTint.DUSK_SECONDS)
		assert_true(DayNightTint.tint_for(GameClock.Phase.DAY, 70.0 - left, left, 1, 20).is_equal_approx(Color.WHITE.lerp(DayNightTint.NIGHT_COLOR, energy)))
		previous = energy

func test_dawn_monotonic_and_final_night_dawn() -> void:
	var previous: float = 1.0
	for day: int in [2, 21]:
		previous = 1.0
		for step: int in range(7):
			var energy: float = NightLights.energy_for(GameClock.Phase.DAY, step, 70.0 - step, day)
			assert_true(energy <= previous)
			assert_almost_eq(energy, 1.0 - step / DayNightTint.DAWN_SECONDS)
			previous = energy

func test_completed_command_center_center_radius_and_day_disabled() -> void:
	assert_eq(_view.get_child_count(), 1)
	var cc: Building = _state.buildings.all_of_type("command_center")[0]
	var light: PointLight2D = _view.get_child(0) as PointLight2D
	assert_eq(light.position, cc.center_world())
	assert_almost_eq(light.texture.get_width() * light.texture_scale / 2.0, 3.0 * Grid.TILE)
	assert_eq(light.color, Color("ffcf8a"))
	assert_almost_eq(light.energy, 0.0)
	assert_false(light.enabled)
	assert_false(light.shadow_enabled)

func test_blueprint_and_partial_construction_wait_until_completed() -> void:
	var b: Building = _state.buildings.add("shelter", Vector2i(5, 5), false)
	assert_eq(_view.get_child_count(), 1, "Blueprint has no light")
	b.progress = b.build_time / 2.0
	_view._process(0.0)
	assert_eq(_view.get_child_count(), 1, "Construction has no light")
	_state.buildings.finish(b.uid)
	assert_eq(_view.get_child_count(), 2)
	_state.buildings.finish(b.uid)
	_state.buildings.building_completed.emit(b)
	assert_eq(_view.get_child_count(), 2, "Completion never duplicates a light")

func test_all_supported_buildings_share_texture_and_other_buildings_have_no_light() -> void:
	for type_id: String in ["shelter", "watchtower", "turret", "radio_tower", "farm", "wooden_wall", "storage", "workshop", "lumber_yard", "gate", "reinforced_wall"]:
		_state.buildings.add(type_id, Vector2i(2 + _state.buildings.all().size() * 3, 5), true)
	assert_eq(_view.get_child_count(), 5)
	var cc_light: PointLight2D = _view.get_child(0) as PointLight2D
	for index: int in range(1, _view.get_child_count()):
		var light: PointLight2D = _view.get_child(index) as PointLight2D
		assert_eq(light.texture, cc_light.texture)
		assert_eq(light.texture.get_size(), Vector2(128, 128))
		assert_almost_eq(light.texture.get_width() * light.texture_scale / 2.0, 2.0 * Grid.TILE)
		assert_eq(light.range_item_cull_mask, 1)

func test_light_energy_updates_and_returns_to_disabled_day() -> void:
	var light: PointLight2D = _view.get_child(0) as PointLight2D
	_state.clock.elapsed = 64.0
	_view._process(0.0)
	assert_almost_eq(light.energy, 0.5)
	assert_true(light.enabled)
	_state.clock.phase = GameClock.Phase.NIGHT
	_state.clock.day = 20
	_view._process(0.0)
	assert_almost_eq(light.energy, 1.0)
	var b: Building = _state.buildings.add("turret", Vector2i(5, 5), true)
	var added: PointLight2D = _view._lights[b.uid]
	assert_almost_eq(added.energy, 1.0, 0.001, "New lights inherit the current phase")
	_state.clock.phase = GameClock.Phase.DAY
	_state.clock.day = 21
	_state.clock.elapsed = 3.0
	_view._process(0.0)
	assert_almost_eq(light.energy, 0.5)
	_state.clock.elapsed = 6.0
	_view._process(0.0)
	assert_almost_eq(light.energy, 0.0)
	assert_false(light.enabled)
	assert_false(added.enabled)

func test_removed_and_destroyed_buildings_free_their_lights() -> void:
	var b: Building = _state.buildings.add("watchtower", Vector2i(5, 5), true)
	var light: PointLight2D = _view._lights[b.uid]
	_state.buildings.remove(b.uid)
	assert_eq(_view.get_child_count(), 1)
	assert_false(is_instance_valid(light))
	b = _state.buildings.add("shelter", Vector2i(5, 5), true)
	light = _view._lights[b.uid]
	_state.damage_building(b, b.max_hp)
	assert_eq(_view.get_child_count(), 1)
	assert_false(is_instance_valid(light))
	var cc: Building = _state.buildings.all_of_type("command_center")[0]
	light = _view._lights[cc.uid]
	_state.damage_building(cc, cc.max_hp)
	assert_eq(_view.get_child_count(), 0, "Retained destroyed CC has no light")
	assert_false(is_instance_valid(light))
	_view.bind(_state)
	assert_eq(_view.get_child_count(), 0, "Rebind cannot relight a destroyed CC")

func test_rebind_disconnects_previous_store_and_clears_lights() -> void:
	var previous: GameState = _state
	_state = GameState.new(GameData.load_default(), 1337)
	_state.waves.enabled = false
	_state.clock.phase = GameClock.Phase.NIGHT
	_view.bind(_state)
	assert_eq(_view.get_child_count(), 1)
	previous.buildings.add("shelter", Vector2i(5, 5), true)
	previous.buildings.remove(previous.buildings.all_of_type("command_center")[0].uid)
	assert_eq(_view.get_child_count(), 1)
	assert_almost_eq((_view.get_child(0) as PointLight2D).energy, 1.0)
	_view.bind(null)
	assert_eq(_view.get_child_count(), 0)
	assert_false(_state.buildings.building_added.is_connected(_view._add_light))

func test_world_owns_lights_outside_ysort() -> void:
	var world: Node2D = (load("res://scenes/world/world.tscn") as PackedScene).instantiate() as Node2D
	var lights: NightLights = world.get_node("NightLights") as NightLights
	assert_not_null(lights)
	assert_eq(lights.get_parent(), world)
	assert_false(lights.y_sort_enabled)
	world.free()
