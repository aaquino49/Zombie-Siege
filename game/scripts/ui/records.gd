class_name Records extends RefCounted
## Small local record book, kept separate from game saves and settings.

const PATH := "user://records.cfg"
const DIFFICULTIES: Array[String] = ["easy", "normal", "hard"]

static func load_all(path: String = PATH) -> Dictionary:
	path = _path_or_default(path)
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return {}
	var records: Dictionary = {}
	for difficulty: String in DIFFICULTIES:
		var value: Variant = cfg.get_value("records", difficulty, false)
		if value is Dictionary:
			var record: Dictionary = _clean_record(value)
			if not record.is_empty():
				records[difficulty] = record
	return records

static func submit(difficulty: String, nights_survived: int, won: bool,
		time_played_s: float, path: String = PATH) -> Dictionary:
	path = _path_or_default(path)
	var beaten := {"best_nights": false, "fastest_win": false, "first_win": false}
	if not DIFFICULTIES.has(difficulty):
		return beaten
	var all: Dictionary = load_all(path)
	var record: Dictionary = all.get(difficulty, {})
	var nights: int = maxi(0, nights_survived)
	if record.is_empty() or nights > int(record.get("best_nights", -1)):
		beaten["best_nights"] = true
		record["best_nights"] = nights
	record["wins"] = int(record.get("wins", 0))
	record["fastest_win_s"] = int(record.get("fastest_win_s", 0))
	if won:
		beaten["first_win"] = int(record["wins"]) == 0
		record["wins"] = int(record["wins"]) + 1
		var elapsed: int = maxi(0, roundi(time_played_s))
		if int(record["fastest_win_s"]) == 0 or elapsed < int(record["fastest_win_s"]):
			beaten["fastest_win"] = true
			record["fastest_win_s"] = elapsed
	all[difficulty] = record
	var cfg := ConfigFile.new()
	for level: String in DIFFICULTIES:
		if all.has(level):
			cfg.set_value("records", level, all[level])
	var error: Error = cfg.save(path)
	if error != OK:
		return {"best_nights": false, "fastest_win": false, "first_win": false}
	return beaten

static func menu_line(path: String = PATH) -> String:
	return format_menu_line(load_all(path))

static func format_menu_line(records: Dictionary) -> String:
	var parts: Array[String] = []
	for difficulty: String in DIFFICULTIES:
		var record: Variant = records.get(difficulty, null)
		if record is Dictionary and record.has("best_nights"):
			parts.append("%s %d" % [difficulty.capitalize(), int(record["best_nights"])])
	if parts.is_empty():
		return ""
	return "Best: %s nights" % " · ".join(parts)

static func new_record_lines(beaten: Dictionary, difficulty: String, nights: int,
		time_played_s: float) -> String:
	var lines: Array[String] = []
	if bool(beaten.get("best_nights", false)):
		lines.append("New record: %d nights (%s)" % [nights, difficulty.capitalize()])
	if bool(beaten.get("fastest_win", false)):
		var seconds: int = maxi(0, roundi(time_played_s))
		lines.append("Fastest win: %d:%02d" % [seconds / 60, seconds % 60])
	if bool(beaten.get("first_win", false)):
		lines.append("First win: %s" % difficulty.capitalize())
	return "\n".join(lines)

static func remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

static func _clean_record(value: Dictionary) -> Dictionary:
	var record: Dictionary = {}
	var nights: Variant = value.get("best_nights", null)
	var wins: Variant = value.get("wins", 0)
	var fastest: Variant = value.get("fastest_win_s", 0)
	if (typeof(nights) == TYPE_INT or typeof(nights) == TYPE_FLOAT) and is_finite(float(nights)):
		record["best_nights"] = maxi(0, int(nights))
	if (typeof(wins) == TYPE_INT or typeof(wins) == TYPE_FLOAT) and is_finite(float(wins)):
		record["wins"] = maxi(0, int(wins))
	else:
		record["wins"] = 0
	if (typeof(fastest) == TYPE_INT or typeof(fastest) == TYPE_FLOAT) and is_finite(float(fastest)):
		record["fastest_win_s"] = maxi(0, int(fastest))
	else:
		record["fastest_win_s"] = 0
	return record

static func _path_or_default(path: String) -> String:
	if path != PATH or not _is_automated_run():
		return path
	return "user://automated_records_%d.cfg" % OS.get_process_id()

static func _is_automated_run() -> bool:
	if DisplayServer.get_name() == "headless":
		return true
	for arg: String in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if arg.begins_with("--scenario=") or arg.begins_with("--screenshot=") or arg.begins_with("--quit-frames="):
			return true
	return false
