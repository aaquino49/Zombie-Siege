class_name TestVictory extends TestCase

var data: GameData
var state: GameState
var _won_count: int = 0
var _lost_count: int = 0

func before_each() -> void:
	data = GameData.load_default()
	state = GameState.new(data, 1337)
	state.waves.enabled = false
	_won_count = 0
	_lost_count = 0
	state.game_won.connect(func(): _won_count += 1)
	state.game_lost.connect(func(_r: String): _lost_count += 1)

func after_each() -> void:
	data = null
	state = null

func get_clear_pos() -> Vector2i:
	var origin := state.map.command_center_origin()
	var tower_pos := origin + Vector2i(-4, 0)
	for y: int in range(tower_pos.y - 1, tower_pos.y + 3):
		for x: int in range(tower_pos.x - 1, tower_pos.x + 3):
			var tile := Vector2i(x, y)
			if state.map.occupant_at(tile) in [1, 2, 3]:
				state.map.vacate(tile, Vector2i.ONE)
	return tower_pos

func advance_to_dawn(day: int) -> void:
	state.clock.day = day - 1
	state.clock.phase = GameClock.Phase.NIGHT
	state.clock.elapsed = float(data.balance("night_min_length", 45)) - 0.1
	state.tick(0.2)

func test_victory_at_night_20() -> void:
	var p := get_clear_pos()
	state.resources.add("wood", 1000)
	state.resources.add("scrap", 1000)
	state.clock.day = 8
	var r := state.try_place("radio_tower", p)
	assert_eq(r, Placement.Result.OK, "Should place tower")
	var b := state.buildings.get_at(p)
	state.buildings.finish(b.uid)
	
	advance_to_dawn(21)
	
	assert_true(state.won, "Should win")
	assert_true(state.game_over, "Game should be over")
	assert_eq(_won_count, 1, "Emitted game_won once")
	assert_eq(_lost_count, 0, "No game_lost")
	var stats: Dictionary = state.stats()
	assert_eq(int(stats.get("nights_survived", 0)), 20, "Should have 20 nights survived")
	assert_eq(state.lose_reason, "", "Victory must not set a loss reason")
	advance_to_dawn(22)
	assert_eq(_won_count, 1, "Later dawn must not emit game_won again")
	assert_eq(_lost_count, 0, "Later lose checks must not turn victory into loss")

func test_no_tower_night_20() -> void:
	advance_to_dawn(21)
	assert_false(state.won, "Should not win without tower")
	assert_eq(state.clock.day, 21, "Day should advance to 21")
	assert_eq(state.clock.phase, GameClock.Phase.DAY, "Phase should be DAY")
	
	var w19: Dictionary = data.wave_for_night(19)
	var w21: Dictionary = data.wave_for_night(21)
	assert_false(bool(w21.get("final", true)), "Night 21 is not the final horde")
	assert_gt(int(w21.get("walker", 0)), int(w19.get("walker", 0)), "Wave 21 should have more walkers")

func test_tower_day_22() -> void:
	advance_to_dawn(21)
	assert_false(state.won, "No win yet")
	
	advance_to_dawn(22)
	assert_false(state.won, "Still no win")
	
	var p := get_clear_pos()
	state.resources.add("wood", 1000)
	state.resources.add("scrap", 1000)
	assert_eq(state.clock.day, 22, "Tower is placed during actual day 22")
	assert_eq(state.try_place("radio_tower", p), Placement.Result.OK, "Should place late tower")
	state.buildings.finish(state.buildings.get_at(p).uid)
	state.tick(0.1)
	assert_false(state.won, "Completing the tower during day must wait for dawn")
	
	advance_to_dawn(23)
	assert_true(state.won, "Win at dawn 23")

func test_night_19() -> void:
	var p := get_clear_pos()
	state.resources.add("wood", 1000)
	state.resources.add("scrap", 1000)
	state.clock.day = 8
	assert_eq(state.try_place("radio_tower", p), Placement.Result.OK, "Should place tower")
	state.buildings.finish(state.buildings.get_at(p).uid)
	
	advance_to_dawn(20)
	assert_false(state.won, "Not won at 19 nights")

func test_tower_blueprint() -> void:
	var p := get_clear_pos()
	state.resources.add("wood", 1000)
	state.resources.add("scrap", 1000)
	state.clock.day = 8
	assert_eq(state.try_place("radio_tower", p), Placement.Result.OK, "Should place blueprint")
	
	advance_to_dawn(21)
	assert_false(state.won, "Blueprint doesn't win")

func test_tower_destroyed() -> void:
	var p := get_clear_pos()
	state.resources.add("wood", 1000)
	state.resources.add("scrap", 1000)
	state.clock.day = 8
	assert_eq(state.try_place("radio_tower", p), Placement.Result.OK, "Should place tower before destruction")
	var b := state.buildings.get_at(p)
	state.buildings.finish(b.uid)
	
	state.damage_building(b, 10000)
	
	advance_to_dawn(21)
	assert_false(state.won, "Destroyed tower doesn't win")

func test_loss_beats_victory() -> void:
	var p := get_clear_pos()
	state.resources.add("wood", 1000)
	state.resources.add("scrap", 1000)
	state.clock.day = 8
	assert_eq(state.try_place("radio_tower", p), Placement.Result.OK, "Should place tower before same-dawn loss")
	var b := state.buildings.get_at(p)
	state.buildings.finish(b.uid)
	
	for s: Survivor in state.survivors.all().duplicate():
		state.damage_survivor(s, 1000)
		
	advance_to_dawn(21)
	assert_false(state.won, "Should not win")
	assert_eq(_lost_count, 1, "Should emit game_lost")
	assert_eq(_won_count, 0, "Should not emit game_won")

func test_tower_unlock_day() -> void:
	var p := get_clear_pos()
	state.resources.add("wood", 1000)
	state.resources.add("scrap", 1000)
	state.clock.day = 7
	var r := state.try_place("radio_tower", p)
	assert_eq(r, Placement.Result.LOCKED, "Locked on day 7")
	
	state.clock.day = 8
	r = state.try_place("radio_tower", p)
	assert_eq(r, Placement.Result.OK, "OK on day 8")

func test_victory_screen() -> void:
	var v := load("res://scenes/ui/victory.tscn").instantiate() as CanvasLayer
	
	state.won = true
	state.game_over = true
	state.difficulty = "hard"
	state.time_played = 65.0
	state.clock.day = 21
	v.call("bind", state)
	
	var content: Node = v.get_node("Dim/Center/Panel/Margin/Content")
	assert_eq(content.get_node("Title").text, "RESCUED!", "Title should be RESCUED!")
	assert_eq(content.get_node("Reason").text, "The helicopter got you out after 20 nights.", "Subtitle formatted")
	assert_eq(content.get_node("Difficulty").text, "Difficulty: Hard")
	
	var rows: GridContainer = content.get_node("Stats")
	var children := rows.get_children()
	assert_eq(children.size(), 10, "5 pairs of stat cells")
	
	assert_eq(children[1].text, "20", "Nights stat")
	assert_eq(children[9].text, "1:05", "Time played stat")
	
	v.free()

func test_configured_threshold_before_final_horde() -> void:
	data._balance["nights_to_win"] = 10
	var p := get_clear_pos()
	state.resources.add("wood", 1000)
	state.resources.add("scrap", 1000)
	state.clock.day = 8
	assert_eq(state.try_place("radio_tower", p), Placement.Result.OK, "Should place tower")
	state.buildings.finish(state.buildings.get_at(p).uid)
	advance_to_dawn(10)
	assert_false(state.won, "Nine nights is below the configured threshold")
	advance_to_dawn(11)
	assert_true(state.won, "Configured ten nights wins before the final horde")
	assert_eq(_won_count, 1, "Configured threshold emits victory once")

func test_configured_threshold_after_final_horde() -> void:
	data._balance["nights_to_win"] = 22
	var p := get_clear_pos()
	state.resources.add("wood", 1000)
	state.resources.add("scrap", 1000)
	state.clock.day = 8
	assert_eq(state.try_place("radio_tower", p), Placement.Result.OK, "Should place tower")
	state.buildings.finish(state.buildings.get_at(p).uid)
	advance_to_dawn(21)
	assert_false(state.won, "Default final horde cannot override a higher win threshold")
	advance_to_dawn(23)
	assert_true(state.won, "Configured twenty-two nights wins at dawn 23")

func test_dawn_listeners_see_final_victory_state() -> void:
	var p := get_clear_pos()
	state.resources.add("wood", 1000)
	state.resources.add("scrap", 1000)
	state.clock.day = 8
	assert_eq(state.try_place("radio_tower", p), Placement.Result.OK, "Should place tower")
	state.buildings.finish(state.buildings.get_at(p).uid)
	var seen: Array[Dictionary] = []
	state.dawn_processed.connect(func(report: Dictionary) -> void:
		seen.append({"won": state.won, "over": state.game_over,
			"won_count": _won_count, "report_saved": state.last_dawn_report == report,
			"food_eaten": report.get("food_eaten", 0)}))
	advance_to_dawn(21)
	assert_eq(seen.size(), 1, "One dawn report")
	assert_true(bool(seen[0]["won"]), "Dawn listener sees won")
	assert_true(bool(seen[0]["over"]), "Dawn listener sees game_over")
	assert_eq(int(seen[0]["won_count"]), 1, "Victory signal precedes dawn report")
	assert_true(bool(seen[0]["report_saved"]), "Report is saved before notification")
	assert_gt(int(seen[0]["food_eaten"]), 0, "DawnRules processed food before notification")

func test_dawn_departures_lose_before_victory() -> void:
	var p := get_clear_pos()
	state.resources.add("wood", 1000)
	state.resources.add("scrap", 1000)
	state.clock.day = 8
	assert_eq(state.try_place("radio_tower", p), Placement.Result.OK, "Should place tower")
	state.buildings.finish(state.buildings.get_at(p).uid)
	state.resources.take("food", state.resources.get_amount("food"))
	var population: int = state.survivors.count()
	for s: Survivor in state.survivors.all():
		s.hungry_days = int(data.balance("food_hungry_leave_days")) - 1
	var seen: Array[Dictionary] = []
	state.dawn_processed.connect(func(report: Dictionary) -> void:
		seen.append({"won": state.won, "over": state.game_over,
			"lost_count": _lost_count, "left": (report["left"] as Array).size()}))
	advance_to_dawn(21)
	assert_false(state.won, "Losing all survivors in DawnRules must prevent victory")
	assert_eq(_won_count, 0, "No victory signal")
	assert_eq(_lost_count, 1, "One loss signal")
	assert_eq(seen.size(), 1, "Dawn report still fires after loss")
	assert_false(bool(seen[0]["won"]), "Listener sees no win")
	assert_true(bool(seen[0]["over"]), "Listener sees finalized loss")
	assert_eq(int(seen[0]["lost_count"]), 1, "Loss signal precedes dawn report")
	assert_eq(int(seen[0]["left"]), population, "DawnRules ran before loss check")

func test_victory_screen_live_signal_pauses_and_locks() -> void:
	var v := load("res://scenes/ui/victory.tscn").instantiate() as CanvasLayer
	v.call("bind", state)
	assert_false(v.visible, "Victory screen is initially hidden")
	var p := get_clear_pos()
	state.resources.add("wood", 1000)
	state.resources.add("scrap", 1000)
	state.clock.day = 8
	assert_eq(state.try_place("radio_tower", p), Placement.Result.OK, "Should place tower")
	state.buildings.finish(state.buildings.get_at(p).uid)
	advance_to_dawn(21)
	assert_true(v.visible, "Real victory signal reveals screen")
	assert_true(state.clock.paused, "Victory pauses clock")
	assert_true(state.clock.locked, "Victory locks clock")
	state.clock.set_paused(false)
	state.clock.set_speed(3)
	assert_true(state.clock.paused, "Speed/pause controls cannot resume after victory")
	var content: Node = v.get_node("Dim/Center/Panel/Margin/Content")
	var rows: GridContainer = content.get_node("Stats")
	var expected: Array[Array] = GameOverScreen.stat_rows(state.stats())
	assert_eq(rows.get_child_count(), 10, "Five reused stat pairs")
	for i: int in range(expected.size()):
		assert_eq(rows.get_child(i * 2).text, expected[i][0], "Stat label")
		assert_eq(rows.get_child(i * 2 + 1).text, expected[i][1], "Stat value")
	assert_eq(v.layer, 20, "Victory uses overlay layer 20")
	var restart: Button = content.get_node("Buttons/Restart")
	var quit_button: Button = content.get_node("Buttons/MainMenu")
	assert_true(restart.pressed.is_connected(Callable(v, "_restart")), "Restart is wired")
	assert_true(quit_button.pressed.is_connected(Callable(v, "_main_menu")), "Quit is wired")
	v.free()
