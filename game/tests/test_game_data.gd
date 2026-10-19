extends "res://tests/test_case.gd"

var _fixture_dir: String

func before_each() -> void:
	_fixture_dir = temp_path("data_fixture")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_fixture_dir))

func after_each() -> void:
	var path: String = _fixture_dir.path_join("buildings.json")
	if FileAccess.file_exists(path):
		assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)), OK, "Remove temporary fixture file")
	assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(_fixture_dir)), OK, "Remove temporary fixture directory")

func test_load_default() -> void:
	var gd := GameData.load_default()
	assert_not_null(gd, "GameData should not be null")
	var ids = gd.building_ids()
	assert_true(ids.size() > 0, "Should have loaded buildings")

func test_newcomer_food_threshold_matches_gdd() -> void:
	var gd: GameData = GameData.load_default()
	var threshold: Variant = gd.balance("food_newcomers_threshold")
	assert_not_null(threshold, "Newcomer food threshold must be available through GameData")
	if threshold == null:
		return
	assert_true(typeof(threshold) == TYPE_INT or typeof(threshold) == TYPE_FLOAT, "Newcomer threshold must be numeric")
	assert_eq(float(threshold), 2.0, "Newcomers require food >= 2 * population")

func test_buildings_fields_and_values() -> void:
	var gd := GameData.load_default()
	
	# every building has all required fields with correct types
	var ids = gd.building_ids()
	for id in ids:
		var b = gd.get_building(id)
		assert_true(typeof(b.name) == TYPE_STRING, "Name should be string")
		assert_true(typeof(b.size) == TYPE_ARRAY and b.size.size() == 2, "Size should be array of 2")
		assert_true(typeof(b.cost) == TYPE_DICTIONARY and b.cost.has("wood") and b.cost.has("scrap"), "Cost should be dict with wood/scrap")
		for dimension in b.size:
			assert_true(typeof(dimension) == TYPE_INT or typeof(dimension) == TYPE_FLOAT, "Size dimensions should be numbers")
		for resource in ["wood", "scrap"]:
			assert_true(typeof(b.cost[resource]) == TYPE_INT or typeof(b.cost[resource]) == TYPE_FLOAT, "Cost amounts should be numbers")
		assert_true(typeof(b.hp) == TYPE_INT or typeof(b.hp) == TYPE_FLOAT, "HP should be number")
		assert_true(typeof(b.workers) == TYPE_INT or typeof(b.workers) == TYPE_FLOAT, "Workers should be number")
		assert_true(typeof(b.unlock_day) == TYPE_INT or typeof(b.unlock_day) == TYPE_FLOAT, "Unlock day should be number")
		assert_true(typeof(b.build_time) == TYPE_INT or typeof(b.build_time) == TYPE_FLOAT, "Build time should be number")
		assert_true(typeof(b.beds) == TYPE_INT or typeof(b.beds) == TYPE_FLOAT, "Beds should be number")

	# values for at least wooden_wall, shelter, turret and radio_tower match GDD
	var wall = gd.get_building("wooden_wall")
	assert_eq(int(wall.cost.wood), 5, "Wooden wall wood cost")
	assert_eq(int(wall.cost.scrap), 0, "Wooden wall scrap cost")
	assert_eq(int(wall.hp), 200, "Wooden wall hp")

	var shelter = gd.get_building("shelter")
	assert_eq(int(shelter.cost.wood), 30, "Shelter wood cost")
	assert_eq(int(shelter.hp), 200, "Shelter hp")
	assert_eq(int(shelter.beds), 4, "Shelter beds")

	var turret = gd.get_building("turret")
	assert_eq(int(turret.cost.wood), 10, "Turret wood cost")
	assert_eq(int(turret.cost.scrap), 25, "Turret scrap cost")
	assert_eq(int(turret.hp), 200, "Turret hp")
	assert_eq(int(turret.range_tiles), 6, "Turret range")

	var radio_tower = gd.get_building("radio_tower")
	assert_eq(int(radio_tower.cost.wood), 150, "Radio tower wood cost")
	assert_eq(int(radio_tower.cost.scrap), 120, "Radio tower scrap cost")
	assert_eq(int(radio_tower.hp), 500, "Radio tower hp")
	assert_eq(int(radio_tower.build_time), 150, "Radio tower build time")

func test_wave_for_night() -> void:
	var gd := GameData.load_default()
	
	var w1 = gd.wave_for_night(1)
	assert_eq(w1.walker, 7, "Night 1 walkers")
	assert_eq(w1.runner, 0, "Night 1 runners")
	assert_eq(w1.brute, 0, "Night 1 brutes")
	assert_eq(w1.sides, 1, "Night 1 sides")
	
	var w4 = gd.wave_for_night(4)
	assert_eq(w4.walker, 16, "Night 4 walkers")
	assert_eq(w4.runner, 2, "Night 4 runners")
	assert_eq(w4.brute, 0, "Night 4 brutes")
	assert_eq(w4.sides, 2, "Night 4 sides")
	
	var w8 = gd.wave_for_night(8)
	assert_eq(w8.walker, 28, "Night 8 walkers")
	assert_eq(w8.runner, 10, "Night 8 runners")
	assert_eq(w8.brute, 0, "Night 8 brutes")
	assert_eq(w8.sides, 2, "Night 8 sides")
	
	var w20 = gd.wave_for_night(20)
	assert_eq(w20.walker, 192, "Night 20 walkers")
	assert_eq(w20.runner, 102, "Night 20 runners")
	assert_eq(w20.brute, 30, "Night 20 brutes")
	assert_eq(w20.sides, 4, "Night 20 sides")
	assert_true(w20.final, "Night 20 should be final")

func test_buildings_unlocked_on() -> void:
	var gd := GameData.load_default()
	var day1 = gd.buildings_unlocked_on(1)
	assert_true("wooden_wall" in day1, "Day 1 should have wooden_wall")
	assert_true("gate" in day1, "Day 1 should have gate")
	assert_true("shelter" in day1, "Day 1 should have shelter")
	assert_true("farm" in day1, "Day 1 should have farm")
	assert_false("turret" in day1, "Day 1 should not have turret")

func test_malformed_file() -> void:
	var path: String = _fixture_dir.path_join("buildings.json")
	
	var file = FileAccess.open(path, FileAccess.WRITE)
	# missing required fields, or wrong types (name is int instead of string)
	file.store_string("{\"b1\": {\"name\": 123}}")
	file.close()
	
	var gd := GameData.new()
	var success = gd.load_from_dir(_fixture_dir)
	assert_false(success, "Should fail on malformed data")

func test_wave_unloaded() -> void:
	var gd := GameData.new()
	var w = gd.wave_for_night(1)
	assert_eq(w.walker, 0, "Unloaded wave walkers should be 0")
	assert_eq(w.runner, 0, "Unloaded wave runners should be 0")
	assert_eq(w.brute, 0, "Unloaded wave brutes should be 0")
	assert_eq(w.sides, 0, "Unloaded wave sides should be 0")

func test_required_building_records_and_gdd_fields() -> void:
	var gd: GameData = GameData.load_default()
	var expected_ids: PackedStringArray = ["command_center", "wooden_wall", "gate", "shelter", "farm", "storage", "watchtower", "workshop", "lumber_yard", "field_lab", "campfire", "turret", "reinforced_wall", "radio_tower"]
	assert_eq(gd.building_ids().size(), expected_ids.size(), "All fourteen buildings must exist")
	for id in expected_ids:
		assert_has(gd.building_ids(), id, "Required building record")
	# Size, wood, scrap, hp, workers, unlock_day, beds from the GDD.
	var expected: Dictionary = {
		"wooden_wall": [[1, 1], 5, 0, 200, 0, 1, 0],
		"shelter": [[2, 2], 30, 0, 200, 0, 1, 4],
		"turret": [[1, 1], 10, 25, 200, 0, 4, 0],
		"radio_tower": [[2, 2], 150, 120, 500, 0, 8, 0],
	}
	for id in expected:
		var b: Dictionary = gd.get_building(id)
		if b.is_empty():
			fail("Required building missing: " + id)
			continue
		assert_eq(int(b.size[0]), expected[id][0][0], id + " width")
		assert_eq(int(b.size[1]), expected[id][0][1], id + " height")
		assert_eq(int(b.cost.wood), expected[id][1], id + " wood cost")
		assert_eq(int(b.cost.scrap), expected[id][2], id + " scrap cost")
		var fields: Array[String] = ["hp", "workers", "unlock_day", "beds"]
		for index in range(fields.size()):
			assert_eq(int(b[fields[index]]), expected[id][index + 3], id + " " + fields[index])

func test_wave_side_thresholds_and_post_final_night() -> void:
	var gd: GameData = GameData.load_default()
	for pair in [[3, 1], [9, 2], [10, 3], [11, 3], [12, 4]]:
		assert_eq(gd.wave_for_night(pair[0]).sides, pair[1], "Side threshold at night %d" % pair[0])
	var wave: Dictionary = gd.wave_for_night(21)
	assert_eq(wave, {"walker": 67, "runner": 36, "brute": 11, "spitter": 5, "sides": 4, "final": false}, "Post-20 nights use the base formula")
