extends TestCase
## T-068 acceptance gaps: exact data, reuse across types, and scenario end states.

var _state: GameState
var _previous_state: GameState
var _main: Node2D
var _layer: ZombieLayer

func before_each() -> void:
	_state = GameState.new(GameData.load_default(), 1337)
	_previous_state = Game.state
	Game.state = _state
	_main = Node2D.new()
	var world := Node2D.new()
	world.name = "World"
	_main.add_child(world)
	var camera := Camera2D.new()
	camera.name = "Camera2D"
	world.add_child(camera)
	_layer = ZombieLayer.new()

func after_each() -> void:
	Game.state = _previous_state
	_layer.free()
	_main.free()
	_state = null

func test_reused_sprite_refreshes_type_transform_and_health() -> void:
	var first: Zombie = _state.spawn_zombie("walker", Vector2(100, 100))
	_layer.bind(_state)
	var sprite: AnimatedSprite2D = _layer.get_child(0) as AnimatedSprite2D
	var bar: HpBar = sprite.get_child(0) as HpBar
	assert_true(sprite.visible)
	assert_not_null(sprite.sprite_frames)
	first.hp = first.max_hp / 2
	_layer.sync()
	assert_almost_eq(bar._ratio, 0.5)
	_state.zombies.remove(first.uid)
	assert_false(sprite.visible)
	assert_almost_eq(bar._ratio, 1.0, 0.001, "Removed sprite must clear its damaged bar")
	for type_id: String in ["brute", "runner"]:
		var zombie: Zombie = _state.spawn_zombie(type_id, Vector2(200, 300))
		zombie.facing = Vector2.LEFT
		zombie.hp = zombie.max_hp / 2
		_layer.sync()
		assert_eq(_layer.get_child_count(), 1)
		assert_eq(_layer._active_sprites[zombie.uid], sprite, "Reuse the same node")
		assert_true(sprite.visible)
		assert_eq(sprite.position, zombie.pos)
		assert_almost_eq(sprite.rotation, 0.0)
		var expected_scale: float = 4.0
		assert_eq(sprite.scale, Vector2.ONE * expected_scale)
		assert_eq(sprite.modulate, Color.WHITE, "Pixel art keeps its own palette")
		assert_true(sprite.sprite_frames.resource_path.contains(type_id))
		assert_almost_eq(bar._ratio, float(zombie.hp) / zombie.max_hp)
		assert_true(bar.top_level, "Bar must not inherit unit rotation/scale")
		assert_eq(bar.global_position, zombie.pos)
		assert_almost_eq(bar.global_rotation, 0.0)
		assert_eq(bar.global_scale, Vector2.ONE)
		_state.zombies.remove(zombie.uid)

func test_complete_building_bar_dimensions_and_zero_hp() -> void:
	var building: Building = _state.buildings.all()[0]
	var node: Node2D = BuildingSprites.make(_state.data, building)
	var bar: HpBar = node.get_node("HpBar") as HpBar
	assert_almost_eq(bar.bar_width, building.size.x * Grid.TILE - 8.0)
	var footprint_h: float = float(building.size.y * Grid.TILE)
	var tex: Texture2D = BuildingSprites.texture_for(_state.data, building.type_id)
	var tex_h: float = float(tex.get_height()) if tex else footprint_h / float(Grid.PIXEL_SCALE)
	var expected_y_offset: float = footprint_h / 2.0 - tex_h * float(Grid.PIXEL_SCALE) - 4.0
	assert_almost_eq(bar.y_offset, expected_y_offset)
	building.hp = 0
	BuildingSprites.update_hp_bar(node, building)
	assert_almost_eq(bar._ratio, 0.0)
	node.free()

func test_survivor_bar_zero_hp_and_shelter_visibility() -> void:
	var layer := SurvivorLayer.new()
	layer.bind(_state)
	var survivor: Survivor = _state.survivors.all()[0]
	var sprite: AnimatedSprite2D = layer._sprites[survivor.uid] as AnimatedSprite2D
	var bar: HpBar = sprite.get_child(0) as HpBar
	survivor.hp = 0
	layer.sync()
	assert_almost_eq(bar._ratio, 0.0)
	survivor.hp = survivor.max_hp / 2
	survivor.sheltered = true
	layer.sync()
	assert_false(sprite.visible)
	assert_false(bar.visible, "Sheltered survivor must not leave a floating health bar")
	survivor.sheltered = false
	layer.sync()
	assert_true(bar.visible)
	assert_eq(bar.global_position, survivor.pos)
	layer.free()

func test_zombies_scenario_reaches_wall_attack_and_pauses() -> void:
	var scenario: GDScript = load("res://dev/scenarios/zombies.gd")
	scenario.setup(_main)
	assert_eq(_state.clock.phase, GameClock.Phase.NIGHT)
	assert_eq(_state.zombies.count(), 12)
	var damaged_walls: int = 0
	var wall_attackers: int = 0
	for building: Building in _state.buildings.all_of_type("wooden_wall"):
		if building.hp > 0 and building.hp < building.max_hp:
			damaged_walls += 1
	for zombie: Zombie in _state.zombies.all():
		var target: Building = _state.buildings.get_by_uid(zombie.target_building_uid)
		if target != null and target.type_id == "wooden_wall":
			wall_attackers += 1
	print("T-068 zombies end state: damaged walls=", damaged_walls, ", wall attackers=", wall_attackers)
	assert_gt(damaged_walls, 0, "Screenshot requires a damaged wall and its HP bar")
	assert_gt(wall_attackers, 0, "Scenario must demonstrate zombies attacking the wall line")
	assert_true(_state.clock.paused, "Freeze the demonstrated attack for capture")
	assert_eq(_in_camera_count(), 12, "The screenshot must show the dozen spawned zombies")
	assert_true(_state.clock.elapsed >= PhaseBanner.BANNER_SECONDS,
		"The night banner must finish before the paused capture")
	var types: Dictionary = {"walker": 0, "runner": 0, "brute": 0}
	var crowd: Array[Zombie] = _state.zombies.all()
	for zombie: Zombie in crowd:
		types[zombie.type_id] += 1
		for other: Zombie in crowd:
			if other.uid <= zombie.uid:
				continue
			assert_true(zombie.pos.distance_to(other.pos) >= Grid.TILE * 0.9,
				"Every zombie needs separate readable space in the paused capture")
	assert_eq(types, {"walker": 10, "runner": 1, "brute": 1})

func test_zombies_perf_scenario_has_visible_crowd_and_pauses() -> void:
	var scenario: GDScript = load("res://dev/scenarios/zombies_perf.gd")
	var pause_events: Array[bool] = []
	_state.clock.speed_changed.connect(func(paused: bool, _speed: int) -> void: pause_events.append(paused))
	scenario.setup(_main)
	assert_eq(_state.clock.phase, GameClock.Phase.NIGHT)
	assert_eq(_state.zombies.count(), 250)
	assert_true(_state.clock.paused, "Perf scenario must pause after the benchmark and banner")
	assert_eq(pause_events, [true], "Pausing must notify the HUD through speed_changed")
	assert_false(_state.waves.enabled, "Automatic waves must not alter the performance crowd")
	assert_true(_state.clock.elapsed >= PhaseBanner.BANNER_SECONDS,
		"The night banner must finish before the paused performance capture")
	var visible_count: int = _in_camera_count()
	print("T-068 zombies_perf end state: zombies in camera=", visible_count)
	assert_gt(visible_count, 24, "A large crowd must be in the capture, not merely counted in the HUD")

func test_zombies_perf_repeats_independently_of_global_rng() -> void:
	var scenario: GDScript = load("res://dev/scenarios/zombies_perf.gd")
	seed(17)
	scenario.setup(_main)
	var first_crowd: Array[Zombie] = _state.zombies.all()
	var second_state: GameState = GameState.new(GameData.load_default(), 1337)
	Game.state = second_state
	seed(90210)
	scenario.setup(_main)
	var second_crowd: Array[Zombie] = second_state.zombies.all()
	assert_eq(first_crowd.size(), second_crowd.size())
	if first_crowd.size() != second_crowd.size():
		return
	for i: int in range(first_crowd.size()):
		assert_eq(first_crowd[i].pos, second_crowd[i].pos, "Repeatable zombie position")
		assert_eq(first_crowd[i].facing, second_crowd[i].facing, "Repeatable zombie orientation")
		assert_eq(first_crowd[i].hp, second_crowd[i].hp, "Repeatable zombie health")
	assert_eq(_state.clock.elapsed, second_state.clock.elapsed)
	assert_true(second_state.clock.paused)

func _in_camera_count() -> int:
	var camera: Camera2D = _main.get_node("World/Camera2D") as Camera2D
	var view_size: Vector2 = Vector2(1280, 720) / camera.zoom
	var bounds := Rect2(camera.position - view_size / 2.0, view_size)
	var count: int = 0
	for zombie: Zombie in _state.zombies.all():
		if bounds.has_point(zombie.pos):
			count += 1
	return count
