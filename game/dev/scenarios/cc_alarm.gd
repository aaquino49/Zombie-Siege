extends RefCounted
## Night siege on the Command Center: zombies damage the CC, which raises the
## red edge vignette. AlarmKeeper lands a small real CC hit whenever the flash
## fades so the capture frame shows red edges with an untouched centre.

class AlarmKeeper extends Node:
	var _alarm: CCAlarm
	var _state: GameState

	func _init(alarm: CCAlarm, state: GameState) -> void:
		_alarm = alarm
		_state = state

	func _process(_delta: float) -> void:
		if _state == null or _state.game_over:
			return
		if _alarm.intensity() < 0.5:
			var cc: Building = _state.buildings.all_of_type("command_center")[0]
			_state.damage_building(cc, 5)

static func setup(main: Node) -> void:
	var state: GameState = Game.state
	state.waves.enabled = false
	state.clock.elapsed = state.data.balance("day_length", 30.0) - 0.05

	var origin: Vector2i = state.map.command_center_origin()

	# Clear ground around the CC so the attackers walk straight to it.
	for y: int in range(origin.y - 6, origin.y + 8):
		for x: int in range(origin.x - 6, origin.x + 8):
			var tile := Vector2i(x, y)
			if state.map.occupant_at(tile) != WorldMap.Occupant.BUILDING:
				state.map._occupants[tile] = WorldMap.Occupant.NONE
				state.map._node_amounts.erase(tile)
	state.map.changed.emit()
	main.get_node("World")._draw_props()
	main.get_node("World")._draw_ground_detail()

	# Let the phase banner finish before composing the attack.
	while state.clock.phase != GameClock.Phase.NIGHT:
		state.tick(0.1)
	state.tick(PhaseBanner.BANNER_SECONDS + 0.1 - state.clock.elapsed)

	for i: int in range(8):
		var tile := Vector2i(origin.x + 2 + (i % 4), origin.y - 1 + (i / 4))
		state.spawn_zombie("walker", Grid.tile_to_world(tile))

	# Tick until the CC is genuinely under attack.
	for i: int in range(1500):
		state.tick(0.1)
		var cc: Building = state.buildings.all_of_type("command_center")[0]
		if cc.hp < cc.max_hp:
			break

	var camera: Camera2D = main.get_node("World/Camera2D")
	camera.position = Grid.tile_to_world(origin + Vector2i(1, 0)) + Vector2(0, Grid.TILE / 2.0)
	camera.zoom = Vector2.ONE
	state.clock.set_paused(true)

	var alarm: CCAlarm = main.get_node("CCAlarm") as CCAlarm
	var cc_final: Building = state.buildings.all_of_type("command_center")[0]
	state.damage_building(cc_final, 5)
	main.add_child(AlarmKeeper.new(alarm, state))
