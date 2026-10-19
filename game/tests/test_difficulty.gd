extends TestCase

func test_difficulty_multipliers_apply_to_resources_waves_and_zombie_hp() -> void:
	var data: GameData = GameData.load_default()
	var normal := GameState.new(data, 1337)
	var easy := GameState.new(data, 1337, "easy")
	var hard := GameState.new(data, 1337, "hard")
	var easy_config: Dictionary = data.difficulty_config("easy")
	var normal_config: Dictionary = data.difficulty_config("normal")
	var hard_config: Dictionary = data.difficulty_config("hard")
	assert_eq(normal.difficulty, "normal")
	assert_eq(normal.difficulty_multipliers, normal_config)
	assert_eq(normal.resources.get_amount("wood"), int(data.balance("start_wood")))
	assert_eq(easy.resources.get_amount("wood"), roundi(float(data.balance("start_wood")) * float(easy_config["start_resource_mult"])))
	assert_eq(hard.resources.get_amount("wood"), roundi(float(data.balance("start_wood")) * float(hard_config["start_resource_mult"])))
	for state: GameState in [normal, easy, hard]:
		state.waves.enabled = true
		state.clock.day = 1
		state.clock.phase = GameClock.Phase.NIGHT
		state.waves.plan_night(1)
	var base_wave: Dictionary = data.wave_for_night(1)
	assert_eq(normal.waves.pending(), int(base_wave.walker))
	assert_eq(easy.waves.pending(), roundi(float(base_wave.walker) * float(easy_config["wave_size_mult"])))
	assert_eq(hard.waves.pending(), roundi(float(base_wave.walker) * float(hard_config["wave_size_mult"])))
	var hp_normal: Zombie = normal.spawn_zombie("walker", Vector2.ZERO)
	var hp_easy: Zombie = easy.spawn_zombie("walker", Vector2.ZERO)
	var hp_hard: Zombie = hard.spawn_zombie("walker", Vector2.ZERO)
	var base_hp: float = float(data.get_zombie("walker").hp)
	assert_eq(hp_normal.max_hp, roundi(base_hp))
	assert_eq(hp_easy.max_hp, roundi(base_hp * float(easy_config["zombie_hp_mult"])))
	assert_eq(hp_hard.max_hp, roundi(base_hp * float(hard_config["zombie_hp_mult"])))

func test_unknown_difficulty_falls_back_to_normal() -> void:
	var state := GameState.new(GameData.load_default(), 1337, "nightmare")
	assert_eq(state.difficulty, "normal")
	assert_eq(state.resources.get_amount("wood"), 60)
	assert_eq(float(state.difficulty_multipliers["wave_size_mult"]), 1.0)

func test_food_multiplier_scales_dawn_consumption() -> void:
	var data: GameData = GameData.load_default()
	var state := GameState.new(data, 1337)
	var food_multiplier: float = float(data.difficulty_config("normal")["food_eaten_mult"]) * 2.0
	state.difficulty_multipliers["food_eaten_mult"] = food_multiplier
	var food_per_survivor: int = roundi(float(data.balance("food_eat_per_survivor")) * food_multiplier)
	var food_consumed: int = state.survivors.count() * food_per_survivor
	assert_eq(DawnRules._eat(state), food_consumed)
	assert_eq(state.resources.get_amount("food"), int(data.balance("start_food")) - food_consumed)

func test_difficulty_data_validation() -> void:
	var data: GameData = GameData.load_default()
	var valid: Dictionary = data.balance("difficulty")
	assert_true(data._validate_difficulty(valid))
	var missing_key: Dictionary = valid.duplicate(true)
	(missing_key["hard"] as Dictionary).erase("food_eaten_mult")
	assert_false(data._validate_difficulty(missing_key))
	var negative: Dictionary = valid.duplicate(true)
	(negative["easy"] as Dictionary)["wave_size_mult"] = -1.0
	assert_false(data._validate_difficulty(negative))

func test_save_round_trip_preserves_difficulty_and_old_save_defaults_normal() -> void:
	var hard := GameState.new(GameData.load_default(), 1337, "hard")
	var saved: Dictionary = SaveGame.capture(hard)
	assert_eq(saved.get("difficulty"), "hard")
	var restored: GameState = SaveGame.restore(GameData.load_default(), SaveGame.from_json(SaveGame.to_json(saved)))
	assert_not_null(restored)
	assert_eq(restored.difficulty, "hard")
	assert_eq(restored.resources.get_amount("wood"), hard.resources.get_amount("wood"))
	var old_save: Dictionary = saved.duplicate(true)
	old_save.erase("difficulty")
	var old_restored: GameState = SaveGame.restore(GameData.load_default(), old_save)
	assert_not_null(old_restored)
	assert_eq(old_restored.difficulty, "normal")
