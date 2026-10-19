class_name TechTree extends RefCounted
## Optional research state. Effects are always read from this module's config.

const EPSILON: float = 0.000001
var data: Dictionary
var done: Array[String] = []
var active: String = ""
var progress: Dictionary = {}
var banked: float = 0.0
var done_today: Array[String] = []
var game_over: bool = false
var game_over_provider: Callable

func _init(p_data: Dictionary) -> void:
	data = p_data

func choose(id: String) -> bool:
	if game_over_provider.is_valid():
		game_over = bool(game_over_provider.call())
	if game_over:
		return false
	if id == "":
		active = ""
		return true
	if not available(id) or is_done(id):
		return false
	if active == id:
		return true
	active = id
	_spend_bank()
	return true

func add_points(amount: float) -> void:
	if not is_finite(amount) or amount < 0.0 or amount == 0.0:
		return
	if active == "" or not available(active):
		banked += amount
		return
	# Newly produced RP always consumes saved bank first. This matters when
	# restoring an older save: restore itself stays observationally neutral.
	var total: float = amount + banked
	banked = 0.0
	_apply_points(total)

func is_done(id: String) -> bool:
	return done.has(id)

func available(id: String) -> bool:
	var upgrades: Dictionary = data.get("upgrades", {})
	if not upgrades.has(id): return false
	if is_done(id): return false
	for required: String in upgrades[id].get("requires", []):
		if not done.has(required): return false
	return true

func mult(key: String) -> float:
	var result: float = 1.0
	for id: String in done:
		var effect: Dictionary = data.upgrades[id].effect
		if effect.key == key and effect.op == "mult": result *= float(effect.value)
	return result

func bonus(key: String) -> float:
	var result: float = 0.0
	for id: String in done:
		var effect: Dictionary = data.upgrades[id].effect
		if effect.key == key and effect.op == "add": result += float(effect.value)
	return result

func status(id: String) -> String:
	if is_done(id): return "done"
	if active == id: return "researching"
	return "available" if available(id) else "locked"

func capture() -> Dictionary:
	return {"done": done.duplicate(), "active": active, "progress": progress.duplicate(true), "banked": banked}

func restore(value: Variant) -> void:
	done.clear()
	active = ""
	progress.clear()
	banked = 0.0
	done_today.clear()
	if typeof(value) != TYPE_DICTIONARY: return
	var upgrades: Dictionary = data.get("upgrades", {})
	var raw_done: Variant = value.get("done", [])
	if raw_done is Array:
		for id_variant: Variant in raw_done:
			var id: String = str(id_variant)
			if not upgrades.has(id):
				push_warning("TechTree.restore: unknown upgrade '%s' dropped" % id)
			elif not done.has(id):
				done.append(id)
	# Drop upgrades whose prerequisites are not also done, until stable.
	var changed: bool = true
	while changed:
		changed = false
		for id: String in done.duplicate():
			var valid: bool = true
			for required: String in upgrades[id].get("requires", []):
				if not done.has(required): valid = false
			if not valid:
				done.erase(id)
				changed = true
	# Canonical order makes effect lookup and duplicate normalization stable.
	done.sort_custom(func(a: String, b: String) -> bool:
		var ua: Dictionary = upgrades[a]
		var ub: Dictionary = upgrades[b]
		if ua.branch != ub.branch: return _branch_order(str(ua.branch)) < _branch_order(str(ub.branch))
		return int(ua.tier) < int(ub.tier))
	var raw_progress: Variant = value.get("progress", {})
	if raw_progress is Dictionary:
		for key_variant: Variant in raw_progress:
			var id: String = str(key_variant)
			var amount: Variant = raw_progress[key_variant]
			if not upgrades.has(id):
				push_warning("TechTree.restore: unknown progress '%s' dropped" % id)
				continue
			if done.has(id) or not available(id): continue
			if (typeof(amount) == TYPE_INT or typeof(amount) == TYPE_FLOAT) and is_finite(float(amount)) and float(amount) >= 0.0:
				progress[id] = minf(float(amount), float(upgrades[id].cost))
	var raw_bank: Variant = value.get("banked", 0.0)
	if (typeof(raw_bank) == TYPE_INT or typeof(raw_bank) == TYPE_FLOAT) and is_finite(float(raw_bank)) and float(raw_bank) >= 0.0:
		banked = float(raw_bank)
	var requested: String = str(value.get("active", ""))
	if available(requested): active = requested
	elif requested != "" and not upgrades.has(requested):
		push_warning("TechTree.restore: unknown active upgrade '%s' dropped" % requested)
	# Completed saved partials normalize to done, without toast or effect replay.
	for id: String in _ordered_ids():
		if not available(id): continue
		if float(progress.get(id, 0.0)) + EPSILON >= float(upgrades[id].cost):
			done.append(id)
			progress.erase(id)
	if active != "" and (not available(active) or done.has(active)): active = ""

func apply_dawn_heal(state: GameState) -> void:
	var amount: int = int(bonus("dawn_heal"))
	if amount <= 0: return
	for survivor: Survivor in state.survivors.all():
		survivor.hp = mini(survivor.max_hp, survivor.hp + amount)

func take_dawn_report(state: GameState) -> Dictionary:
	var has_tree: bool = not done.is_empty() or active != "" or not progress.is_empty() or banked > 0.0 or not done_today.is_empty()
	var report: Dictionary = {}
	if has_tree or state.buildings.count_of("field_lab") > 0:
		var cost: int = int(data.upgrades.get(active, {}).get("cost", 0)) if active != "" else 0
		report = {"active": active, "progress": float(progress.get(active, 0.0)) if active != "" else 0.0,
			"cost": cost, "banked": banked, "done_today": done_today.duplicate()}
	done_today.clear()
	return report

func _ordered_ids() -> Array[String]:
	var ids: Array[String] = []
	for id_variant: Variant in data.get("upgrades", {}).keys(): ids.append(str(id_variant))
	ids.sort_custom(func(a: String, b: String) -> bool:
		var ua: Dictionary = data.upgrades[a]
		var ub: Dictionary = data.upgrades[b]
		if ua.branch != ub.branch: return _branch_order(str(ua.branch)) < _branch_order(str(ub.branch))
		return int(ua.tier) < int(ub.tier))
	return ids

func _branch_order(id: String) -> int:
	var branches: Array = data.get("branches", [])
	for i: int in range(branches.size()):
		if str(branches[i].get("id", "")) == id: return i
	return branches.size()

func _spend_bank() -> void:
	if banked <= 0.0: return
	var amount: float = banked
	banked = 0.0
	_apply_points(amount)

func _apply_points(amount: float) -> void:
	if active == "" or not data.get("upgrades", {}).has(active):
		banked += amount
		return
	var cost: float = float(data.upgrades[active].cost)
	var current: float = float(progress.get(active, 0.0))
	var remaining: float = maxf(0.0, cost - current)
	var applied: float = minf(amount, remaining)
	current += applied
	if current + EPSILON >= cost:
		progress.erase(active)
		done.append(active)
		done_today.append(active)
		active = ""
		banked += maxf(0.0, amount - applied)
	else:
		progress[active] = current
