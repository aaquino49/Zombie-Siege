extends RefCounted

const Fixture: GDScript = preload("res://tests/night_sim_fixture.gd")
const View: GDScript = preload("res://dev/scenarios/qa_m3_night1_defense.gd")

static func setup(main: Node) -> void:
	var state: GameState = Game.state
	Fixture.idle(state)
	var cc: Building = state.buildings.all_of_type("command_center")[0]
	cc.hp = 1
	Fixture.nightfall(state, 5)
	Fixture.run_night(state)
	assert(state.game_over and state.lose_reason == "command_center", "Scheduled zombies must cause real CC defeat")
	assert(state.clock.locked and state.clock.paused, "Game Over view must lock the clock")
	View.show(main, cc.center_world())
	print("T-022 real Game Over: ", JSON.stringify(state.stats()))
