extends RefCounted

static func setup(main: Node) -> void:
	var state: GameState = Game.state
	state.clock.elapsed = float(state.data.balance("day_length")) - 0.25
	state.tick(0.25)
	state.tick(0.25)
	var event := InputEventKey.new()
	event.physical_keycode = KEY_ESCAPE
	event.keycode = KEY_ESCAPE
	event.pressed = true
	main.get_viewport().push_input(event)
	preload("res://dev/scenarios/qa_m4_support.gd").check(main.get_node("PauseMenu").visible
		and state.clock.paused and state.clock.locked, "Esc opens and locks pause menu during night")
