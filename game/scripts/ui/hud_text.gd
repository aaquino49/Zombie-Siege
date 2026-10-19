class_name HudText extends RefCounted

static func research_text(state: GameState) -> String:
	var id: String = state.tech.active
	if id != "":
		return "%s %d/%d" % [state.tech.data.upgrades[id].name, floori(float(state.tech.progress.get(id, 0.0))), int(state.tech.data.upgrades[id].cost)]
	for lab: Building in state.buildings.all_of_type("field_lab"):
		if lab.complete:
			return "Pick research"
	return ""

static func night_text(hostiles: int, seconds_left: int) -> String:
	if hostiles > 0:
		return "Night – %d zombies left" % hostiles
	var left: int = maxi(0, seconds_left)
	return "Night – dawn in %d:%02d" % [left / 60, left % 60]

static func ammo_warning(ammo: int, has_shooters: bool) -> bool:
	return ammo == 0 and has_shooters

static func forecast_text(forecast: Dictionary) -> String:
	var parts: Array[String] = []
	for type_id: String in ["walker", "runner", "brute", "spitter"]:
		var count: int = int(forecast.get(type_id, 0))
		if count <= 0:
			continue
		var label: String = type_id if count == 1 else type_id + "s"
		parts.append("%d %s" % [count, label])
	var sides: int = int(forecast.get("sides", 0))
	if sides > 0:
		parts.append("%d %s" % [sides, "side" if sides == 1 else "sides"])
	if bool(forecast.get("fog", false)) and not bool(forecast.get("final", false)):
		var delta: float = float(forecast["range_delta_tiles"])
		var delta_text: String = str(int(delta)) if is_equal_approx(delta, float(roundi(delta))) else str(delta)
		delta_text = delta_text.replace("-", "−")
		parts.append("Fog: range %s" % delta_text)
	var prefix: String = "FINAL HORDE: " if bool(forecast.get("final", false)) else "Tonight: "
	return prefix + " · ".join(parts)
