extends TestCase

var state: GameState
var reasons: Array[String] = []

func before_each() -> void:
	state = GameState.new(GameData.load_default(), 1337)
	state.waves.enabled = false
	state.game_lost.connect(_lost)
	for s: Survivor in state.survivors.all():
		state.set_job(s.uid, Survivor.Job.IDLE)

func _lost(reason: String) -> void:
	reasons.append(reason)

func test_command_center_loss_once_sim_keeps_running() -> void:
	var cc: Building = state.buildings.all_of_type("command_center")[0]
	state.damage_building(cc, cc.hp)
	state.tick(0.1)
	assert_true(state.game_over)
	assert_eq(state.lose_reason, "command_center")
	state.tick(1.0)
	state._on_dawn(2)
	assert_eq(reasons, ["command_center"])
	assert_almost_eq(state.time_played, 1.1)
	assert_false(state.clock.paused)

func test_last_survivor_killed_once() -> void:
	for s: Survivor in state.survivors.all():
		state.damage_survivor(s, s.hp)
	state.tick(0.1)
	state.tick(0.1)
	assert_true(state.game_over)
	assert_eq(state.lose_reason, "survivors")
	assert_eq(reasons, ["survivors"])
	assert_eq(state.survivors_lost, 4)
	assert_eq(state.stats()["survivors_lost"], 4)

func test_last_survivor_leaves_at_dawn() -> void:
	var all: Array[Survivor] = state.survivors.all()
	for i: int in range(1, all.size()):
		state.damage_survivor(all[i], all[i].hp)
	all[0].hungry_days = int(state.data.balance("food_hungry_leave_days")) - 1
	state.resources.take("food", state.resources.get_amount("food"))
	state.clock.phase = GameClock.Phase.NIGHT
	state.clock.elapsed = float(state.data.balance("night_min_length")) - 0.1
	state.tick(0.2)
	assert_true(state.game_over)
	assert_eq(state.lose_reason, "survivors")
	assert_eq(reasons, ["survivors"])
	assert_eq(state.survivors_lost, 3)
	assert_eq(state.survivors_left, 1)
	assert_eq(state.stats()["survivors_lost"], 4)
	state.tick(1.0)
	assert_eq(reasons.size(), 1)

func test_command_center_reason_takes_precedence() -> void:
	for s: Survivor in state.survivors.all():
		state.damage_survivor(s, s.hp)
	var cc: Building = state.buildings.all_of_type("command_center")[0]
	state.damage_building(cc, cc.hp)
	state.tick(0.0)
	assert_eq(reasons, ["command_center"])

func test_one_survivor_and_standing_cc_no_loss() -> void:
	var all: Array[Survivor] = state.survivors.all()
	for i: int in range(1, all.size()):
		state.damage_survivor(all[i], all[i].hp)
	state.tick(1.0)
	assert_false(state.game_over)
	assert_eq(state.lose_reason, "")
	assert_true(reasons.is_empty())

func test_stats_completions_time_and_kills() -> void:
	assert_eq(state.buildings_built, 0)
	var origin: Vector2i = state.map.command_center_origin()
	var b: Building = state.buildings.add("wooden_wall", origin + Vector2i(3, 0), false)
	assert_eq(state.buildings_built, 0)
	state.buildings.finish(b.uid)
	state.buildings.finish(b.uid)
	assert_eq(state.buildings_built, 1)
	var cancelled: Building = state.buildings.add("wooden_wall", origin + Vector2i(4, 0), false)
	assert_true(state.cancel_building(cancelled.uid))
	state.buildings.finish(cancelled.uid)
	state.buildings.finish(state.buildings.all_of_type("command_center")[0].uid)
	assert_eq(state.buildings_built, 1)
	var z: Zombie = state.spawn_zombie("walker", Vector2.ZERO)
	assert_true(state.damage_zombie(z, z.hp))
	assert_false(state.damage_zombie(z, 1))
	state.clock.day = 6
	state.tick(2.0)
	state.clock.set_speed(2)
	state.tick(1.0)
	state.clock.set_paused(true)
	state.tick(5.0)
	assert_eq(state.stats(), {"nights_survived": 5, "zombies_killed": 1,
		"survivors_lost": 0, "buildings_built": 1, "time_played": 4.0})

func test_locked_clock_cannot_resume() -> void:
	state.clock.set_paused(true)
	state.clock.locked = true
	state.clock.set_speed(2)
	assert_true(state.clock.paused)
	assert_eq(state.clock.speed, 1)
	state.clock.toggle_pause()
	assert_true(state.clock.paused)
	state.clock.set_paused(false)
	assert_true(state.clock.paused)
	state.tick(5.0)
	assert_true(state.clock.paused)
	assert_eq(state.clock.speed, 1)
	assert_almost_eq(state.time_played, 0.0)

func test_partial_damage_and_other_building_loss_are_not_defeat() -> void:
	var cc: Building = state.buildings.all_of_type("command_center")[0]
	state.damage_building(cc, cc.hp - 1)
	var s: Survivor = state.survivors.all()[0]
	state.damage_survivor(s, s.hp - 1)
	var wall: Building = state.buildings.add("wooden_wall", cc.origin + Vector2i(3, 0), false)
	state.buildings.finish(wall.uid)
	state.damage_building(wall, wall.hp)
	state.tick(0.1)
	assert_false(state.game_over)
	assert_true(reasons.is_empty())
	assert_eq(state.stats()["buildings_built"], 1)
	assert_eq(state.stats()["survivors_lost"], 0)

func test_partial_departure_counts_without_defeat() -> void:
	state.resources.take("food", state.resources.get_amount("food"))
	state.survivors.all()[0].hungry_days = int(state.data.balance("food_hungry_leave_days")) - 1
	state.clock.phase = GameClock.Phase.NIGHT
	state.clock.elapsed = float(state.data.balance("night_min_length")) - 0.1
	state.tick(0.2)
	assert_eq(state.survivors.count(), 3)
	assert_false(state.game_over)
	assert_true(reasons.is_empty())
	assert_eq(state.survivors_lost, 0)
	assert_eq(state.stats()["survivors_lost"], 1)

func test_later_command_center_loss_does_not_replace_survivor_reason() -> void:
	for s: Survivor in state.survivors.all():
		state.damage_survivor(s, s.hp)
	state.tick(0.0)
	var cc: Building = state.buildings.all_of_type("command_center")[0]
	state.damage_building(cc, cc.hp)
	state.tick(0.1)
	assert_eq(state.lose_reason, "survivors")
	assert_eq(reasons, ["survivors"])
