class_name GameSettings extends RefCounted
## Keep every settings writer compatible by loading before changing its own keys.

const PATH := AudioSettings.PATH

static func load_window_mode(path: String = PATH) -> String:
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK:
		return _window_mode(cfg.get_value("display", "window_mode", "windowed"))
	return "windowed"

static func save_window_mode(mode: Variant, path: String = PATH) -> void:
	_save("display", "window_mode", _window_mode(mode), path)

static func load_default_speed(path: String = PATH) -> int:
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK:
		return _default_speed(cfg.get_value("gameplay", "default_speed", 1))
	return 1

static func save_default_speed(speed: Variant, path: String = PATH) -> void:
	_save("gameplay", "default_speed", _default_speed(speed), path)

static func load_difficulty(path: String = PATH) -> String:
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK:
		return _difficulty(cfg.get_value("gameplay", "difficulty", "normal"))
	return "normal"

static func save_difficulty(difficulty: Variant, path: String = PATH) -> void:
	_save("gameplay", "difficulty", _difficulty(difficulty), path)

static func load_screen_shake(path: String = PATH) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK:
		var val: Variant = cfg.get_value("gameplay", "screen_shake", true)
		if typeof(val) == TYPE_BOOL:
			return val
	return true

static func save_screen_shake(on: bool, path: String = PATH) -> void:
	_save("gameplay", "screen_shake", on, path)

static func apply_window_mode(mode: String = "") -> void:
	if DisplayServer.get_name() == "headless":
		return
	if mode.is_empty():
		mode = load_window_mode()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if _window_mode(mode) == "fullscreen" else DisplayServer.WINDOW_MODE_WINDOWED)

static func _window_mode(value: Variant) -> String:
	return "fullscreen" if value is String and value == "fullscreen" else "windowed"

static func _default_speed(value: Variant) -> int:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		if is_finite(float(value)):
			return int(clampf(float(value), 1.0, 3.0))
	return 1

static func _difficulty(value: Variant) -> String:
	return value if value is String and value in ["easy", "normal", "hard"] else "normal"

static func _save(section: String, key: String, value: Variant, path: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(path)
	cfg.set_value(section, key, value)
	cfg.save(path)
