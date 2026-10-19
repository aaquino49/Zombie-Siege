extends TestCase

func test_zombies_movement() -> void:
	var data: GameData = GameData.load_default()
	var state: GameState = GameState.new(data, 1337)
	
	var cc_center: Vector2 = Grid.tile_to_world(state.map.command_center_origin()) + Vector2.ONE * Grid.TILE / 2.0
	var z1: Zombie = state.spawn_zombie("walker", cc_center + Vector2(10 * Grid.TILE, 0))
	var cc_b: Building = state.buildings.get_by_uid(1)
	assert_eq(cc_b.type_id, "command_center")
	
	for s in state.survivors.all():
		state.survivors.remove(s.uid)
		
	var ticks: int = int((10.0 * Grid.TILE / z1.speed + 2.0) * 60)
	for i in range(ticks):
		state.tick(1.0 / 60.0)
		
	assert_eq(z1.target_building_uid, cc_b.uid)
	
	var initial_hp: int = cc_b.hp
	for i in range(5 * 60):
		state.tick(1.0 / 60.0)
		
	var dmg: int = initial_hp - cc_b.hp
	assert_true(dmg >= 24 and dmg <= 36)
	assert_eq(z1.hp, z1.max_hp)

func test_zombies_wall_attack() -> void:
	var data: GameData = GameData.load_default()
	var state: GameState = GameState.new(data, 1337)
	state.resources.add("wood", 10000)
	
	var cc_origin: Vector2i = state.map.command_center_origin()
	var wall_t: Vector2i = Vector2i(cc_origin.x + 3, cc_origin.y + 1)
	state.try_place("wooden_wall", wall_t)
	var b_wall: Building = state.buildings.get_at(wall_t)
	
	# Block other routes
	for y in range(0, state.map.size()):
		for x in range(0, state.map.size()):
			var t: Vector2i = Vector2i(x, y)
			var is_path: bool = (t.y == wall_t.y and t.x >= cc_origin.x and t.x <= wall_t.x + 1)
			if is_path or t == wall_t or t == wall_t + Vector2i(1, 0) or t in state.cc_ring_tiles() or (t.x >= cc_origin.x and t.x < cc_origin.x + 2 and t.y >= cc_origin.y and t.y < cc_origin.y + 2):
				var occ: int = state.map.occupant_at(t)
				if occ == WorldMap.Occupant.TREE or occ == WorldMap.Occupant.SCRAP or occ == WorldMap.Occupant.ROCK:
					state.map.vacate(t, Vector2i(1, 1))
			else:
				state.map._occupants[t] = WorldMap.Occupant.TREE
	state.map.changed.emit()
	
	for s in state.survivors.all():
		state.survivors.remove(s.uid)
	
	var cc_center_y: float = (cc_origin.y + 1) * Grid.TILE
	var z1: Zombie = state.spawn_zombie("walker", Vector2(Grid.tile_to_world(wall_t + Vector2i.RIGHT).x, cc_center_y))
	
	var initial_buildings_lost: int = state.buildings_lost
	var b_destroyed_emitted: Array[bool] = [false]
	state.building_destroyed.connect(func(b: Building) -> void: b_destroyed_emitted[0] = true)
	
	var ticks: int = int((10.0 * Grid.TILE / z1.speed + 35.0) * 60)
	for i in range(ticks):
		state.tick(1.0 / 60.0)
		if b_destroyed_emitted[0]:
			break
		
	assert_true(b_destroyed_emitted[0])
	assert_eq(state.buildings_lost, initial_buildings_lost + 1)
	assert_eq(state.buildings.get_at(wall_t), null)
	
	for i in range(10 * 60):
		state.tick(1.0 / 60.0)
		
	var cc_b: Building = state.buildings.get_by_uid(1)
	assert_eq(z1.target_building_uid, cc_b.uid)


func test_zombie_survivor_attack() -> void:
	var data: GameData = GameData.load_default()
	var state: GameState = GameState.new(data, 1337)
	
	var s: Survivor = state.survivors.all()[0]
	s.pos = Vector2(500, 500)
	var s_hp: int = s.hp
	var s_pos: Vector2 = s.pos
	
	var z: Zombie = state.spawn_zombie("walker", s_pos + Vector2(60, 0))
	
	var killed_emitted: Array[bool] = [false]
	state.survivor_killed.connect(func(surv: Survivor) -> void: killed_emitted[0] = true)
	
	for i in range(60 * 15):
		state.tick(1.0 / 60.0)
		if killed_emitted[0]:
			break
			
	assert_true(killed_emitted[0])
	assert_eq(state.survivors_lost, 1)
	
	var old_pos: Vector2 = z.pos
	state.tick(1.0 / 60.0)
	
	assert_eq(z.target_survivor_uid, 0)
	assert_true(z.pos != old_pos)

func test_zombie_shelter_attack() -> void:
	var data: GameData = GameData.load_default()
	var state: GameState = GameState.new(data, 1337)
	state.resources.add("wood", 10000)
	
	var s: Survivor = state.survivors.all()[0]
	var cc_origin: Vector2i = state.map.command_center_origin()
	var shelter_t: Vector2i = Vector2i(cc_origin.x + 3, cc_origin.y)
	for dy in range(2):
		for dx in range(2):
			var occ: int = state.map.occupant_at(shelter_t + Vector2i(dx, dy))
			if occ == WorldMap.Occupant.TREE or occ == WorldMap.Occupant.SCRAP or occ == WorldMap.Occupant.ROCK:
				state.map.vacate(shelter_t + Vector2i(dx, dy), Vector2i(1, 1))
				
	for dx in range(3):
		var path_t: Vector2i = shelter_t + Vector2i(2 + dx, 0)
		var occ: int = state.map.occupant_at(path_t)
		if occ == WorldMap.Occupant.TREE or occ == WorldMap.Occupant.SCRAP or occ == WorldMap.Occupant.ROCK:
			state.map.vacate(path_t, Vector2i(1, 1))
	
	state.try_place("shelter", shelter_t)
	var b: Building = state.buildings.get_at(shelter_t)
	
	s.sheltered = true
	s.shelter_uid = b.uid
	s.shelter_building = b
	s.target = shelter_t
	s.pos = Grid.tile_to_world(shelter_t)
	
	state.clock.phase = GameClock.Phase.NIGHT
	
	var z: Zombie = state.spawn_zombie("walker", s.pos + Vector2(60, 0))
	
	for i in range(60 * 5):
		state.tick(1.0 / 60.0)
		
	# Should attack the shelter, not the survivor
	assert_true(b.hp < data.get_building("shelter").hp)
	assert_eq(float(s.hp), float(data.balance("survivor_hp", 50)))
	
	for i in range(60 * 40):
		state.tick(1.0 / 60.0)
		
	assert_eq(state.buildings.get_at(shelter_t), null)
	assert_true(s.shelter_uid != b.uid)

func test_zombies_cc_destruction() -> void:
	var data: GameData = GameData.load_default()
	var state: GameState = GameState.new(data, 1337)
	
	var cc_b: Building = state.buildings.get_by_uid(1)
	cc_b.hp = 10
	for s in state.survivors.all():
		state.survivors.remove(s.uid)
	
	var cc_center: Vector2 = Grid.tile_to_world(state.map.command_center_origin()) + Vector2.ONE * Grid.TILE / 2.0
	var z: Zombie = state.spawn_zombie("walker", cc_center + Vector2(80, 0))
	
	var cc_destroyed_count: Array[int] = [0]
	state.command_center_destroyed.connect(func() -> void: cc_destroyed_count[0] += 1)
	
	for i in range(60 * 15):
		state.tick(1.0 / 60.0)
		
	assert_true(state.buildings.get_by_uid(1) != null) # never removed
	assert_eq(cc_b.hp, 0)
	assert_true(state.cc_destroyed)
	assert_eq(cc_destroyed_count[0], 1)

func test_zombies_out_of_bounds() -> void:
	var data: GameData = GameData.load_default()
	var state: GameState = GameState.new(data, 1337)
	
	var z: Zombie = state.spawn_zombie("walker", Vector2(-40, 600))
	
	for i in range(60 * 10):
		state.tick(1.0 / 60.0)
		
	assert_true(z.pos.x > 0)
	assert_true(z.pos.x < state.map.size() * Grid.TILE)
	
func test_zombies_kills() -> void:
	var data: GameData = GameData.load_default()
	var state: GameState = GameState.new(data, 1337)
	
	var z: Zombie = state.spawn_zombie("walker", Vector2(100, 100))
	assert_eq(state.hostiles_remaining(), 1)
	
	var killed: bool = state.zombies.damage(z.uid, 20)
	assert_false(killed)
	assert_eq(state.hostiles_remaining(), 1)
	
	killed = state.zombies.damage(z.uid, 40)
	assert_true(killed)
	assert_eq(state.hostiles_remaining(), 0)

func test_zombies_performance() -> void:
	var data: GameData = GameData.load_default()
	var state: GameState = GameState.new(data, 1337)
	
	var map_size: int = state.map.size()
	for i in range(250):
		var side: int = i % 4
		var pos: Vector2 = Vector2()
		if side == 0:
			pos = Vector2(randf() * map_size * Grid.TILE, 0)
		elif side == 1:
			pos = Vector2(randf() * map_size * Grid.TILE, map_size * Grid.TILE)
		elif side == 2:
			pos = Vector2(0, randf() * map_size * Grid.TILE)
		else:
			pos = Vector2(map_size * Grid.TILE, randf() * map_size * Grid.TILE)
			
		state.spawn_zombie("walker", pos)
		
	var initial_rebuild_count: int = state.flow.rebuild_count
	var t0: int = Time.get_ticks_usec()
	for i in range(60):
		state.tick(1.0 / 60.0)
	var t1: int = Time.get_ticks_usec()
	var total_ms: float = (t1 - t0) / 1000.0
	var avg_ms: float = total_ms / 60.0
	print("Performance (250 walkers): ", total_ms, " ms total, avg ", avg_ms, " ms/tick")
	assert_true(total_ms < 1500.0)
	assert_true(state.flow.rebuild_count - initial_rebuild_count <= 1)

func test_zombies_determinism() -> void:
	var data1: GameData = GameData.load_default()
	var state1: GameState = GameState.new(data1, 1337)
	var z1: Zombie = state1.spawn_zombie("walker", Vector2(100, 100))
	for i in range(300):
		state1.tick(1.0 / 60.0)
		
	var data2: GameData = GameData.load_default()
	var state2: GameState = GameState.new(data2, 1337)
	var z2: Zombie = state2.spawn_zombie("walker", Vector2(100, 100))
	for i in range(300):
		state2.tick(1.0 / 60.0)
		
	assert_eq(z1.pos.x, z2.pos.x)
	assert_eq(z1.pos.y, z2.pos.y)

func test_night_waits_for_zombies() -> void:
	var data: GameData = GameData.load_default()
	var state: GameState = GameState.new(data, 1337)
	
	state.clock.phase = GameClock.Phase.NIGHT
	state.clock.elapsed = data.balance("night_min_length", 45) + 5.0
	
	var z: Zombie = state.spawn_zombie("walker", Vector2(-1000, -1000))
	for i in range(120):
		state.tick(1.0 / 60.0)
		
	assert_eq(state.clock.phase, GameClock.Phase.NIGHT)
	
	state.zombies.damage(z.uid, 9999)
	for i in range(60):
		state.tick(1.0 / 60.0)
		
	assert_eq(state.clock.phase, GameClock.Phase.DAY)

func test_zombie_facing_wall() -> void:
	var data: GameData = GameData.load_default()
	var state: GameState = GameState.new(data, 1337)
	state.resources.add("wood", 100)
	
	var cc_origin: Vector2i = state.map.command_center_origin()
	var wall_t: Vector2i = Vector2i(cc_origin.x + 3, cc_origin.y + 1)
	assert_eq(state.try_place("wooden_wall", wall_t), Placement.Result.OK)
	var wall: Building = state.buildings.get_at(wall_t)
	assert_not_null(wall)
	if wall == null:
		return
	state.buildings.finish(wall.uid)
	assert_true(wall.complete)
	
	for y in range(0, state.map.size()):
		for x in range(0, state.map.size()):
			var t: Vector2i = Vector2i(x, y)
			var is_path: bool = (t.y == wall_t.y and t.x >= cc_origin.x and t.x <= wall_t.x + 1)
			if is_path or t == wall_t or t == wall_t + Vector2i(1, 0) or t in state.cc_ring_tiles() or (t.x >= cc_origin.x and t.x < cc_origin.x + 2 and t.y >= cc_origin.y and t.y < cc_origin.y + 2):
				var occ: int = state.map.occupant_at(t)
				if occ == WorldMap.Occupant.TREE or occ == WorldMap.Occupant.SCRAP or occ == WorldMap.Occupant.ROCK:
					state.map.vacate(t, Vector2i(1, 1))
			else:
				state.map._occupants[t] = WorldMap.Occupant.TREE
	state.map.changed.emit()
	
	for s in state.survivors.all():
		state.survivors.remove(s.uid)
		
	var spawn_pos: Vector2 = Grid.tile_to_world(wall_t + Vector2i.RIGHT)
	var z: Zombie = state.spawn_zombie("walker", spawn_pos)
	z.facing = Vector2.DOWN
	assert_eq(state.flow.next_tile(z.tile()), wall_t)
	
	state.tick(0.1)
	assert_true(z.facing.distance_to(Vector2.LEFT) < 0.1)
	assert_eq(z.pos, spawn_pos)
	assert_eq(z.target_building_uid, wall.uid)
	assert_eq(z.target_survivor_uid, 0)
	assert_almost_eq(z.attack_timer, 0.1, 0.0001)
	assert_eq(wall.hp, wall.max_hp)

func test_zombie_facing_survivor() -> void:
	var data: GameData = GameData.load_default()
	var state: GameState = GameState.new(data, 1337)
	
	var s: Survivor = state.survivors.all()[0]
	state.set_job(s.uid, Survivor.Job.IDLE)
	s.sheltered = false
	s.on_tower = false
	s.pos = Vector2(500, 500)
	var initial_hp: int = s.hp
	
	var spawn_pos: Vector2 = s.pos + Vector2(0, 30)
	var z: Zombie = state.spawn_zombie("walker", spawn_pos)
	z.facing = Vector2.DOWN
	
	state.tick(0.1)
	assert_true(z.facing.distance_to(Vector2.UP) < 0.1)
	assert_eq(z.pos, spawn_pos)
	assert_eq(z.target_survivor_uid, s.uid)
	assert_eq(z.target_building_uid, 0)
	assert_almost_eq(z.attack_timer, 0.1, 0.0001)
	assert_eq(s.hp, initial_hp)
