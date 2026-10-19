class_name TestDawnReport extends TestCase

func _reach_dawn(state: GameState) -> void:
	state.clock.phase = GameClock.Phase.NIGHT
	state.clock.elapsed = float(state.data.balance("night_min_length")) - 0.1
	state.tick(0.2)

func _get_passable_tiles(state: GameState, count: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for x in range(-5, 5):
		for y: int in range(-5, 5):
			var t: Vector2i = Vector2i(x, y)
			if state.map.is_passable(t) and not state.buildings.get_at(t):
				tiles.append(t)
				if tiles.size() >= count:
					return tiles
	return tiles

func test_staged_night() -> void:
	var state: GameState = GameState.new(GameData.load_default(), 1337)
	state.waves.enabled = false
	
	state.clock.phase_changed.emit(GameClock.Phase.NIGHT, state.clock.day)
	
	for i: int in range(3):
		var z: Zombie = state.spawn_zombie("walker", Vector2(100, 100))
		state.damage_zombie(z, 9999)
		
	var tiles: Array[Vector2i] = _get_passable_tiles(state, 2)
	var w1: Building = state.buildings.add("wooden_wall", tiles[0], true)
	var w2: Building = state.buildings.add("wooden_wall", tiles[1], true)
	state.damage_building(w1, w1.hp)
	state.damage_building(w2, 30)
	
	var cc: Building = state.buildings.all_of_type("command_center")[0]
	state.damage_building(cc, 40)
	
	var s: Survivor = state.survivors.all()[0]
	var s_name: String = s.name
	state.damage_survivor(s, s.hp)
	
	_reach_dawn(state)
	
	var report: Dictionary = state.last_dawn_report
	assert_eq(int(report["night"]), 1, "night 1")
	assert_eq(int(report["zombies_killed"]), 3, "3 zombies")
	assert_eq(Array(report["buildings_destroyed"]), ["Wooden Wall"], "wall destroyed")
	assert_eq(int(report["buildings_damaged"]), 1, "1 building damaged")
	assert_eq(int(report["cc_damage"]), 40, "40 cc damage")
	assert_true(Array(report["survivors_killed"]).has(s_name), "survivor killed name")

func test_cc_clamp() -> void:
	var state: GameState = GameState.new(GameData.load_default(), 1337)
	state.waves.enabled = false
	state.clock.phase_changed.emit(GameClock.Phase.NIGHT, state.clock.day)
	
	var cc: Building = state.buildings.all_of_type("command_center")[0]
	state.damage_building(cc, cc.hp - 30) # leave 30 hp
	state.night_log.cc_damage = 0 # reset from setup
	
	state.damage_building(cc, 100) # overkill
	_reach_dawn(state)
	assert_eq(int(state.last_dawn_report["cc_damage"]), 30, "cc damage clamped to remaining hp")

func test_per_night() -> void:
	var state: GameState = GameState.new(GameData.load_default(), 1337)
	state.waves.enabled = false
	
	state.clock.phase_changed.emit(GameClock.Phase.NIGHT, state.clock.day)
	var z1: Zombie = state.spawn_zombie("walker", Vector2(100, 100))
	state.damage_zombie(z1, 9999)
	var t: Vector2i = _get_passable_tiles(state, 1)[0]
	var w1: Building = state.buildings.add("wooden_wall", t, true)
	state.damage_building(w1, w1.hp)
	var cc: Building = state.buildings.all_of_type("command_center")[0]
	state.damage_building(cc, 10)
	_reach_dawn(state)
	
	assert_eq(int(state.last_dawn_report["night"]), 1)
	
	state.clock.phase_changed.emit(GameClock.Phase.NIGHT, state.clock.day)
	var z2: Zombie = state.spawn_zombie("walker", Vector2(100, 100))
	state.damage_zombie(z2, 9999)
	_reach_dawn(state)
	
	var report: Dictionary = state.last_dawn_report
	assert_eq(int(report["night"]), 2, "night 2")
	assert_eq(int(report["zombies_killed"]), 1, "only 1 zombie killed in night 2")
	assert_eq(Array(report["buildings_destroyed"]), [], "no buildings destroyed in night 2")
	assert_eq(int(report["cc_damage"]), 0, "no cc damage in night 2")

func test_unlocked() -> void:
	var state: GameState = GameState.new(GameData.load_default(), 1337)
	state.waves.enabled = false
	state.clock.phase_changed.emit(GameClock.Phase.NIGHT, state.clock.day)
	_reach_dawn(state)
	assert_eq(Array(state.last_dawn_report["unlocked"]), ["Campfire", "Storage", "Watchtower", "Workshop"])
	
	state.clock.day = 4
	state.clock.phase_changed.emit(GameClock.Phase.NIGHT, state.clock.day)
	_reach_dawn(state)
	assert_eq(Array(state.last_dawn_report["unlocked"]), [])
	
	state.clock.day = 7
	state.clock.phase_changed.emit(GameClock.Phase.NIGHT, state.clock.day)
	_reach_dawn(state)
	assert_eq(Array(state.last_dawn_report["unlocked"]), ["Radio Tower"])

func test_objective() -> void:
	var text: String
	
	text = DawnReport.objective_text(2, 20, "none", 8)
	assert_eq(text, "Build the Radio Tower (unlocks day 8). 19 nights to go.")
	
	text = DawnReport.objective_text(9, 20, "none", 8)
	assert_eq(text, "Build the Radio Tower. 12 nights to go.")
	
	text = DawnReport.objective_text(9, 20, "building", 8)
	assert_eq(text, "Radio Tower under construction. 12 nights to go.")
	
	text = DawnReport.objective_text(18, 20, "complete", 8)
	assert_eq(text, "Radio Tower ready. Survive 3 more nights for rescue.")
	
	text = DawnReport.objective_text(20, 20, "complete", 8)
	assert_eq(text, "Radio Tower ready. Survive 1 more night for rescue.")
	
	text = DawnReport.objective_text(21, 20, "complete", 8)
	assert_eq(text, "Radio Tower ready. Rescue comes at the next dawn.")
	
	text = DawnReport.objective_text(21, 20, "none", 8)
	assert_eq(text, "Nights are getting worse. Finish the Radio Tower!")
	
	text = DawnReport.objective_text(21, 20, "building", 8)
	assert_eq(text, "Nights are getting worse. Finish the Radio Tower!")
	
	text = DawnReport.objective_text(20, 20, "none", 8) # 1 night left, none
	assert_eq(text, "Build the Radio Tower. 1 night to go.")

func test_lines() -> void:
	var report: Dictionary = {
		"zombies_killed": 5,
		"survivors_killed": ["Alice", "Bob"],
		"buildings_destroyed": ["Farm"],
		"buildings_damaged": 2,
		"cc_damage": 15,
		"food_eaten": 10,
		"hungry": ["Charlie"],
		"left": ["Dave"],
		"arrived": ["Eve"],
		"unlocked": ["Turret"],
		"objective": "Build the Radio Tower. 12 nights to go."
	}
	var out: Array[String] = DawnReport.lines(report)
	assert_eq(out[0], "Zombies killed: 5")
	assert_eq(out[1], "Lost: Alice, Bob")
	assert_eq(out[2], "Destroyed: Farm")
	assert_eq(out[3], "Damaged: 2 buildings")
	assert_eq(out[4], "Command Center took 15 damage")
	assert_eq(out[5], "Food eaten: 10")
	assert_eq(out[6], "Hungry: Charlie")
	assert_eq(out[7], "Left: Dave")
	assert_eq(out[8], "Arrived: Eve")
	assert_eq(out[9], "New buildings unlocked: Turret")
	assert_eq(out[10], "Build the Radio Tower. 12 nights to go.")
	
	var r2: Dictionary = {
		"food_eaten": 4,
		"objective": "Keep going."
	}
	var out2: Array[String] = DawnReport.lines(r2)
	assert_eq(out2.size(), 2)
	assert_eq(out2[0], "Food eaten: 4")
	assert_eq(out2[1], "Keep going.")
	
	var r3: Dictionary = {
		"buildings_damaged": 1
	}
	var out3: Array[String] = DawnReport.lines(r3)
	assert_eq(out3[0], "Damaged: 1 building")
	assert_eq(out3.size(), 1)

func test_existing_keys() -> void:
	var state: GameState = GameState.new(GameData.load_default(), 1337)
	state.waves.enabled = false
	state.clock.phase_changed.emit(GameClock.Phase.NIGHT, state.clock.day)
	_reach_dawn(state)
	
	var report: Dictionary = state.last_dawn_report
	assert_true(report.has("day"))
	assert_true(report.has("food_eaten"))
	assert_true(report.has("hungry"))
	assert_true(report.has("left"))
	assert_true(report.has("arrived"))

func test_no_ref_cycles() -> void:
	var state: GameState = GameState.new(GameData.load_default(), 1337)
	state.waves.enabled = false
	state.clock.phase_changed.emit(GameClock.Phase.NIGHT, state.clock.day)
	var z1: Zombie = state.spawn_zombie("walker", Vector2(100, 100))
	state.damage_zombie(z1, 9999)
	_reach_dawn(state)
	
	var wr: WeakRef = weakref(state)
	state = null
	assert_true(wr.get_ref() == null, "state should free cleanly")

func test_existing_values_match_dawn_rules() -> void:
	# Fed, hungry/leaving, and newcomer dawns must retain DawnRules' values and RNG use.
	for mode: int in range(3):
		var state: GameState = GameState.new(GameData.load_default(), 1337)
		var baseline: GameState = GameState.new(GameData.load_default(), 1337)
		for fixture: GameState in [state, baseline]:
			fixture.waves.enabled = false
			for survivor: Survivor in fixture.survivors.all():
				fixture.set_job(survivor.uid, Survivor.Job.IDLE)
			if mode == 1:
				fixture.resources.take("food", fixture.resources.get_amount("food"))
				var leaving: Survivor = fixture.survivors.all()[0]
				leaving.hungry_days = int(fixture.data.balance("food_hungry_leave_days")) - 1
			elif mode == 2:
				var casualty: Survivor = fixture.survivors.all()[0]
				fixture.damage_survivor(casualty, casualty.hp)
			fixture.clock.phase_changed.emit(GameClock.Phase.NIGHT, fixture.clock.day)
		baseline.clock.day = 2
		var expected: Dictionary = DawnRules.process(baseline)
		_reach_dawn(state)
		for key: String in ["day", "food_eaten", "hungry", "left", "arrived"]:
			assert_eq(state.last_dawn_report.get(key), expected[key], "mode %d: %s" % [mode, key])
		assert_eq(state.resources.get_amount("food"), baseline.resources.get_amount("food"))
		assert_eq(state.rng.state, baseline.rng.state, "report does not consume extra RNG")
		if mode == 1:
			assert_gt(Array(expected["hungry"]).size(), 0)
			assert_eq(Array(expected["left"]).size(), 1)
		elif mode == 2:
			assert_gt(Array(expected["arrived"]).size(), 0)

func test_lines_skips_explicit_zero_and_empty_sections() -> void:
	var report: Dictionary = {
		"zombies_killed": 0, "survivors_killed": [], "buildings_destroyed": [],
		"buildings_damaged": 0, "cc_damage": 0, "food_eaten": 0,
		"hungry": [], "left": [], "arrived": [], "unlocked": [], "objective": ""
	}
	assert_eq(Array(DawnReport.lines(report)), [])
	assert_eq(Array(DawnReport.lines({})), [])
	assert_eq(DawnReport.objective_text(20, 20, "building", 8),
		"Radio Tower under construction. 1 night to go.")
	assert_eq(DawnReport.objective_text(2, 10, "none", 4),
		"Build the Radio Tower (unlocks day 4). 9 nights to go.")

func test_dawn_objective_uses_tower_state_and_data() -> void:
	var data: GameData = GameData.load_default()
	data._balance["nights_to_win"] = 10
	data._buildings["radio_tower"]["unlock_day"] = 4
	var state: GameState = GameState.new(data, 1337)
	state.waves.enabled = false
	state.clock.phase_changed.emit(GameClock.Phase.NIGHT, state.clock.day)
	_reach_dawn(state)
	assert_eq(state.last_dawn_report["objective"],
		"Build the Radio Tower (unlocks day 4). 9 nights to go.")
	var origin: Vector2i = Vector2i(-1, -1)
	var map_size: int = int(data.balance("map_size"))
	for x: int in range(map_size - 1):
		for y: int in range(map_size - 1):
			var tile: Vector2i = Vector2i(x, y)
			var free: bool = true
			for offset: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]:
				if not state.map.is_passable(tile + offset) or state.buildings.get_at(tile + offset) != null:
					free = false
			if free:
				origin = tile
				break
		if origin != Vector2i(-1, -1):
			break
	assert_ne(origin, Vector2i(-1, -1), "free 2x2 tower footprint")
	if origin == Vector2i(-1, -1):
		return
	var tower: Building = state.buildings.add("radio_tower", origin, false)
	state.clock.phase_changed.emit(GameClock.Phase.NIGHT, state.clock.day)
	_reach_dawn(state)
	assert_eq(state.last_dawn_report["objective"], "Radio Tower under construction. 8 nights to go.")
	state.buildings.finish(tower.uid)
	state.clock.phase_changed.emit(GameClock.Phase.NIGHT, state.clock.day)
	_reach_dawn(state)
	assert_eq(state.last_dawn_report["objective"], "Radio Tower ready. Survive 7 more nights for rescue.")
