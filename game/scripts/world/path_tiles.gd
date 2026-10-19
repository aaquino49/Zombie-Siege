class_name PathTiles extends RefCounted
## Suffixes identify the grass side/corner, as specified by the path atlas.
const SUFFIXES: Array[String] = ["center", "edge_n", "edge_e", "edge_s", "edge_w", "outer_ne", "outer_nw", "outer_se", "outer_sw", "inner_ne", "inner_nw", "inner_se", "inner_sw"]
const SIDES: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const SIDE_NAMES: Array[String] = ["n", "e", "s", "w"]
const DIAGONALS: Array[Vector2i] = [Vector2i(1, -1), Vector2i(-1, -1), Vector2i(1, 1), Vector2i(-1, 1)]
const CORNERS: Array[String] = ["ne", "nw", "se", "sw"]

static func _is_grass(map: WorldMap, t: Vector2i) -> bool:
	return Grid.in_bounds(t, map.size()) and map.terrain_at(t) == WorldMap.Terrain.GRASS

static func path_tile_for(map: WorldMap, t: Vector2i) -> String:
	var grass: Array[int] = []
	for i: int in range(4):
		if _is_grass(map, t + SIDES[i]):
			grass.append(i)
	if grass.size() == 1:
		return "edge_" + SIDE_NAMES[grass[0]]
	if grass.size() == 2:
		for i: int in range(4):
			if _is_grass(map, t + Vector2i(DIAGONALS[i].x, 0)) and _is_grass(map, t + Vector2i(0, DIAGONALS[i].y)):
				return "outer_" + CORNERS[i]
	if grass.is_empty():
		var diagonal: int = -1
		for i: int in range(4):
			if _is_grass(map, t + DIAGONALS[i]):
				if diagonal != -1:
					return "center"
				diagonal = i
		if diagonal != -1:
			return "inner_" + CORNERS[diagonal]
	return "center"
