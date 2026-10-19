extends "res://tests/test_case.gd"

func test_mood_catalog_and_band_boundaries() -> void:
	var state := GameState.new(GameData.load_default(), 215)
	var s: Survivor = state.survivors.all()[0]
	assert_eq(state.data.morale_config().moods.size(), 19)
	for pair: Array in [[75,"inspired"],[74,"steady"],[40,"steady"],[39,"low"],[20,"low"],[19,"breaking"]]:
		s.morale = pair[0]
		assert_eq(Morale.band(state, s).id, pair[1], "Boundary %d" % pair[0])

func test_mood_stacks_replace_oldest_and_recompute() -> void:
	var state := GameState.new(GameData.load_default(), 216)
	var s: Survivor = state.survivors.all()[0]
	s.moods.clear()
	Morale.add_mood(state, s, "death", "A")
	Morale.add_mood(state, s, "death", "B")
	Morale.add_mood(state, s, "death", "C")
	assert_eq(s.moods.size(), 2)
	assert_eq(s.moods[0].label, "B died")
	assert_eq(s.morale, 26)

func test_work_rates_and_hungry_low_combination() -> void:
	var state := GameState.new(GameData.load_default(), 217)
	var s: Survivor = state.survivors.all()[0]
	for pair: Array in [[80,1.15],[50,1.0],[30,0.85],[10,0.7]]:
		s.morale = pair[0]
		assert_almost_eq(Morale.work_mult(state, s), pair[1])
	s.morale = 30
	assert_almost_eq(Morale.work_mult(state, s) * float(state.data.balance("food_hungry_speed")), 0.425)

func test_founders_start_at_sixty_and_expiry_returns_to_baseline() -> void:
	var state := GameState.new(GameData.load_default(), 218)
	var s: Survivor = state.survivors.all()[0]
	assert_eq(s.morale, 60)
	Morale.begin_dawn(state)
	assert_eq(s.morale, 60)
	Morale.begin_dawn(state)
	assert_eq(s.morale, 50)

func test_all_mood_values_and_lifetimes_match_contract() -> void:
	var state := GameState.new(GameData.load_default(), 224)
	var expected := {
		"bed":[5,1],"no_bed":[-10,1],"sheltered":[2,1],"hungry":[-15,1],"hurt":[-8,1],
		"campfire":[6,1],"quiet_night":[4,1],"rough_night":[-6,1],"fresh_start":[10,2],
		"new_home":[10,2],"newcomers":[4,2],"death":[-12,3],"left":[-6,2],"scavenged":[8,2],
		"feast":[10,3],"day_off":[12,2],"radio_tower":[10,5],"rescued":[20,5],"still_standing":[8,3]
	}
	for id: String in expected:
		var mood: Dictionary = state.data.morale_config()["moods"][id]
		assert_eq([int(mood.value),int(mood.days)], expected[id], id)

func test_arrival_and_death_moods_apply_to_the_right_survivors() -> void:
	var state := GameState.new(GameData.load_default(), 225)
	var existing: Survivor = state.survivors.all()[0]
	var newcomer: Survivor = state.survivors.add("New", "blue", existing.tile() + Vector2i.RIGHT)
	Morale.on_arrived(state, newcomer)
	assert_true(_has(existing, "newcomers"))
	assert_true(_has(newcomer, "new_home"))
	assert_false(_has(newcomer, "newcomers"))
	state.damage_survivor(newcomer, newcomer.hp)
	assert_true(_has(existing, "death"))
	assert_false(_has(newcomer, "death"))

func test_dawn_snapshots_shelter_beds_and_excludes_new_arrival_from_last_night() -> void:
	var state := GameState.new(GameData.load_default(), 226)
	var residents: Array[Survivor] = state.survivors.all()
	for i: int in range(2):
		state.survivors.add("Extra%d" % i, "blue", residents[0].tile() + Vector2i(i + 2, 0))
	residents = state.survivors.all()
	residents[0].sheltered = true
	for person: Survivor in residents: person.job = Survivor.Job.IDLE
	residents[1].job = Survivor.Job.GUARD
	residents[2].hungry_days = 1
	residents[2].hp = 20
	state.buildings.add("campfire", Vector2i(20, 20), true)
	Morale.begin_dawn(state)
	var newcomer: Survivor = state.survivors.add("Dawn newcomer", "blue", residents[0].tile() + Vector2i(3, 0))
	Morale.on_arrived(state, newcomer)
	var report := {"left":[] as Array[String],"cc_damage":0,"buildings_destroyed":[],"survivors_killed":[],"scavenging":[]}
	Morale.end_dawn(state, report)
	assert_true(_has(residents[0], "sheltered"))
	assert_true(_has(residents[2], "hungry"))
	assert_true(_has(residents[2], "hurt"))
	assert_true(_has(residents[0], "bed"))
	assert_true(_has(residents[1], "no_bed") == false, "night-duty guards do not receive bed moods")
	assert_true(_has(residents[5], "no_bed"), "Bed allocation stops after four non-duty residents")
	assert_false(_has(newcomer, "sheltered"))
	assert_false(_has(newcomer, "bed"))
	assert_false(_has(newcomer, "quiet_night"))
	assert_true(_has(residents[0], "quiet_night"))

func test_campfire_slots_and_duplicate_fire_stack_cap() -> void:
	var state := GameState.new(GameData.load_default(), 227)
	var residents: Array[Survivor] = state.survivors.all()
	for i: int in range(3): state.survivors.add("Extra%d" % i, "blue", residents[0].tile() + Vector2i(i + 2, 0))
	residents = state.survivors.all()
	state.buildings.add("campfire", Vector2i(20, 20), true)
	Morale.begin_dawn(state)
	Morale.end_dawn(state, {"left":[],"cc_damage":1,"buildings_destroyed":[],"survivors_killed":[],"scavenging":[]})
	for i: int in range(6): assert_true(_has(residents[i], "campfire"))
	assert_false(_has(residents[6], "campfire"), "one Campfire has six slots")
	state.buildings.add("campfire", Vector2i(22, 20), true)
	Morale.begin_dawn(state)
	Morale.end_dawn(state, {"left":[],"cc_damage":1,"buildings_destroyed":[],"survivors_killed":[],"scavenging":[]})
	for person: Survivor in residents:
		var count: int = 0
		for mood: Dictionary in person.moods:
			if mood.id == "campfire": count += 1
		assert_eq(count, 1, "duplicate Campfires do not stack")
		assert_true(_has(person, "rough_night"))
		assert_false(_has(person, "quiet_night"))

func test_left_radio_tower_and_endless_milestone_events() -> void:
	var state := GameState.new(GameData.load_default(), 228)
	var people: Array[Survivor] = state.survivors.all()
	Morale.begin_dawn(state)
	Morale.end_dawn(state, {"left":["Mara"],"cc_damage":0,"buildings_destroyed":[],"survivors_killed":["Mara"],"scavenging":[]})
	for survivor: Survivor in people: assert_true(_has(survivor, "left"))
	var tower: Building = state.buildings.add("radio_tower", Vector2i(20, 20), false)
	state.buildings.finish(tower.uid)
	for survivor: Survivor in people: assert_true(_has(survivor, "radio_tower"))
	state.endless = true
	state.clock.day = 25
	Morale.begin_dawn(state)
	Morale.end_dawn(state, {"left":[],"cc_damage":0,"buildings_destroyed":[],"survivors_killed":[],"scavenging":[]})
	for survivor: Survivor in people: assert_false(_has(survivor, "still_standing"), "dawn 25 follows night 24")
	state.buildings.add("radio_tower", Vector2i(23, 20), true)
	state.clock.day = 21
	state.endless = false
	state._on_dawn(21)
	assert_true(state.won)
	for survivor: Survivor in people: assert_true(_has(survivor, "rescued"))

func _has(s: Survivor, id: String) -> bool:
	for mood: Dictionary in s.moods:
		if mood.id == id: return true
	return false
