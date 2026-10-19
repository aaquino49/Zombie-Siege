class_name DecorLayer extends Node2D
## View-only scenery. tile is the bottom-centre footprint tile; size is in tiles.

const PROP_ROOT := "res://assets/pixel/props/"
const SMALL_KINDS: Array[String] = ["barrel", "tire", "sign", "straw", "bush"]
const SMALL_VARIANTS: Array[int] = [4, 2, 8, 6, 10]
const CC_RADIUS := 6.0
const CAR_SPACING := 8.0
const SMALL_DENSITY := 0.03
const MAX_SMALL_PROPS := 300

var _state: GameState
var _entries: Array[Dictionary] = []
var _sprites: Array[Sprite2D] = []
var _by_tile: Dictionary = {}

static func footprint(entry: Dictionary) -> Array[Vector2i]:
	var tile: Vector2i = entry["tile"]
	var size: Vector2i = entry["size"]
	return Grid.rect_tiles(tile - Vector2i(size.x / 2, size.y - 1), size)

static func eligible(map: WorldMap, tile: Vector2i) -> bool:
	if not Grid.in_bounds(tile, map.size()):
		return false
	if map.terrain_at(tile) != WorldMap.Terrain.GRASS or map.occupant_at(tile) != WorldMap.Occupant.NONE:
		return false
	# Measure from the nearest CC footprint tile, keeping its entire clearing open.
	for cc_tile: Vector2i in Grid.rect_tiles(map.command_center_origin(), Vector2i(2, 2)):
		if Vector2(tile).distance_to(Vector2(cc_tile)) <= CC_RADIUS:
			return false
	for dx: int in range(-1, 2):
		for dy: int in range(-1, 2):
			if map.occupant_at(tile + Vector2i(dx, dy)) in [WorldMap.Occupant.TREE, WorldMap.Occupant.ROCK, WorldMap.Occupant.SCRAP]:
				return false
	return true

static func _near_road(map: WorldMap, tile: Vector2i) -> bool:
	for dx: int in range(-2, 3):
		for dy: int in range(-2, 3):
			if dx * dx + dy * dy <= 4 and map.terrain_at(tile + Vector2i(dx, dy)) == WorldMap.Terrain.ROAD:
				return true
	return false

static func _shuffle(tiles: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	for i: int in range(tiles.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, i)
		var tile: Vector2i = tiles[i]
		tiles[i] = tiles[other]
		tiles[other] = tile

static func plan(map: WorldMap, seed: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed ^ 0x5eed
	var result: Array[Dictionary] = []
	var valid: Dictionary = {}
	var tiles: Array[Vector2i] = []
	for x: int in range(map.size()):
		for y: int in range(map.size()):
			var tile := Vector2i(x, y)
			if eligible(map, tile):
				valid[tile] = true
				tiles.append(tile)
	var roadside: Array[Vector2i] = []
	var inland: Array[Vector2i] = []
	for tile: Vector2i in tiles:
		var fits: bool = true
		for covered: Vector2i in footprint({"tile": tile, "size": Vector2i(3, 3)}):
			if not valid.has(covered):
				fits = false
				break
		if fits:
			if _near_road(map, tile):
				roadside.append(tile)
			else:
				inland.append(tile)
	_shuffle(roadside, rng)
	_shuffle(inland, rng)
	roadside.append_array(inland)
	var car_target: int = rng.randi_range(4, 8)
	var car_tiles: Array[Vector2i] = []
	var occupied: Dictionary = {}
	for tile: Vector2i in roadside:
		var spaced: bool = true
		for other: Vector2i in car_tiles:
			if Vector2(tile).distance_to(Vector2(other)) < CAR_SPACING:
				spaced = false
				break
		if not spaced:
			continue
		var entry: Dictionary = {"tile": tile, "texture_path": PROP_ROOT + "wrecked_car_%d.png" % rng.randi_range(1, 12), "size": Vector2i(3, 3)}
		result.append(entry)
		car_tiles.append(tile)
		for covered: Vector2i in footprint(entry):
			occupied[covered] = true
		if car_tiles.size() == car_target:
			break
	_shuffle(tiles, rng)
	var small_target: int = mini(MAX_SMALL_PROPS, roundi(tiles.size() * SMALL_DENSITY))
	var small_count: int = 0
	# Reserve a gap around finished clusters so separate groups don't merge.
	var cluster_gaps: Dictionary = occupied.duplicate()
	for tile: Vector2i in tiles:
		if small_count >= small_target:
			break
		if cluster_gaps.has(tile):
			continue
		var cluster: Array[Vector2i] = [tile]
		var cluster_target: int = mini(rng.randi_range(1, 3), small_target - small_count)
		var kind: int = rng.randi_range(0, SMALL_KINDS.size() - 1)
		var neighbours: Array[Vector2i] = [tile + Vector2i.UP, tile + Vector2i.RIGHT, tile + Vector2i.DOWN, tile + Vector2i.LEFT]
		_shuffle(neighbours, rng)
		for neighbour: Vector2i in neighbours:
			if cluster.size() >= cluster_target:
				break
			if valid.has(neighbour) and not cluster_gaps.has(neighbour):
				cluster.append(neighbour)
		for member: Vector2i in cluster:
			result.append({"tile": member, "texture_path": PROP_ROOT + "%s_%d.png" % [SMALL_KINDS[kind], rng.randi_range(1, SMALL_VARIANTS[kind])], "size": Vector2i.ONE})
			small_count += 1
			for dx: int in range(-1, 2):
				for dy: int in range(-1, 2):
					cluster_gaps[member + Vector2i(dx, dy)] = true
	return result

func bind(state: GameState) -> void:
	if _state:
		_state.map.changed.disconnect(_refresh_all)
		_state.buildings.building_added.disconnect(_on_building_changed)
		_state.buildings.building_removed.disconnect(_on_building_changed)
	for sprite: Sprite2D in _sprites:
		sprite.free()
	_sprites.clear()
	_by_tile.clear()
	_state = state
	y_sort_enabled = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_entries = plan(state.map, state.map_seed)
	for entry: Dictionary in _entries:
		var sprite := Sprite2D.new()
		sprite.texture = load(entry["texture_path"]) as Texture2D
		sprite.scale = Vector2.ONE * Grid.PIXEL_SCALE
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = Grid.tile_to_world(entry["tile"]) + Vector2(0, Grid.TILE / 2.0)
		sprite.offset = Vector2(0, -sprite.texture.get_height() / 2.0)
		add_child(sprite)
		var index: int = _sprites.size()
		_sprites.append(sprite)
		for tile: Vector2i in footprint(entry):
			_by_tile[tile] = index
	_state.map.changed.connect(_refresh_all)
	_state.buildings.building_added.connect(_on_building_changed)
	_state.buildings.building_removed.connect(_on_building_changed)
	_refresh_all()

func _refresh(index: int) -> void:
	var covered: bool = false
	for tile: Vector2i in footprint(_entries[index]):
		if _state.map.occupant_at(tile) == WorldMap.Occupant.BUILDING:
			covered = true
			break
	_sprites[index].visible = not covered

func _refresh_all() -> void:
	for index: int in range(_entries.size()):
		_refresh(index)

func _on_building_changed(building: Building) -> void:
	for tile: Vector2i in building.tiles():
		if _by_tile.has(tile):
			_refresh(_by_tile[tile])
