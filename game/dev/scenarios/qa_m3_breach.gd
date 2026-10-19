extends RefCounted

const Fixture: GDScript = preload("res://tests/night_sim_fixture.gd")
const View: GDScript = preload("res://dev/scenarios/qa_m3_night1_defense.gd")

static func setup(main: Node) -> void:
	var state: GameState = Game.state
	assert(bool(Fixture.defended(state)["ok"]))
	Fixture.idle(state)
	state.resources.take("ammo", state.resources.get_amount("ammo"))
	Fixture.nightfall(state, 5)
	var damaged: Building = null
	for i: int in range(3000):
		state.tick(0.1)
		for b: Building in state.buildings.all():
			if b.type_id in ["wooden_wall", "gate"] and b.hp > 0 and b.hp <= b.max_hp / 2:
				damaged = b
		if damaged != null or state.game_over:
			break
	assert(damaged != null, "Scheduled wave must damage the enclosure")
	View.show(main, state.buildings.all_of_type("command_center")[0].center_world())
	(main.get_node("World/Camera2D") as Camera2D).zoom = Vector2.ONE
	print("T-022 breach: ", damaged.type_id, " HP=", damaged.hp, "/", damaged.max_hp, " zombies=", state.zombies.count())
