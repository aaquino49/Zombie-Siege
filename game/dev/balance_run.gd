extends SceneTree
## godot --headless --path game --script res://dev/balance_run.gd -- --strategy=both

func _initialize() -> void:
	var seeds: PackedStringArray = ["1337"]
	var nights: int = 20
	var repeat_count: int = 1
	var strategy: String = "both"
	var difficulty: String = "normal"
	var out: String = ProjectSettings.globalize_path("res://").path_join("../project/runs/balance")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			seeds = arg.trim_prefix("--seeds=").split(",", false)
		elif arg.begins_with("--nights="):
			var value: String = arg.trim_prefix("--nights=")
			if not value.is_valid_int() or int(value) < 0:
				_fail("--nights requires a nonnegative integer")
				return
			nights = int(value)
		elif arg.begins_with("--repeat="):
			var value: String = arg.trim_prefix("--repeat=")
			if not value.is_valid_int() or int(value) < 1:
				_fail("--repeat requires a positive integer")
				return
			repeat_count = int(value)
		elif arg.begins_with("--strategy="):
			strategy = arg.trim_prefix("--strategy=")
		elif arg.begins_with("--difficulty="):
			difficulty = arg.trim_prefix("--difficulty=")
		elif arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	if strategy not in ["sensible", "none", "scavenger", "both", "all"] or seeds.is_empty() or difficulty not in ["easy", "normal", "hard"]:
		_fail("Expected sensible, none, scavenger, both, or all; easy, normal, or hard; and at least one seed")
		return
	for seed_text: String in seeds:
		if not seed_text.is_valid_int():
			_fail("Invalid seed: " + seed_text)
			return
	if DirAccess.make_dir_recursive_absolute(out) != OK:
		_fail("Cannot create output directory: " + out)
		return
	var strategies: Array[String] = []
	if strategy == "both":
		strategies.assign(["sensible", "none"])
	elif strategy == "all":
		strategies.assign(["none", "sensible", "scavenger"])
	else:
		strategies.append(strategy)
	var summary: PackedStringArray = ["seed,strategy,outcome,nights_survived,cc_hp_pct,ms,min_cc"]
	var results: Dictionary = {}
	for selected: String in strategies:
		results[selected] = []
	for seed_text: String in seeds:
		for selected: String in strategies:
			var seed_results: Array[Dictionary] = []
			for repeat_index: int in range(repeat_count):
				var result: Dictionary
				if repeat_count == 1:
					# Preserve the pre-repeat harness call path byte-for-byte for K=1.
					result = BalanceBot.run(int(seed_text), selected, nights, 0.25, Callable(), difficulty)
				elif selected == "none":
					# No bot cadence exists for this strategy; keep its repeats identical.
					result = BalanceBot.run(int(seed_text), selected, nights, 0.25, Callable(), difficulty)
				else:
					result = _run_jittered(int(seed_text), selected, nights, repeat_index, difficulty)
				seed_results.append(result)
				results[selected].append(result)
				var csv_name: String = "%s_%d.csv" % [selected, int(seed_text)]
				if repeat_count > 1:
					csv_name = "%s_%d_r%d.csv" % [selected, int(seed_text), repeat_index + 1]
				if not _write(out.path_join(csv_name), BalanceBot.to_csv(result["rows"])):
					return
				print("BALANCE seed=%d strategy=%s outcome=%s nights=%d cc=%.1f%% ms=%d" % [result["seed"], selected, result["outcome"], result["nights_survived"], result["cc_hp_pct"], result["ms"]])
				if repeat_count == 1 and selected == "sensible" and int(result["seed"]) == 1337:
					print("BALANCE_TIME seed=1337 sim_seconds=%.2f" % float(result["sim_seconds"]))
				summary.append("%d,%s,%s,%d,%s,%d,%s" % [result["seed"], selected, result["outcome"], result["nights_survived"], str(result["cc_hp_pct"]), result["ms"], str(result["min_cc_hp_pct"])])
				if result["capped"]:
					_fail("Simulation tick cap reached")
					return
			if repeat_count > 1:
				_print_seed_rate(difficulty, int(seed_text), selected, seed_results, repeat_count)
	if _write(out.path_join("summary.csv"), "\n".join(summary) + "\n"):
		for selected: String in strategies:
			_print_summary(difficulty, selected, results[selected], repeat_count)
		quit()

static func _jitter_rng(map_seed: int, repeat_index: int) -> RandomNumberGenerator:
	var jitter_rng := RandomNumberGenerator.new()
	jitter_rng.seed = hash([map_seed, repeat_index, "jitter"])
	return jitter_rng

static func _next_decision_delay(jitter_rng: RandomNumberGenerator) -> float:
	return 5.0 + jitter_rng.randf_range(-2.0, 2.0)

static func _run_jittered(map_seed: int, strategy: String, nights: int,
		repeat_index: int, difficulty: String) -> Dictionary:
	if strategy == "none":
		return BalanceBot.run(map_seed, strategy, nights, 0.25, Callable(), difficulty)
	# This is the harness variant of BalanceBot.run: simulation ticks stay fixed;
	# only the cadence at which the harness invokes the bot is jittered.
	var step: float = 0.25
	var started: int = Time.get_ticks_msec()
	var state := GameState.new(GameData.load_default(), map_seed, difficulty)
	state.waves.enabled = true
	var rows: Array[Dictionary] = []
	var memo: Dictionary = {}
	var scavenging: Dictionary = {"runs": 0, "sent": 0, "sent_by_day": {}, "hurt": 0, "lost": 0,
		"loot": {"wood": 0, "scrap": 0, "food": 0, "ammo": 0}}
	var night: Dictionary = {"dusk_ammo": 0, "dusk_wood": 0, "dusk_scrap": 0,
		"guards": 0, "turrets": 0, "cc_min_hp_pct": _cc_pct(state), "day_researchers": 0}
	var min_cc_hp_pct: float = _cc_pct(state)
	var state_ref: WeakRef = weakref(state)
	state.dawn_processed.connect(func(report: Dictionary) -> void:
		var current: GameState = state_ref.get_ref() as GameState
		night["cc_min_hp_pct"] = minf(float(night["cc_min_hp_pct"]), _cc_pct(current))
		rows.append(BalanceBot._row(current, strategy, report, night, "dawn"))
		night["day_researchers"] = 0
		for run: Dictionary in report.get("scavenging", []):
			scavenging["runs"] = int(scavenging["runs"]) + 1
			if bool(run.get("hurt", false)):
				scavenging["hurt"] = int(scavenging["hurt"]) + 1
			if bool(run.get("lost", false)):
				scavenging["lost"] = int(scavenging["lost"]) + 1
			var loot: Dictionary = run.get("loot", {})
			for kind: String in scavenging["loot"]:
				(scavenging["loot"] as Dictionary)[kind] = int((scavenging["loot"] as Dictionary)[kind]) + int(loot.get(kind, 0))
	)
	var cap: int = ceili((nights + 1) * (float(state.data.balance("day_length")) + 400.0) / step)
	var jitter_rng: RandomNumberGenerator = _jitter_rng(map_seed, repeat_index)
	var next_decision_at: float = 0.0
	var decisions: int = 0
	for tick_index: int in range(cap):
		if state.game_over or state.clock.day > nights:
			break
		if state.clock.phase == GameClock.Phase.DAY and state.time_played >= next_decision_at:
			if strategy in ["sensible", "scavenger"]:
				BalanceBot._decide(state, memo)
			if strategy == "scavenger" and BalanceBot._send_scavenger(state):
				scavenging["sent"] = int(scavenging["sent"]) + 1
				var sent_by_day: Dictionary = scavenging["sent_by_day"]
				sent_by_day[state.clock.day] = int(sent_by_day.get(state.clock.day, 0)) + 1
			decisions += 1
			next_decision_at = state.time_played + _next_decision_delay(jitter_rng)
		BalanceBot._sample_day_researchers(state, night)
		var before: float = state.time_played
		var phase_before: int = state.clock.phase
		state.tick(step)
		var cc_pct: float = _cc_pct(state)
		min_cc_hp_pct = minf(min_cc_hp_pct, cc_pct)
		if phase_before == GameClock.Phase.DAY and state.clock.phase == GameClock.Phase.NIGHT:
			for kind: String in ["ammo", "wood", "scrap"]:
				night["dusk_" + kind] = state.resources.get_amount(kind)
			night["guards"] = 0
			for person: Survivor in state.survivors.all():
				if person.job == Survivor.Job.GUARD and BalanceBotM12.useful(state, person):
					night["guards"] += 1
			night["turrets"] = BalanceBot._complete_count(state, "turret")
			night["cc_min_hp_pct"] = cc_pct
		elif phase_before == GameClock.Phase.NIGHT:
			night["cc_min_hp_pct"] = minf(float(night["cc_min_hp_pct"]), cc_pct)
		var elapsed: float = state.time_played - before
		assert(absf(elapsed - step) <= 1e-6)
	var outcome: String = "survived"
	if state.won:
		outcome = "won"
	elif state.game_over:
		outcome = "lost_cc" if state.lose_reason == "command_center" else "lost_survivors"
		var report: Dictionary = state.night_log.summary(state)
		report["night"] = state.clock.day
		rows.append(BalanceBot._row(state, strategy, report, night, "loss"))
	return {"seed": map_seed, "strategy": strategy, "outcome": outcome,
		"nights_survived": state.clock.day - 1, "cc_hp_pct": _cc_pct(state),
		"rows": rows, "ms": Time.get_ticks_msec() - started, "sim_seconds": state.time_played,
		"scavenging": scavenging, "min_cc_hp_pct": min_cc_hp_pct,
		"capped": not state.game_over and state.clock.day <= nights,
		"jitter_decisions": decisions}

static func _cc_pct(state: GameState) -> float:
	return BalanceBot._cc_pct(state)

func _print_seed_rate(selected_difficulty: String, seed: int, strategy: String,
		results: Array[Dictionary], repeat_count: int) -> void:
	var won: int = 0
	var survived: int = 0
	var lost: int = 0
	for result: Dictionary in results:
		match result["outcome"]:
			"won": won += 1
			"survived": survived += 1
			_: lost += 1
	print("BALANCE_SEED_RATE difficulty=%s seed=%d strategy=%s repeats=%d won=%.1f%% survived=%.1f%% lost=%.1f%%" % [selected_difficulty, seed, strategy, repeat_count, 100.0 * won / repeat_count, 100.0 * survived / repeat_count, 100.0 * lost / repeat_count])

func _print_summary(selected_difficulty: String, strategy: String, results: Array,
		repeat_count: int = 1) -> void:
	var won: int = 0
	var survived: int = 0
	var lost: int = 0
	var nights: Array[int] = []
	var min_cc: float = 100.0
	var scav_runs: int = 0
	var scav_hurt: int = 0
	var scav_lost: int = 0
	var loot: Dictionary = {"wood": 0, "scrap": 0, "food": 0, "ammo": 0}
	for result: Dictionary in results:
		match result["outcome"]:
			"won": won += 1
			"survived": survived += 1
			_: lost += 1
		nights.append(result["nights_survived"])
		min_cc = minf(min_cc, float(result["min_cc_hp_pct"]))
		var scavenging: Dictionary = result.get("scavenging", {})
		scav_runs += int(scavenging.get("sent", scavenging.get("runs", 0)))
		scav_hurt += int(scavenging.get("hurt", 0))
		scav_lost += int(scavenging.get("lost", 0))
		var totals: Dictionary = scavenging.get("loot", {})
		for kind: String in loot:
			loot[kind] = int(loot[kind]) + int(totals.get(kind, 0))
	nights.sort()
	var middle: int = nights.size() >> 1
	var median: float = float(nights[middle])
	if nights.size() % 2 == 0:
		median = (float(nights[middle - 1]) + float(nights[middle])) / 2.0
	var line: String = "BALANCE_SUMMARY strategy=%s runs=%d won=%d survived=%d lost=%d median_nights=%s min_cc=%.1f%%" % [strategy, results.size(), won, survived, lost, str(median), min_cc]
	if repeat_count > 1:
		line = "BALANCE_SUMMARY difficulty=%s strategy=%s runs=%d won=%d survived=%d lost=%d median_nights=%s min_cc=%.1f%%" % [selected_difficulty, strategy, results.size(), won, survived, lost, str(median), min_cc]
		line += " win_rate=%.1f%% survived_rate=%.1f%% lost_rate=%.1f%%" % [100.0 * won / results.size(), 100.0 * survived / results.size(), 100.0 * lost / results.size()]
	if strategy == "scavenger":
		var divisor: float = maxf(1.0, float(scav_runs))
		line += " scav_runs=%d scav_hurt=%d scav_lost=%d avg_loot_wood=%.2f avg_loot_scrap=%.2f avg_loot_food=%.2f avg_loot_ammo=%.2f" % [scav_runs, scav_hurt, scav_lost, float(loot["wood"]) / divisor, float(loot["scrap"]) / divisor, float(loot["food"]) / divisor, float(loot["ammo"]) / divisor]
	print(line)

func _write(path: String, contents: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("Cannot write: " + path)
		return false
	file.store_string(contents)
	file.close()
	return true

func _fail(message: String) -> void:
	printerr(message)
	quit(1)
