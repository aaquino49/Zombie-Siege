extends TestCase

var state: GameState

func before_each() -> void:
	state = GameState.new(GameData.load_default(), 1337)
	for s: Survivor in state.survivors.all():
		state.set_job(s.uid, Survivor.Job.IDLE)

func _tick(count: int = 100) -> void:
	for i: int in range(count):
		state.tick(0.1)

func test_posting_protection_destroyed_tower_and_job_change() -> void:
	var tower: Building = state.buildings.add("watchtower", state.map.command_center_origin() + Vector2i(3, 0), true)
	var a: Survivor = state.survivors.all()[0]
	var b: Survivor = state.survivors.all()[1]
	state.set_job(a.uid, Survivor.Job.GUARD)
	state.set_job(b.uid, Survivor.Job.GUARD)
	_tick()
	assert_true(a.on_tower)
	assert_eq(a.pos, tower.center_world())
	assert_eq(a.activity, Survivor.Activity.GUARDING)
	assert_eq(b.post_uid, 0)
	assert_true(b.post_tile in state.cc_ring_tiles())
	assert_eq(b.activity, Survivor.Activity.GUARDING)
	var z: Zombie = state.spawn_zombie("walker", a.pos + Vector2(30, 0))
	var hp: int = a.hp
	for i: int in range(20):
		ZombieAI.tick(state, 0.1)
	assert_eq(a.hp, hp)
	assert_true(z.target_survivor_uid != a.uid)
	state.zombies.remove(z.uid)
	state.damage_building(tower, tower.hp)
	Jobs.tick(state, 0.1)
	assert_false(a.on_tower)
	assert_eq(a.post_uid, 0)
	assert_true(state.map.is_passable(a.tile()))
	_tick()
	assert_eq(a.activity, Survivor.Activity.GUARDING)
	assert_true(a.post_tile != b.post_tile)
	state.set_job(a.uid, Survivor.Job.BUILDER)
	assert_eq(a.post_tile, Vector2i(-1, -1))
	assert_eq(a.post_uid, 0)
	assert_false(a.on_tower)

func test_completed_tower_promotes_ground_guard_and_incomplete_releases() -> void:
	var s: Survivor = state.survivors.all()[0]
	state.set_job(s.uid, Survivor.Job.GUARD)
	_tick()
	var tower: Building = state.buildings.add("watchtower", state.map.command_center_origin() + Vector2i(3, 0), false)
	_tick(20)
	assert_eq(s.post_uid, 0)
	state.buildings.finish(tower.uid)
	_tick()
	assert_true(s.on_tower)
	state.survivors.evict_from_solid(state.map)
	assert_eq(s.pos, tower.center_world())
	var selection := SelectionController.new()
	selection.bind(state)
	selection.select_at_world(s.pos)
	assert_eq(selection.selected_kind, "survivor")
	selection.free()
	state.set_job(s.uid, Survivor.Job.IDLE)
	assert_true(state.map.is_passable(s.tile()))
	assert_false(s.on_tower)
	state.set_job(s.uid, Survivor.Job.GUARD)
	_tick()
	tower.complete = false
	Jobs.tick(state, 0.1)
	assert_false(s.on_tower)
	assert_true(state.map.is_passable(s.tile()))

func test_nearest_tower_tie_reservation_and_unreachable_retry() -> void:
	var origin: Vector2i = state.map.command_center_origin()
	var a: Building = state.buildings.add("watchtower", origin + Vector2i(3, 0), true)
	var b: Building = state.buildings.add("watchtower", origin + Vector2i(3, 2), true)
	var s: Survivor = state.survivors.all()[0]
	state.set_job(s.uid, Survivor.Job.GUARD)
	s.pos = (a.center_world() + b.center_world()) / 2.0
	assert_eq(GuardJob.free_tower(state, s), a)
	var other: Survivor = state.survivors.all()[1]
	state.set_job(other.uid, Survivor.Job.GUARD)
	other.post_uid = a.uid
	assert_eq(GuardJob.free_tower(state, s), b)
	for y: int in range(b.origin.y - 1, b.origin.y + 2):
		for x: int in range(b.origin.x - 1, b.origin.x + 2):
			var t := Vector2i(x, y)
			if Grid.in_ring(t, b.origin, b.size):
				state.buildings.add("wooden_wall", t, true)
	s.pos = Grid.tile_to_world(origin + Vector2i(-1, 0))
	Jobs.tick(state, 0.1)
	assert_eq(s.post_uid, 0)
	assert_true(s.post_tile != Vector2i(-1, -1))
	var wall: Building = state.buildings.get_at(b.origin + Vector2i.LEFT)
	state.buildings.remove(wall.uid)
	Jobs.tick(state, 0.1)
	_tick()
	assert_true(s.on_tower)

func test_unreachable_tower_assigns_ground_post_and_retry_takes_tower() -> void:
	var origin: Vector2i = state.map.command_center_origin()
	var b: Building = state.buildings.add("watchtower", origin + Vector2i(4, 4), true)
	for y: int in range(b.origin.y - 1, b.origin.y + 2):
		for x: int in range(b.origin.x - 1, b.origin.x + 2):
			var t := Vector2i(x, y)
			if Grid.in_ring(t, b.origin, b.size):
				state.buildings.add("wooden_wall", t, true)
	var s: Survivor = state.survivors.all()[0]
	state.set_job(s.uid, Survivor.Job.GUARD)
	_tick(100)
	assert_eq(s.post_uid, 0)
	assert_true(s.post_tile in state.cc_ring_tiles())
	assert_eq(s.tile(), s.post_tile)
	assert_eq(s.activity, Survivor.Activity.GUARDING)
	
	var wall: Building = state.buildings.get_at(b.origin + Vector2i.LEFT)
	state.buildings.remove(wall.uid)
	_tick(100)
	assert_true(s.on_tower)
	assert_eq(s.post_uid, b.uid)
