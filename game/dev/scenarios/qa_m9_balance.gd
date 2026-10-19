extends RefCounted
## Observation only: bounded unchanged-data runs, including actual win continuation.

static func setup(main: Node) -> void:
	main.get_tree().root.get_node("DevTools").set("_target_frames", 100000)
	var out: String = ProjectSettings.globalize_path("res://../project/runs/T-190/a1")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			out = arg.trim_prefix("--capture-dir=")
	var results: Array[Dictionary] = []
	for config: Array in [[1337, "sensible", "normal"], [1, "scavenger", "normal"], [1, "sensible", "hard"], [7, "scavenger", "hard"]]:
		var lifecycle: Dictionary = {"win_day": 0, "loss_day": 0, "loss_reason": "", "wins": 0}
		var observer: Callable = func(state: GameState, memo: Dictionary) -> void:
			if memo.has("qa_m9_wired"):
				return
			memo["qa_m9_wired"] = true
			var reference: WeakRef = weakref(state)
			state.game_won.connect(func() -> void:
				var current: GameState = reference.get_ref()
				lifecycle["win_day"] = current.clock.day
				lifecycle["wins"] += 1
				current.endless = true
				current.game_over = false
				current.clock.locked = false
				current.clock.set_paused(false))
			state.game_lost.connect(func(reason: String) -> void:
				var current: GameState = reference.get_ref()
				lifecycle["loss_day"] = current.clock.day
				lifecycle["loss_reason"] = reason)
		var result: Dictionary = BalanceBot.run(int(config[0]), str(config[1]), 25, 0.25, observer, str(config[2]))
		result["difficulty"] = config[2]
		result["lifecycle"] = lifecycle
		var csv := FileAccess.open(out.path_join("balance_%s_%s_%d.csv" % [config[2], config[1], config[0]]), FileAccess.WRITE)
		csv.store_string(BalanceBot.to_csv(result["rows"]))
		csv.close()
		results.append(result)
		print("M9 BALANCE: %s %s seed%d completed=%d win_day=%d loss_day=%d capped=%s" % [config[2], config[1], config[0], result["nights_survived"], lifecycle["win_day"], lifecycle["loss_day"], result["capped"]])
		if result["capped"]:
			push_error("M9 balance tick cap reached")
	var file := FileAccess.open(out.path_join("qa_m9_balance.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "\t"))
	file.close()
	Game.request_quit()
