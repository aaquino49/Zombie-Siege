extends TestCase
## T-147: exercise the multiplier paths that the tuned presets leave at 1.0.

func test_non_unit_resource_and_hp_multipliers_reach_the_sim() -> void:
	var data: GameData = GameData.load_default()
	var levels: Dictionary = data.balance("difficulty").duplicate(true)
	levels["hard"]["start_resource_mult"] = 0.75
	levels["hard"]["zombie_hp_mult"] = 1.2
	data._balance["difficulty"] = levels
	var state := GameState.new(data, 1337, "hard")
	for kind: String in ResourceStore.KINDS:
		assert_eq(state.resources.get_amount(kind), roundi(float(data.balance("start_" + kind)) * 0.75))
	for type_id: String in ["walker", "runner", "brute"]:
		var zombie: Zombie = state.spawn_zombie(type_id, Vector2.ZERO)
		assert_eq(zombie.max_hp, roundi(float(data.get_zombie(type_id)["hp"]) * 1.2))
		assert_eq(zombie.hp, zombie.max_hp)

func test_wave_scaling_keeps_present_types_and_absent_types_after_save() -> void:
	var data: GameData = GameData.load_default()
	var levels: Dictionary = data.balance("difficulty").duplicate(true)
	levels["easy"]["wave_size_mult"] = 0.001
	data._balance["difficulty"] = levels
	var state := GameState.new(data, 1337, "easy")
	var restored: GameState = SaveGame.restore(data, SaveGame.from_json(SaveGame.to_json(SaveGame.capture(state))))
	assert_not_null(restored)
	if restored == null:
		return
	assert_eq(restored.difficulty, "easy")
	assert_eq(restored.difficulty_multipliers, data.difficulty_config("easy"))
	for night: int in [1, 20]:
		restored.waves.plan_night(night)
		var base: Dictionary = data.wave_for_night(night)
		for type_id: String in ["walker", "runner", "brute"]:
			var count: int = 0
			for entry: Dictionary in restored.waves._schedule:
				if entry["type"] == type_id:
					count += 1
			assert_eq(count, 1 if int(base[type_id]) >= 1 else 0)
