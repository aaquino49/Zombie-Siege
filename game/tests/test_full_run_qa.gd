extends TestCase
## Full public-command bot run shared by the acceptance assertions (~one 20-night run).

const STEP: float = 0.25
static var _sensible: Dictionary = {}

static func _snapshot(state: GameState) -> Dictionary:
	var buildings: Array[String] = []
	for b: Building in state.buildings.all():
		buildings.append("%s:%s:%s:%d" % [b.type_id, b.origin, b.complete, b.hp])
	buildings.sort()
	var resources: Dictionary = {}
	for kind: String in ["food", "wood", "scrap", "ammo"]:
		resources[kind] = state.resources.get_amount(kind)
	var people: Array[String] = []
	for s: Survivor in state.survivors.all():
		people.append("%d:%s:%d:%d" % [s.uid, s.name, s.hp, s.job])
	people.sort()
	return {"kills": state.zombies_killed, "survivors": people,
		"buildings": buildings, "resources": resources}

static func _run(strategy: String, nights: int) -> Dictionary:
	var state := GameState.new(GameData.load_default(), 1337)
	state.waves.enabled = true
	var result: Dictionary = {"wins": 0, "losses": [], "reports": [],
		"durations": [], "dawn5": {}, "capped": true}
	var state_ref: WeakRef = weakref(state)
	state.game_won.connect(func() -> void: result["wins"] += 1)
	state.game_lost.connect(func(reason: String) -> void: result["losses"].append(reason))
	state.dawn_processed.connect(func(report: Dictionary) -> void:
		var current: GameState = state_ref.get_ref() as GameState
		result["reports"].append({"report": report.duplicate(true),
			"log": current.night_log.summary(current).duplicate(true),
			"saved": current.last_dawn_report == report})
		if int(report["night"]) == 5:
			result["dawn5"] = _snapshot(current))
	var memo: Dictionary = {}
	var decide_acc: float = 5.0
	var night_seconds: float = 0.0
	var max_night: float = float(state.data.balance("night_max_length"))
	var cap: int = ceili((nights + 1) * (float(state.data.balance("day_length")) + 400.0) / STEP)
	for tick_index: int in range(cap):
		if state.game_over or state.clock.day > nights:
			result["capped"] = false
			break
		if state.clock.phase == GameClock.Phase.DAY and decide_acc >= 5.0:
			decide_acc = fmod(decide_acc, 5.0)
			if strategy == "sensible":
				BalanceBot._decide(state, memo)
		var before: float = state.time_played
		var phase_before: int = state.clock.phase
		state.tick(STEP)
		var elapsed: float = state.time_played - before
		decide_acc += elapsed
		if phase_before == GameClock.Phase.NIGHT:
			night_seconds += elapsed
			if state.clock.phase == GameClock.Phase.DAY:
				result["durations"].append(night_seconds)
				night_seconds = 0.0
		elif state.clock.phase == GameClock.Phase.NIGHT:
			night_seconds = state.clock.elapsed
	result.merge({"won": state.won, "reason": state.lose_reason, "day": state.clock.day,
		"tower": state.radio_tower_complete(), "night_cap": max_night, "time": state.time_played})
	# Rechecking terminal state must never duplicate either terminal signal.
	for i: int in range(3):
		state.tick(0.0)
	return result

static func _full() -> Dictionary:
	if _sensible.is_empty():
		_sensible = _run("sensible", 20)
	return _sensible

func test_sensible_bot_seed_1337_matches_forecast_aware_outcome() -> void:
	var run: Dictionary = _full()
	assert_false(run["capped"], "20-night sensible run exceeded bounded tick count")
	assert_false(run["won"], "T-219 v4 policy pin: survives 20 nights with Radio still unfinished; T-220 owns tuning")
	assert_eq(run["reason"], "")
	assert_eq(run["wins"], 0)
	assert_eq(run["losses"], [])
	assert_false(run["tower"], "T-219 v4 deterministic Radio completion pin")
	assert_eq(run["day"] - 1, 20)

func test_do_nothing_loses_early() -> void:
	var run: Dictionary = _run("none", 6)
	assert_false(run["capped"], "Do-nothing loss exceeded bounded tick count")
	assert_eq(run["reason"], "command_center")
	assert_true(run["day"] >= 3 and run["day"] <= 6, "Loss must occur on night 3-6")
	assert_eq(run["losses"], ["command_center"], "Exactly one real loss signal")
	assert_eq(run["wins"], 0)

func test_dawn_report_every_night() -> void:
	var run: Dictionary = _full()
	assert_eq(run["reports"].size(), 20, "Exactly one report for each survived night, including 20")
	for index: int in range(run["reports"].size()):
		var observation: Dictionary = run["reports"][index]
		var report: Dictionary = observation["report"]
		assert_eq(int(report["night"]), index + 1)
		assert_eq(int(report["day"]), index + 2)
		assert_true(observation["saved"], "Saved report must match the signal payload")
		for key: String in ["zombies_killed", "survivors_killed", "buildings_destroyed",
			"buildings_damaged", "cc_damage", "food_eaten", "hungry", "left", "arrived", "unlocked", "objective"]:
			assert_has(report, key, "Dawn Report renderer key")
		for key: String in observation["log"]:
			assert_eq(report[key], observation["log"][key], "NightLog value: " + key)

func test_night_never_exceeds_cap() -> void:
	var run: Dictionary = _full()
	assert_eq(run["durations"].size(), 20)
	for length: float in run["durations"]:
		assert_true(length <= float(run["night_cap"]) + STEP, "Night length %s exceeds cap" % length)

func test_full_run_deterministic() -> void:
	var first: Dictionary = _full()
	var second: Dictionary = _run("sensible", 5)
	assert_false(second["capped"], "Repeat 5-night run exceeded tick cap")
	assert_false(first["dawn5"].is_empty(), "Full run must reach dawn 5")
	assert_eq(second["dawn5"], first["dawn5"], "Same seed: kills, survivors, buildings and resources at dawn 5")
