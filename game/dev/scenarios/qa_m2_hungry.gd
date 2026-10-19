extends RefCounted

static func setup(main: Node) -> void:
	Game.state.waves.enabled = false
	var fixture: GDScript = preload("res://dev/scenarios/qa_m2_colony_day3.gd")
	var state: GameState = Game.state
	state.resources.take("food", state.resources.get_amount("food"))
	fixture.advance_to(state, 2)
	state.tick(0.1)
	fixture.show(main)
	var selection: SelectionController = main.get_node("World/Selection")
	selection.select_at_world(state.survivors.all()[0].pos)
	(main.get_node("InfoPanel") as InfoPanel).refresh()
