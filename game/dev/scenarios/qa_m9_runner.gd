extends Node
## Bounded live M9 probes, with file-backed results and intermediate captures.

var checks: Array[String] = []
var failures: Array[String] = []
var out: String
var main: Node

func check(ok: bool, label: String) -> void:
	checks.append(label)
	print("M9 %s: %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		failures.append(label)

func frames(count: int = 6) -> void:
	for index: int in range(count):
		await get_tree().process_frame

func capture(label: String) -> void:
	main.get_node("HUD")._refresh_day()
	main.get_node("HUD")._refresh_forecast()
	main.get_node("BuildBarLayer").refresh_if_stale()
	await frames(30)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(get_tree().root.get_texture().get_image().save_png(out.path_join("qa_m9_" + label + ".png")) == OK, "capture " + label)

func settle_transition() -> void:
	for index: int in range(360):
		if not Game.transitioning:
			return
		await get_tree().process_frame
	check(false, "scene transition completes in 360 frames")

func wait_sound_idle(audio: AudioManager, sound_name: String) -> void:
	# Accelerated sim nights must allow the real mixer to finish a one-voice cue.
	var deadline: int = Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline:
		var busy: bool = false
		for player: AudioStreamPlayer in audio._sfx_pools.get(sound_name, []):
			busy = busy or player.playing
		if not busy:
			return
		await get_tree().process_frame
	check(false, sound_name + " finishes within five real seconds")

func run(scene: Node, mode: String) -> void:
	main = scene
	out = ProjectSettings.globalize_path("res://../project/runs/T-190/a1")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			out = arg.trim_prefix("--capture-dir=")
	get_tree().root.get_node("DevTools").set("_target_frames", 100000)
	Game.state.clock.set_speed(1)
	Game.state.clock.set_paused(true)
	main.get_node("Hints").set_enabled(false)
	Game.save_path = "user://qa_m9_%s_%d.json" % [mode, OS.get_process_id()]
	if mode == "endless":
		await endless()
	elif mode == "seed":
		await seed_flow()
	else:
		await ranges()
	Game.delete_save()
	Game.save_path = Game.SAVE_PATH
	var file := FileAccess.open(out.path_join("qa_m9_%s_flow.json" % mode), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "passed": failures.is_empty()}, "\t"))
	file.close()
	print("M9 FLOW %s: %d checks, %d failures" % [mode, checks.size(), failures.size()])
	Game.request_quit(0 if failures.is_empty() else 1)

func endless() -> void:
	var state: GameState = Game.state
	state.clock.set_paused(false)
	check(Game.save_now(), "pre-win save exists")
	var wins: Array[int] = []
	state.game_won.connect(func() -> void: wins.append(1))
	VictorySetup.trigger_win()
	main.get_node("World/RescueHelicopter").skip()
	await frames()
	var victory: VictoryScreen = main.get_node("VictoryScreen")
	var audio: AudioManager = main.get_node("Audio")
	check(victory.visible and state.won and wins.size() == 1, "dawn21 shows original Victory")
	check(not Game.has_save(), "Victory deleted save slot")
	check(audio.active_music_name == "" and int(audio.played.get("victory", 0)) == 1, "Victory stops music and plays one stinger")
	await capture("victory_panel")
	victory.get_node("Dim/Center/Panel/Margin/Content/Buttons/KeepFighting").pressed.emit()
	check(state.endless and not state.game_over and not victory.visible and not state.clock.paused and not state.clock.locked, "Keep fighting resumes live colony")
	check(audio.active_music_name == "day_loop" and audio._active_music_player.playing, "real button immediately resumes playing day music")
	check(int(audio.played.get("victory", 0)) == 1, "Keep fighting does not replay victory")
	main.get_node("DawnReport").visible = false
	state.waves.enabled = true
	# Exercise cleared night21 followed by capped night22 without waiting real minutes.
	for night: int in [21, 22]:
		await wait_sound_idle(audio, "night_horn")
		await wait_sound_idle(audio, "dawn_chime")
		var horn_before: int = int(audio.played.get("night_horn", 0))
		var chime_before: int = int(audio.played.get("dawn_chime", 0))
		state.clock.set_paused(false)
		state.clock.elapsed = float(state.data.balance("day_length")) - 0.1
		state.tick(0.2)
		check(state.clock.phase == GameClock.Phase.NIGHT and state.clock.day == night and state.zombies.count() > 0, "night%d really spawns" % night)
		var forecast: Dictionary = WaveSpawner.forecast(state.data, night, state.difficulty_multipliers)
		var total: int = 0
		for type_id: String in ["walker", "runner", "brute", "spitter"]:
			total += int(forecast[type_id])
		check(state.hostiles_remaining() == total and not bool(forecast["final"]), "night%d counts match base forecast" % night)
		check(audio.active_music_name == "night_loop" and int(audio.played.get("night_horn", 0)) == horn_before + 1, "night%d horn and music restored" % night)
		state.clock.set_paused(true)
		await capture("night%d_spawn" % night)
		if night == 21:
			state.waves.clear_pending()
			for zombie: Zombie in state.zombies.all().duplicate():
				state.damage_zombie(zombie, zombie.hp)
			state.clock.elapsed = float(state.data.balance("night_min_length")) - 0.1
		else:
			state.clock.elapsed = float(state.data.balance("night_max_length")) - 0.1
		state.clock.set_paused(false)
		state.tick(0.2)
		check(state.clock.day == night + 1 and state.clock.phase == GameClock.Phase.DAY and state.hostiles_remaining() == 0, "night%d ends at dawn" % night)
		check(audio.active_music_name == "day_loop" and int(audio.played.get("dawn_chime", 0)) == chime_before + 1, "dawn%d chime and music restored" % (night + 1))
		check(Game.has_save() and Game.save_day() == night + 1, "dawn%d writes fresh endless autosave" % (night + 1))
		check(state.last_dawn_report["objective"] == "Survive as long as you can (Endless, night %d)" % night, "endless Dawn Report objective")
		await capture("dawn%d_endless" % (night + 1))
		main.get_node("DawnReport/Center/Panel/Margin/Content/Buttons/Continue").pressed.emit()
		state.clock.set_paused(true)
	check(wins.size() == 1 and not victory.visible, "no second win through dawn23")
	var expected_resources: Dictionary = SaveGame.capture(state)["resources"]
	var expected_kills: int = state.zombies_killed
	main.get_node("PauseMenu").open()
	main.get_node("PauseMenu/Dim/Center/Panel/Margin/Content/Buttons/MainMenu").pressed.emit()
	await get_tree().scene_changed
	main = get_tree().current_scene
	await settle_transition()
	# Screenshot scenarios suppress automatic menu opening in Main._ready().
	check(Game.show_menu, "Quit to Menu selects menu startup")
	main.get_node("MainMenu").open(Game.state)
	check(main.get_node("MainMenu").visible, "Continue menu is visible")
	await capture("endless_continue_menu")
	main.get_node("MainMenu/Dim/Center/Panel/Margin/Content/Buttons/Continue").pressed.emit()
	await get_tree().scene_changed
	main = get_tree().current_scene
	await settle_transition()
	state = Game.state
	state.clock.set_paused(true)
	audio = main.get_node("Audio")
	check(state.endless and state.won and state.clock.day == 23 and not state.game_over, "real menu Continue restores endless Day23")
	check(SaveGame.capture(state)["resources"] == expected_resources and state.zombies_killed == expected_kills, "Continue preserves resources and win statistics")
	check(not main.get_node("VictoryScreen").visible and not main.get_node("World/RescueHelicopter").visible, "Continue never replays rescue")
	check(audio.active_music_name == "day_loop" and int(audio.played.get("victory", 0)) == 0, "Continue plays phase music without victory")
	check(not "FINAL HORDE" in main.get_node("HUD").night_forecast_label.text, "endless forecast has no Final Horde label")
	await capture("endless_restored_day23")
	var cc: Building = state.buildings.all_of_type("command_center")[0]
	state.damage_building(cc, cc.hp)
	state.tick(0.0)
	check(main.get_node("GameOverScreen").visible and not main.get_node("VictoryScreen").visible and state.lose_reason == "command_center", "later loss displays Game Over")
	check(state.zombies_killed == expected_kills and not Game.has_save(), "loss retains kills and deletes save")
	check(audio.active_music_name == "" and int(audio.played.get("game_over", 0)) == 1, "later loss stops music and plays Game Over once")
	check(main.get_node("GameOverScreen/Dim/Center/Panel/Margin/Content/Reason").text == "The Command Center was destroyed.", "Game Over displays correct loss reason")
	check(main.get_node("GameOverScreen/Dim/Center/Panel/Margin/Content/Stats").get_child_count() == 10, "Game Over displays all five statistic rows")
	await capture("endless_loss")
	state.game_lost.emit("again")
	check(int(audio.played.get("game_over", 0)) == 1, "duplicate loss never replays Game Over")

func map_signature(state: GameState) -> String:
	var tiles: Array = []
	for y: int in range(state.map.size()):
		for x: int in range(state.map.size()):
			var tile := Vector2i(x, y)
			tiles.append([state.map.terrain_at(tile), state.map.occupant_at(tile), state.map.get_node_amount(tile)])
	return JSON.stringify(tiles)

func seed_flow() -> void:
	var original: GameState = Game.state
	var original_map: String = map_signature(original)
	var rng_before: int = original.rng.state
	var waves_before: int = original.waves._rng.state
	main.get_node("MainMenu").open(original)
	main.get_node("MainMenu/Dim/Center/Panel/Margin/Content/Buttons/NewGame").pressed.emit()
	var picker: DifficultyPicker = main.get_node("MainMenu/DifficultyPicker")
	var previous: int = Game.preview_seed
	await capture("seed_before")
	picker.get_node(DifficultyPicker.CONTENT + "SeedRow/Reroll").pressed.emit()
	var shown: int = Game.preview_seed
	check(shown != previous and picker.get_node(DifficultyPicker.CONTENT + "SeedRow/Seed").text == "Seed: %d" % shown, "Reroll visibly changes shown seed")
	check(original == Game.state and original.rng.state == rng_before and original.waves._rng.state == waves_before and original.clock.paused, "Reroll preserves colony RNG and pause")
	await capture("seed_rerolled")
	picker.get_node(DifficultyPicker.CONTENT + "Options/Normal/Select").pressed.emit()
	await get_tree().scene_changed
	main = get_tree().current_scene
	await settle_transition()
	Game.state.clock.set_paused(true)
	check(Game.state.map_seed == shown, "New Game starts shown preview seed")
	check(map_signature(Game.state) != original_map, "rerolled seed produces a different map")
	main.get_node("PauseMenu").open()
	check(main.get_node("PauseMenu/Dim/Center/Panel/Margin/Content/Difficulty").text == "Seed %d · Normal" % shown, "pause displays seed and difficulty")
	await capture("seed_pause")
	main.get_node("PauseMenu/Dim/Center/Panel/Margin/Content/Buttons/Restart").pressed.emit()
	await get_tree().scene_changed
	main = get_tree().current_scene
	await settle_transition()
	Game.state.clock.set_paused(true)
	check(Game.state.map_seed == shown and not Game.state.endless and not Game.state.won, "real Restart keeps seed and resets run")
	var reference := GameState.new(Game.state.data, shown, "normal")
	# Resource nodes can be harvested while the scene fades; terrain cannot.
	var terrain_equal: bool = true
	for y: int in range(reference.map.size()):
		for x: int in range(reference.map.size()):
			var tile := Vector2i(x, y)
			terrain_equal = terrain_equal and reference.map.terrain_at(tile) == Game.state.map.terrain_at(tile)
	check(terrain_equal, "Restart regenerates identical terrain")
	await capture("seed_restart_map")

func ranges() -> void:
	preload("res://dev/scenarios/defense.gd").setup(main)
	var state: GameState = Game.state
	var selection: SelectionController = main.get_node("World/Selection")
	var mode: BuildMode = main.get_node("World/BuildMode")
	var turret: Building = state.buildings.all_of_type("turret")[0]
	check(selection.range_preview()["radius"] == float(state.data.get_building("turret")["range_tiles"]) * Grid.TILE, "selected turret radius matches data")
	await capture("turret_day")
	var tower: Building = state.buildings.all_of_type("watchtower")[0]
	selection.select_building(tower.uid)
	check(selection.range_preview()["radius"] == float(state.data.balance("guard_range_tiles")) * float(state.data.get_building("watchtower")["guard_range_mult"]) * Grid.TILE, "selected tower radius matches data")
	await capture("tower_day")
	var guard: Survivor = state.survivors.all()[0]
	guard.job = Survivor.Job.GUARD
	guard.post_uid = tower.uid
	guard.post_tile = tower.origin
	guard.pos = tower.center_world() + Vector2(20, 12)
	selection.select_survivor(guard.uid)
	check(selection.range_preview()["center"] == tower.center_world(), "tower guard ring stays centred on post")
	await capture("guard_day")
	selection.clear()
	state.clock.day = int(state.data.get_building("turret")["unlock_day"])
	state.resources.add("wood", 1000)
	state.resources.add("scrap", 1000)
	var origin: Vector2i = turret.origin + Vector2i(-2, 1)
	state.map.vacate(origin, Vector2i.ONE)
	mode.select("turret")
	mode.preview_at(origin)
	mode._process(0.0)
	check(Placement.check(state, "turret", origin) == Placement.Result.OK and mode._range_preview["color"] == Color(0.2, 1.0, 0.35), "valid ghost is green")
	await capture("ghost_valid")
	mode.preview_at(turret.origin)
	mode._process(0.0)
	check(mode._range_preview["color"] == Color(1.0, 0.2, 0.2), "occupied ghost is red")
	await capture("ghost_invalid")
	mode.preview_at(origin)
	mode.place_at(origin, false)
	check(state.buildings.get_at(origin) != null and mode.active_type == "", "range preview permits placement")
	selection.select_building(state.buildings.get_at(origin).uid)
	check(selection.range_preview().is_empty(), "blueprint selection has no active range")
	selection.select_building(turret.uid)
	state.clock.phase = GameClock.Phase.NIGHT
	state.clock.phase_changed.emit(GameClock.Phase.NIGHT, state.clock.day)
	await capture("turret_night")
	check(state.zombies.count() > 0, "night ring capture retains visible siege zombies")
