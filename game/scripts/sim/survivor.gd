class_name Survivor extends RefCounted

enum Job { IDLE, GATHERER, FARMER, BUILDER, CRAFTER, GUARD, RESEARCHER }
enum Activity { IDLE, WALKING, BUILDING, REPAIRING, HARVESTING, RETURNING, FARMING, CRAFTING, SHELTERED, GUARDING, RESEARCHING }

var uid: int
var name: String
var variant: String
var hungry_days: int = 0
var moods: Array[Dictionary] = []
var morale: int = 50
var breaking_days: int = 0
var refusing: bool = false
var day_off: bool = false
var had_day_off: bool = false
var hp: int
var max_hp: int
var loss_reason: String = ""
var job: int = Job.IDLE
var pos: Vector2
var path: Array[Vector2i]
var target: Vector2i
var facing: Vector2 = Vector2.RIGHT

var post_uid: int = 0
var post_tile: Vector2i = Vector2i(-1, -1)
var on_tower: bool = false
var post_building: Building = null
var post_check_timer: float = 0.0
var fire_timer: float = 0.0

var sheltered: bool = false
var away: bool = false
var shelter_uid: int = 0
# Retain geometry for release after the building has been removed.
var shelter_building: Building = null
var unreachable_shelters: Dictionary = {}
var unsheltered_warned: bool = false
var shelter_night: int = 0

var activity: int = Activity.IDLE
var work_uid: int = 0
var work_acc: float = 0.0
var job_timer: float = 0.0

var gather_kind: String = "wood"
var carry_kind: String = ""
var carry_amount: int = 0
var work_tile: Vector2i = Vector2i(-1, -1)

func is_hungry() -> bool:
	return hungry_days > 0

func reset_shelter_exclusions() -> void:
	unreachable_shelters.clear()
	unsheltered_warned = false

func tile() -> Vector2i:
	return Grid.world_to_tile(pos)

func is_moving() -> bool:
	return not path.is_empty()

static func job_from_name(n: String) -> int:
	if n.begins_with("gatherer"):
		return Job.GATHERER
	match n:
		"farmer": return Job.FARMER
		"builder": return Job.BUILDER
		"crafter": return Job.CRAFTER
		"guard": return Job.GUARD
		"researcher": return Job.RESEARCHER
		_: return Job.IDLE

static func job_label(j: int) -> String:
	match j:
		Job.GATHERER: return "Gatherer"
		Job.FARMER: return "Farmer"
		Job.BUILDER: return "Builder"
		Job.CRAFTER: return "Crafter"
		Job.GUARD: return "Guard"
		Job.RESEARCHER: return "Researcher"
		_: return "Idle"

static func activity_label(a: int) -> String:
	match a:
		Activity.WALKING: return "Walking"
		Activity.BUILDING: return "Building"
		Activity.REPAIRING: return "Repairing"
		Activity.HARVESTING: return "Harvesting"
		Activity.RETURNING: return "Returning"
		Activity.FARMING: return "Farming"
		Activity.CRAFTING: return "Crafting"
		Activity.SHELTERED: return "Sheltered"
		Activity.GUARDING: return "Guarding"
		Activity.RESEARCHING: return "Researching"
		_: return "Idle"
