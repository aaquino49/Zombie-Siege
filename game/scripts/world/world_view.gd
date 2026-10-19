extends Node2D

const SRC_GRASS_FIRST := 0
const GRASS_VARIANTS := 4
const SRC_FLOWERS_FIRST := 4
const FLOWERS_VARIANTS := 2
const SRC_DIRT_FIRST := 6
const DIRT_VARIANTS := 2
const SRC_PATH := 8
const SRC_TUFT_FIRST := 9
const TUFT_VARIANTS := 2

@onready var ground: TileMapLayer = $Ground
@onready var ground_detail: TileMapLayer = $GroundDetail
@onready var props: Node2D = $YSort/Props if has_node("YSort/Props") else $Props
@onready var buildings: Node2D = $YSort/Buildings if has_node("YSort/Buildings") else $Buildings
@onready var camera: CameraController = $Camera2D

var _state: GameState
var _prop_sprites: Dictionary = {}
var _building_nodes: Dictionary = {}
var _incomplete_uids: Dictionary = {}

func _ready() -> void:
	_init_tileset()

func _init_tileset() -> void:
	if ground == null and has_node("Ground"):
		ground = get_node("Ground") as TileMapLayer
	if ground_detail == null and has_node("GroundDetail"):
		ground_detail = get_node("GroundDetail") as TileMapLayer
	if props == null:
		if has_node("YSort/Props"):
			props = get_node("YSort/Props") as Node2D
		elif has_node("Props"):
			props = get_node("Props") as Node2D
	if buildings == null:
		if has_node("YSort/Buildings"):
			buildings = get_node("YSort/Buildings") as Node2D
		elif has_node("Buildings"):
			buildings = get_node("Buildings") as Node2D

	if ground:
		ground.scale = Vector2(Grid.PIXEL_SCALE, Grid.PIXEL_SCALE)
		ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ground_detail:
		ground_detail.scale = Vector2(Grid.PIXEL_SCALE, Grid.PIXEL_SCALE)
		ground_detail.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if props:
		props.y_sort_enabled = true
		props.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if buildings:
		buildings.y_sort_enabled = true

	var tileset: TileSet = TileSet.new()
	tileset.tile_size = Vector2i(Grid.PX_TILE, Grid.PX_TILE)
	
	for i in range(GRASS_VARIANTS):
		_add_single_tile_source(tileset, SRC_GRASS_FIRST + i, "res://assets/pixel/terrain/grass_%d.png" % (i + 1))
	for i in range(FLOWERS_VARIANTS):
		_add_single_tile_source(tileset, SRC_FLOWERS_FIRST + i, "res://assets/pixel/terrain/flowers_%d.png" % (i + 1))
	_add_single_tile_source(tileset, SRC_DIRT_FIRST, "res://assets/pixel/terrain/dirt.png")
	_add_single_tile_source(tileset, SRC_DIRT_FIRST + 1, "res://assets/pixel/terrain/dirt_2.png")
	_add_path_atlas_source(tileset, SRC_PATH, "res://assets/pixel/terrain/path_boundary.png")
	_add_single_tile_source(tileset, SRC_TUFT_FIRST, "res://assets/pixel/terrain/tuft_1.png")
	_add_single_tile_source(tileset, SRC_TUFT_FIRST + 1, "res://assets/pixel/terrain/tuft_2.png")
	
	if ground:
		ground.tile_set = tileset
	if ground_detail:
		ground_detail.tile_set = tileset

func _add_single_tile_source(tileset: TileSet, id: int, path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path) as Texture2D
	if not tex:
		return
	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.texture = tex
	source.texture_region_size = Vector2i(Grid.PX_TILE, Grid.PX_TILE)
	source.create_tile(Vector2i(0, 0))
	tileset.add_source(source, id)

func _add_path_atlas_source(tileset: TileSet, id: int, path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path) as Texture2D
	if not tex:
		return
	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.texture = tex
	source.texture_region_size = Vector2i(Grid.PX_TILE, Grid.PX_TILE)
	for i in range(PathTiles.SUFFIXES.size()):
		source.create_tile(Vector2i(i, 0))
	tileset.add_source(source, id)

func _cc_center() -> Vector2:
	var origin: Vector2i = _state.map.command_center_origin()
	return Grid.tile_to_world(origin) + Vector2(Grid.TILE, Grid.TILE) / 2.0

func bind(state: GameState) -> void:
	_state = state
	_draw_ground()
	_draw_ground_detail()
	_draw_props()
	($YSort/Decor as DecorLayer).bind(state)
	
	_state.map.changed.connect(_on_map_changed)
	_state.buildings.building_added.connect(_on_building_added)
	_state.buildings.building_removed.connect(_on_building_removed)
	_state.buildings.building_completed.connect(_on_building_completed)
	
	_draw_buildings()
	
	camera.position = _cc_center()
	camera.map_px = Vector2(_state.map.size(), _state.map.size()) * Grid.TILE
	var viewport_size: Vector2 = CameraMath.viewport_size_for(camera)
	camera.position = CameraMath.clamp_position(camera.position, camera.zoom.x, viewport_size, camera.map_px)
	camera.bind(_state)

func _draw_ground() -> void:
	ground.clear()
	var size: int = _state.map.size()
	for x in range(size):
		for y in range(size):
			var t: Vector2i = Vector2i(x, y)
			var terrain: int = _state.map.terrain_at(t)
			if terrain == WorldMap.Terrain.GRASS:
				var hash_val: int = absi(hash(Vector2(t.x, t.y)))
				var roll: int = hash_val % 100
				var source_id: int = SRC_GRASS_FIRST
				if roll < 58:
					source_id = SRC_GRASS_FIRST
				elif roll < 70:
					source_id = SRC_GRASS_FIRST + 1
				elif roll < 82:
					source_id = SRC_GRASS_FIRST + 2
				elif roll < 94:
					source_id = SRC_GRASS_FIRST + 3
				elif roll < 97:
					source_id = SRC_FLOWERS_FIRST
				else:
					source_id = SRC_FLOWERS_FIRST + 1
				ground.set_cell(t, source_id, Vector2i(0, 0))
			elif terrain == WorldMap.Terrain.DIRT:
				var suffix: String = PathTiles.path_tile_for(_state.map, t)
				if suffix == "center":
					var hash_val: int = absi(hash(Vector2(t.x, t.y)))
					var source_id: int = SRC_DIRT_FIRST + (hash_val % DIRT_VARIANTS)
					ground.set_cell(t, source_id, Vector2i(0, 0))
				else:
					var idx: int = PathTiles.SUFFIXES.find(suffix)
					if idx < 0:
						idx = 0
					ground.set_cell(t, SRC_PATH, Vector2i(idx, 0))
			elif terrain == WorldMap.Terrain.ROAD:
				var suffix: String = PathTiles.path_tile_for(_state.map, t)
				var idx: int = PathTiles.SUFFIXES.find(suffix)
				if idx < 0:
					idx = 0
				ground.set_cell(t, SRC_PATH, Vector2i(idx, 0))

func _draw_ground_detail() -> void:
	if ground_detail == null:
		return
	ground_detail.clear()
	var size: int = _state.map.size()
	for x in range(size):
		for y in range(size):
			var t: Vector2i = Vector2i(x, y)
			if _state.map.terrain_at(t) == WorldMap.Terrain.GRASS and _state.map.occupant_at(t) == WorldMap.Occupant.NONE:
				var h: int = absi(hash(Vector2(t.x + 7919, t.y + 6421)))
				var roll: int = h % 100
				if roll < 4:
					ground_detail.set_cell(t, SRC_TUFT_FIRST, Vector2i(0, 0))
				elif roll < 8:
					ground_detail.set_cell(t, SRC_TUFT_FIRST + 1, Vector2i(0, 0))

func _draw_props() -> void:
	for child in props.get_children():
		child.queue_free()
	_prop_sprites.clear()
	
	var size: int = _state.map.size()
	for x in range(size):
		for y in range(size):
			var t: Vector2i = Vector2i(x, y)
			var occ: int = _state.map.occupant_at(t)
			if occ in [WorldMap.Occupant.TREE, WorldMap.Occupant.ROCK, WorldMap.Occupant.SCRAP]:
				var sprite: Sprite2D = _create_prop_sprite(t, occ)
				if sprite:
					props.add_child(sprite)
					_prop_sprites[t] = sprite

func _create_prop_sprite(t: Vector2i, occ: int) -> Sprite2D:
	var path: String = ""
	var hash_val: int = absi(hash(Vector2(t.x, t.y)))
	
	if occ == WorldMap.Occupant.TREE:
		path = "res://assets/pixel/props/tree_1.png" if hash_val % 2 == 0 else "res://assets/pixel/props/tree_2.png"
	elif occ == WorldMap.Occupant.ROCK:
		path = "res://assets/pixel/props/rock_a.png" if hash_val % 2 == 0 else "res://assets/pixel/props/rock_b.png"
	elif occ == WorldMap.Occupant.SCRAP:
		var variant: int = hash_val % 3
		if variant == 0:
			path = "res://assets/pixel/props/scrap_1.png"
		elif variant == 1:
			path = "res://assets/pixel/props/scrap_2.png"
		else:
			path = "res://assets/pixel/props/scrap_3.png"
	
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path) as Texture2D
		if not tex:
			return null
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = tex
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.scale = Vector2(Grid.PIXEL_SCALE, Grid.PIXEL_SCALE)
		sprite.centered = true
		sprite.position = Grid.tile_to_world(t) + Vector2(0.0, Grid.TILE / 2.0)
		sprite.offset = Vector2(0.0, -tex.get_height() / 2.0)
		return sprite
	return null


func _draw_buildings() -> void:
	for child: Node2D in buildings.get_children():
		buildings.remove_child(child)
		child.queue_free()
	_building_nodes.clear()
	_incomplete_uids.clear()
	
	for b in _state.buildings.all():
		_on_building_added(b)

func _on_building_added(b: Building) -> void:
	var node: Node2D = BuildingSprites.make(_state.data, b, _state)
	buildings.add_child(node)
	_building_nodes[b.uid] = node
	if not b.complete:
		_incomplete_uids[b.uid] = true
	_update_wall_neighbours(b)

func _on_building_removed(b: Building) -> void:
	_incomplete_uids.erase(b.uid)
	if _building_nodes.has(b.uid):
		var node: Node2D = _building_nodes[b.uid]
		if is_instance_valid(node):
			buildings.remove_child(node)
			node.queue_free()
		_building_nodes.erase(b.uid)
	_update_wall_neighbours(b)

func _on_building_completed(b: Building) -> void:
	_on_building_removed(b)
	_on_building_added(b)

func _update_wall_neighbours(b: Building) -> void:
	if _state == null:
		return
	var checked_uids: Dictionary = {}
	for t in b.tiles():
		for dir in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var nt: Vector2i = t + dir
			var nb: Building = _state.buildings.get_at(nt)
			if nb and not checked_uids.has(nb.uid):
				checked_uids[nb.uid] = true
				var nb_data: Dictionary = _state.data.get_building(nb.type_id)
				if nb_data.get("autotile", false) or nb.type_id == "gate":
					var node: Node2D = _building_nodes.get(nb.uid)
					if node and is_instance_valid(node):
						var sprite: Sprite2D = node.get_node_or_null("Sprite") as Sprite2D
						if not sprite and node.get_child_count() > 0 and node.get_child(0) is Sprite2D:
							sprite = node.get_child(0) as Sprite2D
						if sprite:
							var new_tex: Texture2D = BuildingSprites.gate_texture(_state.data, _state, nb) if nb.type_id == "gate" else BuildingSprites.wall_texture(_state.data, _state, nb)
							if new_tex and sprite.texture != new_tex:
								sprite.texture = new_tex

func _process(_delta: float) -> void:
	if _state == null:
		return
	for uid in _building_nodes.keys():
		var b := _state.buildings.get_by_uid(uid)
		if b:
			if not b.complete:
				BuildingSprites.update_progress(_building_nodes[uid], b)
			else:
				BuildingSprites.update_hp_bar(_building_nodes[uid], b)
				BuildingSprites.update_aim(_building_nodes[uid], b)

func _on_map_changed() -> void:
	var to_remove: Array[Vector2i] = []
	for t in _prop_sprites:
		if _state.map.occupant_at(t) == WorldMap.Occupant.NONE:
			var sprite: Sprite2D = _prop_sprites[t]
			if is_instance_valid(sprite):
				sprite.queue_free()
			to_remove.append(t)
			
	for t in to_remove:
		_prop_sprites.erase(t)
