extends RefCounted

static func setup(main: Node) -> void:
	Game.state.waves.enabled = false
	var fixture: GDScript = preload("res://dev/scenarios/qa_m2_colony_day3.gd")
	var buildings: Array[Building] = fixture.plan(Game.state)
	fixture.advance_to(Game.state, 2)
	# Dispatch dawn release once, with no time skipped or positions fabricated.
	Game.state.tick(0.1)
	fixture.show(main, buildings[1])
