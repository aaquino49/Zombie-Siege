extends TestCase

func test_descriptions_follow_balance_multipliers() -> void:
	var levels: Dictionary = GameData.load_default().balance("difficulty")
	assert_eq(DifficultyPicker._description("easy", levels["easy"]), "Hordes 15% smaller")
	assert_eq(DifficultyPicker._description("normal", levels["normal"]), "The intended siege")
	assert_eq(DifficultyPicker._description("hard", levels["hard"]), "Hordes 10% bigger")
	assert_eq(DifficultyPicker._description("easy", {
		"wave_size_mult": 0.9,
		"zombie_hp_mult": 1.0,
		"start_resource_mult": 0.8,
		"food_eaten_mult": 1.0,
	}), "Hordes 10% smaller · 20% less starting supplies")
