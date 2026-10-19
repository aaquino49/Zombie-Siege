extends TestCase

var state: GameState

func before_each() -> void:
	state = GameState.new(GameData.load_default(), 1337)
	for s: Survivor in state.survivors.all():
		state.set_job(s.uid, Survivor.Job.IDLE)

func test_nightfall_arrives_when_nearest_ring_tile_contains_passable_gate() -> void:
	var cc: Building = state.buildings.all_of_type("command_center")[0]
	var s: Survivor = state.survivors.all()[0]
	var gate_tile: Vector2i = cc.origin + Vector2i.LEFT
	assert_eq(Placement.check(state, "gate", gate_tile), Placement.Result.OK)
	state.buildings.add("gate", gate_tile, true)
	s.pos = Grid.tile_to_world(cc.origin + Vector2i(-4, 0))
	state.clock.phase = GameClock.Phase.NIGHT
	state.clock.elapsed = 0.0
	for i: int in range(200):
		state.tick(0.1)
	assert_true(s.sheltered, "a traversable gate on the nearest approach must not prevent entry when other CC ring tiles are free; tile=%s activity=%s" % [s.tile(), Survivor.activity_label(s.activity)])
	assert_eq(s.activity, Survivor.Activity.SHELTERED)

func test_nightfall_from_gate_on_shelter_ring_enters_without_path() -> void:
	var origin: Vector2i = state.map.command_center_origin() + Vector2i(-4, -4)
	assert_eq(Placement.check(state, "shelter", origin), Placement.Result.OK)
	var b: Building = state.buildings.add("shelter", origin, true)
	var gate_tile: Vector2i = origin + Vector2i.LEFT
	assert_eq(Placement.check(state, "gate", gate_tile), Placement.Result.OK)
	state.buildings.add("gate", gate_tile, true)
	var s: Survivor = state.survivors.all()[0]
	s.pos = Grid.tile_to_world(gate_tile)
	state.clock.phase = GameClock.Phase.NIGHT
	Jobs.tick(state, 0.1)
	assert_true(s.sheltered, "a survivor already on a traversable ring gate has arrived")
	assert_eq(s.shelter_uid, b.uid)
	assert_eq(s.activity, Survivor.Activity.SHELTERED)
	assert_true(s.path.is_empty())

func test_dawn_from_shelter_uses_first_remaining_passable_ring_tile() -> void:
	var origin: Vector2i = state.map.command_center_origin() + Vector2i(-4, -4)
	assert_eq(Placement.check(state, "shelter", origin), Placement.Result.OK)
	var b: Building = state.buildings.add("shelter", origin, true)
	var s: Survivor = state.survivors.all()[0]
	s.pos = Grid.tile_to_world(origin + Vector2i(-1, -1))
	state.clock.phase = GameClock.Phase.NIGHT
	Jobs.tick(state, 0.1)
	assert_true(s.sheltered)
	assert_eq(s.shelter_uid, b.uid)
	# Nighttime blueprint placement can block the former entrance. Dawn must
	# choose the first remaining passable tile of this shelter, not the CC.
	state.buildings.add("wooden_wall", s.tile(), false)
	var expected: Vector2i = Vector2i(-1, -1)
	for y: int in range(origin.y - 1, origin.y + b.size.y + 1):
		for x: int in range(origin.x - 1, origin.x + b.size.x + 1):
			var t := Vector2i(x, y)
			if expected == Vector2i(-1, -1) and Grid.in_ring(t, origin, b.size) and state.map.is_passable(t):
				expected = t
	state.clock.phase = GameClock.Phase.DAY
	Jobs.tick(state, 0.1)
	assert_false(s.sheltered)
	assert_eq(s.shelter_uid, 0)
	assert_eq(s.tile(), expected)
	assert_true(state.map.is_passable(s.tile()))
