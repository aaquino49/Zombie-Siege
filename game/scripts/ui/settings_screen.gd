class_name SettingsScreen extends MenuScreen

var _volumes: Dictionary
var _hints: HintPanel

func bind(hints: HintPanel = null) -> void:
	initialize()
	_hints = hints
	for bus: String in AudioSettings.BUSES:
		var slider: HSlider = get_node(CONTENT + "Volumes/" + bus + "Row/" + bus)
		if not slider.value_changed.is_connected(_volume_changed.bind(bus)):
			slider.value_changed.connect(_volume_changed.bind(bus))
	get_node(CONTENT + "Options/Fullscreen").toggled.connect(_fullscreen_changed)
	get_node(CONTENT + "Options/SpeedRow/Speed").item_selected.connect(_speed_changed)
	get_node(CONTENT + "Options/Hints").toggled.connect(_hints_changed)
	get_node(CONTENT + "Options/ScreenShake").toggled.connect(_shake_changed)
	_refresh()

func open(source: CanvasLayer) -> void:
	_refresh()
	super.open(source)

func _refresh() -> void:
	_volumes = AudioSettings.load_volumes()
	for bus: String in AudioSettings.BUSES:
		get_node(CONTENT + "Volumes/" + bus + "Row/" + bus).set_value_no_signal(float(_volumes[bus]) * 100.0)
	get_node(CONTENT + "Options/Fullscreen").set_pressed_no_signal(GameSettings.load_window_mode() == "fullscreen")
	get_node(CONTENT + "Options/SpeedRow/Speed").select(GameSettings.load_default_speed() - 1)
	get_node(CONTENT + "Options/Hints").set_pressed_no_signal(HintSettings.load_enabled())
	get_node(CONTENT + "Options/ScreenShake").set_pressed_no_signal(GameSettings.load_screen_shake())

func _volume_changed(value: float, bus: String) -> void:
	_volumes[bus] = value / 100.0
	AudioSettings.apply(_volumes)
	AudioSettings.save_volumes(_volumes)

func _fullscreen_changed(enabled: bool) -> void:
	var mode: String = "fullscreen" if enabled else "windowed"
	GameSettings.save_window_mode(mode)
	GameSettings.apply_window_mode(mode)

func _speed_changed(index: int) -> void:
	GameSettings.save_default_speed(index + 1)

func _hints_changed(enabled: bool) -> void:
	HintSettings.save_enabled(enabled)
	if _hints:
		_hints.set_enabled(enabled)

func _shake_changed(enabled: bool) -> void:
	GameSettings.save_screen_shake(enabled)
