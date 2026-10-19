extends RefCounted

static func setup(main: Node) -> void:
	var state: GameState = Game.state
	state.clock.day = 4
	state.clock.phase = GameClock.Phase.NIGHT
	state.clock.phase_changed.emit(GameClock.Phase.NIGHT, 4)
	for person: Survivor in state.survivors.all():
		state.damage_survivor(person, person.hp)
	state.tick(0.25)
	var support: GDScript = preload("res://dev/scenarios/qa_m4_support.gd")
	support.check(state.game_over and state.lose_reason == "survivors", "Real survivor damage produces survivor loss")
	support.check(main.get_node("GameOverScreen").visible, "Actual loss signal shows Game Over")
	support.check(state.clock.paused and state.clock.locked, "Game Over freezes clock")
