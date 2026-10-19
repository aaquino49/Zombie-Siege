class_name TestSaveGame extends TestCase

var data: GameData

func before_each() -> void:
	data = GameData.load_default()

func after_each() -> void:
	data = null

func _free_tile_near(state: GameState, center: Vector2i, size: Vector2i, radius: int = 12) -> Vector2i:
	var origin: Vector2i = state.map.command_center_origin()
	for r: int in range(3, radius + 1):
		for y: int in range(origin.y - r, origin.y + 2 + r):
			for x: int in range(origin.x - r, origin.x + 2 + r):
				if x in [origin.x - r, origin.x + 1 + r] or y in [origin.y - r, origin.y + 1 + r]:
					var t := Vector2i(x, y)
					if state.map.is_free(t, size):
						return t
	return Vector2i(-1, -1)

func _build_day4_state() -> GameState:
	var state := GameState.new(data, 1337)
	state.waves.enabled = false
	state.resources.add("wood", 5000)
	state.resources.add("scrap", 5000)
	state.resources.add("food", 500)
	var guard: int = 0
	while state.clock.day < 4:
		if state.clock.phase == GameClock.Phase.DAY and guard < 200:
			_assign_jobs(state)
			guard += 1
		state.tick(2.0)
		if state.game_over:
			break
	# Completed shelter + farm, one blueprint with progress, one upgraded wall.
	var shelter_pos := _free_tile_near(state, state.map.command_center_origin(), Vector2i(2, 2))
	if shelter_pos.x >= 0:
		state.try_place("shelter", shelter_pos)
		var shelter: Building = state.buildings.get_at(shelter_pos)
		if shelter != null:
			state.buildings.finish(shelter.uid)
	var farm_pos := _free_tile_near(state, state.map.command_center_origin(), Vector2i(2, 2))
	if farm_pos.x >= 0:
		state.try_place("farm", farm_pos)
		var farm: Building = state.buildings.get_at(farm_pos)
		if farm != null:
			state.buildings.finish(farm.uid)
	var wall_pos := _free_tile_near(state, state.map.command_center_origin(), Vector2i(1, 1))
	var wall: Building = null
	if wall_pos.x >= 0:
		state.try_place("wooden_wall", wall_pos)
		wall = state.buildings.get_at(wall_pos)
		if wall != null:
			state.buildings.finish(wall.uid)
			state.damage_building(wall, 10)
	var bp_pos := _free_tile_near(state, state.map.command_center_origin(), Vector2i(1, 1))
	if bp_pos.x >= 0:
		state.try_place("watchtower", bp_pos)
		var bp: Building = state.buildings.get_at(bp_pos)
		if bp != null:
			bp.progress = 2.0
	# Reinforced wall carrying an upgrade history (placed directly, check bypassed).
	var re_pos := _free_tile_near(state, state.map.command_center_origin(), Vector2i(1, 1))
	if re_pos.x >= 0:
		var re: Building = state.buildings.add("reinforced_wall", re_pos, true)
		re.upgraded_from = "wooden_wall"
	# Deplete one tree node entirely.
	var trees: Array[Vector2i] = state.map.nodes_of(WorldMap.Occupant.TREE)
	if not trees.is_empty():
		state.map.harvest(trees[0], 999999)
	# Partially harvest a second node so amounts differ from generation.
	trees = state.map.nodes_of(WorldMap.Occupant.TREE)
	if trees.size() > 1:
		state.map.harvest(trees[1], 3)
	# Lose one survivor, vary jobs and hunger bookkeeping.
	var people: Array[Survivor] = state.survivors.all()
	people.sort_custom(func(a: Survivor, b: Survivor) -> bool: return a.uid < b.uid)
	if people.size() >= 4:
		state.set_job(people[0].uid, Survivor.Job.BUILDER)
		state.set_job(people[1].uid, Survivor.Job.GATHERER, "scrap")
		state.set_job(people[2].uid, Survivor.Job.FARMER)
		people[2].hungry_days = 1
		state.damage_survivor(people[3], 99999)
	# Park a survivor inside the shelter so restore must relocate them.
	var shelters: Array[Building] = state.buildings.all_of_type("shelter")
	var remaining: Array[Survivor] = state.survivors.all()
	if not shelters.is_empty() and not remaining.is_empty():
		remaining.sort_custom(func(a: Survivor, b: Survivor) -> bool: return a.uid < b.uid)
		remaining[0].pos = Grid.tile_to_world(shelters[0].origin)
	state.tick(0.1)
	return state

func _assign_jobs(state: GameState) -> void:
	var people: Array[Survivor] = state.survivors.all()
	people.sort_custom(func(a: Survivor, b: Survivor) -> bool: return a.uid < b.uid)
	for i: int in range(people.size()):
		if i == 0:
			state.set_job(people[i].uid, Survivor.Job.BUILDER)
		elif i == 1:
			state.set_job(people[i].uid, Survivor.Job.GATHERER, "wood")
		elif i == 2:
			state.set_job(people[i].uid, Survivor.Job.GATHERER, "scrap")

func _assert_captures_equal(a: Dictionary, b: Dictionary) -> void:
	assert_eq(int(a.get("version")), int(b.get("version")), "version")
	assert_eq(int(a.get("map_seed")), int(b.get("map_seed")), "map_seed")
	assert_eq(int(a.get("day")), int(b.get("day")), "day")
	var ares: Dictionary = a.get("resources")
	var bres: Dictionary = b.get("resources")
	for kind: String in ["food", "wood", "scrap", "ammo"]:
		assert_eq(int(ares.get(kind)), int(bres.get(kind)), "resource " + kind)
	assert_eq(int(a.get("buildings_next_uid")), int(b.get("buildings_next_uid")), "buildings_next_uid")
	assert_eq(int(a.get("survivors_next_uid")), int(b.get("survivors_next_uid")), "survivors_next_uid")
	var ab: Array = a.get("buildings")
	var bb: Array = b.get("buildings")
	assert_eq(ab.size(), bb.size(), "building count")
	for i: int in range(ab.size()):
		var ea: Dictionary = ab[i]
		var eb: Dictionary = bb[i]
		assert_eq(int(ea["uid"]), int(eb["uid"]), "building uid")
		assert_eq(str(ea["type_id"]), str(eb["type_id"]), "building type")
		assert_eq([int((ea["origin"] as Array)[0]), int((ea["origin"] as Array)[1])], [int((eb["origin"] as Array)[0]), int((eb["origin"] as Array)[1])], "building origin")
		assert_eq(int(ea["hp"]), int(eb["hp"]), "building hp")
		assert_eq(bool(ea["complete"]), bool(eb["complete"]), "building complete")
		assert_almost_eq(float(ea["progress"]), float(eb["progress"]), 0.001, "building progress")
		assert_eq(str(ea.get("upgraded_from", "")), str(eb.get("upgraded_from", "")), "upgraded_from")
	var asur: Array = a.get("survivors")
	var bsur: Array = b.get("survivors")
	assert_eq(asur.size(), bsur.size(), "survivor count")
	for i: int in range(asur.size()):
		var sa: Dictionary = asur[i]
		var sb: Dictionary = bsur[i]
		assert_eq(int(sa["uid"]), int(sb["uid"]), "survivor uid")
		assert_eq(str(sa["name"]), str(sb["name"]), "survivor name")
		assert_eq(str(sa["variant"]), str(sb["variant"]), "survivor variant")
		assert_eq(int(sa["hp"]), int(sb["hp"]), "survivor hp")
		assert_eq(int(sa["max_hp"]), int(sb["max_hp"]), "survivor max_hp")
		assert_eq(str(sa["job"]), str(sb["job"]), "survivor job")
		assert_eq(str(sa["gather_kind"]), str(sb["gather_kind"]), "gather_kind")
		assert_eq(int(sa["hungry_days"]), int(sb["hungry_days"]), "hungry_days")
		assert_eq([int((sa["tile"] as Array)[0]), int((sa["tile"] as Array)[1])], [int((sb["tile"] as Array)[0]), int((sb["tile"] as Array)[1])], "survivor tile")
	var an: Array = a.get("nodes")
	var bn: Array = b.get("nodes")
	assert_eq(an.size(), bn.size(), "node count")
	for i: int in range(an.size()):
		var na: Dictionary = an[i]
		var nb: Dictionary = bn[i]
		assert_eq([int((na["tile"] as Array)[0]), int((na["tile"] as Array)[1])], [int((nb["tile"] as Array)[0]), int((nb["tile"] as Array)[1])], "node tile")
		assert_eq(int(na["occupant"]), int(nb["occupant"]), "node occupant")
		assert_eq(int(na["amount"]), int(nb["amount"]), "node amount")
	var sast: Dictionary = a.get("stats")
	var bsst: Dictionary = b.get("stats")
	for key: String in ["zombies_killed", "survivors_lost", "buildings_lost", "buildings_built", "survivors_left"]:
		assert_eq(int(sast[key]), int(bsst[key]), "stat " + key)
	assert_almost_eq(float(sast["time_played"]), float(bsst["time_played"]), 0.05, "time_played")
	assert_eq(int(a.get("rng_state")), int(b.get("rng_state")), "rng_state")
	assert_eq(a.get("extra"), b.get("extra"), "extra")

func test_round_trip_equals() -> void:
	var state := _build_day4_state()
	state.rng.state = -9147944165202818575
	assert_eq(state.clock.phase, GameClock.Phase.DAY, "capture happens at dawn/day")
	assert_eq(state.zombies.count(), 0, "no zombies at dawn")
	assert_true(state.clock.day >= 4, "day 4 or later")
	assert_false(state.buildings.blueprints().is_empty(), "a blueprint is in progress")
	assert_false(state.buildings.damaged().is_empty(), "a building is damaged")
	assert_gt(state.survivors_lost, 0, "a survivor was lost")
	var save1: Dictionary = SaveGame.capture(state, {"hint_seen": true})
	assert_false(save1.is_empty(), "capture succeeds at dawn")
	var norm1: Dictionary = SaveGame.from_json(SaveGame.to_json(save1))
	assert_false(norm1.is_empty(), "JSON round trip parses")
	var restored: GameState = SaveGame.restore(data, norm1)
	assert_not_null(restored, "restore succeeds")
	var save2: Dictionary = SaveGame.capture(restored, norm1.get("extra", {}))
	assert_false(save2.is_empty(), "recapture succeeds")
	_assert_captures_equal(norm1, save2)

func test_rng_state_and_sequence_survive_json_round_trip() -> void:
	var original := GameState.new(data, 1337)
	original.waves.enabled = false
	original.rng.state = 2343518260280137770
	var original_rng_state: int = original.rng.state
	var save: Dictionary = SaveGame.capture(original)
	assert_eq(save.get("rng_state"), str(original_rng_state), "rng_state is stored as decimal text")
	var decoded: Dictionary = SaveGame.from_json(SaveGame.to_json(save))
	assert_true(typeof(decoded.get("rng_state")) == TYPE_STRING, "JSON round trip keeps rng_state as text")
	var restored: GameState = SaveGame.restore(data, decoded)
	assert_not_null(restored, "restore succeeds")
	assert_eq(restored.rng.state, original_rng_state, "restored RNG state is exact")
	var expected_rng := RandomNumberGenerator.new()
	expected_rng.seed = original.rng.seed
	expected_rng.state = original.rng.state
	for i: int in range(5):
		assert_eq(restored.rng.randi(), expected_rng.randi(), "next RNG value %d matches" % i)

func test_restored_plays_through_night() -> void:
	var state := _build_day4_state()
	var restored: GameState = SaveGame.restore(data, SaveGame.from_json(SaveGame.to_json(SaveGame.capture(state))))
	assert_not_null(restored, "restore succeeds")
	var start_day: int = restored.clock.day
	restored.waves.enabled = true
	var saw_zombie: bool = false
	var steps: int = 0
	while steps < 3000:
		restored.tick(0.5)
		steps += 1
		if restored.zombies.count() > 0:
			saw_zombie = true
		if restored.clock.day == start_day + 1 and restored.clock.phase == GameClock.Phase.DAY:
			break
	assert_true(saw_zombie, "zombies spawned during the next night")
	assert_eq(restored.clock.day, start_day + 1, "reached the next dawn")
	assert_eq(restored.clock.phase, GameClock.Phase.DAY, "phase is DAY at dawn")
	assert_eq(restored.zombies.count(), 0, "dawn cleared zombies")

func test_shelter_tile_moved_and_uids_continue() -> void:
	var state := _build_day4_state()
	var save1: Dictionary = SaveGame.capture(state)
	var restored: GameState = SaveGame.restore(data, SaveGame.from_json(SaveGame.to_json(save1)))
	assert_not_null(restored, "restore succeeds")
	for s: Survivor in restored.survivors.all():
		var t: Vector2i = s.tile()
		var ok: bool = restored.map.is_passable(t) or restored.map.building_at(t) == "gate"
		assert_true(ok, "survivor %d on passable tile" % s.uid)
		assert_false(s.sheltered, "restored survivor is not sheltered")
	var expected_uid: int = int(save1["buildings_next_uid"])
	restored.resources.add("wood", 5000)
	restored.resources.add("scrap", 5000)
	var spot := Vector2i(-1, -1)
	for y: int in range(restored.map.size()):
		for x: int in range(restored.map.size()):
			var t := Vector2i(x, y)
			if restored.map.is_free(t, Vector2i(1, 1)):
				spot = t
				break
		if spot.x >= 0:
			break
	assert_ne(spot, Vector2i(-1, -1), "a free tile exists")
	assert_eq(restored.try_place("wooden_wall", spot), Placement.Result.OK, "place after restore")
	var placed: Building = restored.buildings.get_at(spot)
	assert_not_null(placed, "placed building exists")
	assert_eq(placed.uid, expected_uid, "uids continue from save")
	assert_eq(restored.buildings.next_uid(), expected_uid + 1, "next uid advanced")
	assert_eq(restored.survivors.next_uid(), int(save1["survivors_next_uid"]), "survivor next uid preserved")

func test_capture_refuses_night_and_game_over() -> void:
	var night_state := GameState.new(data, 4242)
	night_state.clock.phase = GameClock.Phase.NIGHT
	night_state.spawn_zombie("walker", Vector2(32, 32))
	assert_true(SaveGame.capture(night_state).is_empty(), "capture refuses with zombies alive")
	var over_state := GameState.new(data, 4242)
	over_state.game_over = true
	assert_true(SaveGame.capture(over_state).is_empty(), "capture refuses after game over")
	var won_state := GameState.new(data, 4242)
	won_state.won = true
	assert_true(SaveGame.capture(won_state).is_empty(), "capture refuses after victory")

func test_restore_refuses_bad_versions_and_garbage() -> void:
	var state := _build_day4_state()
	var good: Dictionary = SaveGame.from_json(SaveGame.to_json(SaveGame.capture(state)))
	var bad0: Dictionary = good.duplicate(true)
	bad0["version"] = 0
	assert_eq(SaveGame.restore(data, bad0), null, "version 0 refused")
	var bad99: Dictionary = good.duplicate(true)
	bad99["version"] = 99
	assert_eq(SaveGame.restore(data, bad99), null, "version 99 refused")
	assert_eq(SaveGame.restore(data, {}), null, "empty refused")
	assert_eq(SaveGame.restore(data, {"foo": 1}), null, "garbage refused")
	assert_true(SaveGame.from_json("not json{{{").is_empty(), "bad JSON gives {}")
	assert_eq(SaveGame.restore(data, SaveGame.from_json("not json{{{")), null, "bad JSON restore refused")
	var missing: Dictionary = good.duplicate(true)
	missing.erase("buildings")
	assert_eq(SaveGame.restore(data, missing), null, "missing section refused")
