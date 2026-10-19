class_name HintSettings extends RefCounted

static func load_enabled(path: String = AudioSettings.PATH) -> bool:
	var cfg := ConfigFile.new()
	var err := cfg.load(path)
	if err == OK:
		var val: Variant = cfg.get_value("gameplay", "hints", true)
		if typeof(val) == TYPE_BOOL:
			return val
	return true

static func save_enabled(on: bool, path: String = AudioSettings.PATH) -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(path)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		cfg = ConfigFile.new()
	cfg.set_value("gameplay", "hints", on)
	cfg.save(path)
