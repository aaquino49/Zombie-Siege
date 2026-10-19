class_name Grid

const TILE := 64
const PIXEL_SCALE := 4
const PX_TILE := 16

static func tile_to_world(t: Vector2i) -> Vector2:
	return Vector2(t.x * TILE + TILE / 2.0, t.y * TILE + TILE / 2.0)

static func world_to_tile(p: Vector2) -> Vector2i:
	return Vector2i(floorf(p.x / TILE), floorf(p.y / TILE))

static func in_bounds(t: Vector2i, size: int) -> bool:
	return t.x >= 0 and t.y >= 0 and t.x < size and t.y < size

static func rect_tiles(origin: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for x in range(size.x):
		for y in range(size.y):
			tiles.append(origin + Vector2i(x, y))
	return tiles

static func in_ring(t: Vector2i, origin: Vector2i, size: Vector2i) -> bool:
	var in_rect := t.x >= origin.x and t.y >= origin.y and t.x < origin.x + size.x and t.y < origin.y + size.y
	if in_rect:
		return false
	return t.x >= origin.x - 1 and t.y >= origin.y - 1 and t.x <= origin.x + size.x and t.y <= origin.y + size.y
