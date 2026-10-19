extends TestCase

const Fixture: GDScript = preload("res://tests/night_sim_fixture.gd")

func _defended() -> GameState:
	var state: GameState = GameState.new(GameData.load_default(), 1337)
	var setup: Dictionary = Fixture.defended(state)
	assert_true(bool(setup["ok"]), "Closed legal wall/gate ring and all three defenses must be placed")
	assert_eq(state.buildings.all_of_type("turret").size(), 2)
	assert_eq(state.buildings.all_of_type("watchtower").size(), 1)
	assert_eq(state.buildings.all_of_type("gate").size(), 1)
	assert_true(state.survivors.all()[0].on_tower, "First guard must man the reachable tower")
	assert_eq(state.survivors.all()[1].activity, Survivor.Activity.GUARDING)
	assert_eq(state.resources.get_amount("ammo"), int(state.data.balance("start_ammo")))
	return state

func test_defended_base_survives_night_1() -> void:
	var state: GameState = _defended()
	Fixture.nightfall(state, 1)
	var result: Dictionary = Fixture.run_night(state)
	print("T-022 defended night 1: ", JSON.stringify(result))
	assert_eq(state.clock.phase, GameClock.Phase.DAY, "Dawn must arrive within 300 simulated seconds")
	assert_eq(state.clock.day, 2)
	assert_false(state.cc_destroyed)
	assert_false(state.game_over)
	var wave: Dictionary = state.data.wave_for_night(1)
	var expected: int = int(wave["walker"]) + int(wave["runner"]) + int(wave["brute"])
	assert_eq(state.zombies_killed, expected)
	assert_eq(state.hostiles_remaining(), 0)
	var max_shot: int = maxi(int(state.data.balance("guard_damage")), int(state.data.get_building("turret")["damage"]))
	var shots_needed: int = ceili(float(state.data.get_zombie("walker")["hp"]) / max_shot)
	var used: int = int(state.data.balance("start_ammo")) - state.resources.get_amount("ammo")
	assert_true(used >= expected * shots_needed, "Kills must consume their required shots")
	assert_eq(state.survivors_lost, 0)
	assert_eq(state.survivors.count(), int(state.data.balance("start_survivors")))
	assert_true(float(result["seconds"]) >= float(state.data.balance("night_min_length")) - 0.1)

func test_undefended_cc_takes_damage_night_5() -> void:
	var state: GameState = GameState.new(GameData.load_default(), 1337)
	Fixture.idle(state)
	var types: Array[String] = []
	state.zombies.zombie_added.connect(func(z: Zombie) -> void: types.append(z.type_id))
	var cc: Building = state.buildings.all_of_type("command_center")[0]
	Fixture.nightfall(state, 5)
	for i: int in range(3000):
		state.tick(0.1)
		if cc.hp < cc.max_hp and types.count("runner") == 4:
			break
	assert_lt(cc.hp, cc.max_hp, "Unprotected CC must be damaged within 300 seconds")
	assert_eq(types.count("runner"), 4)
	assert_eq(state.buildings.all().size(), 1)
	assert_eq(state.resources.get_amount("ammo"), int(state.data.balance("start_ammo")))

func test_cc_destroyed_triggers_game_over() -> void:
	var state: GameState = GameState.new(GameData.load_default(), 1337)
	Fixture.idle(state)
	var cc: Building = state.buildings.all_of_type("command_center")[0]
	cc.hp = 1
	var reasons: Array[String] = []
	state.game_lost.connect(func(reason: String) -> void: reasons.append(reason))
	Fixture.nightfall(state, 5)
	Fixture.run_night(state)
	assert_true(state.cc_destroyed, "Real wave must destroy the low-HP CC")
	assert_true(state.game_over)
	assert_eq(reasons, ["command_center"])
	for i: int in range(100):
		state.tick(0.1)
	assert_true(state.game_over)
	assert_eq(reasons, ["command_center"])

func test_night_sim_deterministic() -> void:
	var first: GameState = _defended()
	var second: GameState = _defended()
	Fixture.nightfall(first, 1)
	Fixture.nightfall(second, 1)
	var a: Dictionary = Fixture.run_night(first)
	var b: Dictionary = Fixture.run_night(second)
	assert_eq(a["phase"], GameClock.Phase.DAY)
	assert_eq(b["phase"], GameClock.Phase.DAY)
	assert_eq(a, b, "Seeded full nights must have identical kills, ammo, CC HP and timing")

func test_waves_disabled_by_default() -> void:
	var state: GameState = GameState.new(GameData.load_default(), 1337)
	assert_false(state.waves.enabled)
	var game: Node = (load("res://scripts/autoload/game.gd") as GDScript).new()
	game.call("new_game", 1337)
	var started: GameState = game.get("state") as GameState
	assert_not_null(started)
	assert_true(started.waves.enabled)
	game.free()
