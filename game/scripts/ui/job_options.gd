class_name JobOptions extends RefCounted

const LABELS: Array[String] = ["Idle", "Gatherer: Wood", "Gatherer: Scrap", "Farmer", "Builder", "Crafter", "Guard", "Researcher"]
const SHORT_LABELS: Array[String] = ["Idle", "Wood", "Scrap", "Farmer", "Builder", "Crafter", "Guard", "Research"]

static func activity_text(s: Survivor, state: GameState = null) -> String:
	if s.refusing:
		return "Refusing work"
	if s.day_off:
		return "Day off"
	var text: String = Survivor.activity_label(s.activity) + (" · Hungry" if s.is_hungry() else "")
	if state and s.job == Survivor.Job.RESEARCHER and s.activity == Survivor.Activity.RESEARCHING:
		var lab: Building = state.buildings.get_by_uid(s.work_uid)
		if lab and lab.complete and lab.type_id == "field_lab":
			text += " · %d/%d" % [ProductionJob.workers_at(state, lab), int(state.data.get_building("field_lab").workers)]
	return text

static func index_for(s: Survivor) -> int:
	if s.job == Survivor.Job.IDLE: return 0
	if s.job == Survivor.Job.GATHERER:
		if s.gather_kind == "scrap": return 2
		return 1
	if s.job == Survivor.Job.FARMER: return 3
	if s.job == Survivor.Job.BUILDER: return 4
	if s.job == Survivor.Job.CRAFTER: return 5
	if s.job == Survivor.Job.GUARD: return 6
	if s.job == Survivor.Job.RESEARCHER: return 7
	return 0

static func apply(state: GameState, uid: int, index: int) -> bool:
	if index < 0 or index >= LABELS.size(): return false
	var job: int = Survivor.Job.IDLE
	var kind: String = ""
	if index == 1:
		job = Survivor.Job.GATHERER
		kind = "wood"
	elif index == 2:
		job = Survivor.Job.GATHERER
		kind = "scrap"
	elif index == 3:
		job = Survivor.Job.FARMER
	elif index == 4:
		job = Survivor.Job.BUILDER
	elif index == 5:
		job = Survivor.Job.CRAFTER
	elif index == 6:
		job = Survivor.Job.GUARD
	elif index == 7:
		job = Survivor.Job.RESEARCHER
	
	state.set_job(uid, job, kind)
	return true

static func fill(btn: OptionButton) -> void:
	btn.clear()
	for label in LABELS:
		btn.add_item(label)
