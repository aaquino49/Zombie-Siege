extends TestCase

var _state: GameState
var _layer: ZombieLayer

func before_each() -> void:
	_state = GameState.new(GameData.load_default(), 12345)
	_layer = ZombieLayer.new()
	_layer.bind(_state)

func after_each() -> void:
	_layer.unbind()
	_layer.free()
	_state = null

func test_pool_reuse_during_pending_deaths_keeps_types_and_clear_frees_every_fade() -> void:
	var deaths: Array[AnimatedSprite2D] = []
	var fades: Array[Tween] = []
	var pooled: AnimatedSprite2D
	for type_id: String in ZombieLayer.TYPES:
		var zombie: Zombie = _state.spawn_zombie(type_id, Vector2(100, 100))
		var active: AnimatedSprite2D = _layer._active_sprites[zombie.uid]
		if pooled != null:
			assert_eq(active, pooled, "reuse the view while the previous death is still fading")
		pooled = active
		assert_true(active.sprite_frames.resource_path.contains("zombie_" + type_id))
		assert_eq(str(active.animation), "walk_down")
		assert_eq(active.frame, 0)
		assert_eq(active.modulate, Color.WHITE)
		_state.damage_zombie(zombie, zombie.hp)
		var death: AnimatedSprite2D = _layer._death_sprites.back()
		var fade: Tween = _layer._death_tweens[death]
		assert_ne(death, active, "death has its own node independent of the pool")
		assert_true(fade.is_valid())
		deaths.append(death)
		fades.append(fade)
	for index: int in range(deaths.size()):
		assert_true(deaths[index].sprite_frames.resource_path.contains("zombie_" + ZombieLayer.TYPES[index]), "later reuse must not change older death art")
		assert_eq(str(deaths[index].animation), "death")
	assert_eq(_layer.get_child_count(), deaths.size() + 1, "one death node per type plus one reused pooled node")
	_layer.clear()
	for death: AnimatedSprite2D in deaths:
		assert_false(is_instance_valid(death), "clear frees each outstanding death synchronously")
	for fade: Tween in fades:
		assert_false(fade.is_valid(), "clear kills each outstanding tween synchronously")
	assert_false(is_instance_valid(pooled))
	assert_eq(_layer.get_child_count(), 0)
	assert_true(_layer._death_sprites.is_empty())
	assert_true(_layer._death_tweens.is_empty())
