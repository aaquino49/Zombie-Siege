extends TestCase

var _world: Node2D
var _state: GameState

func before_each() -> void:
	_state = GameState.new(GameData.load_default(), 1337)
	var scene: PackedScene = load("res://scenes/world/world.tscn")
	_world = scene.instantiate() as Node2D
	_world.set("ground", _world.get_node("Ground"))
	_world.set("props", _world.get_node("YSort/Props"))
	_world.set("buildings", _world.get_node("YSort/Buildings"))
	_world.set("camera", _world.get_node("Camera2D"))
	_world.call("_ready")
	_world.call("bind", _state)

func after_each() -> void:
	_world.free()
	_state = null

func test_adding_and_removing_buildings_updates_nodes() -> void:
	var buildings: Node2D = _world.get_node("YSort/Buildings") as Node2D
	var _building_nodes: Dictionary = _world.get("_building_nodes")
	var o: Vector2i = _state.map.command_center_origin()
	
	assert_eq(buildings.get_child_count(), 1)
	assert_eq(_building_nodes.size(), 1)
	
	var cc_uid: int = -1
	for b in _state.buildings.all():
		cc_uid = b.uid
	assert_true(_building_nodes.has(cc_uid))
	
	var r: int = _state.try_place("shelter", o + Vector2i(2, -2))
	assert_eq(r, Placement.Result.OK)
	
	assert_eq(buildings.get_child_count(), 2)
	
	var shelter_uid: int = -1
	for b in _state.buildings.all():
		if b.type_id == "shelter":
			shelter_uid = b.uid
	
	var shelter_node: Node2D = _building_nodes[shelter_uid] as Node2D
	var shelter_b: Building = _state.buildings.get_by_uid(shelter_uid)
	assert_eq(shelter_node.position, shelter_b.center_world())
	
	var sprite: Sprite2D = shelter_node.get_child(0) as Sprite2D
	assert_eq(sprite.texture.resource_path, "res://assets/pixel/buildings/shelter.png")
	assert_eq(sprite.get_rect().size * sprite.scale, Vector2(128, 128))
	var tex_h: float = sprite.texture.get_height()
	var bottom_y: float = shelter_node.position.y + sprite.position.y + (sprite.offset.y + tex_h / 2.0) * Grid.PIXEL_SCALE
	var expected_bottom: float = shelter_b.center_world().y + Vector2(shelter_b.size).y * Grid.TILE / 2.0
	assert_almost_eq(bottom_y, expected_bottom, 0.01, "Shelter sprite must be bottom-anchored")
	assert_almost_eq(sprite.get_rect().size.x * sprite.scale.x, float(shelter_b.size.x * Grid.TILE), 0.01)
	
	_state.buildings.remove(shelter_uid)
	assert_eq(buildings.get_child_count(), 1)
	assert_false(_building_nodes.has(shelter_uid))

func test_wall_at_free_tile_draws_64x64() -> void:
	var o: Vector2i = _state.map.command_center_origin()
	var wall_t: Vector2i = o + Vector2i(-2, 3)
	var r: int = _state.try_place("wooden_wall", wall_t)
	assert_eq(r, Placement.Result.OK)
	
	var uid: int = -1
	for b in _state.buildings.all():
		if b.type_id == "wooden_wall":
			uid = b.uid
	
	var _building_nodes: Dictionary = _world.get("_building_nodes")
	var wall_node: Node2D = _building_nodes[uid] as Node2D
	
	assert_eq(wall_node.position, Grid.tile_to_world(wall_t))
	var sprite: Sprite2D = wall_node.get_child(0) as Sprite2D
	assert_eq(sprite.get_rect().size * sprite.scale, Vector2(64, 64))

func test_make_turret_has_two_sprites() -> void:
	var free_origin: Vector2i = _state.map.command_center_origin() + Vector2i(-3, -3)
	var b: Building = _state.buildings.add("turret", free_origin, true)
	var node: Node2D = BuildingSprites.make(_state.data, b)
	
	var sprite_count: int = 0
	for child in node.get_children():
		if child is Sprite2D:
			sprite_count += 1
	assert_eq(sprite_count, 2)
	var barrel: Sprite2D = node.get_node_or_null("TurretBarrel") as Sprite2D
	assert_not_null(barrel)
	assert_eq(barrel.rotation, 0.0)
	node.free()

func test_texture_for_returns_non_null_for_all_ids() -> void:
	for type_id in _state.data.building_ids():
		var tex: Texture2D = BuildingSprites.texture_for(_state.data, type_id)
		assert_not_null(tex, type_id + " texture should exist")

func test_blueprint_alpha_progress_and_opaque_replacement_on_finish() -> void:
	var origin: Vector2i = _state.map.command_center_origin() + Vector2i(3, -2)
	assert_eq(_state.try_place("shelter", origin), Placement.Result.OK)
	var b: Building = _state.buildings.get_at(origin)
	var nodes: Dictionary = _world.get("_building_nodes")
	var old_node: Node2D = nodes[b.uid]
	var old_id: int = old_node.get_instance_id()
	var sprite: Sprite2D = old_node.get_child(0) as Sprite2D
	assert_lt(sprite.modulate.a, 1.0)
	assert_not_null(old_node.get_node_or_null("Scaffold"), "Blueprint must have Scaffold")
	var bg: ColorRect = old_node.get_node("ProgressBg") as ColorRect
	var fill: ColorRect = old_node.get_node("ProgressFill") as ColorRect
	assert_eq(fill.size.x, 0.0)
	for ratio: float in [0.25, 0.5, 0.75]:
		b.progress = b.build_time * ratio
		_world.call("_process", 0.0)
		assert_almost_eq(fill.size.x, bg.size.x * ratio)
	_state.buildings.finish(b.uid)
	var new_node: Node2D = nodes[b.uid]
	assert_ne(new_node.get_instance_id(), old_id)
	var opaque: Sprite2D = new_node.get_child(0) as Sprite2D
	assert_eq(opaque.modulate.a, 1.0)
	assert_true(new_node.get_node_or_null("Scaffold") == null, "Completed building must lose Scaffold")
	assert_true(new_node.get_node_or_null("ProgressFill") == null)
	assert_eq(_world.get_node("YSort/Buildings").get_child_count(), _state.buildings.all().size())
	var incomplete: Dictionary = _world.get("_incomplete_uids")
	assert_false(incomplete.has(b.uid))
	_state.buildings.finish(b.uid)
	assert_eq(_world.get_node("YSort/Buildings").get_child_count(), _state.buildings.all().size())

func test_complete_turret_barrel_tracks_aim_each_frame() -> void:
	var b: Building = _state.buildings.add("turret", _state.map.command_center_origin() + Vector2i(3, -2), true)
	var nodes: Dictionary = _world.get("_building_nodes")
	var barrel: Sprite2D = nodes[b.uid].get_node("TurretBarrel") as Sprite2D
	var expectations := {
		Vector2.UP: "turret_barrel_up.png",
		Vector2.RIGHT: "turret_barrel_right.png",
		Vector2.DOWN: "turret_barrel_down.png",
		Vector2.LEFT: "turret_barrel_left.png",
		Vector2(1, -1).normalized(): "turret_barrel_right.png",
	}
	for aim: Vector2 in expectations:
		b.aim = aim
		_world.call("_process", 0.0)
		assert_eq(barrel.rotation, 0.0, "Turret barrel must never rotate")
		assert_eq(barrel.texture.resource_path.get_file(), expectations[aim])

func test_turret_blueprint_does_not_rotate_until_complete() -> void:
	var b: Building = _state.buildings.add("turret", _state.map.command_center_origin() + Vector2i(3, -2), false)
	b.aim = Vector2.RIGHT
	var nodes: Dictionary = _world.get("_building_nodes")
	_world.call("_process", 0.0)
	var barrel: Sprite2D = nodes[b.uid].get_node("TurretBarrel") as Sprite2D
	assert_eq(barrel.rotation, 0.0)
	assert_eq(barrel.texture.resource_path.get_file(), "turret_barrel_down.png")
	_state.buildings.finish(b.uid)
	barrel = nodes[b.uid].get_node("TurretBarrel") as Sprite2D
	assert_eq(barrel.rotation, 0.0)
	assert_eq(barrel.texture.resource_path.get_file(), "turret_barrel_right.png")

func test_wall_suffix_covers_all_16_cases() -> void:
	# 0 connections
	assert_eq(BuildingSprites.wall_suffix(false, false, false, false), "post")
	# 1 connection
	assert_eq(BuildingSprites.wall_suffix(true, false, false, false), "end_n")
	assert_eq(BuildingSprites.wall_suffix(false, true, false, false), "end_e")
	assert_eq(BuildingSprites.wall_suffix(false, false, true, false), "end_s")
	assert_eq(BuildingSprites.wall_suffix(false, false, false, true), "end_w")
	# 2 connections
	assert_eq(BuildingSprites.wall_suffix(true, false, true, false), "v")
	assert_eq(BuildingSprites.wall_suffix(false, true, false, true), "h")
	assert_eq(BuildingSprites.wall_suffix(true, true, false, false), "corner_ne")
	assert_eq(BuildingSprites.wall_suffix(true, false, false, true), "corner_nw")
	assert_eq(BuildingSprites.wall_suffix(false, true, true, false), "corner_se")
	assert_eq(BuildingSprites.wall_suffix(false, false, true, true), "corner_sw")
	# 3 connections
	assert_eq(BuildingSprites.wall_suffix(true, true, true, false), "tee_nes")
	assert_eq(BuildingSprites.wall_suffix(false, true, true, true), "tee_esw")
	assert_eq(BuildingSprites.wall_suffix(true, false, true, true), "tee_nsw")
	assert_eq(BuildingSprites.wall_suffix(true, true, false, true), "tee_new")
	# 4 connections
	assert_eq(BuildingSprites.wall_suffix(true, true, true, true), "cross")

func test_placed_l_of_three_walls_and_removing_middle() -> void:
	var o: Vector2i = _state.map.command_center_origin()
	var t1 := o + Vector2i(5, 0)
	var t2 := o + Vector2i(5, 1)
	var t3 := o + Vector2i(6, 1)
	
	_state.try_place("wooden_wall", t1)
	_state.try_place("wooden_wall", t2)
	_state.try_place("wooden_wall", t3)
	for b in _state.buildings.blueprints():
		_state.buildings.finish(b.uid)
		
	var nodes: Dictionary = _world.get("_building_nodes")
	var b1: Building = _state.buildings.get_at(t1)
	var b2: Building = _state.buildings.get_at(t2)
	var b3: Building = _state.buildings.get_at(t3)
	
	var s1: Sprite2D = nodes[b1.uid].get_child(0) as Sprite2D
	var s2: Sprite2D = nodes[b2.uid].get_child(0) as Sprite2D
	var s3: Sprite2D = nodes[b3.uid].get_child(0) as Sprite2D
	
	assert_eq(s1.texture.resource_path.get_file(), "fence_end_s.png")
	assert_eq(s2.texture.resource_path.get_file(), "fence_corner_ne.png")
	assert_eq(s3.texture.resource_path.get_file(), "fence_end_w.png")
	
	# Remove middle wall
	_state.buildings.remove(b2.uid)
	
	assert_eq(s1.texture.resource_path.get_file(), "fence_post.png")
	assert_eq(s3.texture.resource_path.get_file(), "fence_post.png")

func test_wall_next_to_blueprint_wall_joins() -> void:
	var o: Vector2i = _state.map.command_center_origin()
	var t1 := o + Vector2i(-5, 0)
	var t2 := o + Vector2i(-5, 1)
	var b1: Building = _state.buildings.add("wooden_wall", t1, true)
	var b2: Building = _state.buildings.add("wooden_wall", t2, false)
	
	var nodes: Dictionary = _world.get("_building_nodes")
	var s1: Sprite2D = nodes[b1.uid].get_child(0) as Sprite2D
	var s2: Sprite2D = nodes[b2.uid].get_child(0) as Sprite2D
	
	assert_eq(s1.texture.resource_path.get_file(), "fence_end_s.png")
	assert_eq(s2.texture.resource_path.get_file(), "fence_end_n.png")

func test_gate_texture_requires_only_north_and_south_wall_neighbours() -> void:
	var origin: Vector2i = _state.map.command_center_origin() + Vector2i(7, 7)
	var cases: Array[Dictionary] = [
		{"name": "north_south", "dirs": [Vector2i.UP, Vector2i.DOWN], "expected": "gate_closed_v.png"},
		{"name": "east_west", "dirs": [Vector2i.LEFT, Vector2i.RIGHT], "expected": "gate_closed.png"},
		{"name": "none", "dirs": [], "expected": "gate_closed.png"},
		{"name": "north_east", "dirs": [Vector2i.UP, Vector2i.RIGHT], "expected": "gate_closed.png"},
		{"name": "all_four", "dirs": [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT], "expected": "gate_closed.png"},
	]
	for item: Dictionary in cases:
		var state: GameState = GameState.new(GameData.load_default(), 120)
		var tile: Vector2i = state.map.command_center_origin() + Vector2i(7, 7)
		var gate: Building = state.buildings.add("gate", tile, true)
		for dir: Vector2i in item["dirs"]:
			state.buildings.add("wooden_wall", tile + dir, true)
		var tex: Texture2D = BuildingSprites.gate_texture(state.data, state, gate)
		assert_eq(tex.resource_path.get_file(), item["expected"], str(item["name"]))

func test_gate_retextures_when_north_and_south_walls_are_placed_or_removed() -> void:
	var tile: Vector2i = _state.map.command_center_origin() + Vector2i(7, 7)
	var gate: Building = _state.buildings.add("gate", tile, true)
	var nodes: Dictionary = _world.get("_building_nodes")
	var gate_sprite: Sprite2D = nodes[gate.uid].get_node("Sprite") as Sprite2D
	assert_eq(gate_sprite.texture.resource_path.get_file(), "gate_closed.png")
	var north: Building = _state.buildings.add("wooden_wall", tile + Vector2i.UP, true)
	assert_eq(gate_sprite.texture.resource_path.get_file(), "gate_closed.png")
	var south: Building = _state.buildings.add("wooden_wall", tile + Vector2i.DOWN, true)
	assert_eq(gate_sprite.texture.resource_path.get_file(), "gate_closed_v.png")
	_state.buildings.remove(south.uid)
	assert_eq(gate_sprite.texture.resource_path.get_file(), "gate_closed.png")
	south = _state.buildings.add("wooden_wall", tile + Vector2i.DOWN, true)
	assert_eq(gate_sprite.texture.resource_path.get_file(), "gate_closed_v.png")
	_state.buildings.remove(north.uid)
	assert_eq(gate_sprite.texture.resource_path.get_file(), "gate_closed.png")
	assert_eq(gate_sprite.rotation, 0.0)
	assert_eq(gate_sprite.scale, Vector2(4, 4))
	assert_eq(gate_sprite.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	var drawn_bottom: float = gate_sprite.position.y + (gate_sprite.offset.y + gate_sprite.texture.get_height() / 2.0) * gate_sprite.scale.y
	assert_almost_eq(drawn_bottom, Grid.TILE / 2.0, 0.01, "Gate sprite bottom anchor")
