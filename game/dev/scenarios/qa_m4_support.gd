extends RefCounted
## QA-only public-command bot driver. Yield between bounded batches for live views.

static func sensible_run(main: Node, nights: int) -> void:
	var state: GameState = main.get_tree().root.get_node("Game").state
	var tree: SceneTree = main.get_tree()
	var memo: Dictionary = {}
	var decide_acc: float = 5.0
	var cap: int = ceili((nights + 1) * (float(state.data.balance("day_length")) + 400.0) / 0.25)
	# Stop automatic real-time stepping; each batch unlocks only its manual ticks.
	state.clock.set_paused(true)
	for tick_index: int in range(cap):
		if state.game_over or state.clock.day > nights:
			print("QA M4 BOT: day=%d won=%s time=%.2f" % [state.clock.day, state.won, state.time_played])
			return
		state.clock.set_paused(false)
		if state.clock.phase == GameClock.Phase.DAY and decide_acc >= 5.0:
			decide_acc = fmod(decide_acc, 5.0)
			BalanceBot._decide(state, memo)
		var before: float = state.time_played
		var day_before: int = state.clock.day
		state.tick(0.25)
		decide_acc += state.time_played - before
		if not state.game_over:
			state.clock.set_paused(true)
		if state.clock.day != day_before or tick_index % 128 == 0:
			await tree.process_frame
			await tree.process_frame
			if main.get_node("DawnReport").visible:
				main.get_node("DawnReport/Center/Panel/Margin/Content/Buttons/Continue").pressed.emit()
	push_error("QA M4: sensible live run exceeded tick cap")

static func place(state: GameState, type_id: String) -> Building:
	for y: int in range(state.map.size()):
		for x: int in range(state.map.size()):
			var tile := Vector2i(x, y)
			if Placement.check(state, type_id, tile) == Placement.Result.OK:
				state.try_place(type_id, tile)
				var building: Building = state.buildings.get_at(tile)
				state.buildings.finish(building.uid)
				return building
	push_error("QA M4: no valid placement for " + type_id)
	return null

static func check(condition: bool, description: String) -> void:
	if condition:
		print("QA M4 PASS: " + description)
	else:
		push_error("QA M4 FAIL: " + description)
