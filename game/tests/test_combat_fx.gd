extends TestCase

var _state: GameState
var _fx: CombatFx

func before_each() -> void:
	_state = GameState.new(GameData.load_default(), 1337)
	_fx = CombatFx.new()
	_fx.bind(_state)

func after_each() -> void:
	_fx.free()
	_state = null

func test_pool_reuses_oldest_after_forty_shots() -> void:
	var ids: Array[int] = []
	for child: Node in _fx.get_children():
		ids.append(child.get_instance_id())
	for i: int in range(40):
		_state.shot_fired.emit(Vector2(i, 0), Vector2(i + 100, 0), false)
	assert_eq(_fx.get_child_count(), _pool_nodes())
	for i: int in range(ids.size()):
		assert_eq(_fx.get_child(i).get_instance_id(), ids[i])
	var first: Line2D = _fx.get_child(0) as Line2D
	assert_eq(first.get_point_position(0), Vector2(52, 0), "Oldest slot reused by shot 33")
	assert_eq(first.get_point_position(1), Vector2(100, 0), "Short pixel tracer")

func test_lifetime_fade_and_pause_use_sim_time() -> void:
	_state.shot_fired.emit(Vector2.ZERO, Vector2(100, 0), true)
	var tracer: Line2D = _fx.get_child(0) as Line2D
	var flash: Sprite2D = _fx.get_child(1) as Sprite2D
	assert_true(tracer.visible)
	assert_true(flash.visible)
	assert_eq(flash.position, Vector2(20, 0))
	assert_eq(flash.get_rect().size * flash.scale, Vector2(64, 64))
	assert_eq(flash.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_eq(tracer.width, 4.0)
	assert_false(tracer.antialiased)
	_fx._process(0.04)
	assert_almost_eq(tracer.modulate.a, 0.5)
	assert_eq((flash.texture as AtlasTexture).region.position.x, 48.0, "Shotgun frame 3 of 6")
	_state.clock.set_paused(true)
	_fx._process(10.0)
	assert_true(tracer.visible)
	assert_true(flash.visible)
	assert_almost_eq(tracer.modulate.a, 0.5)
	_state.clock.set_paused(false)
	_fx._process(0.04)
	assert_false(tracer.visible)
	assert_false(flash.visible)

func test_speed_and_rebinding() -> void:
	_state.clock.set_speed(2)
	_state.shot_fired.emit(Vector2.ZERO, Vector2(0, 100), false)
	var tracer: Line2D = _fx.get_child(0) as Line2D
	var flash: Sprite2D = _fx.get_child(1) as Sprite2D
	assert_almost_eq(flash.rotation, PI / 2.0)
	_fx._process(0.04)
	assert_false(tracer.visible)
	var next_state: GameState = GameState.new(GameData.load_default(), 1337)
	_fx.bind(next_state)
	_state.shot_fired.emit(Vector2.ZERO, Vector2(100, 0), false)
	assert_false(tracer.visible)
	next_state.shot_fired.emit(Vector2.ZERO, Vector2(100, 0), false)
	assert_true(tracer.visible)
	assert_eq(_fx.get_child_count(), _pool_nodes())

func _pool_nodes() -> int:
	return CombatFx.POOL_SIZE * 2 + CombatFx.BLOOD_POOL_SIZE + CombatFx.CORPSE_POOL_SIZE + CombatFx.STAIN_POOL_SIZE + CombatFx.ACID_POOL_SIZE + CombatFx.ACID_SPLASH_POOL_SIZE

func _zombie(uid: int, position: Vector2 = Vector2(120, 120)) -> Zombie:
	var z: Zombie = Zombie.new()
	z.uid = uid
	z.pos = position
	z.type_id = "walker"
	return z

func _visible_count(sprites: Array[Sprite2D]) -> int:
	var count: int = 0
	for sprite: Sprite2D in sprites:
		count += int(sprite.visible)
	return count

func _begin_dawn() -> void:
	_state.clock.phase = GameClock.Phase.DAY
	_state.clock.day = 2
	_state.clock.elapsed = 0.0
	_state.clock.phase_changed.emit(GameClock.Phase.DAY, 2)

func test_fixed_pools_after_200_shots_100_hits_and_100_kills() -> void:
	var ids: Array[int] = []
	for child: Node in _fx.get_children():
		ids.append(child.get_instance_id())
	for i: int in range(200):
		_state.shot_fired.emit(Vector2(i, 0), Vector2(i + 100, 0), i % 2 == 0)
	for i: int in range(100):
		_state.zombie_hit.emit(_zombie(i))
		_state.zombie_killed.emit(_zombie(i, Vector2(i, 100)))
	assert_eq(_fx.get_child_count(), _pool_nodes())
	for i: int in range(ids.size()):
		assert_eq(_fx.get_child(i).get_instance_id(), ids[i], "Every pool node survives recycling")
	_fx._process(ZombieLayer.DEATH_SECONDS)
	assert_eq(_visible_count(_fx._corpses), CombatFx.CORPSE_POOL_SIZE)
	assert_eq(_visible_count(_fx._stains), CombatFx.STAIN_POOL_SIZE)
	assert_eq(_fx._corpses[0].position, Vector2(64, 100), "Oldest body recycled")
	assert_eq(_fx._stains[0].position, Vector2(96, 108), "Oldest stain recycled independently")
	assert_eq(_fx._active, 0)
	assert_eq(_fx._active_blood, 0)

func test_pixel_strips_advance_once_and_cache_cells_across_rebinds() -> void:
	_state.shot_fired.emit(Vector2.ZERO, Vector2(100, 0), false)
	_state.shot_fired.emit(Vector2.ZERO, Vector2(100, 0), true)
	assert_eq((_fx._flashes[0].texture as AtlasTexture).atlas, CombatFx.PISTOL_TEXTURE)
	assert_eq((_fx._flashes[1].texture as AtlasTexture).atlas, CombatFx.SHOTGUN_TEXTURE)
	for i: int in range(1, 5):
		_fx._process(CombatFx.LIFETIME / 5.0)
		assert_eq((_fx._flashes[0].texture as AtlasTexture).region.position.x, float(i * 16))
	_fx._process(CombatFx.LIFETIME)
	assert_false(_fx._flashes[0].visible)
	assert_false(_fx._flashes[1].visible)
	var cached: AtlasTexture = _fx._pistol_frames[0]
	_fx.bind(_state)
	assert_eq(_fx._pistol_frames[0], cached)
	assert_eq(FxStrip.frames(CombatFx.PISTOL_TEXTURE)[0], cached)

func test_blood_is_bottom_anchored_and_uses_paused_scaled_time() -> void:
	var z: Zombie = _zombie(1)
	_state.zombie_hit.emit(z)
	var blood: Sprite2D = _fx._blood[0]
	assert_eq(blood.position, z.pos)
	assert_eq(blood.get_rect().end.y, 0.0, "Blood cell bottom at feet")
	assert_eq(blood.scale, Vector2(4, 4))
	_state.clock.set_paused(true)
	_fx._process(10.0)
	assert_eq((blood.texture as AtlasTexture).region.position.x, 0.0)
	_state.clock.set_speed(3)
	_fx._process(0.021)
	assert_eq((blood.texture as AtlasTexture).region.position.x, 16.0)
	_fx._process(0.1)
	assert_false(blood.visible)

func test_corpses_wait_for_death_fade_and_loop_only_their_own_body() -> void:
	_state.zombie_killed.emit(_zombie(0))
	_state.zombie_killed.emit(_zombie(1))
	assert_true(_fx._blood[0].visible, "Lethal hits also spray blood")
	assert_false(_fx._corpses[0].visible)
	assert_false(_fx._stains[0].visible)
	_fx._process(ZombieLayer.DEATH_SECONDS - 0.01)
	assert_false(_fx._corpses[0].visible)
	_state.clock.set_paused(true)
	_fx._process(10.0)
	assert_false(_fx._corpses[0].visible)
	_state.clock.set_speed(2)
	_fx._process(0.006)
	assert_true(_fx._corpses[0].visible)
	assert_true(_fx._stains[0].visible)
	assert_eq(_fx._corpses[0].get_rect().end.y, 0.0)
	assert_false(_fx._corpses[0].z_as_relative)
	assert_eq(_fx._corpses[0].z_index, 0)
	for i: int in range(7):
		_fx._process(0.125)
		assert_eq((_fx._corpses[0].texture as AtlasTexture).atlas, CombatFx.CORPSE_TEXTURES[0])
		assert_eq((_fx._corpses[1].texture as AtlasTexture).atlas, CombatFx.CORPSE_TEXTURES[1])
		assert_eq((_fx._corpses[0].texture as AtlasTexture).region.position.x, float(((i + 1) % 3) * 16))

func test_dawn_fades_decals_with_clock_and_pause_then_removes_pending_bodies() -> void:
	_state.zombie_killed.emit(_zombie(1))
	_fx._process(ZombieLayer.DEATH_SECONDS)
	_begin_dawn()
	_state.clock.set_speed(3)
	_state.clock.advance(_state.clock.scale(1.0))
	_fx._process(1.0)
	assert_almost_eq(_fx._corpses[0].modulate.a, 0.5)
	assert_almost_eq(_fx._stains[0].modulate.a, 0.5)
	_state.clock.set_paused(true)
	_state.clock.advance(_state.clock.scale(10.0))
	_fx._process(10.0)
	assert_almost_eq(_fx._corpses[0].modulate.a, 0.5)
	assert_true(_fx._stains[0].visible)
	_state.zombie_killed.emit(_zombie(2))
	assert_false(_fx._corpses[1].visible)
	_state.clock.set_speed(3)
	_state.clock.advance(_state.clock.scale(1.0))
	_fx._process(1.0)
	assert_eq(_visible_count(_fx._corpses), 0)
	assert_eq(_visible_count(_fx._stains), 0)
	_fx._process(100.0)
	assert_eq(_visible_count(_fx._corpses), 0, "Pending deaths never return")
	assert_eq(_visible_count(_fx._stains), 0)

func test_clear_and_rebind_disconnect_all_old_signals_and_reset_pools() -> void:
	_state.zombie_killed.emit(_zombie(5))
	_state.shot_fired.emit(Vector2.ZERO, Vector2(100, 0), false)
	_fx._process(0.6)
	_fx.clear()
	for child: CanvasItem in _fx.get_children():
		assert_false(child.visible)
	var next_state: GameState = GameState.new(GameData.load_default(), 2)
	_fx.bind(next_state)
	_state.zombie_hit.emit(_zombie(6))
	_state.zombie_killed.emit(_zombie(6))
	_state.shot_fired.emit(Vector2.ZERO, Vector2(100, 0), false)
	_begin_dawn()
	assert_false(_fx._dawn_clearing, "Old phase signal disconnected")
	for child: CanvasItem in _fx.get_children():
		assert_false(child.visible)
	next_state.zombie_killed.emit(_zombie(5))
	_fx._process(0.6)
	assert_true(_fx._corpses[0].visible)
	assert_eq(_fx._stains[0].texture, CombatFx.STAIN_TEXTURES[1], "UID chooses repeatable stain")
	assert_eq(_fx.get_child_count(), _pool_nodes())

func test_ammo_warning_truth_table() -> void:
	assert_true(HudText.ammo_warning(0, true))
	assert_false(HudText.ammo_warning(0, false))
	assert_false(HudText.ammo_warning(1, true))
	assert_false(HudText.ammo_warning(1, false))

func test_spit_fired_does_not_show_gun_flash_or_tracer() -> void:
	_state.spit_fired.emit(Vector2(100, 120), Vector2(180, 200))
	for tracer: Line2D in _fx._tracers:
		assert_false(tracer.visible, "Spit has no gun tracer")
	for flash: Sprite2D in _fx._flashes:
		assert_false(flash.visible, "Spit has no muzzle flash")
	_fx._on_phase_changed(GameClock.Phase.NIGHT, 9)
	assert_true(_fx._acid_globs[0].modulate.g > _fx._acid_globs[0].modulate.r, "Night compensation preserves acid green")
	var night_tint: Color = _fx._acid_globs[0].modulate
	_fx._on_phase_changed(GameClock.Phase.DAY, 9)
	assert_true(_fx._acid_globs[0].modulate.g > _fx._acid_globs[0].modulate.r, "Day acid is green-biased over red")
	assert_true(_fx._acid_globs[0].modulate.g > _fx._acid_globs[0].modulate.b, "Day acid is green-biased over blue")
	var day_tint: Color = _fx._acid_globs[0].modulate
	_state.clock.phase_changed.emit(GameClock.Phase.NIGHT, 9)
	assert_eq(_fx._acid_globs[0].modulate, night_tint, "Night acid tint remains unchanged")
	assert_ne(day_tint, night_tint)

func test_acid_splash_advances_atlas_frames_then_hides() -> void:
	_state.acid_hit.emit(Vector2(120, 140))
	var splash: Sprite2D = _fx._acid_splashes[0]
	assert_true(splash.visible)
	assert_eq(splash.texture, _fx._acid_splash_frames[0], "Splash starts on frame 0")
	_fx._process(CombatFx.ACID_SPLASH_LIFETIME / 3.0)
	assert_eq(splash.texture, _fx._acid_splash_frames[1], "Splash advances to frame 1")
	_fx._process(CombatFx.ACID_SPLASH_LIFETIME / 3.0)
	assert_eq(splash.texture, _fx._acid_splash_frames[2], "Splash advances to frame 2")
	_fx._process(CombatFx.ACID_SPLASH_LIFETIME / 3.0)
	assert_false(splash.visible, "Splash hides at the end of its lifetime")

func test_acid_glob_and_splash_use_fixed_pools_and_clear_at_dawn() -> void:
	var turret: Building = _state.buildings.add("turret", Vector2i(12, 12), true)
	_state.projectiles.launch(_state, Vector2(400, 500), turret, turret.origin, _state.data.get_zombie("spitter")["ranged"])
	_fx._process(0.1)
	assert_true(_fx._acid_globs[0].visible)
	assert_eq(_fx._acid_globs[0].scale, Vector2(4, 4))
	_state.acid_hit.emit(Grid.tile_to_world(turret.origin))
	assert_true(_fx._acid_splashes[0].visible)
	var ids: Array[int] = []
	for child: Node in _fx.get_children():
		ids.append(child.get_instance_id())
	assert_eq(_fx.get_child_count(), _pool_nodes())
	_fx._process(1.0)
	assert_false(_fx._acid_splashes[0].visible)
	_state.projectiles.launch(_state, Vector2(400, 500), turret, turret.origin, _state.data.get_zombie("spitter")["ranged"])
	_fx._process(0.1)
	assert_true(_fx._acid_globs[0].visible)
	_fx._on_phase_changed(GameClock.Phase.DAY, 2)
	for sprite: Sprite2D in _fx._acid_globs + _fx._acid_splashes:
		assert_false(sprite.visible)
	assert_eq(_fx.get_child_count(), _pool_nodes())
	for i: int in range(ids.size()):
		assert_eq(_fx.get_child(i).get_instance_id(), ids[i], "Acid pools reuse their nodes")
