extends RefCounted

static func setup(main: Node) -> void:
	var state: GameState = Game.state
	state.waves.enabled = false
	state.clock.day = 16
	state.resources.add("wood", 300)
	var wall: Building = preload("res://dev/scenarios/qa_m4_support.gd").place(state, "wooden_wall")
	state.clock.phase = GameClock.Phase.NIGHT
	state.clock.phase_changed.emit(GameClock.Phase.NIGHT, 16)
	state.damage_building(wall, wall.hp)
	var person: Survivor = state.survivors.all()[0]
	state.damage_survivor(person, person.hp)
	var cc: Building = state.buildings.all_of_type("command_center")[0]
	state.damage_building(cc, 40)
	for i: int in range(5):
		var zombie: Zombie = state.spawn_zombie("walker", cc.center_world())
		state.damage_zombie(zombie, zombie.hp)
	state.clock.elapsed = float(state.data.balance("night_min_length")) - 0.25
	state.tick(0.25)
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	var support: GDScript = preload("res://dev/scenarios/qa_m4_support.gd")
	support.check(main.get_node("DawnReport").visible, "Night 16 dawn opens real report")
	support.check(state.last_dawn_report["zombies_killed"] == 5 and state.last_dawn_report["survivors_killed"].size() == 1
		and state.last_dawn_report["buildings_destroyed"].size() == 1, "Report records actual damage and kills")
