extends TestCase
## Acceptance checks for T-004's rendered map, independent of frame timing.

var _world: Node2D
var _state: GameState

func before_each() -> void:
	_state = GameState.new(GameData.load_default(), 1337)
	var scene: PackedScene = load("res://scenes/world/world.tscn")
	_world = scene.instantiate() as Node2D
	# The synchronous runner executes before scenes enter the tree. Supply the
	# onready references explicitly, then initialize the same renderer used at launch.
	_world.set("ground", _world.get_node("Ground"))
	_world.set("ground_detail", _world.get_node("GroundDetail"))
	_world.set("props", _world.get_node("YSort/Props"))
	_world.set("buildings", _world.get_node("YSort/Buildings"))
	_world.set("camera", _world.get_node("Camera2D"))
	_world.call("_ready")
	_world.call("bind", _state)

func after_each() -> void:
	_world.free()
	_state = null

func test_ground_paints_every_terrain_cell_at_grid_centers() -> void:
	var ground: TileMapLayer = _world.get_node("Ground") as TileMapLayer
	assert_eq(ground.get_used_cells().size(), _state.map.size() * _state.map.size())
	assert_eq(ground.tile_set.tile_size, Vector2i(Grid.PX_TILE, Grid.PX_TILE))
	assert_eq(ground.scale, Vector2(Grid.PIXEL_SCALE, Grid.PIXEL_SCALE))
	for tile: Vector2i in ground.get_used_cells():
		var cell_center: Vector2 = ground.transform * ground.map_to_local(tile)
		assert_eq(cell_center, Grid.tile_to_world(tile), "Ground cell center")
		var source_id: int = ground.get_cell_source_id(tile)
		var source: TileSetAtlasSource = ground.tile_set.get_source(source_id) as TileSetAtlasSource
		assert_not_null(source, "Ground must use an atlas source")
		if source == null:
			continue
		var path: String = source.texture.resource_path
		match _state.map.terrain_at(tile):
			WorldMap.Terrain.GRASS:
				var file_name: String = path.get_file()
				assert_true(file_name.begins_with("grass_") or file_name.begins_with("flowers_"), "Grass tile texture")
			WorldMap.Terrain.DIRT:
				var suffix: String = PathTiles.path_tile_for(_state.map, tile)
				if suffix == "center":
					assert_true(path.get_file().begins_with("dirt"), "Dirt tile texture center")
				else:
					assert_eq(path.get_file(), "path_boundary.png", "Dirt tile path texture boundary")
					var expected_coords := Vector2i(PathTiles.SUFFIXES.find(suffix), 0)
					assert_eq(ground.get_cell_atlas_coords(tile), expected_coords, "Dirt boundary atlas coords")
			WorldMap.Terrain.ROAD:
				var suffix: String = PathTiles.path_tile_for(_state.map, tile)
				assert_eq(path.get_file(), "path_boundary.png", "Road path texture boundary")
				var expected_coords := Vector2i(PathTiles.SUFFIXES.find(suffix), 0)
				assert_eq(ground.get_cell_atlas_coords(tile), expected_coords, "Road boundary atlas coords")

func test_all_props_are_centered_without_stretching() -> void:
	var sprites: Dictionary = _world.get("_prop_sprites")
	var expected_count: int = 0
	var props_node: Node2D = _world.get_node("YSort/Props") as Node2D
	assert_true(props_node.y_sort_enabled, "Props node must be y-sorted")
	for x: int in range(_state.map.size()):
		for y: int in range(_state.map.size()):
			var tile := Vector2i(x, y)
			var occupant: int = _state.map.occupant_at(tile)
			if occupant not in [WorldMap.Occupant.TREE, WorldMap.Occupant.ROCK, WorldMap.Occupant.SCRAP]:
				continue
			expected_count += 1
			assert_has(sprites, tile, "Every prop occupant must render")
			if not sprites.has(tile):
				continue
			var sprite: Sprite2D = sprites[tile] as Sprite2D
			assert_eq(sprite.scale, Vector2(Grid.PIXEL_SCALE, Grid.PIXEL_SCALE), "Prop scale must be (4, 4)")
			assert_true(sprite.centered)
			var tex_h: float = sprite.texture.get_height()
			var drawn_bottom: float = sprite.position.y + (sprite.offset.y + tex_h / 2.0) * sprite.scale.y
			var tile_bottom: float = Grid.tile_to_world(tile).y + Grid.TILE / 2.0
			assert_almost_eq(drawn_bottom, tile_bottom, 0.01)
			assert_almost_eq(sprite.position.x, Grid.tile_to_world(tile).x, 0.01)
			if occupant in [WorldMap.Occupant.TREE, WorldMap.Occupant.ROCK]:
				var footprint_width: float = sprite.texture.get_width() * sprite.scale.x
				assert_true(footprint_width <= Grid.TILE, "Footprint width <= 64 for trees and rocks")
	assert_eq(sprites.size(), expected_count)
	assert_eq(props_node.get_child_count(), expected_count)

func test_ground_and_detail_determinism_across_binds() -> void:
	var state1 := GameState.new(GameData.load_default(), 4242)
	var state2 := GameState.new(GameData.load_default(), 4242)
	
	var scene: PackedScene = load("res://scenes/world/world.tscn")
	var world1: Node2D = scene.instantiate() as Node2D
	world1.set("ground", world1.get_node("Ground"))
	world1.set("ground_detail", world1.get_node("GroundDetail"))
	world1.set("props", world1.get_node("YSort/Props"))
	world1.set("buildings", world1.get_node("YSort/Buildings"))
	world1.set("camera", world1.get_node("Camera2D"))
	world1.call("_ready")
	world1.call("bind", state1)
	
	var world2: Node2D = scene.instantiate() as Node2D
	world2.set("ground", world2.get_node("Ground"))
	world2.set("ground_detail", world2.get_node("GroundDetail"))
	world2.set("props", world2.get_node("YSort/Props"))
	world2.set("buildings", world2.get_node("YSort/Buildings"))
	world2.set("camera", world2.get_node("Camera2D"))
	world2.call("_ready")
	world2.call("bind", state2)
	
	var g1: TileMapLayer = world1.get_node("Ground") as TileMapLayer
	var g2: TileMapLayer = world2.get_node("Ground") as TileMapLayer
	var gd1: TileMapLayer = world1.get_node("GroundDetail") as TileMapLayer
	var gd2: TileMapLayer = world2.get_node("GroundDetail") as TileMapLayer
	
	assert_eq(g1.get_used_cells().size(), g2.get_used_cells().size())
	for t in g1.get_used_cells():
		assert_eq(g1.get_cell_source_id(t), g2.get_cell_source_id(t), "Ground source id mismatch at %s" % t)
		assert_eq(g1.get_cell_atlas_coords(t), g2.get_cell_atlas_coords(t), "Ground atlas coords mismatch at %s" % t)
	
	assert_eq(gd1.get_used_cells().size(), gd2.get_used_cells().size())
	assert_true(gd1.get_used_cells().size() > 0, "GroundDetail should have painted tufts")
	for t in gd1.get_used_cells():
		assert_eq(gd1.get_cell_source_id(t), gd2.get_cell_source_id(t), "GroundDetail source id mismatch at %s" % t)
		assert_eq(gd1.get_cell_atlas_coords(t), gd2.get_cell_atlas_coords(t), "GroundDetail atlas coords mismatch at %s" % t)
	
	world1.free()
	world2.free()


func test_detail_tiles_use_scaled_tufts_only_on_unoccupied_grass() -> void:
	var ground: TileMapLayer = _world.get_node("Ground") as TileMapLayer
	var detail: TileMapLayer = _world.get_node("GroundDetail") as TileMapLayer
	var ysort: Node2D = _world.get_node("YSort") as Node2D
	assert_lt(ground.get_index(), detail.get_index())
	assert_lt(detail.get_index(), ysort.get_index())
	assert_eq(detail.scale, Vector2(4, 4))
	assert_eq(detail.tile_set.tile_size, Vector2i(16, 16))
	var used_textures: Dictionary = {}
	for tile: Vector2i in detail.get_used_cells():
		assert_eq(_state.map.terrain_at(tile), WorldMap.Terrain.GRASS)
		assert_eq(_state.map.occupant_at(tile), WorldMap.Occupant.NONE)
		assert_eq(detail.transform * detail.map_to_local(tile), Grid.tile_to_world(tile))
		var source: TileSetAtlasSource = detail.tile_set.get_source(detail.get_cell_source_id(tile)) as TileSetAtlasSource
		assert_not_null(source)
		if source == null:
			continue
		var path: String = source.texture.resource_path
		assert_true(path in ["res://assets/pixel/terrain/tuft_1.png", "res://assets/pixel/terrain/tuft_2.png"])
		used_textures[path] = true
	assert_eq(used_textures.size(), 2, "Both tuft variants should be visible")
	var cells_before: Array[Vector2i] = detail.get_used_cells()
	_state.map.changed.emit()
	assert_eq(detail.get_used_cells(), cells_before, "Map changes must not repaint decals")

func test_pixel_props_use_pack_textures_and_tree_crowns_rise_above_footprints() -> void:
	var sprites: Dictionary = _world.get("_prop_sprites")
	for tile: Vector2i in sprites:
		var sprite: Sprite2D = sprites[tile] as Sprite2D
		assert_true(sprite.texture.resource_path.begins_with("res://assets/pixel/props/"))
		if _state.map.occupant_at(tile) == WorldMap.Occupant.TREE:
			assert_eq(sprite.texture.get_size(), Vector2(16, 32))
			var drawn_top: float = sprite.position.y + (sprite.offset.y - sprite.texture.get_height() / 2.0) * sprite.scale.y
			assert_eq(drawn_top, Grid.tile_to_world(tile).y - Grid.TILE * 1.5, "Tree crown extends one tile above its footprint")

func _uses_nearest_filter(item: CanvasItem) -> bool:
	var current: Node = item
	while current != null:
		if current is CanvasItem:
			var canvas_item: CanvasItem = current as CanvasItem
			if canvas_item.texture_filter != CanvasItem.TEXTURE_FILTER_PARENT_NODE:
				return canvas_item.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
		current = current.get_parent()
	return int(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter")) == Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST

func test_pixel_ground_detail_and_props_use_nearest_filtering() -> void:
	var filter_message: String = "Ground must use Nearest filtering for crisp 4x pixels (project default=%d, Viewport Nearest=%d)" % [ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter"), Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST]
	assert_true(_uses_nearest_filter(_world.get_node("Ground") as CanvasItem), filter_message)
	assert_true(_uses_nearest_filter(_world.get_node("GroundDetail") as CanvasItem), "GroundDetail must use Nearest filtering for crisp 4x pixels")
	var sprites: Dictionary = _world.get("_prop_sprites")
	var all_props_nearest: bool = true
	for tile: Vector2i in sprites:
		all_props_nearest = all_props_nearest and _uses_nearest_filter(sprites[tile] as CanvasItem)
	assert_true(all_props_nearest, "Pixel props must use Nearest filtering")

func test_command_center_and_default_camera_match_two_by_two_footprint() -> void:
	var buildings: Node2D = _world.get_node("YSort/Buildings") as Node2D
	assert_eq(buildings.get_child_count(), 1)
	var b_node: Node2D = buildings.get_child(0) as Node2D
	var sprite: Sprite2D = null
	if b_node.get_child_count() > 0:
		sprite = b_node.get_child(0) as Sprite2D
	assert_not_null(sprite, "Command Center must use its available texture")
	if sprite == null:
		return
	var origin: Vector2i = _state.map.command_center_origin()
	var corner := Vector2(origin) * Grid.TILE
	var footprint_size := Vector2(Grid.TILE * 2, Grid.TILE * 2)
	assert_eq(sprite.texture.resource_path, "res://assets/pixel/buildings/command_center.png")
	
	assert_eq(sprite.scale, Vector2(Grid.PIXEL_SCALE, Grid.PIXEL_SCALE))
	var tex_h: float = sprite.texture.get_height()
	var drawn_bottom: float = b_node.position.y + sprite.position.y + (sprite.offset.y + tex_h / 2.0) * Grid.PIXEL_SCALE
	var footprint_bottom: float = corner.y + footprint_size.y
	assert_almost_eq(drawn_bottom, footprint_bottom, 0.01)
	assert_almost_eq(sprite.get_rect().size.x * sprite.scale.x, footprint_size.x, 0.01)
	var camera: Camera2D = _world.get_node("Camera2D") as Camera2D
	assert_eq(camera.position, corner + footprint_size / 2.0)
	assert_eq(camera.zoom, Vector2.ONE)

func test_ysort_contains_props_and_buildings() -> void:
	var ysort: Node2D = _world.get_node("YSort") as Node2D
	assert_not_null(ysort)
	assert_true(ysort.y_sort_enabled, "YSort node must be y-sorted")
	var props_node: Node2D = _world.get_node("YSort/Props") as Node2D
	var buildings_node: Node2D = _world.get_node("YSort/Buildings") as Node2D
	assert_not_null(props_node)
	assert_not_null(buildings_node)
	assert_true(props_node.y_sort_enabled, "Props node must be y-sorted")
	assert_true(buildings_node.y_sort_enabled, "Buildings node must be y-sorted")

func test_game_and_events_autoloads_are_registered() -> void:
	assert_eq(ProjectSettings.get_setting("autoload/Game"), "*res://scripts/autoload/game.gd")
	assert_eq(ProjectSettings.get_setting("autoload/Events"), "*res://scripts/autoload/events.gd")
	var events_script: GDScript = load("res://scripts/autoload/events.gd")
	var events: Node = events_script.new() as Node
	assert_true(events.has_signal("game_started"))
	events.free()
