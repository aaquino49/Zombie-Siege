extends TestCase

var _state: GameState
var _layer: ZombieLayer

func before_each() -> void:
	_state = GameState.new(GameData.load_default(), 12345)
	_layer = ZombieLayer.new()

func after_each() -> void:
	_layer.unbind()
	_layer.free()
	_state = null

func test_off_tree_bind_and_add_have_distinct_animated_frames() -> void:
	assert_false(_layer.is_inside_tree())
	_state.spawn_zombie("walker", Vector2(10, 10))
	_layer.bind(_state)
	_state.spawn_zombie("runner", Vector2(20, 20))
	_state.spawn_zombie("brute", Vector2(30, 30))
	assert_eq(_layer.get_child_count(), 3)
	for z: Zombie in _state.zombies.all():
		var sprite: AnimatedSprite2D = _layer._active_sprites[z.uid]
		assert_not_null(sprite.sprite_frames)
		assert_true(sprite.sprite_frames.resource_path.contains("zombie_" + z.type_id))
		assert_eq(sprite.position, z.pos)
		assert_eq(sprite.scale, Vector2(4, 4))
		assert_eq(sprite.modulate, Color.WHITE)
		assert_eq(sprite.offset, Vector2(0, -5))
		assert_true(sprite.centered)
		assert_false(sprite.flip_h)
		assert_eq(sprite.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
		assert_eq(sprite.frame, 0)
		for facing: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN, Vector2(1, 1)]:
			z.facing = facing
			_layer.sync()
			assert_eq(sprite.rotation, 0.0, "pixel zombies never rotate")
			assert_eq(str(sprite.animation), "idle_" + SurvivorLayer.dir_name(facing))

func test_all_frames_have_counts_order_rates_and_loops() -> void:
	for type_id: String in ZombieLayer.TYPES:
		var frames: SpriteFrames = load(ZombieLayer.FRAME_PATH % type_id)
		assert_eq(frames.get_animation_names().size(), 25 if type_id == "spitter" else 21)
		assert_false(frames.has_animation("default"))
		for direction: String in SurvivorLayer.DIRECTIONS:
			for kind: String in ["idle", "walk", "attack", "hurt", "death"]:
				var animation_name: String = "%s_%s" % [kind, direction]
				var order: Array = [0, 1, 0, 2] if kind in ["walk", "attack"] else ([0, 1, 2] if kind == "hurt" else [0])
				assert_eq(frames.get_frame_count(animation_name), order.size())
				var rate: float = {"idle": 4.0, "walk": 12.0 if type_id == "runner" else 8.0, "attack": 10.0, "hurt": 12.0, "death": 10.0}[kind]
				assert_almost_eq(frames.get_animation_speed(animation_name), rate)
				assert_eq(frames.get_animation_loop(animation_name), kind in ["idle", "walk", "attack"])
				for index: int in range(order.size()):
					var texture: AtlasTexture = frames.get_frame_texture(animation_name, index) as AtlasTexture
					assert_not_null(texture)
					if texture == null:
						continue
					assert_eq(texture.region, Rect2(order[index] * 16, 0, 16, 16))
					var strip_kind: String = "hurt" if kind in ["hurt", "death"] else "walk"
					assert_eq(texture.atlas.resource_path, "res://assets/pixel/zombies/%s_%s_%s.png" % [type_id, strip_kind, direction])
		assert_eq(frames.get_frame_count("death"), 1)
		assert_false(frames.get_animation_loop("death"))
		var death: AtlasTexture = frames.get_frame_texture("death", 0) as AtlasTexture
		assert_eq(death.region, Rect2(0, 0, 16, 16))
		assert_eq(death.atlas.resource_path, "res://assets/pixel/zombies/%s_hurt_down.png" % type_id)

func test_movement_attack_facing_and_no_play_restart() -> void:
	var z: Zombie = _state.spawn_zombie("walker", Vector2(100, 100))
	_layer.bind(_state)
	var sprite: AnimatedSprite2D = _layer._active_sprites[z.uid]
	for direction: Vector2 in [Vector2.RIGHT, Vector2.UP, Vector2.LEFT, Vector2.DOWN]:
		z.pos += direction * 4.0
		z.facing = -direction
		_layer.sync()
		assert_eq(str(sprite.animation), "walk_" + SurvivorLayer.dir_name(direction), "movement beats old facing")
	var wall: Building = _state.buildings.add("wooden_wall", Vector2i(10, 10), true)
	z.pos = wall.center_world() + Vector2(0, 64)
	z.facing = (wall.center_world() - z.pos).normalized()
	z.target_building_uid = wall.uid
	_layer.sync()
	_layer.sync()
	assert_eq(str(sprite.animation), "attack_up")
	sprite.set_frame_and_progress(2, 0.4)
	_layer.sync()
	assert_eq(sprite.frame, 2, "sync does not restart the attack")
	assert_almost_eq(sprite.frame_progress, 0.4)
	z.target_building_uid = 0
	z.target_survivor_uid = _state.survivors.all()[0].uid
	z.facing = Vector2.RIGHT
	_layer.sync()
	assert_eq(str(sprite.animation), "attack_right")
	z.target_survivor_uid = 0
	z.facing = Vector2.ZERO
	_layer.sync()
	assert_eq(str(sprite.animation), "idle_right", "zero facing retains direction")

func test_spitter_uses_distinct_frames_and_returns_from_directional_spit() -> void:
	var spitter: Zombie = _state.spawn_zombie("spitter", Vector2(100, 100))
	_layer.bind(_state)
	var sprite: AnimatedSprite2D = _layer._active_sprites[spitter.uid]
	assert_eq(sprite.sprite_frames.resource_path, "res://assets/pixel/frames/zombie_spitter.tres")
	assert_eq(sprite.self_modulate, Color.WHITE, "Spitter art is not tinted")
	_state.spit_fired.emit(spitter.pos, spitter.pos + Vector2.RIGHT * 100.0)
	assert_eq(str(sprite.animation), "spit_right")
	assert_false(sprite.sprite_frames.get_animation_loop("spit_right"))
	sprite.animation_finished.emit()
	assert_eq(str(sprite.animation), "idle_right")
	assert_false(_layer._spitting[spitter.uid])

func test_hurt_is_not_interrupted_or_restarted_and_resumes_latest_state() -> void:
	var z: Zombie = _state.spawn_zombie("brute", Vector2(100, 100))
	_layer.bind(_state)
	var sprite: AnimatedSprite2D = _layer._active_sprites[z.uid]
	z.facing = Vector2.UP
	_state.zombie_hit.emit(z)
	assert_eq(str(sprite.animation), "hurt_up")
	sprite.set_frame_and_progress(1, 0.3)
	z.facing = Vector2.LEFT
	_state.zombie_hit.emit(z)
	assert_eq(str(sprite.animation), "hurt_up", "repeated hits do not restart hurt")
	assert_eq(sprite.frame, 1)
	assert_almost_eq(sprite.frame_progress, 0.3)
	z.pos += Vector2.RIGHT * 8.0
	_layer.sync()
	assert_eq(str(sprite.animation), "hurt_up", "movement does not interrupt hurt")
	sprite.animation_finished.emit()
	assert_eq(str(sprite.animation), "walk_right")
	z.target_building_uid = _state.buildings.all()[0].uid
	z.facing = Vector2.LEFT
	_layer.sync()
	_state.zombie_hit.emit(z)
	sprite.animation_finished.emit()
	assert_eq(str(sprite.animation), "attack_left")

func test_pool_reuse_mid_hurt_resets_type_animation_alpha_and_bar() -> void:
	var first: Zombie = _state.spawn_zombie("walker", Vector2(10, 10))
	_layer.bind(_state)
	var sprite: AnimatedSprite2D = _layer._active_sprites[first.uid]
	var bar: HpBar = sprite.get_child(0) as HpBar
	first.hp = first.max_hp / 2
	_layer.sync()
	_state.zombie_hit.emit(first)
	sprite.set_frame_and_progress(2, 0.8)
	sprite.modulate.a = 0.2
	_state.zombies.remove(first.uid)
	assert_false(sprite.visible)
	assert_false(bar.visible)
	assert_eq(bar._ratio, 1.0)
	var second: Zombie = _state.spawn_zombie("brute", Vector2(90, 110))
	assert_eq(_layer.get_child_count(), 1)
	assert_eq(_layer._active_sprites[second.uid], sprite)
	assert_true(sprite.sprite_frames.resource_path.contains("zombie_brute"))
	assert_eq(str(sprite.animation), "walk_down")
	assert_eq(sprite.frame, 0)
	assert_eq(sprite.frame_progress, 0.0)
	assert_true(sprite.is_playing())
	assert_true(sprite.visible)
	assert_eq(sprite.modulate, Color.WHITE)
	assert_eq(sprite.position, second.pos)
	assert_eq(bar.global_position, second.pos)
	assert_eq(bar._ratio, 1.0)
	assert_false(bar.visible)
	assert_false(_layer._hurt[second.uid])
	sprite.animation_finished.emit()
	assert_eq(str(sprite.animation), "walk_down", "recycled signal uses the new uid")

func test_zombie_hp_bar_follows_above_head_without_inheriting_scale() -> void:
	var z: Zombie = _state.spawn_zombie("brute", Vector2(100, 100))
	_layer.bind(_state)
	var sprite: AnimatedSprite2D = _layer._active_sprites[z.uid]
	var bar: HpBar = sprite.get_child(0) as HpBar
	_layer.sync()
	assert_eq(bar._ratio, 1.0)
	assert_false(bar.visible)
	z.hp = z.max_hp / 2
	z.pos += Vector2(20, 30)
	_layer.sync()
	assert_eq(bar._ratio, 0.5)
	assert_true(bar.visible)
	assert_true(bar.top_level)
	assert_eq(bar.global_position, z.pos)
	assert_eq(bar.global_scale, Vector2.ONE)
	assert_eq(bar.global_rotation, 0.0)
	assert_eq(bar.y_offset, -56.0)
	z.hp = 0
	_layer.sync()
	assert_eq(bar._ratio, 0.0)
	assert_false(bar.visible)

func test_death_clear_frees_all_nodes_and_tweens() -> void:
	var z: Zombie = _state.spawn_zombie("brute", Vector2(100, 100))
	_layer.bind(_state)
	_state.damage_zombie(z, z.hp)
	assert_eq(_layer._death_sprites.size(), 1)
	var death: AnimatedSprite2D = _layer._death_sprites[0]
	var tween: Tween = _layer._death_tweens[death]
	assert_eq(str(death.animation), "death")
	assert_eq(death.position, z.pos)
	assert_eq(death.scale, Vector2(4, 4))
	assert_eq(death.offset, Vector2(0, -5))
	assert_eq(death.rotation, 0.0)
	assert_true(death.sprite_frames.resource_path.contains("zombie_brute"))
	assert_eq(death.modulate.a, 1.0)
	assert_eq(ZombieLayer.DEATH_SECONDS, 0.5)
	_layer.clear()
	assert_false(tween.is_valid())
	assert_false(is_instance_valid(death))
	assert_eq(_layer.get_child_count(), 0)
	assert_true(_layer._death_sprites.is_empty())
	assert_true(_layer._death_tweens.is_empty())
	assert_true(_layer._active_sprites.is_empty())
	assert_true(_layer._free_sprites.is_empty())

func test_unbind_frees_death_and_disconnects_then_rebinds() -> void:
	var z: Zombie = _state.spawn_zombie("runner", Vector2(100, 100))
	_layer.bind(_state)
	_state.damage_zombie(z, z.hp)
	var death: AnimatedSprite2D = _layer._death_sprites[0]
	var tween: Tween = _layer._death_tweens[death]
	_layer.unbind()
	assert_false(is_instance_valid(death))
	assert_false(tween.is_valid())
	assert_eq(_layer.get_child_count(), 0)
	assert_false(_state.zombie_hit.is_connected(_layer._on_zombie_hit))
	assert_false(_state.zombie_killed.is_connected(_layer._on_zombie_killed))
	assert_false(_state.zombies.zombie_added.is_connected(_layer._on_zombie_added))
	assert_false(_state.zombies.zombie_removed.is_connected(_layer._on_zombie_removed))
	_state.spawn_zombie("walker", Vector2.ZERO)
	assert_eq(_layer.get_child_count(), 0)
	_layer.bind(_state)
	assert_eq(_layer.get_child_count(), 1, "rebind creates views without duplicate connections")
	_layer.bind(_state)
	assert_eq(_layer.get_child_count(), 1)

func test_building_hp_bar() -> void:
	var b = Building.new()
	b.type_id = "wooden_wall"
	var type_data = _state.data.get_building("wooden_wall")
	b.hp = type_data["hp"]
	b.max_hp = type_data["hp"]
	b.complete = true
	b.progress = type_data["build_time"] # Make it complete
	
	var node = BuildingSprites.make(_state.data, b)
	var hp_bar = node.get_node_or_null("HpBar") as HpBar
	
	assert_not_null(hp_bar, "complete building has hp bar")
	assert_eq(hp_bar._ratio, 1.0, "full hp")
	assert_false(hp_bar.always_show, "Buildings do not opt into night bars")
	assert_false(hp_bar.should_draw())
	
	b.hp = b.max_hp / 2
	BuildingSprites.update_hp_bar(node, b)
	assert_eq(hp_bar._ratio, 0.5, "damaged building hp ratio")
	
	# Test blueprint
	var bp = Building.new()
	bp.type_id = "wooden_wall"
	bp.hp = type_data["hp"]
	bp.max_hp = type_data["hp"]
	bp.progress = 0
	var bp_node = BuildingSprites.make(_state.data, bp)
	var bp_hp_bar = bp_node.get_node_or_null("HpBar") as HpBar
	assert_true(bp_hp_bar == null, "blueprint has no hp bar")
	
	node.free()
	bp_node.free()

func test_survivor_hp_bar() -> void:
	var layer = SurvivorLayer.new()
	layer.bind(_state)
	
	var s = _state.survivors.add("Bob", "blue", Vector2i(0, 0))
	s.hp = s.max_hp
	
	var sprite = layer._sprites[s.uid] as AnimatedSprite2D
	var hp_bar = sprite.get_child(0) as HpBar
	assert_not_null(hp_bar, "survivor has hp bar")
	
	layer.sync()
	assert_eq(hp_bar._ratio, 1.0, "full hp")
	_state.clock.phase = GameClock.Phase.NIGHT
	layer.sync()
	assert_false(hp_bar.always_show, "Survivors do not opt into night bars")
	assert_false(hp_bar.should_draw())
	
	s.hp = 25
	layer.sync()
	assert_eq(hp_bar._ratio, 0.5, "half hp")
	
	layer.free()
