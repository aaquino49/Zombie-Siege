extends RefCounted
## Morale mood UI: four survivors staged into the four bands (Inspired,
## Steady, Low, Breaking) with visible mood reasons. The roster shows the
## mood icon + number column; the selected Low survivor shows the morale
## line and its top two reasons. Day 5, paused, no zombies.

static func setup(main: Node) -> void:
	var state: GameState = Game.state
	state.waves.enabled = false
	state.clock.day = 5
	state.clock.phase = GameClock.Phase.DAY
	state.clock.elapsed = 5.0
	state.clock.set_paused(true)

	var survivors: Array[Survivor] = state.survivors.all()
	for s: Survivor in survivors:
		s.moods.clear()
		s.refusing = false
		s.day_off = false
		s.breaking_days = 0
	# Inspired: 50 + 10 + 12 + 6 + 4 = 82.
	Morale.add_mood(state, survivors[0], "feast")
	Morale.add_mood(state, survivors[0], "day_off")
	Morale.add_mood(state, survivors[0], "campfire")
	Morale.add_mood(state, survivors[0], "quiet_night")
	# Steady: 50 + 5 + 2 + 4 = 61.
	Morale.add_mood(state, survivors[1], "bed")
	Morale.add_mood(state, survivors[1], "sheltered")
	Morale.add_mood(state, survivors[1], "quiet_night")
	# Low: 50 - 15 - 6 = 29, selected for its reasons.
	Morale.add_mood(state, survivors[2], "hungry")
	Morale.add_mood(state, survivors[2], "rough_night")
	# Breaking: 50 - 12 - 12 - 15 = 11.
	Morale.add_mood(state, survivors[3], "death", "Mara")
	Morale.add_mood(state, survivors[3], "death", "Theo")
	Morale.add_mood(state, survivors[3], "hungry")

	var selection: SelectionController = main.get_node("World/Selection")
	selection.select_survivor(survivors[2].uid)

	var roster: RosterPanel = main.get_node("RosterPanel")
	if not roster.is_open():
		roster.toggle()
	roster.refresh()

	var origin: Vector2i = state.map.command_center_origin()
	var camera: Camera2D = main.get_node("World/Camera2D")
	camera.position = Grid.tile_to_world(origin) + Vector2(Grid.TILE / 2.0, Grid.TILE / 2.0)
	camera.zoom = Vector2.ONE
	camera.set_process(false)
