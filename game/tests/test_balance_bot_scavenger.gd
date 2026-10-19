class_name TestBalanceBotScavenger extends TestCase

func test_scavenger_runs_once_each_allowed_morning_and_is_deterministic() -> void:
	var first: Dictionary = BalanceBot.run(1337, "scavenger", 5)
	var second: Dictionary = BalanceBot.run(1337, "scavenger", 5)
	assert_eq(BalanceBot.to_csv(first["rows"]), BalanceBot.to_csv(second["rows"]), "Same seed produces identical rows")
	assert_eq(first["scavenging"], second["scavenging"], "Same seed produces identical scavenging totals")
	var sent_by_day: Dictionary = first["scavenging"]["sent_by_day"]
	for night: int in range(1, 6):
		assert_eq(int(sent_by_day.get(night, 0)), 1, "One allowed scavenging run should be sent on day %d" % night)

func test_scavenger_never_sends_a_guard() -> void:
	var data: GameData = GameData.load_default()
	var state := GameState.new(data, 1337)
	state.waves.enabled = false
	state.clock.elapsed = 0.0
	for person: Survivor in state.survivors.all():
		person.job = Survivor.Job.GUARD
	BalanceBot._send_scavenger(state)
	assert_true(state.expeditions.active().is_empty(), "A guard must never be sent")
	state = null
	data = null

func test_existing_none_and_sensible_rows_are_stable() -> void:
	for strategy: String in ["none", "sensible"]:
		var first: Dictionary = BalanceBot.run(1337, strategy, 5)
		var second: Dictionary = BalanceBot.run(1337, strategy, 5)
		assert_eq(BalanceBot.to_csv(first["rows"]), BalanceBot.to_csv(second["rows"]), "%s output stays deterministic" % strategy)
