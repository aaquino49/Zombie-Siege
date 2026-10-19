class_name AudioSettings extends RefCounted

const PATH := "user://settings.cfg"
const BUSES := ["Master", "SFX", "Music"]

static func to_db(linear: float) -> float:
	if linear <= 0.0:
		return -80.0
	return linear_to_db(clampf(linear, 0.0, 1.0))

static func load_volumes(path: String = PATH) -> Dictionary:
	var v := {}
	for b: String in BUSES:
		v[b] = 0.8
		
	var cfg := ConfigFile.new()
	var err := cfg.load(path)
	if err == OK:
		for b: String in BUSES:
			var val: Variant = cfg.get_value("audio", b, 0.8)
			if typeof(val) == TYPE_FLOAT or typeof(val) == TYPE_INT:
				v[b] = clampf(float(val), 0.0, 1.0)
	return v

static func save_volumes(v: Dictionary, path: String = PATH) -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(path)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		cfg = ConfigFile.new()
	
	for b: String in BUSES:
		if v.has(b):
			cfg.set_value("audio", b, v[b])
	cfg.save(path)

static func apply(v: Dictionary) -> void:
	for b: String in BUSES:
		if not v.has(b):
			continue
		var idx := AudioServer.get_bus_index(b)
		if idx < 0:
			continue
		
		var linear := float(v[b])
		AudioServer.set_bus_volume_db(idx, to_db(linear))
		AudioServer.set_bus_mute(idx, linear <= 0.0)
