extends TestCase
## Release checks through real colony, save service, selection and result screens.

class ReleaseGame:
	extends "res://scripts/autoload/game.gd"
	var settings_path: String
	func _transition(_to_menu: bool, _fresh_seed: bool = false) -> void:
		new_game(next_seed, settings_path)

var data: GameData
var state: GameState
var owned: Array[Node] = []
var records_path: String
var service: ReleaseGame

func before_each() -> void:
	data = GameData.load_default()
	state = GameState.new(data, 1337, "normal")
	state.waves.enabled = false
	records_path = temp_path("m10_records", "cfg")
	Records.remove_file(records_path)
	service = ReleaseGame.new()
	owned.append(service)
	service.settings_path = temp_path("m10_settings", "cfg")
	service.save_path = temp_path("m10_dawn", "json")
	service.state = state

func after_each() -> void:
	service.delete_save()
	Records.remove_file(records_path)
	for node: Node in owned:
		node.free()
	owned.clear()
	state = null
	data = null

func _farm_day(rain: bool) -> int:
	var farm_data: GameData = GameData.load_default()
	farm_data.weather_config()["rain"]["chance"] = 1.0 if rain else 0.0
	var colony := GameState.new(farm_data, 1337)
	colony.waves.enabled = false
	colony.clock.day = 3
	for survivor: Survivor in colony.survivors.all():
		colony.set_job(survivor.uid, Survivor.Job.IDLE)
	var origin: Vector2i = colony.map.command_center_origin() + Vector2i(-3, 3)
	var farm: Building = colony.buildings.add("farm", origin, true)
	var farmer: Survivor = colony.survivors.all()[0]
	colony.set_job(farmer.uid, Survivor.Job.FARMER)
	farmer.pos = Grid.tile_to_world(origin + Vector2i(0, -1))
	var before: int = colony.resources.get_amount("food")
	var worked: bool = false
	for tick: int in range(2000):
		if colony.clock.phase != GameClock.Phase.DAY:
			break
		colony.tick(0.1)
		worked = worked or farmer.work_uid == farm.uid
	assert_eq(colony.weather_day(), "rain" if rain else "clear")
	assert_true(worked, "Farmer reached the real farm during the day")
	assert_eq(colony.clock.phase, GameClock.Phase.NIGHT)
	return colony.resources.get_amount("food") - before

func test_rain_day_produces_more_real_farm_food_than_identical_clear_day() -> void:
	var clear_food: int = _farm_day(false)
	var rain_food: int = _farm_day(true)
	assert_gt(clear_food, 0)
	assert_gt(rain_food, clear_food)

func _fog_seed(night: int) -> int:
	for seed: int in range(1, 10000):
		if Weather.night_weather(data, seed, night) == "fog":
			return seed
	fail("No real fog seed found")
	return 1337

func test_fog_forecast_selection_and_tower_guard_ranges_agree() -> void:
	state.map_seed = _fog_seed(5)
	state.clock.day = 5
	var turret: Building = state.buildings.add("turret", state.map.command_center_origin() + Vector2i(4, 0), true)
	var tower: Building = state.buildings.add("watchtower", turret.origin + Vector2i(0, 3), true)
	var selection := SelectionController.new()
	owned.append(selection)
	selection.bind(state)
	var info: InfoPanel = load("res://scenes/ui/info_panel.tscn").instantiate()
	owned.append(info)
	info.bind(state, selection)
	selection.select_building(turret.uid)
	info.refresh()
	assert_true(info._range_label.text.contains("5 in fog tonight"))
	var forecast: Dictionary = WaveSpawner.forecast(data, 5, state.difficulty_multipliers, state.map_seed)
	assert_true(bool(forecast["fog"]))
	assert_true(HudText.forecast_text(forecast).contains("Fog: range −1"))
	var turret_clear: float = Combat.turret_range_px(state)
	var guard: Survivor = state.survivors.all()[0]
	guard.job = Survivor.Job.GUARD
	guard.post_uid = tower.uid
	guard.post_building = tower
	guard.on_tower = true
	guard.pos = tower.center_world()
	var tower_clear: float = GuardJob.effective_range_px(state, guard, tower)
	state.clock.phase = GameClock.Phase.NIGHT
	assert_eq(state.weather_night(), "fog")
	assert_eq(Combat.turret_range_px(state), turret_clear - Grid.TILE)
	assert_eq(GuardJob.effective_range_px(state, guard, tower), tower_clear - Grid.TILE)
	assert_eq(selection.range_preview()["radius"], 5.0 * Grid.TILE)
	info.refresh()
	assert_eq(info._range_label.text, "Range: 5 tiles")
	selection.select_survivor(guard.uid)
	assert_eq(selection.range_preview()["radius"], tower_clear - Grid.TILE)

func test_final_night_and_adjacent_nights_never_get_forbidden_fog() -> void:
	var fog_seen: int = 0
	for seed: int in range(1, 101):
		state.map_seed = seed
		var previous: bool = false
		for night: int in range(1, 61):
			state.clock.day = night
			var fog: bool = state.weather_night() == "fog"
			assert_false(fog and previous, "Seed %d night %d" % [seed, night])
			if night == 20:
				assert_false(fog, "Final Horde must be clear")
			fog_seen += int(fog)
			previous = fog
	assert_gt(fog_seen, 0)

func _weather_calendar(colony: GameState) -> Array[String]:
	var result: Array[String] = []
	for day: int in range(1, 41):
		colony.clock.day = day
		result.append(colony.weather_day() + "/" + colony.weather_night())
	return result

func test_restart_and_file_continue_preserve_weather_from_real_dawn_save() -> void:
	var calendar: Array[String] = _weather_calendar(state)
	state.clock.day = 5
	state.clock.phase = GameClock.Phase.NIGHT
	state.clock.elapsed = float(data.balance("night_min_length")) - 0.1
	state.tick(0.2)
	assert_eq(state.clock.day, 6)
	assert_eq(state.clock.phase, GameClock.Phase.DAY)
	assert_true(service.save_now())
	service.continue_game()
	assert_eq(service.state.clock.day, 6)
	assert_eq(service.state.map_seed, 1337)
	assert_eq(_weather_calendar(service.state), calendar)
	service.restart()
	assert_eq(service.state.clock.day, 1)
	assert_eq(service.state.map_seed, 1337)
	assert_eq(_weather_calendar(service.state), calendar)

func test_idle_count_click_i_cycle_camera_and_live_job_change() -> void:
	# Reuse the real HUD fixture, including onready bindings and real input map.
	var fixture: TestCase = load("res://tests/test_idle_button.gd").new()
	fixture.before_each()
	var colony: GameState = fixture.get("_state")
	var hud: CanvasLayer = fixture.get("_hud")
	var selection: SelectionController = fixture.get("_selection")
	var camera: CameraController = fixture.get("_camera")
	var survivors: Array[Survivor] = colony.survivors.all()
	for survivor: Survivor in survivors:
		colony.set_job(survivor.uid, Survivor.Job.BUILDER)
	colony.set_job(survivors[0].uid, Survivor.Job.IDLE)
	colony.set_job(survivors[1].uid, Survivor.Job.IDLE)
	hud.call("_refresh_ammo_warning")
	var button: Button = hud.get("idle_button")
	assert_true(button.visible)
	assert_eq(button.text, "Idle: 2")
	button.pressed.emit()
	assert_eq(selection.selected_uid, survivors[0].uid)
	assert_eq(camera.position, survivors[0].pos)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_I
	key.pressed = true
	hud.call("_unhandled_input", key)
	assert_eq(selection.selected_uid, survivors[1].uid)
	assert_eq(camera.position, survivors[1].pos)
	button.pressed.emit()
	assert_eq(selection.selected_uid, survivors[0].uid)
	colony.set_job(survivors[0].uid, Survivor.Job.BUILDER)
	hud.call("_refresh_ammo_warning")
	assert_eq(button.text, "Idle: 1")
	colony.clock.phase = GameClock.Phase.NIGHT
	hud.call("_refresh_ammo_warning")
	assert_false(button.visible)
	fixture.after_each()

func _loss_screen() -> GameOverScreen:
	var screen: GameOverScreen = load("res://scenes/ui/game_over.tscn").instantiate()
	owned.append(screen)
	screen.records_path = records_path
	screen.bind(state)
	return screen

func _destroy_cc() -> void:
	var cc: Building = state.buildings.all_of_type("command_center")[0]
	state.damage_building(cc, cc.hp)
	state.tick(0.0)

func test_real_game_over_submits_new_record_and_menu_reads_it() -> void:
	state.clock.day = 6
	var screen: GameOverScreen = _loss_screen()
	_destroy_cc()
	assert_true(state.game_over and screen.visible)
	assert_eq(Records.load_all(records_path)["normal"]["best_nights"], 5)
	assert_eq(Records.load_all(records_path)["normal"]["wins"], 0)
	assert_eq(screen.get_node("Dim/Center/Panel/Margin/Content/RecordLine").text, "New record: 5 nights (Normal)")
	var menu: MainMenu = load("res://scenes/ui/main_menu.tscn").instantiate()
	owned.append(menu)
	menu.records_path = records_path
	menu.call("_refresh_records")
	assert_eq(menu.get_node("Dim/Center/Panel/Margin/Content/BestRecords").text, "Best: Normal 5 nights")

func test_real_victory_keep_fighting_then_later_loss_counts_win_once() -> void:
	var loss: GameOverScreen = _loss_screen()
	var victory: VictoryScreen = load("res://scenes/ui/victory.tscn").instantiate()
	owned.append(victory)
	victory.records_path = records_path
	victory.bind(state)
	state.clock.day = 20
	state.time_played = 2470.0
	state.resources.add("wood", 1000)
	state.resources.add("scrap", 1000)
	VictorySetup.place_finished_tower(state)
	state.clock.phase = GameClock.Phase.NIGHT
	state.clock.elapsed = float(data.balance("night_min_length"))
	state.tick(0.1)
	assert_true(state.won and victory.visible)
	assert_eq(Records.load_all(records_path)["normal"]["wins"], 1)
	var fastest: int = Records.load_all(records_path)["normal"]["fastest_win_s"]
	victory.get_node("Dim/Center/Panel/Margin/Content/Buttons/KeepFighting").pressed.emit()
	assert_true(state.endless and not state.game_over and not victory.visible)
	state.clock.day = 24
	state.time_played += 300.0
	_destroy_cc()
	assert_true(loss.visible and state.game_over)
	var record: Dictionary = Records.load_all(records_path)["normal"]
	assert_eq(record["wins"], 1)
	assert_eq(record["best_nights"], 23)
	assert_eq(record["fastest_win_s"], fastest)
	state.game_lost.emit("command_center")
	assert_eq(Records.load_all(records_path)["normal"], record)
