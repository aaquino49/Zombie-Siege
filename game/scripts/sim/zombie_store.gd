class_name ZombieStore extends RefCounted

signal zombie_added(z: Zombie)
signal zombie_removed(z: Zombie)

var _zombies: Dictionary = {}
var _next_uid: int = 1
var _data: GameData

func _init(data: GameData) -> void:
	_data = data

func add(type_id: String, pos: Vector2, hp_multiplier: float = 1.0) -> Zombie:
	var z := Zombie.new()
	z.uid = _next_uid
	_next_uid += 1
	z.type_id = type_id
	z.pos = pos
	z.facing = Vector2.DOWN
	
	var z_data := _data.get_zombie(type_id)
	z.priority = z_data.get("target_priority", "command_center")
	z.max_hp = roundi(float(z_data.get("hp", 100)) * hp_multiplier)
	z.hp = z.max_hp
	z.speed = z_data.get("speed", 50.0)
	z.damage = z_data.get("damage", 10)
	var rate: float = z_data.get("attack_rate", 1.0)
	z.attack_interval = 1.0 / rate if rate > 0 else 1.0
	z.attack_timer = 0.0
	z.target_building_uid = 0
	z.target_survivor_uid = 0
	
	_zombies[z.uid] = z
	zombie_added.emit(z)
	return z

func remove(uid: int) -> void:
	if _zombies.has(uid):
		var z: Zombie = _zombies[uid]
		_zombies.erase(uid)
		zombie_removed.emit(z)

func get_by_uid(uid: int) -> Zombie:
	return _zombies.get(uid, null)

func all() -> Array[Zombie]:
	var result: Array[Zombie] = []
	for uid in _zombies:
		result.append(_zombies[uid])
	result.sort_custom(func(a: Zombie, b: Zombie) -> bool: return a.uid < b.uid)
	return result

func count() -> int:
	return _zombies.size()

func damage(uid: int, amount: int) -> bool:
	var z: Zombie = get_by_uid(uid)
	if z == null:
		return false
	z.hp -= amount
	if z.hp <= 0:
		remove(uid)
		return true
	return false
