class_name TestScavengeHintTiming extends TestCase

var data: GameData
var state: GameState

func before_each() -> void:
	data = GameData.load_default()
	state = GameState.new(data, 1337)
	state.waves.enabled = false

func after_each() -> void:
	state = null
	data = null

func _hints_ready_for_scavenge() -> TutorialHints:
	var hints := TutorialHints.new()
	hints.shown = {
		"welcome": true,
		"farm": true,
		"night_soon": true,
		"ammo": true,
	}
	return hints

func test_scavenge_hint_waits_for_a_sendable_morning_and_retries_next_day() -> void:
	var hints: TutorialHints = _hints_ready_for_scavenge()
	state.clock.day = 2
	state.clock.phase = GameClock.Phase.NIGHT
	state.clock.elapsed = 0.0
	assert_ne(hints.check(state, 0.0), "scavenge", "hint does not fire at night")
	assert_false(hints.shown.has("scavenge"), "night does not consume the one-shot hint")

	state.clock.phase = GameClock.Phase.DAY
	var morning_cutoff: float = float(data.balance("day_length")) * float(data.expeditions().get("morning_fraction", 0.4))
	state.clock.elapsed = morning_cutoff
	assert_ne(hints.check(state, 0.0), "scavenge", "hint does not fire at or after the morning cutoff")
	assert_false(hints.shown.has("scavenge"), "past cutoff does not consume the one-shot hint")

	state.clock.day = 3
	state.clock.elapsed = 0.0
	assert_eq(hints.check(state, 0.0), "scavenge", "missed hint appears on the next morning")
	assert_eq(hints.check(state, 0.0), "", "scavenge hint only appears once")

func test_scavenge_hint_waits_until_a_survivor_can_be_sent() -> void:
	var hints: TutorialHints = _hints_ready_for_scavenge()
	state.clock.day = 2
	state.clock.phase = GameClock.Phase.DAY
	state.clock.elapsed = 0.0
	for s: Survivor in state.survivors.all():
		assert_true(state.set_job(s.uid, Survivor.Job.GUARD), "all survivors are set to Guard")

	assert_ne(hints.check(state, 0.0), "scavenge", "all-Guard morning does not show the scavenge hint")
	assert_false(hints.shown.has("scavenge"), "ineligible morning does not consume the hint")

	var eligible: Survivor = state.survivors.all()[0]
	assert_true(state.set_job(eligible.uid, Survivor.Job.IDLE), "one survivor becomes Idle")
	assert_eq(hints.check(state, 0.0), "scavenge", "hint appears when a survivor can be sent")
	assert_eq(hints.check(state, 0.0), "", "scavenge hint appears only once")
