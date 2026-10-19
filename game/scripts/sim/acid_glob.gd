class_name AcidGlob extends RefCounted
## Transient, tile-locked projectile. No RNG or persistence.

var pos: Vector2
var target_tile: Vector2i
var target_uid: int
var speed: float
var damage: int

func _init(from: Vector2, tile: Vector2i, uid: int, velocity: float, amount: int) -> void:
	pos = from
	target_tile = tile
	target_uid = uid
	speed = velocity
	damage = amount

func tick(state: GameState, dt: float) -> bool:
	var destination: Vector2 = Grid.tile_to_world(target_tile)
	var distance: float = pos.distance_to(destination)
	if distance > speed * dt:
		pos = pos.move_toward(destination, speed * dt)
		return false
	pos = destination
	var building: Building = state.buildings.get_at(target_tile)
	if building == null or building.uid != target_uid or building.hp <= 0:
		return true
	# Capture posted guards before a lethal building hit removes their tower.
	if building.type_id == "watchtower":
		for survivor: Survivor in state.survivors.all():
			if survivor.on_tower and survivor.post_uid == building.uid:
				state.damage_survivor(survivor, damage)
	state.damage_building(building, damage)
	state.acid_hit.emit(destination)
	return true
