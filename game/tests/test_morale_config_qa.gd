extends TestCase
## T-215 / GDD 23.8: all required fields and finite numeric values.

func _set_path(root: Dictionary, path: String, value: Variant, erase: bool = false) -> void:
	var parts: PackedStringArray = path.split(".")
	var current: Variant = root
	for i: int in range(parts.size() - 1):
		current = current[int(parts[i])] if current is Array else current[parts[i]]
	var key: String = parts[parts.size() - 1]
	if erase: current.erase(key)
	elif current is Array: current[int(key)] = value
	else: current[key] = value

func test_every_required_config_field_rejects_missing_null_and_wrong_type() -> void:
	var data := GameData.load_default()
	var original: Dictionary = data.morale_config().duplicate(true)
	var paths: Array[String] = ["baseline","bands","moods","campfire_slots","endless_milestone_every","feast","feast.food_per_survivor","feast.cooldown_days","breaking","breaking.leave_after_dawns","breaking.max_leavers_per_dawn","day_off_morning_fraction"]
	for i: int in range(4):
		for key: String in ["id","name","min","work_mult","hit_chance"]:
			paths.append("bands.%d.%s" % [i,key])
	for id: String in original.moods:
		paths.append("moods." + id)
		for key: String in ["label","value","days","stack"]:
			paths.append("moods.%s.%s" % [id,key])
	var buildings: Dictionary = {"campfire":data.get_building("campfire")}
	for path: String in paths:
		for mutation: int in range(3):
			var config: Dictionary = original.duplicate(true)
			_set_path(config, path, null if mutation == 1 else true, mutation == 0)
			assert_false(data._validate_morale(config, buildings), path + " missing/null/bool")

func test_nonfinite_morale_numbers_and_campfire_build_time_are_rejected() -> void:
	var data := GameData.load_default()
	var paths: Array[String] = ["day_off_morning_fraction"]
	for i: int in range(4):
		paths.append("bands.%d.work_mult" % i)
		paths.append("bands.%d.hit_chance" % i)
	for path: String in paths:
		for value: float in [INF, -INF, NAN]:
			var config: Dictionary = data.morale_config().duplicate(true)
			_set_path(config, path, value)
			assert_false(data._validate_morale(config, {"campfire":data.get_building("campfire")}), "nonfinite " + path + "=" + str(value))
	for value: float in [INF, -INF, NAN]:
		var fire: Dictionary = data.get_building("campfire").duplicate(true)
		fire.build_time = value
		assert_false(data._validate_morale(data.morale_config(), {"campfire":fire}), "nonfinite Campfire build_time=" + str(value))
