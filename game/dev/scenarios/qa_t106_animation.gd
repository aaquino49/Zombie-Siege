extends RefCounted
## Live verification: run at 60 fps with --frames=300 and inspect the PASS log.

class PlaybackCheck extends Node:
	var state: GameState
	var layer: ZombieLayer
	var zombie: Zombie
	var sprite: AnimatedSprite2D
	var death: AnimatedSprite2D
	var fade: Tween
	var elapsed: float = 0.0
	var stage: int = 0
	var seen_frame: bool = false

	func check(condition: bool, description: String) -> void:
		if condition:
			print("T106 LIVE PASS: " + description)
		else:
			push_error("T106 LIVE FAIL: " + description)

	func _process(delta: float) -> void:
		elapsed += delta
		if stage <= 1:
			zombie.pos += Vector2.RIGHT
		if stage == 0:
			seen_frame = seen_frame or sprite.frame > 0
			if elapsed < 0.35:
				return
			check(seen_frame and str(sprite.animation) == "walk_right", "walk frames advance while moving")
			state.zombie_hit.emit(zombie)
			stage = 1
			seen_frame = false
			elapsed = 0.0
		elif stage == 1:
			seen_frame = seen_frame or (str(sprite.animation).begins_with("hurt_") and sprite.frame > 0)
			if elapsed < 0.35:
				return
			check(seen_frame, "hurt advances without movement interrupting it")
			check(str(sprite.animation) == "walk_right", "hurt finishes and resumes moving")
			zombie.target_building_uid = state.buildings.all()[0].uid
			zombie.facing = Vector2.UP
			stage = 2
			seen_frame = false
			elapsed = 0.0
		elif stage == 2:
			seen_frame = seen_frame or sprite.frame > 0
			if elapsed < 0.4:
				return
			check(seen_frame and str(sprite.animation) == "attack_up" and sprite.rotation == 0.0,
				"stationary attack animates toward target without rotation")
			state.damage_zombie(zombie, zombie.hp)
			death = layer._death_sprites[0]
			stage = 3
			elapsed = 0.0
		elif stage == 3:
			if elapsed < 0.25:
				return
			check(is_instance_valid(death) and death.modulate.a > 0.2 and death.modulate.a < 0.8,
				"death is around half alpha at 0.25 seconds")
			stage = 4
		elif stage == 4:
			if elapsed < 0.6:
				return
			check(not is_instance_valid(death) and layer._death_sprites.is_empty() and layer._death_tweens.is_empty(),
				"death and tracking freed after 0.5 seconds")
			var next: Zombie = state.spawn_zombie("brute", zombie.pos)
			var recycled: AnimatedSprite2D = layer._active_sprites[next.uid]
			check(recycled == sprite and str(recycled.animation) == "walk_down" and recycled.modulate == Color.WHITE
				and recycled.sprite_frames.resource_path.contains("brute"), "death pool reuse resets type, walk and alpha")
			state.damage_zombie(next, next.hp)
			death = layer._death_sprites[0]
			fade = layer._death_tweens[death]
			layer.clear()
			check(not is_instance_valid(death) and not fade.is_valid(), "clear frees death and kills tween synchronously")
			var last: Zombie = state.spawn_zombie("runner", zombie.pos)
			state.damage_zombie(last, last.hp)
			death = layer._death_sprites[0]
			fade = layer._death_tweens[death]
			layer.unbind()
			check(not is_instance_valid(death) and not fade.is_valid(), "unbind frees death and kills tween synchronously")
			layer.bind(state)
			stage = 5
			elapsed = 0.0
		elif stage == 5 and elapsed > 0.65:
			check(layer._death_sprites.is_empty() and layer._death_tweens.is_empty(), "no delayed death callbacks after clear or unbind")
			print("T106 LIVE COMPLETE")
			set_process(false)

static func setup(main: Node) -> void:
	var state: GameState = Game.state
	state.waves.enabled = false
	state.clock.set_paused(true)
	var layer: ZombieLayer = main.get_node("World/YSort/Zombies")
	var zombie: Zombie = state.spawn_zombie("walker", state.survivors.all()[0].pos + Vector2(200, 0))
	zombie.facing = Vector2.RIGHT
	zombie.pos += Vector2.RIGHT
	layer.sync()
	var checker := PlaybackCheck.new()
	checker.state = state
	checker.layer = layer
	checker.zombie = zombie
	checker.sprite = layer._active_sprites[zombie.uid]
	main.add_child(checker)
