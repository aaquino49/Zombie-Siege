extends TestCase

var state: GameState
var shots: int = 0

func before_each() -> void:
	state = GameState.new(GameData.load_default(), 1337)
	for s: Survivor in state.survivors.all():
		state.set_job(s.uid, Survivor.Job.IDLE)
	state.shot_fired.connect(_shot)

func _shot(_from: Vector2, _to: Vector2, _is_turret: bool) -> void:
	shots += 1

func test_turret_uses_data_range_interval_and_damage() -> void:
	var stats: Dictionary = state.data.get_building("turret")
	stats["range_tiles"] = 2.0
	stats["fire_interval"] = 0.25
	stats["damage"] = 3
	var turret: Building = state.buildings.add("turret", state.map.command_center_origin() + Vector2i(3, 0), true)
	var z: Zombie = state.spawn_zombie("walker", turret.center_world() + Vector2(2.1 * Grid.TILE, 0))
	Combat.tick_turrets(state, 0.5)
	assert_eq(shots, 0)
	assert_eq(z.hp, z.max_hp)
	z.pos = turret.center_world() + Vector2(1.9 * Grid.TILE, 0)
	turret.fire_timer = 0.0
	Combat.tick_turrets(state, 0.24)
	assert_eq(shots, 0)
	Combat.tick_turrets(state, 0.01)
	assert_eq(shots, 1)
	assert_eq(z.hp, z.max_hp - 3)
	assert_eq(state.resources.get_amount("ammo"), 39)

func test_guard_uses_balance_and_tower_multiplier() -> void:
	state.data._balance["guard_range_tiles"] = 2.0
	state.data._balance["guard_fire_interval"] = 0.25
	state.data._balance["guard_damage"] = 7
	var s: Survivor = state.survivors.all()[0]
	state.set_job(s.uid, Survivor.Job.GUARD)
	Jobs.tick(state, 0.1)
	var z: Zombie = state.spawn_zombie("walker", s.pos + Vector2(3.5 * Grid.TILE, 0))
	Jobs.tick(state, 0.5)
	assert_eq(shots, 0)
	assert_eq(z.hp, z.max_hp)
	state.data.get_building("watchtower")["guard_range_mult"] = 2.0
	var tower: Building = state.buildings.add("watchtower", state.map.command_center_origin() + Vector2i(3, 0), true)
	GuardJob.leave_post(state, s)
	s.pos = Grid.tile_to_world(tower.origin + Vector2i.UP)
	Jobs.tick(state, 0.1)
	assert_true(s.on_tower)
	z.pos = s.pos + Vector2(3.5 * Grid.TILE, 0)
	s.fire_timer = 0.0
	Jobs.tick(state, 0.24)
	assert_eq(shots, 0)
	Jobs.tick(state, 0.01)
	assert_eq(shots, 1)
	assert_eq(z.hp, z.max_hp - 7)
	assert_eq(state.resources.get_amount("ammo"), 39)

func test_fresh_blueprint_never_shoots_or_spends_ammo() -> void:
	var turret: Building = state.buildings.add("turret", state.map.command_center_origin() + Vector2i(3, 0), false)
	var z: Zombie = state.spawn_zombie("walker", turret.center_world() + Vector2(Grid.TILE, 0))
	for i: int in range(20):
		Combat.tick_turrets(state, 0.1)
	assert_eq(shots, 0)
	assert_eq(z.hp, z.max_hp)
	assert_eq(state.resources.get_amount("ammo"), 40)
	assert_almost_eq(turret.fire_timer, 0.0)
