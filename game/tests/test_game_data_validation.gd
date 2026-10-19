extends "res://tests/test_case.gd"
## Acceptance regressions: temporary files, required records/keys and basic types.

var _fixture_dir: String
const FILES: Array[String] = ["buildings.json", "zombies.json", "waves.json", "balance.json", "expeditions.json", "weather.json", "morale.json", "tech.json"]

func before_each() -> void:
	_fixture_dir = temp_path("qa_t002_validation")
	assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_fixture_dir)), OK, "Create temporary fixture directory")
	_restore_defaults()

func after_each() -> void:
	for filename in FILES:
		var path: String = _fixture_dir.path_join(filename)
		if FileAccess.file_exists(path):
			assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)), OK, "Remove temporary fixture")
	assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(_fixture_dir)), OK, "Remove temporary directory")

func _restore_defaults() -> void:
	for filename in FILES:
		assert_eq(DirAccess.copy_absolute(ProjectSettings.globalize_path("res://data/" + filename), ProjectSettings.globalize_path(_fixture_dir.path_join(filename))), OK, "Copy valid " + filename)

func _read_fixture(filename: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_fixture_dir.path_join(filename)))
	assert_true(parsed is Dictionary, "Fixture root must be a dictionary")
	return parsed if parsed is Dictionary else {}

func _write_fixture(filename: String, data: Dictionary) -> void:
	_write_text(filename, JSON.stringify(data))

func _write_text(filename: String, content: String) -> void:
	var file: FileAccess = FileAccess.open(_fixture_dir.path_join(filename), FileAccess.WRITE)
	assert_not_null(file, "Open fixture for writing")
	if file == null:
		return
	file.store_string(content)
	file.close()

func test_missing_files_are_rejected() -> void:
	for filename in FILES:
		_restore_defaults()
		assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(_fixture_dir.path_join(filename))), OK)
		assert_false(GameData.new().load_from_dir(_fixture_dir), "Missing " + filename + " must return false and push_error")

func test_invalid_json_is_rejected() -> void:
	for filename in FILES:
		_restore_defaults()
		_write_text(filename, "{ invalid JSON")
		assert_false(GameData.new().load_from_dir(_fixture_dir), "Invalid syntax in " + filename + " must return false and push_error")

func test_missing_required_records_are_rejected() -> void:
	for pair in [["buildings.json", "command_center"], ["zombies.json", "walker"]]:
		_restore_defaults()
		var data: Dictionary = _read_fixture(pair[0])
		data.erase(pair[1])
		_write_fixture(pair[0], data)
		assert_false(GameData.new().load_from_dir(_fixture_dir), "Missing required " + pair[1] + " record must return false and push_error")

func test_missing_building_and_zombie_keys_are_rejected() -> void:
	for item in [["buildings.json", "wooden_wall", "hp"], ["zombies.json", "walker", "speed"]]:
		_restore_defaults()
		var data: Dictionary = _read_fixture(item[0])
		data[item[1]].erase(item[2])
		_write_fixture(item[0], data)
		assert_false(GameData.new().load_from_dir(_fixture_dir), "Missing required " + item[2] + " must return false and push_error")

func test_missing_wave_and_balance_keys_are_rejected() -> void:
	for pair in [["waves.json", "walkers_per_night"], ["waves.json", "endless_wave_mult"], ["balance.json", "day_length"], ["balance.json", "food_newcomers_threshold"]]:
		_restore_defaults()
		var data: Dictionary = _read_fixture(pair[0])
		data.erase(pair[1])
		_write_fixture(pair[0], data)
		assert_false(GameData.new().load_from_dir(_fixture_dir), "Missing required " + pair[1] + " must return false and push_error")

func test_wrong_building_numeric_types_are_rejected() -> void:
	for field in ["size", "cost"]:
		_restore_defaults()
		var data: Dictionary = _read_fixture("buildings.json")
		if field == "size":
			data.wooden_wall.size = ["one", 1]
		else:
			data.wooden_wall.cost.wood = "five"
		_write_fixture("buildings.json", data)
		assert_false(GameData.new().load_from_dir(_fixture_dir), "Non-numeric " + field + " values must be rejected")

func test_wrong_wave_and_balance_types_are_rejected() -> void:
	for item in [["waves.json", "sides_by_night", []], ["waves.json", "endless_wave_mult", "small"], ["balance.json", "day_length", "fast"]]:
		_restore_defaults()
		var data: Dictionary = _read_fixture(item[0])
		data[item[1]] = item[2]
		_write_fixture(item[0], data)
		assert_false(GameData.new().load_from_dir(_fixture_dir), "Wrong basic type for " + item[1] + " must return false and push_error")

func test_non_positive_endless_wave_multiplier_is_rejected() -> void:
	for multiplier: float in [0.0, -0.8]:
		_restore_defaults()
		var data: Dictionary = _read_fixture("waves.json")
		data["endless_wave_mult"] = multiplier
		_write_fixture("waves.json", data)
		assert_false(GameData.new().load_from_dir(_fixture_dir), "Non-positive endless multiplier must be rejected")

func test_weather_is_required_and_validated() -> void:
	assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(_fixture_dir.path_join("weather.json"))), OK)
	assert_false(GameData.new().load_from_dir(_fixture_dir), "Missing weather.json must be rejected")
	for mutation: Array in [["rain", "chance", -0.1], ["rain", "farm_mult", "fast"], ["fog", "range_delta_tiles", "near"], ["fog", "no_repeat", 1]]:
		_restore_defaults()
		var weather: Dictionary = _read_fixture("weather.json")
		weather[mutation[0]][mutation[1]] = mutation[2]
		_write_fixture("weather.json", weather)
		assert_false(GameData.new().load_from_dir(_fixture_dir), "Invalid weather field %s.%s must be rejected" % [mutation[0], mutation[1]])

func test_morale_config_invalid_values_are_rejected() -> void:
	for pair: Array in [["baseline",101],["campfire_slots",0],["day_off_morning_fraction",0.0]]:
		_restore_defaults()
		var morale: Dictionary = _read_fixture("morale.json")
		morale[pair[0]] = pair[1]
		_write_fixture("morale.json", morale)
		assert_false(GameData.new().load_from_dir(_fixture_dir), "Invalid morale field %s rejected" % pair[0])
	var bad_morale: Array = [
		["morale.json", "baseline", "50"], ["morale.json", "bands.0.id", "new"],
		["morale.json", "bands.0.min", 39], ["morale.json", "bands.0.min", 75.5],
		["morale.json", "bands.0.name", ""], ["morale.json", "bands.2.work_mult", 0.0],
		["morale.json", "bands.0.hit_chance", 1.1], ["morale.json", "bands.2.hit_chance", 0.5],
		["morale.json", "bands.1.work_mult", 0.9], ["morale.json", "moods.bed.value", 101],
		["morale.json", "moods.bed.days", 0], ["morale.json", "moods.death.stack", 3],
		["morale.json", "moods.death.label", "Someone died"], ["morale.json", "moods.bed.label", ""],
		["morale.json", "moods.bed.label", "No {name}"],
		["morale.json", "feast.food_per_survivor", -1], ["morale.json", "feast.cooldown_days", 0],
		["morale.json", "breaking.leave_after_dawns", 1], ["morale.json", "breaking.max_leavers_per_dawn", 0],
		["morale.json", "endless_milestone_every", 0], ["buildings.json", "campfire.sprite", "fire"],
		["buildings.json", "campfire.name", "Fire"], ["buildings.json", "campfire.blurb", ""],
		["buildings.json", "campfire.size.0", 2], ["buildings.json", "campfire.cost.wood", -1],
		["buildings.json", "campfire.cost.scrap", "free"], ["buildings.json", "campfire.hp", 0],
		["buildings.json", "campfire.workers", -1], ["buildings.json", "campfire.beds", -1],
		["buildings.json", "campfire.unlock_day", 0], ["buildings.json", "campfire.build_time", 0]
	]
	for mutation: Array in bad_morale:
		_restore_defaults()
		var filename: String = mutation[0]
		var fixture: Dictionary = _read_fixture(filename)
		_set_path(fixture, str(mutation[1]), mutation[2])
		_write_fixture(filename, fixture)
		assert_false(GameData.new().load_from_dir(_fixture_dir), "Invalid config %s.%s rejected" % [filename, mutation[1]])
	_restore_defaults()
	var missing_moods: Dictionary = _read_fixture("morale.json")
	missing_moods.erase("moods")
	_write_fixture("morale.json", missing_moods)
	assert_false(GameData.new().load_from_dir(_fixture_dir), "Missing mood table is rejected")
	_restore_defaults()
	var missing_mood: Dictionary = _read_fixture("morale.json")
	missing_mood.moods.erase("bed")
	_write_fixture("morale.json", missing_mood)
	assert_false(GameData.new().load_from_dir(_fixture_dir), "Missing required mood definition is rejected")

func test_tech_graph_types_and_effect_pairs_are_rejected() -> void:
	var mutations: Array = [
		["upgrades.oiled_turrets.requires", ["ammo_press"]],
		["upgrades.spotters.effect.op", "mult"],
		["upgrades.first_aid.effect.value", 2.5],
		["upgrades.better_tools.effect.key", "made_up"],
		["upgrades.crop_rotation.effect.value", 0.0],
		["upgrades.reinforced_frames.tier", 2.5],
		["rp_per_researcher_per_day", "ten"]
	]
	for mutation: Array in mutations:
		_restore_defaults()
		var tech: Dictionary = _read_fixture("tech.json")
		_set_path(tech, str(mutation[0]), mutation[1])
		_write_fixture("tech.json", tech)
		assert_false(GameData.new().load_from_dir(_fixture_dir), "Invalid tech %s rejected" % mutation[0])
	var invalid_graphs: Array[Dictionary] = [
		{"path": "upgrades.spotters.requires", "value": ["spotters"]},
		{"path": "upgrades.oiled_turrets.requires", "value": ["spotters", "spotters"]},
		{"path": "upgrades.oiled_turrets.requires", "value": ["missing"]},
		{"path": "upgrades.spotters.tier", "value": 2},
		{"path": "upgrades.reinforced_frames.tier", "value": 4},
		{"path": "upgrades.reinforced_frames.requires", "value": ["reinforced_frames"]},
		{"path": "upgrades.better_tools.effect", "value": []},
		{"path": "upgrades.camp_songs.effect.value", "value": true},
		{"path": "upgrades.first_aid.effect.value", "value": 10.5},
		{"path": "upgrades.bunk_beds.effect.key", "value": "made_up"},
		{"path": "upgrades.ammo_press.effect.value", "value": -1},
		{"path": "rp_per_researcher_per_day", "value": NAN},
		{"path": "branches.0", "value": "defense"}
	]
	for mutation: Dictionary in invalid_graphs:
		_restore_defaults()
		var config: Dictionary = _read_fixture("tech.json")
		_set_path(config, str(mutation.path), mutation.value)
		_write_fixture("tech.json", config)
		assert_false(GameData.new().load_from_dir(_fixture_dir), "Invalid graph/type rejected: %s" % mutation.path)
	_restore_defaults()
	var bad_container: Dictionary = _read_fixture("tech.json")
	bad_container["upgrades"] = []
	_write_fixture("tech.json", bad_container)
	assert_false(GameData.new().load_from_dir(_fixture_dir), "Wrong upgrades container rejected")
	_restore_defaults()
	for max_count: Variant in [true, 1.5, -1]:
		var buildings: Dictionary = _read_fixture("buildings.json")
		buildings.field_lab.max_count = max_count
		_write_fixture("buildings.json", buildings)
		assert_false(GameData.new().load_from_dir(_fixture_dir), "Invalid max_count rejected: %s" % max_count)
		_restore_defaults()
	var missing_effect: Dictionary = _read_fixture("tech.json")
	missing_effect.upgrades.spotters.effect.erase("value")
	_write_fixture("tech.json", missing_effect)
	assert_false(GameData.new().load_from_dir(_fixture_dir), "Missing nested effect field rejected")

func _set_path(root: Dictionary, path: String, value: Variant) -> void:
	var parts: PackedStringArray = path.split(".")
	var current: Variant = root
	for i: int in range(parts.size() - 1):
		var key: String = parts[i]
		current = current[int(key)] if current is Array else current[key]
	var last: String = parts[parts.size() - 1]
	if current is Array:
		current[int(last)] = value
	else:
		current[last] = value
