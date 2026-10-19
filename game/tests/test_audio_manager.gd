class_name TestAudioManager extends TestCase

const AudioManager = preload("res://scripts/audio/audio_manager.gd")

var data: GameData
var state: GameState
var audio: AudioManager
var build_mode: BuildMode

func before_each() -> void:
	data = GameData.load_default()
	state = GameState.new(data, 1337)
	audio = AudioManager.new()
	build_mode = BuildMode.new()
	audio.bind(state, build_mode)

func after_each() -> void:
	if audio != null:
		audio.unbind()
		audio.free()
		audio = null
	if build_mode != null:
		build_mode.free()
		build_mode = null
	state = null
	data = null

func test_all_audio_paths_load() -> void:
	for sound_name: String in AudioManager.SOUNDS:
		var path: String = AudioManager.SOUNDS[sound_name]
		assert_true(ResourceLoader.exists(path), "File exists: " + path)
		var res := load(path)
		assert_true(res != null, "Audio loads: " + path)
		assert_true(res is AudioStream, "Is AudioStream: " + path)

func test_voice_cap_helper() -> void:
	assert_true(audio._can_start("gunshot", 0))
	assert_true(audio._can_start("gunshot", 3))
	assert_false(audio._can_start("gunshot", 4), "Refuses 5th concurrent gunshot")
	assert_false(audio._can_start("gunshot", 5))

	assert_true(audio._can_start("turret_shot", 3))
	assert_false(audio._can_start("turret_shot", 4))

	assert_true(audio._can_start("zombie_hit", 2))
	assert_false(audio._can_start("zombie_hit", 3))

	assert_true(audio._can_start("building_hit", 1))
	assert_false(audio._can_start("building_hit", 2))

func test_buses_assigned() -> void:
	for sound_name: String in AudioManager.SOUNDS:
		if sound_name == "day_loop" or sound_name == "night_loop":
			continue
		var pool: Array = audio._sfx_pools.get(sound_name, [])
		assert_gt(pool.size(), 0, "Pool exists for " + sound_name)
		for p: AudioStreamPlayer in pool:
			assert_eq(p.bus, &"SFX", "Player bus is SFX for " + sound_name)
	assert_eq(audio._music_player_a.bus, &"Music")
	assert_eq(audio._music_player_b.bus, &"Music")

func test_shots_event_to_sound() -> void:
	state.shot_fired.emit(Vector2.ZERO, Vector2.RIGHT, false)
	assert_eq(audio.played.get("gunshot", 0), 1)
	assert_eq(audio.played.get("turret_shot", 0), 0)

	state.shot_fired.emit(Vector2.ZERO, Vector2.RIGHT, true)
	assert_eq(audio.played.get("gunshot", 0), 1)
	assert_eq(audio.played.get("turret_shot", 0), 1)

func test_zombie_damage_hit_vs_kill() -> void:
	var z := state.spawn_zombie("walker", Vector2(100, 100))
	state.damage_zombie(z, 10)
	assert_eq(audio.played.get("zombie_hit", 0), 1)
	assert_eq(audio.played.get("zombie_die", 0), 0)

	state.damage_zombie(z, 9999)
	assert_eq(audio.played.get("zombie_hit", 0), 1)
	assert_eq(audio.played.get("zombie_die", 0), 1)

func test_cc_alarm_throttle() -> void:
	var cc: Building = state.buildings.all_of_type("command_center")[0]
	state.damage_building(cc, 10)
	assert_eq(audio.played.get("building_hit", 0), 1)
	assert_eq(audio.played.get("cc_alarm", 0), 1)

	# Second hit within 5 s of manager time
	state.damage_building(cc, 10)
	assert_eq(audio.played.get("building_hit", 0), 2)
	assert_eq(audio.played.get("cc_alarm", 0), 1, "cc_alarm throttled within 5s")

	# Advance manager time by 5.1 s
	audio._process(5.1)
	state.damage_building(cc, 10)
	assert_eq(audio.played.get("building_hit", 0), 3)
	assert_eq(audio.played.get("cc_alarm", 0), 2, "cc_alarm plays again after 5s")

func test_non_cc_building_damaged_no_cc_alarm() -> void:
	var wall_pos := state.map.command_center_origin() + Vector2i(5, 5)
	state.try_place("wooden_wall", wall_pos)
	var wall := state.buildings.get_at(wall_pos)
	state.damage_building(wall, 10)
	assert_eq(audio.played.get("building_hit", 0), 1)
	assert_eq(audio.played.get("cc_alarm", 0), 0)

func test_building_destroyed() -> void:
	var wall_pos := state.map.command_center_origin() + Vector2i(5, 5)
	state.try_place("wooden_wall", wall_pos)
	var wall := state.buildings.get_at(wall_pos)
	state.damage_building(wall, 9999)
	assert_eq(audio.played.get("building_destroyed", 0), 1)

func test_survivor_damaged() -> void:
	var s: Survivor = state.survivors.all()[0]
	state.damage_survivor(s, 10)
	assert_eq(audio.played.get("survivor_hurt", 0), 1)

func test_placement_attempted() -> void:
	build_mode.placement_attempted.emit(true)
	assert_eq(audio.played.get("building_placed", 0), 1)
	assert_eq(audio.played.get("ui_error", 0), 0)

	build_mode.placement_attempted.emit(false)
	assert_eq(audio.played.get("building_placed", 0), 1)
	assert_eq(audio.played.get("ui_error", 0), 1)

func test_phase_changed_horn_chime_and_music_switch() -> void:
	assert_eq(audio.active_music_name, "day_loop")

	state.clock.phase_changed.emit(GameClock.Phase.NIGHT, 1)
	assert_eq(audio.played.get("night_horn", 0), 1)
	assert_eq(audio.active_music_name, "night_loop")
	assert_eq(audio.active_music_stream, audio.get_stream("night_loop"))

	state.clock.phase_changed.emit(GameClock.Phase.DAY, 2)
	assert_eq(audio.played.get("dawn_chime", 0), 1)
	assert_eq(audio.active_music_name, "day_loop")
	assert_eq(audio.active_music_stream, audio.get_stream("day_loop"))

func test_game_state_signals_arguments() -> void:
	var hit_z: Array = []
	state.zombie_hit.connect(func(z: Zombie) -> void: hit_z.append(z))
	var z := state.spawn_zombie("walker", Vector2(50, 50))
	state.damage_zombie(z, 20)
	assert_eq(hit_z.size(), 1)
	assert_eq(hit_z[0], z)
	hit_z.clear()
	state.damage_zombie(z, 9999)
	assert_eq(hit_z.size(), 0, "zombie_hit not emitted on fatal blow")

	var hit_b: Array = []
	state.building_damaged.connect(func(b: Building, amt: int) -> void: hit_b.append([b, amt]))
	var cc: Building = state.buildings.all_of_type("command_center")[0]
	state.damage_building(cc, 15)
	assert_eq(hit_b.size(), 1)
	assert_eq(hit_b[0][0], cc)
	assert_eq(hit_b[0][1], 15)

	var hurt_s: Array = []
	state.survivor_damaged.connect(func(s: Survivor, amt: int) -> void: hurt_s.append([s, amt]))
	var surv: Survivor = state.survivors.all()[0]
	state.damage_survivor(surv, 25)
	assert_eq(hurt_s.size(), 1)
	assert_eq(hurt_s[0][0], surv)
	assert_eq(hurt_s[0][1], 25)

func test_build_complete_skips_starting_cc() -> void:
	var cc: Building = state.buildings.all_of_type("command_center")[0]
	state.buildings.building_completed.emit(cc)
	assert_eq(audio.played.get("build_complete", 0), 0, "Starting CC should be skipped")

	var wall_pos := state.map.command_center_origin() + Vector2i(5, 5)
	state.try_place("wooden_wall", wall_pos)
	var wall := state.buildings.get_at(wall_pos)
	state.buildings.finish(wall.uid)
	assert_eq(audio.played.get("build_complete", 0), 1)

func test_game_over_and_victory_stingers_and_reentry() -> void:
	state.game_won.emit()
	assert_eq(audio.played.get("victory", 0), 1)
	assert_true(audio.active_music_stream == null)

	# Re-entry check
	state.game_won.emit()
	assert_eq(audio.played.get("victory", 0), 1, "Guarded against re-entry")
	state.game_lost.emit("lost")
	assert_eq(audio.played.get("game_over", 0), 0, "Game won cannot trigger game over")

func test_game_lost_stinger() -> void:
	audio.unbind()
	state = GameState.new(data, 1337)
	audio.bind(state, build_mode)

	state.game_lost.emit("Command center destroyed")
	assert_eq(audio.played.get("game_over", 0), 1)
	assert_true(audio.active_music_stream == null)

	state.game_lost.emit("again")
	assert_eq(audio.played.get("game_over", 0), 1, "Guarded against re-entry")

func test_endless_continue_audio_lifecycle() -> void:
	state.clock.phase = GameClock.Phase.DAY
	state.game_won.emit()
	assert_eq(audio.played.get("victory", 0), 1, "Win plays victory once")
	assert_eq(audio.active_music_name, "", "Win stops phase music")

	# VictoryScreen calls this hook when Keep fighting is pressed.
	audio.resume_after_endless_continue()
	assert_eq(audio.active_music_name, "day_loop", "Continue resumes the current phase music")
	assert_eq(audio.played.get("day_loop", 0), 2, "Initial and resumed day music are counted")
	assert_eq(audio.played.get("victory", 0), 1, "Continue does not replay victory")

	state.clock.phase_changed.emit(GameClock.Phase.NIGHT, 22)
	assert_eq(audio.played.get("night_horn", 0), 1, "Endless night plays its horn")
	assert_eq(audio.active_music_name, "night_loop", "Endless night switches to night music")
	state.clock.phase_changed.emit(GameClock.Phase.DAY, 23)
	assert_eq(audio.played.get("dawn_chime", 0), 1, "Endless dawn plays its chime")
	assert_eq(audio.active_music_name, "day_loop", "Endless dawn switches to day music")
	state.game_lost.emit("command_center")
	assert_eq(audio.played.get("game_over", 0), 1, "Later loss plays Game Over")
	assert_eq(audio.active_music_name, "", "Later loss stops music")
	state.game_lost.emit("again")
	assert_eq(audio.played.get("game_over", 0), 1, "Later loss plays Game Over exactly once")

func test_endless_continue_resumes_current_night_without_phase_cues() -> void:
	state.game_won.emit()
	state.clock.phase = GameClock.Phase.NIGHT
	audio.resume_after_endless_continue()
	assert_eq(audio.active_music_name, "night_loop", "Continue selects the live night phase")
	assert_eq(audio._active_music_player.stream, audio.get_stream("night_loop"))
	assert_eq(audio.played.get("night_loop", 0), 1)
	assert_eq(audio.played.get("victory", 0), 1, "Continue does not replay victory")
	assert_eq(audio.played.get("night_horn", 0), 0, "Continue is not a new nightfall")
	assert_eq(audio.played.get("dawn_chime", 0), 0, "Continue is not a new dawn")

func test_determinism_with_and_without_audio_manager() -> void:
	var state_no_audio := GameState.new(data, 4242)
	var state_with_audio := GameState.new(data, 4242)
	var test_audio: AudioManager = AudioManager.new()
	test_audio.bind(state_with_audio, null)

	for i in range(200):
		state_no_audio.tick(0.1)
		state_with_audio.tick(0.1)
		test_audio._process(0.1)

	assert_eq(state_with_audio.zombies_killed, state_no_audio.zombies_killed)
	assert_eq(state_with_audio.zombies.count(), state_no_audio.zombies.count())
	assert_eq(state_with_audio.survivors_lost, state_no_audio.survivors_lost)
	assert_eq(state_with_audio.buildings_lost, state_no_audio.buildings_lost)

	test_audio.unbind()
	test_audio.free()

func test_ui_click() -> void:
	var btn := Button.new()
	audio._connect_button(btn)
	btn.pressed.emit()
	assert_eq(audio.played.get("ui_click", 0), 1)
	btn.free()

func test_night_groan_timer() -> void:
	state.clock.phase = GameClock.Phase.NIGHT
	state.spawn_zombie("walker", Vector2(100, 100))
	audio._groan_timer = 0.5
	audio._process(0.6)
	var total_groans: int = audio.played.get("zombie_groan_1", 0) + audio.played.get("zombie_groan_2", 0) + audio.played.get("zombie_groan_3", 0)
	assert_eq(total_groans, 1)

func test_real_placement_and_drag_emit_one_cue_per_attempt() -> void:
	build_mode.bind(state)
	build_mode.select("wooden_wall")
	var origin: Vector2i = state.map.command_center_origin() + Vector2i(5, 5)
	assert_eq(build_mode.place_at(origin, true), Placement.Result.OK)
	assert_eq(audio.played.get("building_placed", 0), 1)
	assert_ne(build_mode.place_at(origin, true), Placement.Result.OK)
	assert_eq(audio.played.get("ui_error", 0), 1)

	build_mode.begin_drag(origin + Vector2i(0, 1))
	assert_eq(build_mode.end_drag(origin + Vector2i(2, 1), true), 3)
	assert_eq(audio.played.get("building_placed", 0), 2, "A three-wall drag emits one placement cue")
	build_mode.begin_drag(origin + Vector2i(0, 1))
	assert_eq(build_mode.end_drag(origin + Vector2i(2, 1), true), 0)
	assert_eq(audio.played.get("ui_error", 0), 2, "A failed drag emits one error cue")

func test_determinism_through_two_combat_nights() -> void:
	var silent := GameState.new(data, 4242)
	var audible := GameState.new(data, 4242)
	# Equal resilient colonies keep both real wave cycles running regardless of balance.
	for sim: GameState in [silent, audible]:
		sim.waves.enabled = true
		sim.resources.add("ammo", 1000)
		sim.buildings.all_of_type("command_center")[0].hp = 100000
		for survivor: Survivor in sim.survivors.all():
			survivor.hp = 100000
			sim.set_job(survivor.uid, Survivor.Job.GUARD)
	var manager := AudioManager.new()
	manager.bind(audible)
	for i: int in range(1800):
		silent.tick(0.5)
		audible.tick(0.5)
		manager._process(0.5)
		if audible.clock.day >= 3:
			break
	assert_eq(audible.clock.day, 3, "Both nights reach dawn")
	assert_eq(silent.clock.day, audible.clock.day)
	assert_gt(audible.zombies_killed, 0, "Comparison exercises actual combat")
	assert_eq(audible.zombies_killed, silent.zombies_killed)
	assert_eq(audible.zombies.count(), silent.zombies.count())
	assert_eq(audible.survivors_lost, silent.survivors_lost)
	assert_eq(audible.buildings_lost, silent.buildings_lost)
	assert_eq(audible.rng.state, silent.rng.state, "Audio randomness does not consume simulation randomness")
	assert_eq(audible.waves._rng.state, silent.waves._rng.state, "Audio randomness does not consume wave randomness")
	assert_eq(manager.played.get("night_horn", 0), 2)
	assert_eq(manager.played.get("dawn_chime", 0), 2)
	assert_gt(manager.played.get("gunshot", 0), 0)
	assert_gt(manager.played.get("zombie_die", 0), 0)
	var groans: int = manager.played.get("zombie_groan_1", 0) + manager.played.get("zombie_groan_2", 0) + manager.played.get("zombie_groan_3", 0)
	assert_gt(groans, 0, "Audio RNG runs while real waves are alive")
	manager.unbind()
	manager.free()

func test_release_audio_and_unbind_clears_players_and_rebind_restores() -> void:
	assert_not_null(audio._active_music_player.stream, "Active player has stream after initial bind")
	# Populate both music slots and an actual valid tween without adding nodes
	# to the tree (the synchronous runner never advances frames).
	audio._music_player_b.stream = audio.get_stream("night_loop")
	var fade: Tween = tree.create_tween()
	fade.tween_property(audio._music_player_a, "volume_db", -40.0, 2.0)
	audio._music_tween = fade

	# Test direct _release_audio()
	audio._release_audio()
	_assert_all_audio_released()
	assert_false(fade.is_valid(), "Teardown kills the registered crossfade tween")
	assert_true(audio._music_player_a.stream == null, "Music player A stream is null after _release_audio")
	assert_true(audio._music_player_b.stream == null, "Music player B stream is null after _release_audio")
	assert_false(audio._music_player_a.playing, "Music player A not playing after _release_audio")
	assert_false(audio._music_player_b.playing, "Music player B not playing after _release_audio")
	assert_true(audio.active_music_stream == null, "active_music_stream is null after _release_audio")

	# Re-binding restores music stream on the active player
	audio.bind(state, build_mode)
	assert_not_null(audio._active_music_player.stream, "Active player has stream restored after re-bind")
	assert_eq(audio._active_music_player.stream, audio.get_stream("day_loop"), "Active player plays day_loop after re-bind")
	for sound_name: String in audio._sfx_pools:
		for player: AudioStreamPlayer in audio._sfx_pools[sound_name]:
			assert_not_null(player.stream, "Rebind restores SFX " + sound_name)

	# Test unbind() clears streams as well
	audio.unbind()
	_assert_all_audio_released()
	assert_true(audio._music_player_a.stream == null, "Music player A stream is null after unbind")
	assert_true(audio._music_player_b.stream == null, "Music player B stream is null after unbind")
	assert_false(audio._music_player_a.playing, "Music player A not playing after unbind")
	assert_false(audio._music_player_b.playing, "Music player B not playing after unbind")
	assert_true(audio.active_music_stream == null, "active_music_stream is null after unbind")
	state.clock.phase_changed.emit(GameClock.Phase.NIGHT, 1)
	build_mode.placement_attempted.emit(true)
	_assert_all_audio_released()

func _assert_all_audio_released() -> void:
	for player: Node in audio.get_children():
		if player is AudioStreamPlayer:
			assert_true(player.stream == null, "Stream released: " + player.name)
			assert_false(player.playing, "Player stopped: " + player.name)
	assert_true(audio.active_music_stream == null, "Active music reference released")
	assert_eq(audio.active_music_name, "", "Active music name cleared")
	assert_true(audio._streams.is_empty(), "Stream cache cleared")
	assert_true(audio._music_tween == null or not audio._music_tween.is_valid(), "Tween released")

func test_release_for_quit_is_idempotent_and_rejects_ui_audio() -> void:
	var button := Button.new()
	audio._connect_button(button)
	audio.release_for_quit()
	_assert_all_audio_released()
	var clicks: int = audio.played.get("ui_click", 0)
	button.pressed.emit()
	assert_eq(audio.played.get("ui_click", 0), clicks, "Late UI signals cannot restart audio during quit")
	assert_false(audio.play("gunshot"), "Quit rejects SFX playback")
	audio.release_for_quit()
	_assert_all_audio_released()
	button.free()

func test_quit_pending_check_uses_lifetime_not_frames() -> void:
	var game: Node = load("res://scripts/autoload/game.gd").new()
	var held: RefCounted = RefCounted.new()
	var pending: Array[WeakRef] = [weakref(held)]
	assert_true(game._has_pending_audio(pending), "Live references keep shutdown pending")
	var other: RefCounted = RefCounted.new()
	pending.append(weakref(other))
	assert_eq(game._pending_audio_count(pending), 2, "Count every live playback for the timeout warning")
	held = null
	assert_true(game._has_pending_audio(pending), "Wait until the last playback is freed")
	assert_eq(game._pending_audio_count(pending), 1, "Ignore expired references")
	other = null
	assert_false(game._has_pending_audio(pending), "Freed references complete shutdown")
	pending.clear()
	assert_false(game._has_pending_audio(pending), "A silent manager needs no delay")
	game.free()

func test_quit_audio_wait_timeout_boundary() -> void:
	var game_script: GDScript = load("res://scripts/autoload/game.gd")
	var deadline_ms: int = game_script.QUIT_AUDIO_DEADLINE_MS
	assert_eq(deadline_ms, 2000, "Shutdown safety deadline is two seconds")
	assert_true(game_script.should_keep_waiting(2, 5000, 5000, deadline_ms))
	assert_true(game_script.should_keep_waiting(1, 5000, 6999, deadline_ms), "Live playback waits before deadline")
	assert_false(game_script.should_keep_waiting(1, 5000, 7000, deadline_ms), "Stop at the exact deadline")
	assert_false(game_script.should_keep_waiting(2, 5000, 7001, deadline_ms), "Stalled playbacks cannot prevent quit")

func test_quit_audio_wait_finishes_without_fixed_delay() -> void:
	var game_script: GDScript = load("res://scripts/autoload/game.gd")
	var deadline_ms: int = game_script.QUIT_AUDIO_DEADLINE_MS
	assert_false(game_script.should_keep_waiting(0, 5000, 5000, deadline_ms), "No playback means immediate quit")
	assert_false(game_script.should_keep_waiting(0, 5000, 5001, deadline_ms), "Freed playbacks quit before deadline")
	assert_false(game_script.should_keep_waiting(0, 5000, 7001, deadline_ms), "No warning or wait needed after release")

func test_quit_prevents_new_scene_transitions() -> void:
	var game: Node = load("res://scripts/autoload/game.gd").new()
	game._quitting = true
	game.start_new_game()
	game.restart()
	game.quit_to_menu()
	assert_false(game.transitioning, "Quitting cannot start a fade or reload that restarts audio")
	game.free()

