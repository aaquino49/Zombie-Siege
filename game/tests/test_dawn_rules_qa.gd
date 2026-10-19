extends TestCase

func test_incomplete_command_center_supplies_no_beds() -> void:
	var data: GameData = GameData.load_default()
	var state: GameState = GameState.new(data, 1337)
	var cc: Building = state.buildings.all_of_type("command_center")[0]
	cc.complete = false
	assert_eq(state.buildings.total_beds(), 0, "an incomplete CC supplies no beds")
	state.buildings.finish(cc.uid)
	assert_eq(state.buildings.total_beds(), int(data.get_building("command_center")["beds"]))

func test_fed_dawn_breaks_consecutive_hunger_streak() -> void:
	var data: GameData = GameData.load_default()
	var state: GameState = GameState.new(data, 1337)
	var survivor: Survivor = state.survivors.all()[0]
	var need: int = int(data.balance("food_eat_per_survivor"))
	var leave_days: int = int(data.balance("food_hungry_leave_days"))
	state.resources.take("food", state.resources.get_amount("food"))
	survivor.hungry_days = leave_days - 1
	state.resources.add("food", need)
	var fed_report: Dictionary = DawnRules.process(state)
	assert_eq(survivor.hungry_days, 0)
	assert_false(fed_report["hungry"].has(survivor.name))
	for day: int in range(leave_days - 1):
		var hungry_report: Dictionary = DawnRules.process(state)
		assert_eq(survivor.hungry_days, day + 1)
		assert_not_null(state.survivors.get_by_uid(survivor.uid))
		assert_has(hungry_report["hungry"], survivor.name)
		assert_false(hungry_report["left"].has(survivor.name))
	var left_report: Dictionary = DawnRules.process(state)
	assert_eq(state.survivors.get_by_uid(survivor.uid), null)
	assert_has(left_report["left"], survivor.name)
