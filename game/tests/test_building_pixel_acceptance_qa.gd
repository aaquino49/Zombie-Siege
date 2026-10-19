extends TestCase
## T-104: pixel geometry and mixed-material joins beyond the existing view tests.

var _state: GameState
var _world: Node2D

func before_each() -> void:
	_state = GameState.new(GameData.load_default(), 1337)
	_state.clock.day = 8
	_state.resources.add("wood", 1000)
	_state.resources.add("scrap", 1000)
	_world = (load("res://scenes/world/world.tscn") as PackedScene).instantiate() as Node2D
	_world.set("ground", _world.get_node("Ground"))
	_world.set("props", _world.get_node("YSort/Props"))
	_world.set("buildings", _world.get_node("YSort/Buildings"))
	_world.set("camera", _world.get_node("Camera2D"))
	_world.call("_ready")
	_world.call("bind", _state)

func after_each() -> void:
	_world.free()
	_state = null

func _sprite(b: Building) -> Sprite2D:
	var nodes: Dictionary = _world.get("_building_nodes")
	return nodes[b.uid].get_node("Sprite") as Sprite2D

func test_all_building_types_keep_native_proportions_and_bottom_anchor() -> void:
	for type_id: String in _state.data.building_ids():
		var b: Building = _state.buildings.add(type_id, Vector2i(8, 8), true)
		if type_id == "campfire":
			_assert_campfire_lit_geometry(b)
			_state.buildings.remove(b.uid)
			continue
		var sprite: Sprite2D = _sprite(b)
		assert_not_null(sprite, type_id)
		if sprite == null:
			return
		assert_true(sprite.texture.resource_path.begins_with(BuildingSprites.PIXEL_DIR), type_id)
		assert_eq(sprite.scale, Vector2(Grid.PIXEL_SCALE, Grid.PIXEL_SCALE), type_id)
		assert_eq(sprite.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, type_id)
		assert_almost_eq(sprite.texture.get_width() * sprite.scale.x, b.size.x * Grid.TILE, 0.01, type_id)
		var bottom: float = b.center_world().y + sprite.position.y + (sprite.offset.y + sprite.texture.get_height() / 2.0) * sprite.scale.y
		assert_almost_eq(bottom, (b.origin.y + b.size.y) * Grid.TILE, 0.01, type_id)
		var hp: HpBar = sprite.get_parent().get_node("HpBar") as HpBar
		var top: float = sprite.position.y + (sprite.offset.y - sprite.texture.get_height() / 2.0) * sprite.scale.y
		assert_almost_eq(hp.y_offset, top - 4.0, 0.01, type_id)
		_state.buildings.remove(b.uid)

## T-217 focused assertion: a completed Campfire plays T-224's four-frame
## 64x16 strip at 6 fps with the same native scale, nearest filter, 16x16
## footprint geometry and HP-bar placement as a static sprite.
func _assert_campfire_lit_geometry(b: Building) -> void:
	var nodes: Dictionary = _world.get("_building_nodes")
	var sprite: AnimatedSprite2D = nodes[b.uid].get_node("Sprite") as AnimatedSprite2D
	assert_not_null(sprite, "campfire")
	if sprite == null:
		return
	assert_true(sprite.is_playing(), "campfire")
	assert_eq(sprite.sprite_frames.get_frame_count("default"), 4, "campfire")
	assert_eq(sprite.sprite_frames.get_animation_speed("default"), 6.0, "campfire")
	assert_eq(sprite.scale, Vector2(Grid.PIXEL_SCALE, Grid.PIXEL_SCALE), "campfire")
	assert_eq(sprite.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, "campfire")
	var frame: Texture2D = sprite.sprite_frames.get_frame_texture("default", 0)
	assert_almost_eq(frame.get_width() * sprite.scale.x, b.size.x * Grid.TILE, 0.01, "campfire")
	var bottom: float = b.center_world().y + sprite.position.y + (sprite.offset.y + frame.get_height() / 2.0) * sprite.scale.y
	assert_almost_eq(bottom, (b.origin.y + b.size.y) * Grid.TILE, 0.01, "campfire")
	var hp: HpBar = sprite.get_parent().get_node("HpBar") as HpBar
	var top: float = sprite.position.y + (sprite.offset.y - frame.get_height() / 2.0) * sprite.scale.y
	assert_almost_eq(hp.y_offset, top - 4.0, 0.01, "campfire")

func test_wall_upgrade_keeps_gate_and_neighbour_joins_and_existing_nodes() -> void:
	var o := Vector2i(8, 8)
	_state.map.vacate(o, Vector2i(3, 1))
	var west: Building = _state.buildings.add("wooden_wall", o, true)
	var middle: Building = _state.buildings.add("wooden_wall", o + Vector2i.RIGHT, true)
	var east: Building = _state.buildings.add("gate", o + Vector2i(2, 0), true)
	var west_sprite: Sprite2D = _sprite(west)
	var gate_sprite: Sprite2D = _sprite(east)
	assert_eq(_state.try_upgrade(middle.uid), Placement.Result.OK)
	var replacement: Building = _state.buildings.get_at(middle.origin)
	assert_eq(replacement.type_id, "reinforced_wall")
	assert_eq(_sprite(replacement).texture.resource_path.get_file(), "wall_earth_h.png")
	assert_eq(_sprite(west), west_sprite, "Retiling preserves neighbouring nodes")
	assert_eq(west_sprite.texture.resource_path.get_file(), "fence_end_e.png")
	assert_eq(_sprite(east), gate_sprite)
	assert_eq(gate_sprite.texture.resource_path.get_file(), "gate_closed.png")
	_state.buildings.finish(replacement.uid)
	assert_eq(_sprite(replacement).texture.resource_path.get_file(), "wall_earth_h.png")
	_state.buildings.remove(replacement.uid)
	assert_eq(west_sprite.texture.resource_path.get_file(), "fence_post.png")
	assert_eq(gate_sprite.texture.resource_path.get_file(), "gate_closed.png")

func test_one_tile_scaffold_is_opaque_and_disappears_on_completion() -> void:
	var b: Building = _state.buildings.add("wooden_wall", Vector2i(8, 8), false)
	var nodes: Dictionary = _world.get("_building_nodes")
	var scaffold: Sprite2D = nodes[b.uid].get_node("Scaffold") as Sprite2D
	assert_eq(scaffold.texture.resource_path.get_file(), "construction_1x1.png")
	assert_eq(scaffold.modulate, Color.WHITE)
	assert_eq(scaffold.scale, Vector2(Grid.PIXEL_SCALE, Grid.PIXEL_SCALE))
	assert_gt(scaffold.get_index(), _sprite(b).get_index())
	b.progress = b.build_time * 0.5
	_world.call("_process", 0.0)
	var fill: ColorRect = nodes[b.uid].get_node("ProgressFill") as ColorRect
	var bg: ColorRect = nodes[b.uid].get_node("ProgressBg") as ColorRect
	assert_almost_eq(fill.size.x, bg.size.x / 2.0)
	_state.buildings.finish(b.uid)
	assert_true(nodes[b.uid].get_node_or_null("Scaffold") == null)

func test_tall_ghost_matches_real_building_geometry() -> void:
	var bm: BuildMode = _world.get_node("BuildMode") as BuildMode
	bm.bind(_state)
	bm.select("storage")
	var o := Vector2i(8, 8)
	bm.preview_at(o)
	bm._process(0.0)
	var ghost: Sprite2D = bm._ghost_sprites[0]
	var b: Building = _state.buildings.add("storage", o, true)
	var real: Sprite2D = _sprite(b)
	assert_eq(ghost.texture, real.texture)
	assert_eq(ghost.scale, real.scale)
	assert_eq(ghost.offset, real.offset)
	assert_eq(ghost.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_eq(ghost.position, b.center_world() + real.position)
	assert_eq(ghost.texture.get_size() * ghost.scale, Vector2(128, 192))

func test_zero_turret_aim_defaults_down_without_rotation() -> void:
	var b: Building = _state.buildings.add("turret", Vector2i(8, 8), true)
	b.aim = Vector2.ZERO
	_world.call("_process", 0.0)
	var nodes: Dictionary = _world.get("_building_nodes")
	var barrel: Sprite2D = nodes[b.uid].get_node("TurretBarrel") as Sprite2D
	assert_eq(barrel.texture.resource_path.get_file(), "turret_barrel_down.png")
	assert_eq(barrel.rotation, 0.0)

func test_rendered_l_has_continuous_north_join() -> void:
	var o := Vector2i(8, 8)
	var north: Building = _state.buildings.add("wooden_wall", o, true)
	var corner: Building = _state.buildings.add("wooden_wall", o + Vector2i.DOWN, true)
	_state.buildings.add("wooden_wall", o + Vector2i.DOWN + Vector2i.RIGHT, true)
	var upper_image: Image = _sprite(north).texture.get_image()
	var corner_image: Image = _sprite(corner).texture.get_image()
	var touching: bool = false
	for x: int in range(upper_image.get_width()):
		if upper_image.get_pixel(x, upper_image.get_height() - 1).a > 0.0 and corner_image.get_pixel(x, 0).a > 0.0:
			touching = true
	assert_true(touching, "The north arm of fence_corner_ne must touch fence_end_s at the shared tile edge; an entirely transparent north edge leaves a visible gap")
