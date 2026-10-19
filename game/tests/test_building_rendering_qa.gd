extends TestCase
## T-044: store-driven rendering, incremental updates and sprite fallbacks.

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

func test_placement_and_removal_preserve_other_nodes() -> void:
	var container: Node2D = _world.get_node("YSort/Buildings") as Node2D
	var nodes: Dictionary = _world.get("_building_nodes")
	var cc: Building = _state.buildings.all()[0]
	var cc_node: Node2D = nodes[cc.uid] as Node2D
	var origin: Vector2i = _state.map.command_center_origin()
	assert_eq(_state.try_place("shelter", origin + Vector2i(2, -2)), Placement.Result.OK)
	var shelter: Building = _state.buildings.get_at(origin + Vector2i(2, -2))
	assert_not_null(shelter)
	if shelter == null:
		return
	var shelter_node: Node2D = nodes[shelter.uid] as Node2D
	assert_eq(container.get_child_count(), 2)
	assert_eq(nodes[cc.uid], cc_node, "Placement must preserve the CC node")
	assert_false(cc_node.is_queued_for_deletion())
	assert_eq(_state.try_place("wooden_wall", origin + Vector2i(-2, 3)), Placement.Result.OK)
	var wall: Building = _state.buildings.get_at(origin + Vector2i(-2, 3))
	assert_not_null(wall)
	if wall == null:
		return
	var wall_node: Node2D = nodes[wall.uid] as Node2D
	assert_eq(container.get_child_count(), 3)
	assert_eq(nodes[shelter.uid], shelter_node, "Adding a wall must preserve the shelter node")
	_state.buildings.remove(shelter.uid)
	assert_eq(container.get_child_count(), 2)
	assert_eq(nodes.size(), 2)
	assert_false(nodes.has(shelter.uid))
	assert_true(shelter_node.get_parent() == null, "Removed node must detach immediately")
	assert_true(shelter_node.is_queued_for_deletion(), "Removed node must be freed next frame")
	assert_eq(nodes[cc.uid], cc_node)
	assert_eq(nodes[wall.uid], wall_node)
	assert_false(cc_node.is_queued_for_deletion())
	assert_false(wall_node.is_queued_for_deletion())

func test_rejected_placement_leaves_rendered_nodes_unchanged() -> void:
	var container: Node2D = _world.get_node("YSort/Buildings") as Node2D
	var cc_node: Node2D = container.get_child(0) as Node2D
	assert_eq(_state.try_place("shelter", _state.map.command_center_origin()), Placement.Result.BLOCKED)
	assert_eq(container.get_child_count(), 1)
	assert_eq(container.get_child(0), cc_node)
	assert_false(cc_node.is_queued_for_deletion())

func test_empty_building_store_has_no_hard_coded_command_center() -> void:
	var cc: Building = _state.buildings.all()[0]
	_state.buildings.remove(cc.uid)
	var container: Node2D = _world.get_node("YSort/Buildings") as Node2D
	assert_eq(container.get_child_count(), 0)
	_world.call("_draw_buildings")
	assert_eq(container.get_child_count(), 0)
	var nodes: Dictionary = _world.get("_building_nodes")
	assert_eq(nodes.size(), 0)

func test_texture_lookup_handles_unknown_missing_key_and_missing_file() -> void:
	assert_eq(BuildingSprites.texture_for(_state.data, "qa_unknown_building"), null)
	var record: Dictionary = _state.data.get_building("shelter")
	record.erase("sprite")
	assert_eq(BuildingSprites.texture_for(_state.data, "shelter"), null)
	record["sprite"] = "qa_missing_sprite"
	assert_eq(BuildingSprites.texture_for(_state.data, "shelter"), null)

func test_missing_turret_top_keeps_base_sprite() -> void:
	var record: Dictionary = _state.data.get_building("turret")
	record["sprite_top"] = "qa_missing_barrel"
	var building: Building = _state.buildings.add("turret", _state.map.command_center_origin() + Vector2i(-3, -3), true)
	var node: Node2D = BuildingSprites.make(_state.data, building)
	assert_eq(node.get_child_count(), 2) # Sprite and HpBar
	var base: Sprite2D = node.get_child(0) as Sprite2D
	assert_not_null(base)
	if base != null:
		assert_eq(base.texture.resource_path, "res://assets/pixel/buildings/turret_base.png")
	node.free()

func test_sprite_scaling_uses_building_footprint() -> void:
	var building: Building = _state.buildings.all()[0]
	building.size = Vector2i(3, 1)
	var node: Node2D = BuildingSprites.make(_state.data, building)
	assert_eq(node.position, building.center_world())
	var sprite: Sprite2D = node.get_child(0) as Sprite2D
	assert_not_null(sprite)
	if sprite != null:
		assert_eq(sprite.scale, Vector2(Grid.PIXEL_SCALE, Grid.PIXEL_SCALE))
		var tex_h: float = sprite.texture.get_height()
		var bottom_y: float = node.position.y + sprite.position.y + (sprite.offset.y + tex_h / 2.0) * Grid.PIXEL_SCALE
		var expected_bottom: float = building.center_world().y + Vector2(building.size).y * Grid.TILE / 2.0
		assert_almost_eq(bottom_y, expected_bottom, 0.01, "Building sprite must be bottom-anchored")
	node.free()
