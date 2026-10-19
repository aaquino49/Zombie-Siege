extends RefCounted

const SCENARIO_SAVE := "user://t146_main_menu_continue.json"

static func setup(main: Node) -> void:
	Game.save_path = SCENARIO_SAVE
	var state: GameState = Game.state
	state.clock.day = 4
	state.resources.add("wood", 75)
	Game.save_now({"hints": {"welcome": true}})
	main.get_node("MainMenu").open(state)
