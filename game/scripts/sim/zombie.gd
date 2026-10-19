class_name Zombie extends RefCounted

var uid: int
var type_id: String
var priority: String = "command_center"
var pos: Vector2
var facing: Vector2
var hp: int
var max_hp: int
var speed: float
var damage: int
var attack_interval: float
var attack_timer: float
var target_building_uid: int
var target_survivor_uid: int
var chase_survivor_uid: int = 0
var chase_best_dist: float = INF
var chase_stall: float = 0.0
var chase_cooldown: float = 0.0
var defence_scan_timer: float = 0.0
var defence_uid: int = 0
var spit_timer: float = 0.0

func reset_chase() -> void:
	chase_survivor_uid = 0
	chase_best_dist = INF
	chase_stall = 0.0

func tile() -> Vector2i:
	return Grid.world_to_tile(pos)

func is_attacking() -> bool:
	return target_building_uid != 0 or target_survivor_uid != 0
