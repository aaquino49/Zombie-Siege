extends RefCounted
## T-067 screenshot evidence for the fully unlocked, rebuilt build bar.

static func setup(main: Node) -> void:
	Game.state.waves.enabled = false
	preload("res://dev/scenarios/qa_m2_colony_day3.gd").setup(main)
	Game.state.clock.day = 8
	Game.state.clock.dawn.emit(8)
