extends TestCase

var _layer: SurvivorLayer
var _state: GameState

func before_each() -> void:
	_state = GameState.new(GameData.load_default(), 1337)
	_layer = SurvivorLayer.new()
	_layer.bind(_state)

func after_each() -> void:
	if _layer:
		_layer.unbind()
		_layer.free()
		_layer = null
	_state = null

func test_four_direction_mapping_and_diagonal_tie() -> void:
	assert_eq(SurvivorLayer.dir_name(Vector2.DOWN), "down")
	assert_eq(SurvivorLayer.dir_name(Vector2.UP), "up")
	assert_eq(SurvivorLayer.dir_name(Vector2.LEFT), "left")
	assert_eq(SurvivorLayer.dir_name(Vector2.RIGHT), "right")
	assert_eq(SurvivorLayer.dir_name(Vector2(1, 1)), "right", "horizontal wins diagonal ties")

func test_animated_sprite_scale_facing_and_movement_state() -> void:
	assert_eq(_layer.get_child_count(), 4)
	var survivor: Survivor = _state.survivors.all()[0]
	var sprite: AnimatedSprite2D = _layer._sprites[survivor.uid]
	survivor.facing = Vector2.LEFT
	_layer.sync()
	assert_eq(sprite.scale, Vector2(4, 4))
	assert_eq(sprite.position, survivor.pos)
	assert_eq(sprite.rotation, 0.0, "pixel sprites are never rotated")
	assert_eq(str(sprite.animation), "idle_left")
	survivor.path.append(Vector2i(1, 0))
	survivor.pos += Vector2(4, 0)
	_layer.sync()
	assert_eq(str(sprite.animation), "walk_right", "movement delta sets facing")
	survivor.path.clear()
	survivor.pos += Vector2(0, 2)
	_layer.sync()
	assert_eq(str(sprite.animation), "walk_down")

func test_damage_plays_hurt_and_blocks_movement_until_finished() -> void:
	var survivor: Survivor = _state.survivors.all()[0]
	var sprite: AnimatedSprite2D = _layer._sprites[survivor.uid]
	survivor.facing = Vector2.UP
	_state.survivor_damaged.emit(survivor, 1)
	assert_eq(str(sprite.animation), "hurt_up")
	survivor.pos += Vector2.RIGHT * 8.0
	_layer.sync()
	assert_eq(str(sprite.animation), "hurt_up", "movement does not interrupt hurt")
	_layer._on_animation_finished(survivor.uid)
	assert_eq(str(sprite.animation), "idle_up")

func test_variant_frames_and_all_seven_resources_have_contract() -> void:
	var variants: Array = _state.data.balance("survivor_variants")
	for variant: String in variants:
		var survivor: Survivor = _state.survivors.add("Variant", variant, Vector2i(10, 10))
		var sprite: AnimatedSprite2D = _layer._sprites[survivor.uid]
		assert_true(sprite.sprite_frames.resource_path.contains(variant), "frames match " + variant)
		var frames: SpriteFrames = load("res://assets/pixel/frames/survivor_%s.tres" % variant)
		assert_eq(frames.get_animation_names().size(), 21)
		for direction: String in SurvivorLayer.DIRECTIONS:
			assert_eq(frames.get_frame_count("idle_%s" % direction), 1)
			assert_eq(frames.get_frame_count("walk_%s" % direction), 4)
			assert_eq(frames.get_frame_count("attack_%s" % direction), 1)
			assert_eq(frames.get_frame_count("hurt_%s" % direction), 3)
		assert_eq(frames.get_frame_count("death"), 1)

func test_death_clear_and_survivor_removal_cleanup() -> void:
	var survivor: Survivor = _state.survivors.all()[0]
	_state.survivor_killed.emit(survivor)
	assert_eq(_layer._death_sprites.size(), 1)
	_layer.clear()
	assert_eq(_layer.get_child_count(), 0, "clear frees death and active nodes synchronously")
	_layer.bind(_state)
	var added: Survivor = _state.survivors.add("Added", "blue", Vector2i(10, 10))
	assert_true(_layer._sprites.has(added.uid))
	_state.survivors.remove(added.uid)
	assert_false(_layer._sprites.has(added.uid))

func test_tower_z_order_hp_and_shelter_visibility() -> void:
	var survivor: Survivor = _state.survivors.all()[0]
	var sprite: AnimatedSprite2D = _layer._sprites[survivor.uid]
	var bar: HpBar = sprite.get_child(0) as HpBar
	survivor.on_tower = true
	survivor.sheltered = true
	survivor.hp = survivor.max_hp / 2
	_layer.sync()
	assert_eq(sprite.z_index, 1)
	assert_false(sprite.visible)
	assert_false(bar.visible)
	assert_eq(bar.global_position, survivor.pos)
	assert_almost_eq(bar._ratio, 0.5)
