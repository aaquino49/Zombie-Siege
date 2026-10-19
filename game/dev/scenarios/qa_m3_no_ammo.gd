extends RefCounted

const Fixture: GDScript = preload("res://tests/night_sim_fixture.gd")
const View: GDScript = preload("res://dev/scenarios/qa_m3_night1_defense.gd")

static func setup(main: Node) -> void:
	var state: GameState = Game.state
	assert(bool(Fixture.defended(state)["ok"]))
	state.resources.take("ammo", state.resources.get_amount("ammo"))
	var shots: Array[int] = [0]
	var on_shot: Callable = func(_from: Vector2, _to: Vector2, _turret: bool) -> void: shots[0] += 1
	state.shot_fired.connect(on_shot)
	Fixture.nightfall(state, 1)
	var wall_hit: bool = false
	for i: int in range(3000):
		state.tick(0.1)
		for b: Building in state.buildings.all():
			if b.type_id in ["wooden_wall", "gate"] and b.hp < b.max_hp:
				wall_hit = true
		if wall_hit:
			break
	state.shot_fired.disconnect(on_shot)
	assert(wall_hit and shots[0] == 0 and state.zombies_killed == 0, "Empty ammo must silence guards and turrets")
	View.show(main, state.buildings.all_of_type("command_center")[0].center_world())
	print("T-022 no ammo: shots=", shots[0], " kills=", state.zombies_killed, " zombies=", state.zombies.count())
