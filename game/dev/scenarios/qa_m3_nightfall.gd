extends RefCounted

const Fixture: GDScript = preload("res://tests/night_sim_fixture.gd")
const View: GDScript = preload("res://dev/scenarios/qa_m3_night1_defense.gd")

static func setup(main: Node) -> void:
	var state: GameState = Game.state
	assert(bool(Fixture.defended(state)["ok"]))
	Fixture.nightfall(state, 1)
	assert(state.zombies.count() == 1 and state.waves.pending() == 6)
	View.show(main, state.buildings.all_of_type("command_center")[0].center_world())
	print("T-022 nightfall: live=", state.zombies.count(), " pending=", state.waves.pending(), " HUD total=", state.hostiles_remaining())
