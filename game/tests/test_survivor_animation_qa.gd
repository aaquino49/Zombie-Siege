extends TestCase

var _state: GameState
var _layer: SurvivorLayer

func before_each() -> void:
	_state = GameState.new(GameData.load_default(), 1337)
	_layer = SurvivorLayer.new()
	_layer.bind(_state)

func after_each() -> void:
	_layer.unbind()
	_layer.free()
	_state = null

func test_zero_facing_preserves_direction_and_walk_does_not_restart() -> void:
	var survivor: Survivor = _state.survivors.all()[0]
	var sprite: AnimatedSprite2D = _layer._sprites[survivor.uid]
	survivor.facing = Vector2.LEFT
	_layer.sync()
	survivor.facing = Vector2.ZERO
	_layer.sync()
	assert_eq(str(sprite.animation), "idle_left")
	survivor.path.append(Vector2i(1, 0))
	survivor.pos += Vector2.RIGHT
	_layer.sync()
	sprite.set_frame_and_progress(2, 0.4)
	_layer.sync()
	assert_eq(str(sprite.animation), "walk_right")
	assert_eq(sprite.frame, 2, "repeated sync preserves the walk frame")
	assert_almost_eq(sprite.frame_progress, 0.4)
	assert_false(sprite.flip_h, "pre-mirrored right strip needs no flip")

func test_guard_shot_faces_target_then_returns_to_idle() -> void:
	var survivor: Survivor = _state.survivors.all()[0]
	var sprite: AnimatedSprite2D = _layer._sprites[survivor.uid]
	survivor.job = Survivor.Job.GUARD
	survivor.facing = Vector2.RIGHT
	_layer.sync()
	_state.shot_fired.emit(survivor.pos, survivor.pos + Vector2(100, 0), false)
	assert_eq(str(sprite.animation), "attack_right")
	_layer.sync()
	assert_eq(str(sprite.animation), "attack_right", "sync does not interrupt attack")
	_layer._on_animation_finished(survivor.uid)
	assert_eq(str(sprite.animation), "idle_right")
	_state.survivor_damaged.emit(survivor, 1)
	_state.shot_fired.emit(survivor.pos, survivor.pos + Vector2(100, 0), false)
	assert_eq(str(sprite.animation), "hurt_right", "a shot cannot interrupt hurt")

func test_frames_have_strip_order_rates_and_loop_flags() -> void:
	for variant: String in _state.data.balance("survivor_variants"):
		var frames: SpriteFrames = load(SurvivorLayer.FRAME_PATH % variant)
		assert_false(frames.has_animation("default"))
		for direction: String in SurvivorLayer.DIRECTIONS:
			for kind: String in ["idle", "walk", "attack", "hurt"]:
				var animation_name: String = "%s_%s" % [kind, direction]
				var expected_rate: float = {"idle": 4.0, "walk": 8.0, "attack": 10.0, "hurt": 12.0}[kind]
				assert_almost_eq(frames.get_animation_speed(animation_name), expected_rate)
				assert_eq(frames.get_animation_loop(animation_name), kind in ["idle", "walk"])
				var order: Array = [0, 1, 0, 2] if kind == "walk" else ([0, 1, 2] if kind == "hurt" else [0])
				for index: int in range(order.size()):
					var texture: AtlasTexture = frames.get_frame_texture(animation_name, index) as AtlasTexture
					assert_not_null(texture)
					if texture == null:
						continue
					assert_eq(texture.region, Rect2(order[index] * 16, 0, 16, 16))
					var strip_kind: String = "hurt" if kind == "hurt" else "walk"
					assert_eq(texture.atlas.resource_path, "res://assets/pixel/characters/survivor_%s_%s_%s.png" % [variant, strip_kind, direction])
		assert_false(frames.get_animation_loop("death"))
		var death: AtlasTexture = frames.get_frame_texture("death", 0) as AtlasTexture
		assert_eq(death.atlas.resource_path, "res://assets/pixel/characters/survivor_%s_hurt_down.png" % variant)
		assert_eq(death.region, Rect2(0, 0, 16, 16))

func test_first_guard_attack_faces_the_shot_target() -> void:
	var survivor: Survivor = _state.survivors.all()[0]
	_state.set_job(survivor.uid, Survivor.Job.GUARD)
	survivor.path.clear()
	survivor.post_tile = survivor.tile()
	survivor.post_check_timer = 10.0
	survivor.activity = Survivor.Activity.GUARDING
	survivor.facing = Vector2.UP
	_layer.sync()
	_state.spawn_zombie("brute", survivor.pos + Vector2(100, 0))
	GuardJob.tick(_state, survivor, float(_state.data.balance("guard_fire_interval")))
	assert_eq(survivor.facing, Vector2.RIGHT, "simulation aims at the new target")
	_layer.sync()
	var sprite: AnimatedSprite2D = _layer._sprites[survivor.uid]
	assert_eq(str(sprite.animation), "attack_right", "attack must face the shot target on the first shot")

func test_world_units_share_y_sort_with_buildings_and_props() -> void:
	var world: Node2D = (load("res://scenes/world/world.tscn") as PackedScene).instantiate()
	var y_sort: Node2D = world.get_node("YSort")
	assert_true(y_sort.y_sort_enabled)
	for child_name: String in ["Units", "Buildings", "Props", "Zombies"]:
		var child: Node2D = y_sort.get_node(child_name)
		assert_true(child.y_sort_enabled, child_name + " participates in shared sorting")
		assert_eq(child.z_index, 0)
	assert_eq(world.get_node("YSort/Zombies").get_parent(), y_sort)
	world.free()

func test_unbind_disconnects_state_and_frees_death_nodes() -> void:
	var survivor: Survivor = _state.survivors.all()[0]
	_state.survivor_killed.emit(survivor)
	var death: AnimatedSprite2D = _layer._death_sprites[0]
	_layer.unbind()
	assert_false(is_instance_valid(death))
	assert_eq(_layer.get_child_count(), 0)
	assert_false(_state.survivor_damaged.is_connected(_layer._on_survivor_damaged))
	assert_false(_state.survivor_killed.is_connected(_layer._on_survivor_killed))
	assert_false(_state.shot_fired.is_connected(_layer._on_shot_fired))
	_state.survivors.add("After unbind", "blue", Vector2i(10, 10))
	assert_eq(_layer.get_child_count(), 0)

func test_clear_cancels_pending_death_tween() -> void:
	var previous: Array[Tween] = tree.get_processed_tweens()
	_state.survivor_killed.emit(_state.survivors.all()[0])
	var created: Array[Tween] = []
	for tween: Tween in tree.get_processed_tweens():
		if not previous.has(tween):
			created.append(tween)
	assert_eq(created.size(), 1, "death creates one fade tween")
	_layer.clear()
	for tween: Tween in created:
		assert_false(tween.is_valid(), "clear must cancel the fade callback before freeing its sprite")
		tween.kill() # Keep the failing regression from leaving its own pending callback.
