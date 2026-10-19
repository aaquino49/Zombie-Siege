class_name Building extends RefCounted

var uid: int
var type_id: String
var origin: Vector2i
var size: Vector2i
var max_hp: int
var hp: int
var complete: bool
var build_time: float = 0.0
var progress: float = 0.0
var upgraded_from: String = ""
var fire_timer: float = 0.0
var aim: Vector2 = Vector2.UP

func progress_ratio() -> float:
	if build_time <= 0.0:
		return 1.0
	return clampf(progress / build_time, 0.0, 1.0)

func is_damaged() -> bool:
	return complete and hp < max_hp

func tiles() -> Array[Vector2i]:
	return Grid.rect_tiles(origin, size)

func center_world() -> Vector2:
	return Vector2(origin.x * Grid.TILE + (size.x * Grid.TILE) / 2.0, origin.y * Grid.TILE + (size.y * Grid.TILE) / 2.0)

func contains(t: Vector2i) -> bool:
	return t.x >= origin.x and t.x < origin.x + size.x and t.y >= origin.y and t.y < origin.y + size.y
