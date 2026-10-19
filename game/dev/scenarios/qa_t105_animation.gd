extends RefCounted
## Live QA only: actual animation timing, fading, and unbind during a fade.

class PlaybackCheck extends Node:
	var state: GameState
	var layer: SurvivorLayer
	var survivor: Survivor
	var sprite: AnimatedSprite2D
	var death: AnimatedSprite2D
	var elapsed: float = 0.0
	var stage: int = 0
	var seen_walk_frame: bool = false
	var seen_hurt_frame: bool = false

	func check(condition: bool, description: String) -> void:
		if condition:
			print("T105 LIVE PASS: " + description)
		else:
			push_error("T105 LIVE FAIL: " + description)

	func _process(delta: float) -> void:
		elapsed += delta
		if stage == 0:
			seen_walk_frame = seen_walk_frame or sprite.frame > 0
			if elapsed < 0.3:
				return
			check(seen_walk_frame, "walk advances without restarting")
			state.survivor_damaged.emit(survivor, 1)
			stage = 1
			elapsed = 0.0
		elif stage == 1:
			seen_hurt_frame = seen_hurt_frame or (str(sprite.animation).begins_with("hurt_") and sprite.frame > 0)
			if elapsed < 0.35:
				return
			check(seen_hurt_frame, "hurt advances through flash frames")
			check(str(sprite.animation) == "walk_right", "hurt completes and resumes walk")
			state.survivor_killed.emit(survivor)
			state.survivors.remove(survivor.uid)
			death = layer._death_sprites[0]
			stage = 2
			elapsed = 0.0
		elif stage == 2:
			if elapsed < 0.25:
				return
			check(is_instance_valid(death) and death.modulate.a > 0.2 and death.modulate.a < 0.8, "death fades around half alpha at 0.25 seconds")
			stage = 3
		elif stage == 3:
			if elapsed < 0.6:
				return
			check(not is_instance_valid(death) and layer._death_sprites.is_empty(), "death freed after the 0.5 second fade")
			var next: Survivor = state.survivors.all()[0]
			state.survivor_killed.emit(next)
			layer.unbind()
			layer.bind(state)
			stage = 4
			elapsed = 0.0
		elif stage == 4 and elapsed > 0.65:
			check(layer._death_sprites.is_empty(), "unbind during fade leaves no death nodes")
			print("T105 LIVE COMPLETE")
			set_process(false)

static func setup(main: Node) -> void:
	var state: GameState = Game.state
	state.clock.set_paused(true)
	var layer: SurvivorLayer = main.get_node("World/YSort/Units")
	var survivor: Survivor = state.survivors.all()[0]
	survivor.facing = Vector2.RIGHT
	survivor.path.append(Vector2i(1, 0))
	layer.sync()
	var checker := PlaybackCheck.new()
	checker.state = state
	checker.layer = layer
	checker.survivor = survivor
	checker.sprite = layer._sprites[survivor.uid]
	main.add_child(checker)
