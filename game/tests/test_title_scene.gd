extends TestCase
## Presentation-only title tests run synchronously, without a viewport or game.

var _title: TitleScene

func before_each() -> void:
	_title = load("res://scenes/ui/title_scene.tscn").instantiate() as TitleScene

func after_each() -> void:
	_title.free()

func test_builds_off_tree_without_game_state_and_is_idempotent() -> void:
	var game: Node = tree.root.get_node_or_null("Game")
	var original_state: Variant = game.get("state") if game != null else null
	assert_false(_title.is_inside_tree())
	_title.build_scene()
	var actors: Node2D = _title.get_node("Viewport/Stage/Actors")
	assert_not_null(actors.get_node("CommandCenter"))
	assert_not_null(actors.get_node("Watchtower"))
	assert_eq(_title._zombies.size(), TitleScene.DEATH_TIMES.size())
	assert_eq(_title._zombies[3].sprite_frames, TitleScene.RUNNER_FRAMES)
	assert_eq(_title._guard.sprite_frames, TitleScene.GUARD_FRAMES)
	var animated_count: int = 0
	for child: Node in actors.get_children():
		if child is AnimatedSprite2D:
			animated_count += 1
	assert_eq(animated_count, 21, "Guard, two idle survivors and eighteen siege zombies")
	var children_before: int = actors.get_child_count()
	_title.build_scene()
	assert_eq(actors.get_child_count(), children_before)
	if game != null:
		assert_eq(game.get("state"), original_state, "Diorama leaves Game.state untouched")
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/title_scene.gd")
	assert_false(source.contains("Game.state"), "No singleton state access")
	assert_false(source.contains("GameState"), "No simulation hooks")

func test_native_pixels_and_dusk_stay_in_private_viewport() -> void:
	_title.build_scene()
	assert_eq(_title.stretch_shrink, 4)
	assert_eq(_title.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	var viewport: SubViewport = _title.get_node("Viewport")
	assert_eq(viewport.size, Vector2i(320, 180))
	assert_eq(viewport.canvas_item_default_texture_filter, Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
	var tint: CanvasModulate = _title.get_node("Viewport/Stage/Dusk")
	assert_eq(tint.color, Color(1, 0.86, 0.72, 1), "Warm day colours, isolated from menu text")
	assert_eq(_title.get_node("Viewport/Stage/Ground").get_child_count(), 258)

func test_hurt_death_blood_corpse_fade_and_loop() -> void:
	_title.build_scene()
	_title.seek(5.85)
	assert_eq(_title._zombies[7].animation, &"hurt_left")
	_title.seek(6.05)
	assert_true(_title._flash.visible, "Capture has a muzzle flash")
	assert_eq(_title._guard.animation, &"attack_right")
	assert_true(_title._tracer.visible, "A tracer is visible with the muzzle flash")
	assert_true(_title._blood[7].visible, "Capture has blood")
	assert_eq(_title._zombies[7].animation, &"death")
	var exposed_zombies: int = 0
	for zombie: AnimatedSprite2D in _title._zombies:
		if zombie.visible and zombie.position.x >= 278.0 and zombie.position.x <= 312.0 and zombie.position.y >= 16.0 and zombie.position.y <= 164.0:
			exposed_zombies += 1
	assert_gt(exposed_zombies, 1, "At least two complete zombies fit in the uncovered right margin")
	_title.seek(6.35)
	assert_false(_title._zombies[7].visible)
	assert_false(_title._blood[7].visible)
	assert_true(_title._corpses[7].visible)
	_title.seek(8.55)
	assert_true(_title._corpses[7].visible)
	assert_almost_eq(_title._corpses[7].modulate.a, 0.5)
	_title.seek(8.9)
	assert_false(_title._corpses[7].visible)
	_title.seek(0.5)
	var initial: Array = _snapshot(_title)
	_title.seek(TitleScene.LOOP_SECONDS + 0.5)
	assert_eq(_snapshot(_title), initial, "Loop restores positions, poses and all effects")

func test_live_loop_keeps_zombies_visible_and_shots_on_targets() -> void:
	_title.build_scene()
	assert_eq(TitleScene.SPAWN_TIMES.size(), TitleScene.DEATH_TIMES.size())
	assert_eq(TitleScene.LANES.size(), TitleScene.DEATH_TIMES.size())
	assert_eq(TitleScene.SPEEDS.size(), TitleScene.DEATH_TIMES.size())
	for i: int in range(TitleScene.DEATH_TIMES.size()):
		var death_x: float = TitleScene.ZOMBIE_ENTRY_X - TitleScene.LIFE_SECONDS * TitleScene.SPEEDS[i]
		assert_true(death_x >= 280.0, "Zombie %d dies outside the menu panel" % i)
		_title.seek(TitleScene.DEATH_TIMES[i])
		assert_almost_eq(_title._zombies[i].position.x, roundf(death_x))
	_title.seek(TitleScene.LOOP_SECONDS - 0.05)
	var was_visible: Array[bool] = []
	for _i: int in range(_title._zombies.size()):
		was_visible.append(false)
	for i: int in range(_title._zombies.size()):
		was_visible[i] = _title._zombies[i].visible
	var margin_samples: int = 0
	var sample_count: int = 0
	for step: int in range(289):
		var t: float = float(step) * 0.05
		_title.seek(t)
		var in_margin: bool = false
		for i: int in range(_title._zombies.size()):
			var zombie: AnimatedSprite2D = _title._zombies[i]
			if zombie.visible:
				if not was_visible[i]:
					assert_true(zombie.position.x >= 312.0, "Zombie %d enters fully onscreen" % i)
				assert_true(zombie.position.y >= 48.0, "Zombie %d stays above the bottom edge" % i)
				assert_true(zombie.position.y <= 148.0, "Zombie %d stays above the bottom edge" % i)
				assert_false(zombie.position.distance_to(TitleScene.GUARD_FEET) < 10.0,
					"Zombie %d never overlaps the guard" % i)
				if zombie.position.x >= 278.0 and zombie.position.x <= 312.0:
					in_margin = true
			was_visible[i] = zombie.visible
		if in_margin:
			margin_samples += 1
		sample_count += 1
		if _title._tracer.visible:
			var dying_index: int = -1
			for i: int in range(_title._zombies.size()):
				var age: float = fposmod(_title._time - TitleScene.SPAWN_TIMES[i], TitleScene.LOOP_SECONDS)
				var life_age: float = fposmod(TitleScene.DEATH_TIMES[i] - TitleScene.SPAWN_TIMES[i],
					TitleScene.LOOP_SECONDS)
				var death_age: float = age - life_age
				if death_age >= 0.0 and death_age < 0.1:
					dying_index = i
					break
			assert_true(dying_index >= 0, "Firing sample at %.2f has a zombie in its death animation" % t)
			if dying_index >= 0:
				assert_eq(_title._tracer.get_point_position(1), _title._zombies[dying_index].position,
					"Firing sample at %.2f targets dying zombie %d" % [t, dying_index])
	assert_true(float(margin_samples) / float(sample_count) >= 0.9,
		"A zombie occupies the exposed right margin in at least 90% of the loop")

func test_fixed_capture_frames_are_repeatable_and_animate() -> void:
	_title.build_scene()
	_title.start_capture()
	for i: int in range(120):
		_title._process(0.001)
	var frame_120: Array = _snapshot(_title)
	for i: int in range(120):
		_title._process(0.2)
	assert_ne(_snapshot(_title), frame_120, "120 frames later moves actors and changes effects")
	var second: TitleScene = load("res://scenes/ui/title_scene.tscn").instantiate() as TitleScene
	second.build_scene()
	second.start_capture()
	for i: int in range(120):
		second._process(0.09)
	assert_eq(_snapshot(second), frame_120, "Same frame is independent of machine frame timing")
	var ground_a: Node = _title.get_node("Viewport/Stage/Ground")
	var ground_b: Node = second.get_node("Viewport/Stage/Ground")
	for i: int in range(240):
		assert_eq(ground_a.get_child(i).texture, ground_b.get_child(i).texture, "Fixed-seed terrain")
	second.free()

func test_freeing_title_releases_all_owned_actors_and_effects() -> void:
	_title.build_scene()
	var guard_ref: WeakRef = weakref(_title._guard)
	var blood_ref: WeakRef = weakref(_title._blood[0])
	var viewport_ref: WeakRef = weakref(_title.get_node("Viewport"))
	_title.free()
	assert_eq(guard_ref.get_ref(), null)
	assert_eq(blood_ref.get_ref(), null)
	assert_eq(viewport_ref.get_ref(), null)
	# after_each owns this fresh unbuilt instance.
	_title = load("res://scenes/ui/title_scene.tscn").instantiate() as TitleScene

func _snapshot(title: TitleScene) -> Array:
	var snapshot: Array = [title._guard.animation, title._guard.frame, title._flash.visible,
		title._flash.texture, title._tracer.visible]
	for i: int in range(title._zombies.size()):
		var zombie: AnimatedSprite2D = title._zombies[i]
		snapshot.append([zombie.position, zombie.animation, zombie.frame, zombie.visible,
			title._blood[i].visible, title._blood[i].texture, title._corpses[i].visible,
			title._corpses[i].modulate.a])
	return snapshot
