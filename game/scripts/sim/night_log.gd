class_name NightLog extends RefCounted

var zombies_killed: int = 0
var survivors_killed: Array[String] = []
var buildings_destroyed: Array[String] = []
var damaged_uids: Dictionary = {}
var cc_damage: int = 0
var _start_zombies_killed: int = 0

func begin(state: GameState) -> void:
	_start_zombies_killed = state.zombies_killed
	survivors_killed.clear()
	buildings_destroyed.clear()
	damaged_uids.clear()
	cc_damage = 0

func on_building_damaged(b: Building, amount: int) -> void:
	if b.type_id == "command_center":
		cc_damage += amount
	else:
		damaged_uids[b.uid] = true

func on_building_destroyed(b: Building, display_name: String) -> void:
	buildings_destroyed.append(display_name)
	damaged_uids.erase(b.uid)

func on_survivor_killed(s: Survivor) -> void:
	survivors_killed.append(s.name)

func summary(state: GameState) -> Dictionary:
	var dmg_count: int = 0
	for uid: int in damaged_uids.keys():
		var b: Building = state.buildings.get_by_uid(uid)
		if b != null and b.hp < b.max_hp:
			dmg_count += 1
			
	return {
		"night": state.clock.day - 1,
		"zombies_killed": state.zombies_killed - _start_zombies_killed,
		"survivors_killed": survivors_killed.duplicate(),
		"buildings_destroyed": buildings_destroyed.duplicate(),
		"buildings_damaged": dmg_count,
		"cc_damage": cc_damage
	}
