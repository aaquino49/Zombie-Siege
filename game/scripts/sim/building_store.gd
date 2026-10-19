class_name BuildingStore extends RefCounted

signal building_added(b: Building)
signal building_removed(b: Building)
signal building_completed(b: Building)

var _data: GameData
var _map: WorldMap
var tech: TechTree
var _next_uid: int = 1
var _buildings: Dictionary = {}
var _by_tile: Dictionary = {}

func _init(data: GameData, map: WorldMap) -> void:
	_data = data
	_map = map

func beds_for(b: Building) -> int:
	var beds: int = int(_data.get_building(b.type_id).get("beds", 0))
	if b.type_id == "shelter" and tech != null:
		beds += int(tech.bonus("shelter_beds"))
	return beds

func add(type_id: String, origin: Vector2i, complete: bool) -> Building:
	var b_data := _data.get_building(type_id)
	var b := Building.new()
	b.uid = _next_uid
	_next_uid += 1
	b.type_id = type_id
	b.origin = origin
	
	var sz: Array = b_data.get("size", [1, 1])
	b.size = Vector2i(int(sz[0]), int(sz[1]))
	
	b.max_hp = int(b_data.get("hp", 100))
	b.hp = b.max_hp
	b.complete = complete
	b.build_time = float(b_data.get("build_time", 0.0))
	if b.complete:
		b.progress = b.build_time
	
	_buildings[b.uid] = b
	_map.occupy(origin, b.size, type_id)
	for t in b.tiles():
		_by_tile[t] = b.uid
		
	building_added.emit(b)
	return b

func remove(uid: int) -> void:
	if not _buildings.has(uid):
		return
	var b: Building = _buildings[uid]
	_map.vacate(b.origin, b.size)
	for t in b.tiles():
		_by_tile.erase(t)
	_buildings.erase(uid)
	building_removed.emit(b)

func next_uid() -> int:
	return _next_uid

func set_next_uid(v: int) -> void:
	_next_uid = maxi(1, v)

func restore(b: Building) -> Building:
	_buildings[b.uid] = b
	_map.occupy(b.origin, b.size, b.type_id)
	for t in b.tiles():
		_by_tile[t] = b.uid
	_next_uid = maxi(_next_uid, b.uid + 1)
	return b

func finish(uid: int) -> void:
	if not _buildings.has(uid):
		return
	var b: Building = _buildings[uid]
	if b.complete:
		return
	b.complete = true
	b.progress = b.build_time
	b.hp = b.max_hp
	building_completed.emit(b)

func get_at(t: Vector2i) -> Building:
	if _by_tile.has(t):
		return _buildings.get(_by_tile[t])
	return null

func get_by_uid(uid: int) -> Building:
	return _buildings.get(uid)

func all() -> Array[Building]:
	var result: Array[Building] = []
	var uids := _buildings.keys()
	uids.sort()
	for uid in uids:
		result.append(_buildings[uid])
	return result

func blueprints() -> Array[Building]:
	var result: Array[Building] = []
	var uids := _buildings.keys()
	uids.sort()
	for uid in uids:
		var b: Building = _buildings[uid]
		if not b.complete:
			result.append(b)
	return result

func damaged() -> Array[Building]:
	var result: Array[Building] = []
	var uids := _buildings.keys()
	uids.sort()
	for uid in uids:
		var b: Building = _buildings[uid]
		if b.is_damaged():
			result.append(b)
	return result

func count_of(type_id: String) -> int:
	var c := 0
	for b: Building in _buildings.values():
		if b.type_id == type_id:
			c += 1
	return c

func all_of_type(type_id: String) -> Array[Building]:
	var result: Array[Building] = []
	var uids := _buildings.keys()
	uids.sort()
	for uid in uids:
		var b: Building = _buildings[uid]
		if b.type_id == type_id:
			result.append(b)
	return result

func total_beds() -> int:
	var beds: int = 0
	for b: Building in all():
		if b.complete:
			beds += beds_for(b)
	return beds
