extends "res://tests/test_case.gd"

const JobOptions = preload("res://scripts/ui/job_options.gd")

func test_job_options() -> void:
	var btn = OptionButton.new()
	JobOptions.fill(btn)
	assert_eq(btn.get_item_count(), 8, "fill adds 8 options")
	assert_eq(btn.get_item_text(0), "Idle", "first is Idle")
	assert_eq(btn.get_item_text(2), "Gatherer: Scrap", "third is scrap")
	btn.free()

	var data = preload("res://scripts/sim/game_data.gd").load_default()
	var state = GameState.new(data, 12345)
	var s = state.survivors.add("Test", "blue", Vector2i(0, 0))
	assert_eq(JobOptions.index_for(s), 0, "idle index is 0")

	var ok = JobOptions.apply(state, s.uid, 4)
	assert_true(ok, "valid index returns true")
	assert_eq(s.job, Survivor.Job.BUILDER, "job is BUILDER")
	assert_eq(JobOptions.index_for(s), 4, "builder index is 4")

	JobOptions.apply(state, s.uid, 2)
	assert_eq(s.job, Survivor.Job.GATHERER, "job is GATHERER")
	assert_eq(s.gather_kind, "scrap", "kind is scrap")
	assert_eq(JobOptions.index_for(s), 2, "gatherer scrap index is 2")

	ok = JobOptions.apply(state, s.uid, 99)
	assert_false(ok, "invalid index returns false")
	assert_eq(s.job, Survivor.Job.GATHERER, "job did not change")
