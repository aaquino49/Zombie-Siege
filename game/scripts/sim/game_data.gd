class_name GameData extends RefCounted

var _buildings: Dictionary = {}
var _zombies: Dictionary = {}
var _waves: Dictionary = {}
var _balance: Dictionary = {}
var _expeditions: Dictionary = {}
var _weather: Dictionary = {}
var _morale: Dictionary = {}
var _tech: Dictionary = {}

static func load_default() -> GameData:
	var data := GameData.new()
	data.load_from_dir("res://data")
	return data

func load_from_dir(dir: String) -> bool:
	_buildings.clear()
	_zombies.clear()
	_waves.clear()
	_balance.clear()
	_expeditions.clear()
	_weather.clear()
	_morale.clear()
	_tech.clear()
	
	var b := _load_json(dir.path_join("buildings.json"))
	if not _validate_buildings(b):
		push_error("Failed to load or validate buildings.json")
		return false
	_buildings = b
	
	var z := _load_json(dir.path_join("zombies.json"))
	if not _validate_zombies(z):
		push_error("Failed to load or validate zombies.json")
		return false
	_zombies = z
	
	var w := _load_json(dir.path_join("waves.json"))
	if not _validate_waves(w):
		push_error("Failed to load or validate waves.json")
		return false
	_waves = w
	
	var bal := _load_json(dir.path_join("balance.json"))
	if not _validate_balance(bal):
		push_error("Failed to load or validate balance.json")
		return false
	_balance = bal
	var expeditions := _load_json(dir.path_join("expeditions.json"))
	if not _validate_expeditions(expeditions):
		push_error("Failed to load or validate expeditions.json")
		return false
	_expeditions = expeditions
	var weather := _load_json(dir.path_join("weather.json"))
	if not _validate_weather(weather):
		push_error("Failed to load or validate weather.json")
		return false
	_weather = weather
	var morale := _load_json(dir.path_join("morale.json"))
	if not _validate_morale(morale, b):
		push_error("Failed to load or validate morale.json")
		return false
	_morale = morale
	var tech := _load_json(dir.path_join("tech.json"))
	if not _validate_tech(tech, b):
		push_error("Failed to load or validate tech.json")
		return false
	_tech = tech
	
	return true

func _validate_weather(weather: Dictionary) -> bool:
	for kind: String in ["rain", "fog"]:
		if typeof(weather.get(kind, null)) != TYPE_DICTIONARY:
			return false
	var rain: Dictionary = weather["rain"]
	if not _is_number(rain.get("first_day", null)) or int(rain["first_day"]) < 1:
		return false
	if not _is_number(rain.get("chance", null)) or float(rain["chance"]) < 0.0 or float(rain["chance"]) > 1.0:
		return false
	if not _is_number(rain.get("farm_mult", null)) or float(rain["farm_mult"]) <= 0.0:
		return false
	var fog: Dictionary = weather["fog"]
	if not _is_number(fog.get("first_night", null)) or int(fog["first_night"]) < 1:
		return false
	if not _is_number(fog.get("chance", null)) or float(fog["chance"]) < 0.0 or float(fog["chance"]) > 1.0:
		return false
	if not _is_number(fog.get("range_delta_tiles", null)):
		return false
	for flag: String in ["never_final", "no_repeat"]:
		if typeof(fog.get(flag, null)) != TYPE_BOOL:
			return false
	return true

func _validate_expeditions(e: Dictionary) -> bool:
	for key: String in ["morning_fraction", "max_runs", "loot_per_day", "newcomer_chance", "hurt_base", "hurt_per_day", "hurt_max", "lost_base", "lost_per_day", "lost_max"]:
		if not _is_number(e.get(key, null)):
			return false
	if float(e["morning_fraction"]) <= 0.0 or float(e["morning_fraction"]) > 1.0 or int(e["max_runs"]) < 1:
		return false
	if typeof(e.get("max_runs_from_day", null)) != TYPE_DICTIONARY:
		return false
	for day: String in e["max_runs_from_day"]:
		if not day.is_valid_int() or int(day) < 1 or not _is_number(e["max_runs_from_day"][day]) or int(e["max_runs_from_day"][day]) < 1:
			return false
	if typeof(e.get("loot", null)) != TYPE_DICTIONARY:
		return false
	for kind: String in ["wood", "scrap", "food", "ammo"]:
		var bounds: Variant = e["loot"].get(kind, null)
		if typeof(bounds) != TYPE_ARRAY or bounds.size() != 2 or not _is_number(bounds[0]) or not _is_number(bounds[1]) or int(bounds[0]) < 0 or int(bounds[1]) < int(bounds[0]):
			return false
	for key: String in ["loot_per_day", "newcomer_chance", "hurt_base", "hurt_per_day", "hurt_max", "lost_base", "lost_per_day", "lost_max"]:
		if float(e[key]) < 0.0 or float(e[key]) > 1.0:
			return false
	return true

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var text := file.get_as_text()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		return {}
	if typeof(json.data) != TYPE_DICTIONARY:
		return {}
	return json.data

func _validate_buildings(b: Dictionary) -> bool:
	if b.is_empty(): return false
	var required_ids = ["command_center", "wooden_wall", "gate", "shelter", "farm", "storage", "watchtower", "workshop", "lumber_yard", "turret", "reinforced_wall", "radio_tower"]
	required_ids.append("field_lab")
	for id in required_ids:
		if not b.has(id): return false
	var required_keys = ["name", "size", "cost", "hp", "workers", "unlock_day", "build_time", "beds"]
	for k in b.keys():
		var entry = b[k]
		if typeof(entry) != TYPE_DICTIONARY: return false
		for req in required_keys:
			if not entry.has(req): return false
		
		if typeof(entry["name"]) != TYPE_STRING: return false
		if typeof(entry["size"]) != TYPE_ARRAY or entry["size"].size() != 2: return false
		if not _is_number(entry["size"][0]) or not _is_number(entry["size"][1]): return false
		if typeof(entry["cost"]) != TYPE_DICTIONARY or not entry["cost"].has("wood") or not entry["cost"].has("scrap"): return false
		if not _is_number(entry["cost"]["wood"]) or not _is_number(entry["cost"]["scrap"]): return false
		if not _is_number(entry["hp"]) or not _is_number(entry["workers"]) or not _is_number(entry["unlock_day"]) or not _is_number(entry["build_time"]) or not _is_number(entry["beds"]): return false
		if entry.has("blurb") and typeof(entry["blurb"]) != TYPE_STRING: return false
		if entry.has("max_count") and (not _integer(entry.max_count) or int(entry.max_count) < 0): return false
	return true

func _validate_tech(t: Dictionary, buildings: Dictionary) -> bool:
	if t.is_empty() or not _finite_number(t.get("rp_per_researcher_per_day", null)) or float(t.rp_per_researcher_per_day) <= 0.0:
		return false
	if typeof(t.get("branches", null)) != TYPE_ARRAY or t.branches.size() != 3:
		return false
	var branch_ids: Array[String] = ["defense", "economy", "survivors"]
	for i: int in range(3):
		var branch: Variant = t.branches[i]
		if typeof(branch) != TYPE_DICTIONARY or branch.get("id", null) != branch_ids[i]: return false
		for key: String in ["name", "icon"]:
			if typeof(branch.get(key, null)) != TYPE_STRING or str(branch[key]).is_empty(): return false
	if typeof(t.get("upgrades", null)) != TYPE_DICTIONARY: return false
	var upgrades: Dictionary = t.upgrades
	if upgrades.size() < 8 or upgrades.size() > 12: return false
	var tiers: Dictionary = {"defense": {}, "economy": {}, "survivors": {}}
	var effect_pairs: Dictionary = {"guard_range_tiles":"add", "turret_fire_interval":"mult", "structure_damage_taken":"mult", "gather_time":"mult", "farm_food":"mult", "ammo_per_scrap":"add", "campfire_morale":"mult", "dawn_heal":"add", "shelter_beds":"add"}
	var counts: Dictionary = {"defense": 0, "economy": 0, "survivors": 0}
	var id_pattern := RegEx.new()
	id_pattern.compile("^[a-z][a-z0-9_]*$")
	for id_variant: Variant in upgrades.keys():
		var id: String = str(id_variant)
		if id_pattern.search(id) == null: return false
		var u: Variant = upgrades[id]
		if typeof(u) != TYPE_DICTIONARY: return false
		for key: String in ["branch", "tier", "name", "cost", "requires", "text", "effect"]:
			if not u.has(key): return false
		var branch_id: String = str(u.branch)
		if not branch_ids.has(branch_id) or typeof(u.branch) != TYPE_STRING: return false
		if not _integer(u.tier) or int(u.tier) < 1 or int(u.tier) > 4 or tiers[branch_id].has(int(u.tier)): return false
		tiers[branch_id][int(u.tier)] = id
		counts[branch_id] += 1
		if typeof(u.name) != TYPE_STRING or str(u.name).is_empty() or typeof(u.text) != TYPE_STRING or str(u.text).is_empty(): return false
		if not _integer(u.cost) or int(u.cost) <= 0 or typeof(u.requires) != TYPE_ARRAY: return false
		for req: Variant in u.requires:
			if typeof(req) != TYPE_STRING or str(req) == id: return false
		if typeof(u.effect) != TYPE_DICTIONARY: return false
		var effect: Dictionary = u.effect
		if typeof(effect.get("key", null)) != TYPE_STRING or typeof(effect.get("op", null)) != TYPE_STRING or not effect_pairs.has(str(effect.key)): return false
		if str(effect.op) != effect_pairs[str(effect.key)] or not _finite_number(effect.get("value", null)): return false
		var value: float = float(effect.value)
		match str(effect.key):
			"guard_range_tiles": if value < 0.0: return false
			"turret_fire_interval", "structure_damage_taken", "gather_time": if value <= 0.0 or value > 1.0: return false
			"farm_food", "campfire_morale": if value < 1.0: return false
			_: if value < 0.0 or not _integer(effect.value): return false
	for branch_id: String in branch_ids:
		if counts[branch_id] < 2: return false
		if tiers[branch_id].size() != counts[branch_id]: return false
		for tier: int in range(1, counts[branch_id] + 1):
			if not tiers[branch_id].has(tier): return false
			var id: String = str(tiers[branch_id][tier])
			var reqs: Array = upgrades[id].requires
			if tier == 1:
				if not reqs.is_empty(): return false
			elif reqs.size() != 1 or str(reqs[0]) != str(tiers[branch_id][tier - 1]): return false
	# Require every dependency to exist and guard against cycles/disconnected graphs.
	for id_variant: Variant in upgrades.keys():
		var id: String = str(id_variant)
		for req: String in upgrades[id].requires:
			if not upgrades.has(req): return false
		var seen: Dictionary = {}
		var cursor: String = id
		while cursor != "":
			if seen.has(cursor): return false
			seen[cursor] = true
			var reqs: Array = upgrades[cursor].requires
			cursor = str(reqs[0]) if not reqs.is_empty() else ""
	var lab: Variant = buildings.get("field_lab", null)
	if typeof(lab) != TYPE_DICTIONARY: return false
	if lab.get("sprite", "") != "field_lab" or lab.get("name", "") != "Field Lab" or lab.get("blurb", "") != "Researchers earn research points by day.": return false
	if typeof(lab.size) != TYPE_ARRAY or lab.size.size() != 2 or not _integer(lab.size[0]) or not _integer(lab.size[1]) or int(lab.size[0]) != 2 or int(lab.size[1]) != 2: return false
	if typeof(lab.cost) != TYPE_DICTIONARY or not _integer(lab.cost.get("wood", null)) or not _integer(lab.cost.get("scrap", null)): return false
	if int(lab.cost.wood) < 0 or int(lab.cost.scrap) < 0 or not _integer(lab.hp) or int(lab.hp) <= 0: return false
	if not _integer(lab.workers) or int(lab.workers) < 1 or not _integer(lab.unlock_day) or int(lab.unlock_day) < 1: return false
	if not _finite_number(lab.build_time) or float(lab.build_time) <= 0.0 or not _integer(lab.beds) or int(lab.beds) < 0: return false
	if not _integer(lab.get("max_count", 0)) or int(lab.get("max_count", 0)) != 1: return false
	return true

func _validate_morale(m: Dictionary, buildings: Dictionary) -> bool:
	if m.is_empty(): return false
	for key: String in ["baseline", "campfire_slots", "endless_milestone_every"]:
		if not _integer(m.get(key, null)): return false
	if int(m.baseline) < 0 or int(m.baseline) > 100 or int(m.campfire_slots) < 1 or int(m.endless_milestone_every) < 1: return false
	if typeof(m.get("bands", null)) != TYPE_ARRAY or m.bands.size() != 4: return false
	var ids: Array[String] = ["inspired", "steady", "low", "breaking"]
	var previous: int = 101
	for i: int in range(4):
		var band: Variant = m.bands[i]
		if typeof(band) != TYPE_DICTIONARY: return false
		if typeof(band.get("id", null)) != TYPE_STRING or str(band.id) != ids[i]: return false
		if typeof(band.get("name", null)) != TYPE_STRING or str(band.name).is_empty(): return false
		if not _integer(band.get("min", null)) or int(band.min) >= previous or int(band.min) < 0 or int(band.min) > 100: return false
		previous = int(band.min)
		if not _finite_number(band.get("work_mult", null)) or not _finite_number(band.get("hit_chance", null)): return false
		if float(band.work_mult) <= 0.0 or float(band.hit_chance) <= 0.0 or float(band.hit_chance) > 1.0: return false
		if i > 0 and (float(band.work_mult) > float(m.bands[i-1].work_mult) or float(band.hit_chance) > float(m.bands[i-1].hit_chance)): return false
	if int(m.bands[3].min) != 0 or float(m.bands[0].hit_chance) != 1.0 or float(m.bands[1].work_mult) != 1.0 or float(m.bands[1].hit_chance) != 1.0: return false
	var mood_ids: Array[String] = ["bed","no_bed","sheltered","hungry","hurt","campfire","quiet_night","rough_night","fresh_start","new_home","newcomers","death","left","scavenged","feast","day_off","radio_tower","rescued","still_standing"]
	if typeof(m.get("moods", null)) != TYPE_DICTIONARY: return false
	for id: String in mood_ids:
		var mood: Variant = m.moods.get(id, null)
		if typeof(mood) != TYPE_DICTIONARY: return false
		if typeof(mood.get("label", null)) != TYPE_STRING or str(mood.label).is_empty(): return false
		if not _integer(mood.get("value", null)) or int(mood.value) < -100 or int(mood.value) > 100: return false
		if not _integer(mood.get("days", null)) or int(mood.days) < 1: return false
		if not _integer(mood.get("stack", null)) or int(mood.stack) < 1 or int(mood.stack) > (2 if id in ["death", "left"] else 1): return false
		if id in ["death", "left"]:
			if not str(mood.label).contains("{name}"): return false
		elif str(mood.label).contains("{") or str(mood.label).contains("}"):
			return false
	for key: String in ["feast", "breaking"]:
		if typeof(m.get(key, null)) != TYPE_DICTIONARY: return false
	var feast: Dictionary = m.feast
	var breaking: Dictionary = m.breaking
	for pair: Array in [[feast,"food_per_survivor",0],[feast,"cooldown_days",1],[breaking,"leave_after_dawns",2],[breaking,"max_leavers_per_dawn",1]]:
		if not _integer(pair[0].get(pair[1], null)) or int(pair[0][pair[1]]) < int(pair[2]): return false
	if not _finite_number(m.get("day_off_morning_fraction", null)) or float(m.day_off_morning_fraction) <= 0.0 or float(m.day_off_morning_fraction) > 1.0: return false
	if not buildings.has("campfire"): return false
	var fire: Dictionary = buildings.campfire
	if fire.get("sprite", "") != "campfire" or fire.get("name", "") != "Campfire" or fire.get("blurb", "") != "Cheers up to 6 survivors every morning.": return false
	var fire_size: Variant = fire.get("size", null)
	if typeof(fire_size) != TYPE_ARRAY or fire_size.size() != 2 or not _finite_number(fire_size[0]) or not _finite_number(fire_size[1]) or float(fire_size[0]) != 1.0 or float(fire_size[1]) != 1.0: return false
	if typeof(fire.get("cost", null)) != TYPE_DICTIONARY: return false
	if not _integer(fire.cost.get("wood", null)) or not _integer(fire.cost.get("scrap", null)) or int(fire.cost.wood) < 0 or int(fire.cost.scrap) < 0: return false
	if not _integer(fire.get("hp", null)) or int(fire.hp) <= 0: return false
	for field: String in ["workers", "beds"]:
		if not _integer(fire.get(field, null)) or int(fire[field]) < 0: return false
	if not _integer(fire.get("unlock_day", null)) or int(fire.unlock_day) < 1: return false
	if not _finite_number(fire.get("build_time", null)) or float(fire.build_time) <= 0.0: return false
	return true

func _finite_number(value: Variant) -> bool:
	return _is_number(value) and is_finite(float(value))

func _integer(value: Variant) -> bool:
	return _is_number(value) and is_finite(float(value)) and floorf(float(value)) == float(value)

func _validate_zombies(z: Dictionary) -> bool:
	if z.is_empty(): return false
	var required_ids = ["walker", "runner", "brute"]
	for id in required_ids:
		if not z.has(id): return false
	var required_keys = ["hp", "speed", "damage", "attack_rate", "first_night", "target_priority", "scale", "tint"]
	for k in z.keys():
		var entry = z[k]
		if typeof(entry) != TYPE_DICTIONARY: return false
		for req in required_keys:
			if not entry.has(req): return false
		
		if not _is_number(entry["hp"]) or not _is_number(entry["speed"]) or not _is_number(entry["damage"]) or not _is_number(entry["attack_rate"]) or not _is_number(entry["first_night"]) or not _is_number(entry["scale"]): return false
		if typeof(entry["target_priority"]) != TYPE_STRING: return false
		if typeof(entry["tint"]) != TYPE_STRING: return false
		if entry.has("ranged"):
			if typeof(entry["ranged"]) != TYPE_DICTIONARY: return false
			var ranged: Dictionary = entry["ranged"]
			for key: String in ["range_tiles", "damage", "interval", "projectile_speed"]:
				if not _is_number(ranged.get(key, null)) or float(ranged[key]) <= 0.0:
					return false
	return true

func _validate_waves(w: Dictionary) -> bool:
	if w.is_empty(): return false
	var required_keys = ["walkers_base", "walkers_per_night", "runners_mult", "runners_offset", "brutes_mult", "brutes_offset", "sides_by_night", "spawn_window_fraction", "final_night", "final_multiplier", "final_sides", "endless_wave_mult"]
	for req in required_keys:
		if not w.has(req): return false
	
	if typeof(w["sides_by_night"]) != TYPE_DICTIONARY: return false
	if not _is_number(w["walkers_base"]) or not _is_number(w["walkers_per_night"]): return false
	if not _is_number(w["runners_mult"]) or not _is_number(w["runners_offset"]): return false
	if not _is_number(w["brutes_mult"]) or not _is_number(w["brutes_offset"]): return false
	if not _is_number(w["spawn_window_fraction"]): return false
	if not _is_number(w["final_night"]) or not _is_number(w["final_multiplier"]) or not _is_number(w["final_sides"]): return false
	if not _is_number(w["endless_wave_mult"]) or float(w["endless_wave_mult"]) <= 0.0: return false
	for key: String in ["spitters_mult", "spitters_offset", "spitters_div"]:
		if w.has(key) and (not _is_number(w[key]) or float(w[key]) < 0.0): return false
	if w.has("spitters_div") and float(w["spitters_div"]) <= 0.0: return false
	return true

func _validate_balance(bal: Dictionary) -> bool:
	if bal.is_empty(): return false
	var required_keys = [
		"start_food", "start_wood", "start_scrap", "start_ammo", "start_survivors", "survivor_hp",
		"day_length", "night_min_length", "food_eat_per_survivor", "food_hungry_speed", "food_hungry_leave_days",
		"food_newcomers_min", "food_newcomers_max", "food_newcomers_threshold", "map_size", "map_tile", "map_clear_radius",
		"map_trees_min", "map_trees_max", "map_scrap_min", "map_scrap_max", "map_rocks_min", "map_rocks_max",
		"repair_cost_fraction", "refund_before_build", "refund_after_build", "survivor_attack_range", "nights_to_win"
	]
	for req in required_keys:
		if not bal.has(req): return false
		if not _is_number(bal[req]): return false
	if not _validate_difficulty(bal.get("difficulty", null)):
		return false
	return true

func _validate_difficulty(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	var levels: Dictionary = value
	for level: String in ["easy", "normal", "hard"]:
		if typeof(levels.get(level, null)) != TYPE_DICTIONARY:
			return false
		var multipliers: Dictionary = levels[level]
		for key: String in ["wave_size_mult", "zombie_hp_mult", "start_resource_mult", "food_eaten_mult"]:
			if not _is_number(multipliers.get(key, null)) or float(multipliers[key]) < 0.0:
				return false
	return true

func difficulty_config(level: String) -> Dictionary:
	var levels: Dictionary = _balance.get("difficulty", {})
	if not levels.has(level) or typeof(levels[level]) != TYPE_DICTIONARY:
		push_warning("Unknown difficulty '%s'; using normal" % level)
		return (levels.get("normal", {}) as Dictionary).duplicate()
	return (levels[level] as Dictionary).duplicate()

func _is_number(val: Variant) -> bool:
	return typeof(val) == TYPE_INT or typeof(val) == TYPE_FLOAT

func building_ids() -> PackedStringArray:
	return PackedStringArray(_buildings.keys())

func get_building(id: String) -> Dictionary:
	if not _buildings.has(id):
		push_error("Building not found: " + id)
		return {}
	return _buildings[id]

func zombie_ids() -> PackedStringArray:
	return PackedStringArray(_zombies.keys())

func get_zombie(id: String) -> Dictionary:
	if not _zombies.has(id):
		push_error("Zombie not found: " + id)
		return {}
	return _zombies[id]

func balance(key: String, default_value: Variant = null) -> Variant:
	return _balance.get(key, default_value)

func expeditions() -> Dictionary:
	return _expeditions

func weather_config() -> Dictionary:
	return _weather

func morale_config() -> Dictionary:
	return _morale

func tech_config() -> Dictionary:
	return _tech

func wave_value(key: String, default_value: Variant = null) -> Variant:
	return _waves.get(key, default_value)

func final_night() -> int:
	return int(_waves.get("final_night", 20))

func wave_for_night(n: int) -> Dictionary:
	if _waves.is_empty():
		return {"walker": 0, "runner": 0, "brute": 0, "spitter": 0, "sides": 0, "final": false}
	
	var is_final: bool = (n == final_night())
	
	var base_walkers: int = int(_waves.get("walkers_base", 4)) + int(_waves.get("walkers_per_night", 3)) * n
	var runners_base: int = n - int(_waves.get("runners_offset", 3))
	var base_runners: int = 0
	if runners_base > 0:
		base_runners = int(_waves.get("runners_mult", 2)) * runners_base
		
	var brutes_base: int = n - int(_waves.get("brutes_offset", 7))
	var base_brutes: int = 0
	if brutes_base > 0:
		base_brutes = int(_waves.get("brutes_mult", 1)) * brutes_base
	
	var base_spitters: int = 0
	if _waves.has("spitters_mult") and _waves.has("spitters_offset") and _waves.has("spitters_div"):
		var divisor: float = float(_waves["spitters_div"])
		if divisor > 0.0:
			base_spitters = maxi(0, floori((n - float(_waves["spitters_offset"])) / divisor)) * int(_waves["spitters_mult"])

	var sides: int = 1
	var thresholds: Dictionary = _waves.get("sides_by_night", {})
	var side_keys = thresholds.keys()
	var sorted_keys = []
	for k in side_keys:
		sorted_keys.append(int(k))
	sorted_keys.sort()
	for k in sorted_keys:
		if n >= k:
			sides = int(thresholds[str(k)])
	
	if is_final:
		var mult: int = int(_waves.get("final_multiplier", 2))
		base_walkers *= mult
		base_runners *= mult
		base_brutes *= mult
		base_spitters *= mult
		sides = int(_waves.get("final_sides", 4))
		
	return {
		"walker": base_walkers,
		"runner": base_runners,
		"brute": base_brutes,
		"spitter": base_spitters,
		"sides": sides,
		"final": is_final
	}

func buildings_unlocked_on(day: int) -> PackedStringArray:
	var unlocked = PackedStringArray()
	for id in _buildings.keys():
		var b = _buildings[id]
		if int(b.get("unlock_day", 999)) <= day:
			unlocked.append(id)
	return unlocked
