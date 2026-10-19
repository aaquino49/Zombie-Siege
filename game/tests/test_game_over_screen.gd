extends TestCase

var screen: GameOverScreen
var state: GameState

func before_each() -> void:
	state = GameState.new(GameData.load_default(), 1337)
	screen = (load("res://scenes/ui/game_over.tscn") as PackedScene).instantiate() as GameOverScreen
	screen.bind(state)

func after_each() -> void:
	screen.free()

func test_stat_order_and_time_format() -> void:
	assert_eq(GameOverScreen.stat_rows({"nights_survived": 5, "zombies_killed": 127,
		"survivors_lost": 3, "buildings_built": 6, "time_played": 125.4}),
		[["Nights survived", "5"], ["Zombies killed", "127"], ["Survivors lost", "3"],
		["Buildings built", "6"], ["Time played", "2:05"]])
	assert_eq(GameOverScreen.stat_rows({})[4][1], "0:00")
	assert_eq(GameOverScreen.stat_rows({"time_played": 3600.9})[4][1], "60:00")

func test_loss_shows_panel_and_locks_clock() -> void:
	assert_false(screen.visible)
	var cc: Building = state.buildings.all_of_type("command_center")[0]
	state.damage_building(cc, cc.hp)
	state.tick(0.1)
	assert_true(screen.visible)
	assert_true(state.clock.paused)
	assert_true(state.clock.locked)
	assert_eq(screen.get_node("Dim").mouse_filter, Control.MOUSE_FILTER_STOP)
	var content: Node = screen.get_node("Dim/Center/Panel/Margin/Content")
	assert_eq(content.get_node("Reason").text, "The Command Center was destroyed.")
	assert_eq(content.get_node("Difficulty").text, "Difficulty: Normal")
	assert_eq(content.get_node("Stats").get_child_count(), 10)
	assert_eq(content.get_node("Buttons/Restart").text, "Restart")
	assert_eq(content.get_node("Buttons/MainMenu").text, "Main Menu")
	state.clock.set_speed(3)
	state.tick(1.0)
	assert_almost_eq(state.time_played, 0.1)

func test_survivor_reason_and_fresh_state() -> void:
	for s: Survivor in state.survivors.all():
		state.damage_survivor(s, s.hp)
	state.tick(0.0)
	assert_eq(screen.get_node("Dim/Center/Panel/Margin/Content/Reason").text, "No survivors remain.")
	var fresh := GameState.new(GameData.load_default(), 1337)
	assert_false(fresh.game_over)
	assert_false(fresh.clock.locked)
	assert_false(fresh.clock.paused)
	assert_eq(fresh.stats()["time_played"], 0.0)

func test_dawn_loss_freezes_remaining_tick_time() -> void:
	state.waves.enabled = false
	state.resources.take("food", state.resources.get_amount("food"))
	for s: Survivor in state.survivors.all():
		state.set_job(s.uid, Survivor.Job.IDLE)
		s.hungry_days = int(state.data.balance("food_hungry_leave_days")) - 1
	state.clock.phase = GameClock.Phase.NIGHT
	state.clock.elapsed = float(state.data.balance("night_min_length")) - 1.0
	state.tick(10.0)
	assert_true(state.game_over)
	assert_true(state.clock.locked)
	assert_almost_eq(state.time_played, 1.0)
	assert_almost_eq(state.clock.elapsed, 0.0)

func test_bind_after_win_stays_hidden() -> void:
	var s := GameState.new(GameData.load_default(), 1337)
	s.won = true
	s.game_over = true
	s.lose_reason = ""
	var screen2: GameOverScreen = (load("res://scenes/ui/game_over.tscn") as PackedScene).instantiate() as GameOverScreen
	screen2.bind(s)
	assert_false(screen2.visible)
	assert_false(s.clock.paused)
	assert_false(s.clock.locked)
	screen2.free()

func test_bind_after_loss_shows_immediately() -> void:
	var s := GameState.new(GameData.load_default(), 1337)
	s.game_over = true
	s.won = false
	s.lose_reason = "command_center"
	var screen2: GameOverScreen = (load("res://scenes/ui/game_over.tscn") as PackedScene).instantiate() as GameOverScreen
	screen2.bind(s)
	assert_true(screen2.visible)
	var content: Node = screen2.get_node("Dim/Center/Panel/Margin/Content")
	assert_eq(content.get_node("Reason").text, "The Command Center was destroyed.")
	assert_true(s.clock.paused)
	assert_true(s.clock.locked)
	screen2.free()

func test_loss_signal_after_win_stays_hidden() -> void:
	state.won = true
	state.game_over = true
	state.game_lost.emit("command_center")
	assert_false(screen.visible)
	assert_false(state.clock.paused)
	assert_false(state.clock.locked)
