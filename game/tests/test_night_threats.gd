extends TestCase

var _state: GameState
var _layer: ZombieLayer

func before_each() -> void:
	_state = GameState.new(GameData.load_default(), 1337)
	_state.waves.enabled = false
	_layer = ZombieLayer.new()
	_layer.bind(_state)

func after_each() -> void:
	_layer.unbind()
	_layer.free()
	_state = null

func test_rim_switches_at_night_and_dawn_and_keeps_shared_material() -> void:
	var z: Zombie = _state.spawn_zombie("walker", Vector2(100, 100))
	var sprite: AnimatedSprite2D = _layer._active_sprites[z.uid]
	var material: ShaderMaterial = sprite.material as ShaderMaterial
	assert_almost_eq((material.get_shader_parameter("outline_color") as Color).a, 0.0)
	_state.clock.advance(_state.clock.time_left())
	assert_eq(_state.clock.phase, GameClock.Phase.NIGHT)
	assert_almost_eq((material.get_shader_parameter("outline_color") as Color).a, 1.0)
	var bar: HpBar = sprite.get_child(0) as HpBar
	assert_true(bar.always_show)
	assert_true(bar.visible)
	assert_true(bar.should_draw(), "Full-health zombie bar draws at night")
	_state.clock.phase = GameClock.Phase.DAY
	_state.clock.phase_changed.emit(GameClock.Phase.DAY, 2)
	assert_almost_eq((material.get_shader_parameter("outline_color") as Color).a, 0.0)
	assert_false(bar.always_show)
	assert_false(bar.visible)
	assert_eq(sprite.material, material)

func test_normal_and_final_night_rim_survives_canvas_tint() -> void:
	_state.clock.phase = GameClock.Phase.NIGHT
	for day: int in [5, _state.data.final_night()]:
		_state.clock.day = day
		_layer.sync()
		var rim: Color = _layer._outline_material.get_shader_parameter("outline_color")
		var tint: Color = DayNightTint.FINAL_COLOR if day == _state.data.final_night() else DayNightTint.NIGHT_COLOR
		assert_true((rim * tint).is_equal_approx(ZombieLayer.NIGHT_RIM))
		for i: int in range(5):
			_layer.sync()
		assert_eq(_layer._outline_material.get_shader_parameter("outline_color"), rim)

func test_all_types_pool_reuse_and_death_share_material() -> void:
	_state.clock.phase = GameClock.Phase.NIGHT
	_layer.sync()
	for type_id: String in ZombieLayer.TYPES:
		var z: Zombie = _state.spawn_zombie(type_id, Vector2(100, 100))
		var sprite: AnimatedSprite2D = _layer._active_sprites[z.uid]
		assert_eq(sprite.material, _layer._outline_material)
		var bar: HpBar = sprite.get_child(0) as HpBar
		assert_eq(bar.bar_width, 32.0)
		assert_true(bar.always_show)
		assert_true(bar.visible)
		_state.zombies.remove(z.uid)
		assert_false(bar.visible)
		var next: Zombie = _state.spawn_zombie(type_id, Vector2(200, 200))
		assert_eq(_layer._active_sprites[next.uid], sprite)
		assert_true(bar.always_show)
		assert_true(bar.visible)
		_state.damage_zombie(next, next.hp)
		assert_eq(_layer._death_sprites.back().material, _layer._outline_material)

func test_dawn_damaged_bars_zero_hp_and_day_pool_reuse() -> void:
	_state.clock.phase = GameClock.Phase.NIGHT
	_layer.sync()
	var z: Zombie = _state.spawn_zombie("brute", Vector2(100, 100))
	var sprite: AnimatedSprite2D = _layer._active_sprites[z.uid]
	var bar: HpBar = sprite.get_child(0) as HpBar
	z.hp = z.max_hp / 2
	_layer.sync()
	_state.clock.phase = GameClock.Phase.DAY
	_layer.sync()
	assert_false(bar.always_show)
	assert_true(bar.visible, "Damaged bar remains visible by day")
	z.hp = 0
	_layer.sync()
	assert_false(bar.visible)
	_state.zombies.remove(z.uid)
	var next: Zombie = _state.spawn_zombie("runner", Vector2(200, 200))
	assert_eq(_layer._active_sprites[next.uid], sprite)
	assert_false(bar.always_show)
	assert_false(bar.visible)

func test_rebind_changes_phase_and_disconnects_old_clock() -> void:
	var previous: GameState = _state
	_state = GameState.new(GameData.load_default(), 1337)
	_state.clock.phase = GameClock.Phase.NIGHT
	_state.spawn_zombie("runner", Vector2.ZERO)
	_layer.bind(_state)
	assert_false(previous.clock.phase_changed.is_connected(_layer._on_phase_changed))
	assert_true(_state.clock.phase_changed.is_connected(_layer._on_phase_changed))
	previous.clock.phase_changed.emit(GameClock.Phase.DAY, 1)
	assert_almost_eq((_layer._outline_material.get_shader_parameter("outline_color") as Color).a, 1.0)
	_layer.unbind()
	assert_false(_state.clock.phase_changed.is_connected(_layer._on_phase_changed))

func test_hp_bar_full_health_opt_in_and_empty_health_hidden() -> void:
	var bar := HpBar.new()
	assert_false(bar.should_draw(), "Other entities keep damaged-only default")
	bar.always_show = true
	assert_true(bar.should_draw(), "Full HP takes the draw path when opted in")
	bar.set_ratio(0.0)
	assert_false(bar.should_draw())
	bar.set_ratio(0.5)
	assert_true(bar.should_draw())
	bar.always_show = false
	assert_true(bar.should_draw())
	bar.set_ratio(1.0)
	assert_false(bar.should_draw())
	bar.free()
