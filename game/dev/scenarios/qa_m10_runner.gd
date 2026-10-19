extends Node
## Bounded real UI M10 flow; all save/record files are disposable.

var main: Node
var out: String
var checks: Array[String] = []
var failures: Array[String] = []
var records_path: String
var panel_bounds: Dictionary = {}

func check(ok: bool, label: String) -> void:
	checks.append(label)
	print("M10 %s: %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		failures.append(label)

func frames(count: int = 6) -> void:
	for index: int in range(count):
		await get_tree().process_frame

func capture(label: String) -> void:
	var hud: Node = main.get_node("HUD")
	hud._refresh_day()
	hud._refresh_rain_tag()
	hud._refresh_forecast()
	main.get_node("BuildBarLayer").refresh_if_stale()
	await frames(20)
	await RenderingServer.frame_post_draw
	var image: Image = get_tree().root.get_texture().get_image()
	check(image.get_size() == Vector2i(1280, 720), label + " is 1280x720")
	check(image.save_png(out.path_join("qa_m10_" + label + ".png")) == OK, "capture " + label)
	for screen: String in ["VictoryScreen", "GameOverScreen", "MainMenu"]:
		if main.get_node(screen).visible:
			var rect: Rect2 = main.get_node(screen + "/Dim/Center/Panel").get_global_rect()
			panel_bounds[label + "/" + screen] = {"x": rect.position.x, "y": rect.position.y,
				"width": rect.size.x, "height": rect.size.y}

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	get_tree().root.push_input(event)
	event = event.duplicate() as InputEventKey
	event.pressed = false
	get_tree().root.push_input(event)
	await frames(2)

func click(button: Button) -> void:
	var center: Vector2 = button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = center
	get_tree().root.push_input(motion)
	var event := InputEventMouseButton.new()
	event.position = center
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	get_tree().root.push_input(event)
	event = event.duplicate() as InputEventMouseButton
	event.pressed = false
	get_tree().root.push_input(event)
	await frames(3)

func configure_scene() -> void:
	Game.state.clock.set_paused(true)
	Game.state.waves.enabled = false
	main.get_node("Hints").set_enabled(false)
	main.get_node("GameOverScreen").records_path = records_path
	main.get_node("VictoryScreen").records_path = records_path
	main.get_node("MainMenu").records_path = records_path

func settle_transition() -> void:
	for index: int in range(360):
		if not Game.transitioning:
			return
		await get_tree().process_frame
	check(false, "transition completes in 360 frames")

func restart() -> void:
	Game.restart()
	await get_tree().scene_changed
	main = get_tree().current_scene
	await settle_transition()
	configure_scene()

func run(scene: Node) -> void:
	main = scene
	out = ProjectSettings.globalize_path("res://../project/runs/T-198/a1")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			out = arg.trim_prefix("--capture-dir=")
	get_tree().root.get_node("DevTools").set("_target_frames", 100000)
	records_path = "user://qa_m10_records_%d.cfg" % OS.get_process_id()
	Records.remove_file(records_path)
	Game.save_path = "user://qa_m10_save_%d.json" % OS.get_process_id()
	configure_scene()
	await weather_and_idle()
	await loss_record()
	await restart()
	await victory_record()
	await restart()
	await persistence()
	await difficulty()
	Game.delete_save()
	Records.remove_file(records_path)
	var file := FileAccess.open(out.path_join("qa_m10_flow.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "passed": failures.is_empty(), "panel_bounds": panel_bounds}, "\t"))
	file.close()
	print("M10 FLOW: %d checks, %d failures" % [checks.size(), failures.size()])
	Game.request_quit(0 if failures.is_empty() else 1)

func weather_and_idle() -> void:
	Game.state.clock.set_paused(false)
	preload("res://dev/scenarios/weather_rain.gd").setup(main)
	var state: GameState = Game.state
	var weather: WeatherLayer = main.get_node("World/WeatherLayer")
	weather._process(1.1)
	check(state.weather_day() == "rain" and weather._target_kind == "rain", "real rain targets streaks")
	await capture("rain_day")
	check(main.get_node("HUD").rain_tag.visible and main.get_node("HUD").rain_tag.text == "Rain: farms +50%", "visible rain farm bonus tag")
	for person: Survivor in state.survivors.all():
		state.set_job(person.uid, Survivor.Job.BUILDER)
	var people: Array[Survivor] = state.survivors.all()
	for index: int in range(2):
		state.set_job(people[index].uid, Survivor.Job.IDLE)
		people[index].pos = Grid.tile_to_world(state.map.command_center_origin() + Vector2i(index * 2, 3))
	var selection: SelectionController = main.get_node("World/Selection")
	selection.clear()
	await frames()
	var button: Button = main.get_node("HUD").idle_button
	check(button.visible and button.text == "Idle: 2", "live Idle count is two")
	await capture("idle_before")
	await click(button)
	check(selection.selected_uid == people[0].uid, "real mouse Idle click selects first in roster order")
	check(main.get_node("World/Camera2D").position == people[0].pos, "mouse click centers camera")
	await capture("idle_click")
	await key(KEY_I)
	check(selection.selected_uid == people[1].uid, "real I input cycles to second idle survivor")
	check(main.get_node("World/Camera2D").position == people[1].pos, "I centers camera")
	await capture("idle_i")
	await key(KEY_I)
	check(selection.selected_uid == people[0].uid, "I wraps to first idle survivor")
	await capture("idle_wrap")
	preload("res://dev/scenarios/weather_fog.gd").setup(main)
	weather._process(1.1)
	var turret: Building = state.buildings.all_of_type("turret")[0]
	check(state.weather_night() == "fog" and weather._target_kind == "fog", "real fog targets patches")
	check(selection.range_preview()["radius"] == 4.0 * Grid.TILE, "fog turret ring is four tiles")
	check(state.zombies.count() == 5, "fog scene contains five readable zombies")
	await capture("fog_night")
	check(not button.visible and not main.get_node("HUD").rain_tag.visible, "night hides Idle and rain tag")
	state.clock.phase = GameClock.Phase.DAY
	await capture("fog_forecast")
	check(main.get_node("HUD").night_forecast_label.text.contains("Fog: range −1"), "day forecast names fog range penalty")
	check(main.get_node("InfoPanel")._range_label.text.contains("4 in fog tonight"), "day turret info explains fog forecast")
	state.clock.phase = GameClock.Phase.NIGHT
	selection.select_building(turret.uid)

func loss_record() -> void:
	var state: GameState = Game.state
	state.clock.set_paused(false)
	var cc: Building = state.buildings.all_of_type("command_center")[0]
	state.damage_building(cc, cc.hp)
	state.tick(0.0)
	check(main.get_node("GameOverScreen").visible, "real CC loss displays Game Over")
	await capture("game_over_record")
	var nights: int = int(state.stats()["nights_survived"])
	check(Records.load_all(records_path)[state.difficulty]["best_nights"] == nights, "Game Over writes nights record")
	check(main.get_node("GameOverScreen/Dim/Center/Panel/Margin/Content/RecordLine").text.begins_with("New record:"), "Game Over shows New record line")
	main.get_node("GameOverScreen").visible = false
	main.get_node("MainMenu").open(state)
	await capture("menu_best")
	check(main.get_node("MainMenu/Dim/Center/Panel/Margin/Content/BestRecords").text == Records.menu_line(records_path), "main menu reads same Best record")

func victory_record() -> void:
	var state: GameState = Game.state
	state.clock.set_paused(false)
	VictorySetup.trigger_win()
	main.get_node("World/RescueHelicopter").skip()
	await frames()
	check(state.won and main.get_node("VictoryScreen").visible, "real final-night victory displays records")
	check(Records.load_all(records_path)[state.difficulty]["wins"] == 1, "Victory counts one win")
	var fastest: int = Records.load_all(records_path)[state.difficulty]["fastest_win_s"]
	await capture("victory_record")
	await click(main.get_node("VictoryScreen/Dim/Center/Panel/Margin/Content/Buttons/KeepFighting"))
	check(state.endless and not state.game_over and not main.get_node("VictoryScreen").visible, "real Keep fighting click resumes")
	main.get_node("DawnReport").visible = false
	state.clock.day = 24
	var cc: Building = state.buildings.all_of_type("command_center")[0]
	state.damage_building(cc, cc.hp)
	state.tick(0.0)
	var record: Dictionary = Records.load_all(records_path)[state.difficulty]
	check(record["wins"] == 1 and record["best_nights"] == 23 and record["fastest_win_s"] == fastest, "later endless loss updates nights without counting another win")
	await capture("endless_loss_record")

func calendar(state: GameState) -> Array[String]:
	var result: Array[String] = []
	for day: int in range(1, 41):
		result.append(Weather.day_weather(state.data, state.map_seed, day) + "/" + Weather.night_weather(state.data, state.map_seed, day))
	return result

func persistence() -> void:
	var state: GameState = Game.state
	var expected: Array[String] = calendar(state)
	var seed: int = state.map_seed
	state.clock.day = 5
	state.clock.phase = GameClock.Phase.NIGHT
	state.clock.elapsed = float(state.data.balance("night_min_length")) - 0.1
	state.clock.set_paused(false)
	state.tick(0.2)
	check(state.clock.day == 6 and Game.has_save(), "real dawn autosaves Day6")
	await capture("dawn_save")
	main.get_node("DawnReport/Center/Panel/Margin/Content/Buttons/Continue").pressed.emit()
	Game.continue_game()
	await get_tree().scene_changed
	main = get_tree().current_scene
	await settle_transition()
	configure_scene()
	check(Game.state.clock.day == 6 and Game.state.map_seed == seed and calendar(Game.state) == expected, "real Continue preserves forty-day weather calendar")
	await capture("continued_weather")
	await restart()
	check(Game.state.clock.day == 1 and Game.state.map_seed == seed and calendar(Game.state) == expected, "real Restart preserves forty-day weather calendar")
	await capture("restarted_weather")

func difficulty() -> void:
	main.get_node("MainMenu").open(Game.state)
	main.get_node("MainMenu/Dim/Center/Panel/Margin/Content/Buttons/NewGame").pressed.emit()
	await capture("difficulty_picker")
	var picker: DifficultyPicker = main.get_node("MainMenu/DifficultyPicker")
	picker.get_node(DifficultyPicker.CONTENT + "Options/Hard/Select").pressed.emit()
	await get_tree().scene_changed
	main = get_tree().current_scene
	await settle_transition()
	configure_scene()
	check(Game.state.difficulty == "hard" and Game.state.difficulty_multipliers == Game.state.data.difficulty_config("hard"), "real Hard picker applies data multipliers")
	main.get_node("PauseMenu").open()
	check(main.get_node("PauseMenu/Dim/Center/Panel/Margin/Content/Difficulty").text.ends_with("Hard"), "Hard pause label matches simulation")
	await capture("difficulty_hard")
