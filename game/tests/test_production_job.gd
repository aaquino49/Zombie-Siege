extends TestCase

var _state: GameState
var _origin: Vector2i
var _s1: Survivor
var _s2: Survivor
var _s3: Survivor

func before_each() -> void:
	_state = GameState.new(GameData.load_default(), 1337)
	for s in _state.survivors.all():
		_state.set_job(s.uid, Survivor.Job.IDLE)
	_origin = _state.map.command_center_origin() + Vector2i(-3, 3)
	
	var all_s := _state.survivors.all()
	_s1 = all_s[0]
	_s2 = all_s[1]
	_s3 = all_s[2]

func _ticks(count: int) -> void:
	for i in range(count):
		_state.tick(0.1)

func test_farmer_produces_food_during_day() -> void:
	var farm: Building = _state.buildings.add("farm", _origin, true)
	
	_state.set_job(_s1.uid, Survivor.Job.FARMER)
	_s1.pos = Grid.tile_to_world(_origin + Vector2i(0, -1))
	
	var initial_food := _state.resources.get_amount("food")
	var b_data := _state.data.get_building("farm")
	var expected_food := initial_food + int(b_data.get("food_per_farmer", 3.0))
	
	var ticks := 0
	while _state.clock.phase == GameClock.Phase.DAY and ticks < 2000:
		_state.tick(0.1)
		ticks += 1
		
	assert_eq(_state.resources.get_amount("food"), expected_food)

func test_worker_slots_respected() -> void:
	var farm: Building = _state.buildings.add("farm", _origin, true)
	
	_state.set_job(_s1.uid, Survivor.Job.FARMER)
	_state.set_job(_s2.uid, Survivor.Job.FARMER)
	_state.set_job(_s3.uid, Survivor.Job.FARMER)
	
	_s1.pos = Grid.tile_to_world(_origin + Vector2i(0, -1))
	_s2.pos = Grid.tile_to_world(_origin + Vector2i(1, -1))
	_s3.pos = Grid.tile_to_world(_origin + Vector2i(0, -2))
	
	_ticks(5)
	
	assert_eq(_s1.work_uid, farm.uid)
	assert_eq(_s2.work_uid, farm.uid)
	assert_eq(_s3.work_uid, 0)
	assert_eq(_s3.activity, Survivor.Activity.IDLE)
	
	var origin2 := _origin + Vector2i(5, 0)
	var farm2: Building = _state.buildings.add("farm", origin2, true)
	
	_ticks(20)
	
	assert_eq(_s3.work_uid, farm2.uid)

func test_crafter_produces_ammo() -> void:
	var workshop: Building = _state.buildings.add("workshop", _origin, true)
	
	_state.resources.take("scrap", _state.resources.get_amount("scrap"))
	_state.resources.take("ammo", _state.resources.get_amount("ammo"))
	_state.resources.add("scrap", 15)
	_state.resources.add("ammo", 40)
	
	_state.set_job(_s1.uid, Survivor.Job.CRAFTER)
	_s1.pos = Grid.tile_to_world(_origin + Vector2i(0, -1))
	
	var b_data := _state.data.get_building("workshop")
	var craft_time := float(b_data.get("craft_time", 10.0))
	var ammo_per_scrap := int(b_data.get("ammo_per_scrap", 5))
	
	_ticks(int(craft_time * 10) + 10)
	
	assert_eq(_state.resources.get_amount("scrap"), 14)
	assert_eq(_state.resources.get_amount("ammo"), 40 + ammo_per_scrap)

func test_crafter_with_no_scrap_waits() -> void:
	var workshop: Building = _state.buildings.add("workshop", _origin, true)
	
	_state.resources.take("scrap", _state.resources.get_amount("scrap"))
	
	_state.set_job(_s1.uid, Survivor.Job.CRAFTER)
	_s1.pos = Grid.tile_to_world(_origin + Vector2i(0, -1))
	
	_ticks(50)
	
	assert_eq(_state.resources.get_amount("scrap"), 0)
	assert_eq(_s1.activity, Survivor.Activity.IDLE)
	assert_eq(_s1.work_uid, workshop.uid)
	
	_state.resources.add("scrap", 5)
	var b_data := _state.data.get_building("workshop")
	var craft_time := float(b_data.get("craft_time", 10.0))
	_ticks(int(craft_time * 10) + 5)
	
	assert_eq(_state.resources.get_amount("scrap"), 4)

func test_no_production_at_night() -> void:
	var farm: Building = _state.buildings.add("farm", _origin, true)
	
	_state.set_job(_s1.uid, Survivor.Job.FARMER)
	_s1.pos = Grid.tile_to_world(_origin + Vector2i(0, -1))
	
	_state.clock.phase = GameClock.Phase.NIGHT
	var initial_food := _state.resources.get_amount("food")
	var initial_ammo := _state.resources.get_amount("ammo")
	
	_ticks(200) # 20 seconds
	
	assert_eq(_state.resources.get_amount("food"), initial_food)
	assert_eq(_state.resources.get_amount("ammo"), initial_ammo)
	assert_eq(_s1.activity, Survivor.Activity.SHELTERED) # T-056: workers spend nights inside.

func test_removing_building_frees_worker() -> void:
	var farm: Building = _state.buildings.add("farm", _origin, true)
	
	_state.set_job(_s1.uid, Survivor.Job.FARMER)
	_s1.pos = Grid.tile_to_world(_origin + Vector2i(0, -1))
	
	_ticks(5)
	
	assert_eq(_s1.work_uid, farm.uid)
	
	_state.buildings.remove(farm.uid)
	_ticks(5)
	
	assert_eq(_s1.work_uid, 0)
	assert_eq(_s1.activity, Survivor.Activity.IDLE)

func test_repairing_builder_does_not_count() -> void:
	var farm: Building = _state.buildings.add("farm", _origin, true)
	farm.hp = 50
	
	_state.set_job(_s1.uid, Survivor.Job.BUILDER)
	_s1.pos = Grid.tile_to_world(_origin + Vector2i(0, -1))
	
	_ticks(5)
	
	assert_eq(_s1.work_uid, farm.uid)
	assert_eq(_s1.activity, Survivor.Activity.REPAIRING)
	
	assert_eq(ProductionJob.workers_at(_state, farm), 0)

func test_blueprint_not_chosen() -> void:
	var farm: Building = _state.buildings.add("farm", _origin, false)
	
	_state.set_job(_s1.uid, Survivor.Job.FARMER)
	_s1.pos = Grid.tile_to_world(_origin + Vector2i(0, -1))
	
	_ticks(10)
	
	assert_eq(_s1.work_uid, 0)

func test_changing_job_frees_slot() -> void:
	var farm: Building = _state.buildings.add("farm", _origin, true)
	
	_state.set_job(_s1.uid, Survivor.Job.FARMER)
	_state.set_job(_s2.uid, Survivor.Job.FARMER)
	_state.set_job(_s3.uid, Survivor.Job.FARMER)
	
	_s1.pos = Grid.tile_to_world(_origin + Vector2i(0, -1))
	_s2.pos = Grid.tile_to_world(_origin + Vector2i(1, -1))
	_s3.pos = Grid.tile_to_world(_origin + Vector2i(0, -2))
	
	_ticks(5)
	
	assert_eq(_s1.work_uid, farm.uid)
	assert_eq(_s2.work_uid, farm.uid)
	assert_eq(_s3.work_uid, 0)
	
	_state.set_job(_s1.uid, Survivor.Job.IDLE)
	_ticks(20) # S3 timer is 1 second, retry is quick
	
	assert_eq(_s1.work_uid, 0)
	assert_eq(_s3.work_uid, farm.uid)

func test_worker_stays_on_passable_tile() -> void:
	var farm: Building = _state.buildings.add("farm", _origin, true)
	
	_state.set_job(_s1.uid, Survivor.Job.FARMER)
	_s1.pos = Grid.tile_to_world(_origin + Vector2i(0, -5))
	
	_ticks(50)
	
	assert_true(_state.map.is_passable(_s1.tile()))
