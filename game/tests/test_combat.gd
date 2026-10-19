extends TestCase

var state: GameState
var shots: int = 0
var kills: int = 0

func before_each() -> void:
	state = GameState.new(GameData.load_default(), 1337)
	for s: Survivor in state.survivors.all():
		state.set_job(s.uid, Survivor.Job.IDLE)
	state.shot_fired.connect(_shot)
	state.zombie_killed.connect(_kill)

func _shot(_from: Vector2, _to: Vector2, _turret: bool) -> void:
	shots += 1

func _kill(_z: Zombie) -> void:
	kills += 1

func test_turret_range_blueprint_and_aim() -> void:
	var b: Building = state.buildings.add("turret", state.map.command_center_origin() + Vector2i(3, 0), true)
	var z: Zombie = state.spawn_zombie("walker", b.center_world() + Vector2(6.1 * Grid.TILE, 0))
	Combat.tick_turrets(state, 0.5)
	assert_eq(shots, 0)
	z.pos = b.center_world() + Vector2(5.9 * Grid.TILE, 0)
	Combat.tick_turrets(state, 0.1)
	assert_eq(shots, 1)
	assert_eq(z.hp, 0)
	assert_eq(b.aim, Vector2.RIGHT)
	b.complete = false
	Combat.tick_turrets(state, 5.0)
	assert_eq(shots, 1)

func test_nearest_target_ties_and_inclusive_boundary() -> void:
	var z1: Zombie = state.spawn_zombie("walker", Vector2(100, 0))
	var z2: Zombie = state.spawn_zombie("walker", Vector2(-100, 0))
	assert_eq(Combat.nearest_zombie(state, Vector2.ZERO, 100), z1)
	z2.pos = Vector2(99, 0)
	assert_eq(Combat.nearest_zombie(state, Vector2.ZERO, 100), z2)
	assert_eq(Combat.nearest_zombie(state, Vector2.ZERO, 98), null)

func test_fire_rate_ammo_and_kill_once() -> void:
	var b: Building = state.buildings.add("turret", state.map.command_center_origin() + Vector2i(3, 0), true)
	var z: Zombie = state.spawn_zombie("walker", b.center_world() + Vector2(Grid.TILE, 0))
	for i: int in range(20):
		Combat.tick_turrets(state, 0.1)
	assert_eq(shots, 1)
	assert_eq(state.resources.get_amount("ammo"), 39)
	assert_eq(state.zombies_killed, 1)
	assert_eq(kills, 1)
	assert_false(state.damage_zombie(z, 10))
	assert_eq(kills, 1)

func test_zero_ammo_no_damage_no_signal_and_ready_recovery() -> void:
	var b: Building = state.buildings.add("turret", state.map.command_center_origin() + Vector2i(3, 0), true)
	var z: Zombie = state.spawn_zombie("walker", b.center_world() + Vector2(Grid.TILE, 0))
	state.resources.take("ammo", 40)
	Combat.tick_turrets(state, 3.0)
	assert_eq(shots, 0)
	assert_eq(z.hp, 40)
	assert_eq(b.fire_timer, 0.5)
	state.resources.add("ammo", 1)
	Combat.tick_turrets(state, 0.1)
	assert_eq(shots, 1)
	assert_eq(z.hp, 0)
	assert_eq(state.resources.get_amount("ammo"), 0)

func test_guard_range_rate_and_four_hits() -> void:
	var s: Survivor = state.survivors.all()[0]
	state.set_job(s.uid, Survivor.Job.GUARD)
	s.post_tile = s.tile()
	s.activity = Survivor.Activity.GUARDING
	var z: Zombie = state.spawn_zombie("walker", s.pos + Vector2(7 * Grid.TILE, 0))
	for i: int in range(20):
		Jobs.tick(state, 0.1)
	assert_eq(shots, 0)
	z.pos = s.pos + Vector2(4 * Grid.TILE, 0)
	s.fire_timer = 0.0
	for i: int in range(20):
		Jobs.tick(state, 0.1)
	assert_eq(shots, 1)
	assert_eq(z.hp, 0)
	assert_eq(state.resources.get_amount("ammo"), 39)
	for i: int in range(20):
		Jobs.tick(state, 0.1)
	assert_eq(state.zombies_killed, 1)
	assert_eq(kills, 1)
	var tower: Building = state.buildings.add("watchtower", state.map.command_center_origin() + Vector2i(3, 0), true)
	GuardJob.leave_post(state, s)
	s.pos = Grid.tile_to_world(tower.origin + Vector2i.UP)
	Jobs.tick(state, 0.1)
	assert_true(s.on_tower)
	z = state.spawn_zombie("walker", s.pos + Vector2(7 * Grid.TILE, 0))
	Jobs.tick(state, 1.0)
	assert_eq(z.hp, 0)
	state.resources.take("ammo", 40)
	Jobs.tick(state, 3.0)
	assert_eq(z.hp, 0)
	assert_eq(shots, 2)
