extends TestCase
## T-203: repeat cadence jitter stays isolated from the fixed simulation tick.

const BALANCE_RUN: GDScript = preload("res://dev/balance_run.gd")

func test_default_repeat_keeps_the_original_balance_result() -> void:
	var expected: Dictionary = BalanceBot.run(1337, "sensible", 3, 0.25)
	var actual: Dictionary = BalanceBot.run(1337, "sensible", 3, 0.25, Callable(), "normal")
	assert_eq(actual["outcome"], expected["outcome"])
	assert_eq(actual["nights_survived"], expected["nights_survived"])
	assert_eq(BalanceBot.to_csv(actual["rows"]), BalanceBot.to_csv(expected["rows"]))

func test_repeat_jitter_is_seeded_and_only_changes_bot_cadence() -> void:
	var first_rng: RandomNumberGenerator = BALANCE_RUN._jitter_rng(1337, 0)
	var second_rng: RandomNumberGenerator = BALANCE_RUN._jitter_rng(1337, 1)
	var first_delay: float = BALANCE_RUN._next_decision_delay(first_rng)
	var second_delay: float = BALANCE_RUN._next_decision_delay(second_rng)
	assert_ne(first_delay, second_delay, "Repeat indices should use independent deterministic cadence jitter")
	var repeat_rng: RandomNumberGenerator = BALANCE_RUN._jitter_rng(1337, 0)
	assert_eq(first_delay, BALANCE_RUN._next_decision_delay(repeat_rng), "Jitter must reproduce for a seed and repeat index")
	assert_true(first_delay >= 3.0 and first_delay <= 7.0)
	assert_true(second_delay >= 3.0 and second_delay <= 7.0)

	var first: Dictionary = BALANCE_RUN._run_jittered(1337, "sensible", 3, 0, "normal")
	var second: Dictionary = BALANCE_RUN._run_jittered(1337, "sensible", 3, 1, "normal")
	assert_eq(first["seed"], 1337)
	assert_eq(second["seed"], 1337)
	assert_false(bool(first["capped"]))
	assert_false(bool(second["capped"]))
	assert_almost_eq(fmod(float(first["sim_seconds"]), 0.25), 0.0, 0.0001,
		"Simulation time must advance only in fixed 0.25 second ticks")
	assert_almost_eq(fmod(float(second["sim_seconds"]), 0.25), 0.0, 0.0001,
		"Simulation time must advance only in fixed 0.25 second ticks")
	assert_true(int(first["jitter_decisions"]) > 0 and int(second["jitter_decisions"]) > 0)
	var replay: Dictionary = BALANCE_RUN._run_jittered(1337, "sensible", 3, 0, "normal")
	assert_eq(first.rows, replay.rows, "The full jittered simulation repeats deterministically")
	for row: Dictionary in first.rows:
		assert_eq(row.keys(), BalanceBot.COLUMNS)
		for column: String in BalanceBot.COLUMNS: assert_has(row, column)

func test_none_has_no_jitter_cadence_and_keeps_loss_measurements() -> void:
	var fixed: Dictionary = BalanceBot.run(1337, "none", 8)
	for repeat_index: int in range(3):
		var result: Dictionary = BALANCE_RUN._run_jittered(1337, "none", 8, repeat_index, "normal")
		assert_eq(result.get("jitter_decisions", 0), 0)
		assert_eq(result.rows, fixed.rows)
		assert_eq(result.rows[-1].night, 4)
		assert_eq(result.rows[-1].end, "loss")
		assert_eq(result.rows[-1].morale_left, 0)
		for row: Dictionary in result.rows:
			assert_eq(row.keys(), BalanceBot.COLUMNS)
			assert_eq(row.day_researchers, 0)

func test_none_csv_preserves_all_pre_t229_columns_and_values() -> void:
	# SHA-256 of the seed-1337 normal none/8-night CSV captured before T-229.
	var result: Dictionary = BalanceBot.run(1337, "none", 8)
	var old_lines: PackedStringArray = []
	for line: String in BalanceBot.to_csv(result.rows).split("\n", false):
		var fields: PackedStringArray = line.split(",")
		assert_eq(fields.size(), BalanceBot.COLUMNS.size())
		fields.remove_at(fields.size() - 1)
		old_lines.append(",".join(fields))
	assert_eq(("\n".join(old_lines) + "\n").sha256_text(),
		"c54764e915758b12074b2387647768bd77d9dc89562a47365ca9b05a0019005e")
