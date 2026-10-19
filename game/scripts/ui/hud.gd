extends CanvasLayer

signal research_requested
signal top_left_stack_changed

@onready var top_bar: NinePatchRect = $TopBar
@onready var food_icon: TextureRect = $TopBar/Margin/HBox/Resources/FoodBox/Icon
@onready var food_label: Label = $TopBar/Margin/HBox/Resources/FoodBox/Label
@onready var wood_icon: TextureRect = $TopBar/Margin/HBox/Resources/WoodBox/Icon
@onready var wood_label: Label = $TopBar/Margin/HBox/Resources/WoodBox/Label
@onready var scrap_icon: TextureRect = $TopBar/Margin/HBox/Resources/ScrapBox/Icon
@onready var scrap_label: Label = $TopBar/Margin/HBox/Resources/ScrapBox/Label
@onready var ammo_icon: TextureRect = $TopBar/Margin/HBox/Resources/AmmoBox/Icon
@onready var ammo_label: Label = $TopBar/Margin/HBox/Resources/AmmoBox/Label
@onready var day_label: Label = $TopBar/Margin/HBox/DayArea/DayLabel
@onready var rain_tag: Label = $TopBar/Margin/HBox/DayArea/RainTag
@onready var idle_button: Button = $TopBar/Margin/HBox/DayArea/IdleButton
@onready var time_label: Label = $TopBar/Margin/HBox/ClockArea/TimeLabel

@onready var btn_pause: Button = $TopBar/Margin/HBox/ClockArea/SpeedButtons/BtnPause
@onready var btn_1x: Button = $TopBar/Margin/HBox/ClockArea/SpeedButtons/Btn1x
@onready var btn_2x: Button = $TopBar/Margin/HBox/ClockArea/SpeedButtons/Btn2x
@onready var btn_3x: Button = $TopBar/Margin/HBox/ClockArea/SpeedButtons/Btn3x
@onready var shelter_warning_label: Label = get_node_or_null("ShelterWarning") as Label
@onready var night_forecast_panel: NinePatchRect = get_node_or_null("NightForecast") as NinePatchRect
@onready var night_forecast_label: Label = get_node_or_null("NightForecast/Label") as Label
@onready var phase_icon: TextureRect = get_node_or_null("TopBar/Margin/HBox/DayArea/PhaseIcon") as TextureRect

const ICON_DAY = preload("res://assets/pixel/ui/icon_day.png")
const ICON_NIGHT = preload("res://assets/pixel/ui/icon_night.png")
const COLOR_AMMO_WARN = Color("#e0451b")

const TOAST_LIFETIME := 4.0
const TOAST_FADE := 1.0
const TOAST_MAX_VISIBLE := 3

var _labels: Dictionary = {}
var _state: GameState
var _selection: SelectionController
var _camera: CameraController
var _overlay_root: Node
var _idle_uids: Array[int] = []
var _shown_day: int = -1
var _last_displayed_text: String = ""
var _shelter_warning_timer: float = 0.0
var _shelter_warning_names: Array[String] = []
var _toast_box: VBoxContainer
var _toast_queue: Array[Dictionary] = []
var _active_toasts: Array[Dictionary] = []
var _research_button: Button
var _research_readout: Label
var _research_row: HBoxContainer
var _survivors_button: Button
var _research_seen: Dictionary = {}

func _ready() -> void:
	_labels = {
		"food": food_label,
		"wood": wood_label,
		"scrap": scrap_label,
		"ammo": ammo_label
	}
	
	if ResourceLoader.exists("res://assets/pixel/ui/x2/panel.png"):
		top_bar.texture = load("res://assets/pixel/ui/x2/panel.png") as Texture2D
	_load_texture(food_icon, "res://assets/pixel/ui/icon_food.png")
	_load_texture(wood_icon, "res://assets/pixel/ui/icon_wood.png")
	_load_texture(scrap_icon, "res://assets/pixel/ui/icon_scrap.png")
	_load_texture(ammo_icon, "res://assets/pixel/ui/icon_ammo.png")
	
	_load_button_icon(btn_pause, "res://assets/pixel/ui/x2/icon_pause.png")
	_load_button_icon(btn_1x, "res://assets/pixel/ui/x2/icon_play.png")
	_load_button_icon(btn_2x, "res://assets/pixel/ui/x2/icon_fast.png")
	_load_button_icon(btn_3x, "res://assets/pixel/ui/x2/icon_faster.png")

	if phase_icon:
		phase_icon.texture = ICON_DAY
	
	btn_pause.pressed.connect(_on_btn_pause)
	btn_1x.pressed.connect(_on_btn_1x)
	btn_2x.pressed.connect(_on_btn_2x)
	btn_3x.pressed.connect(_on_btn_3x)
	idle_button.pressed.connect(select_next_idle)
	idle_button.add_theme_font_size_override("font_size", UiFont.BODY)
	var rain_settings: LabelSettings = rain_tag.label_settings.duplicate() as LabelSettings
	rain_settings.font_size = UiFont.BODY
	rain_tag.label_settings = rain_settings

func _load_texture(rect: TextureRect, path: String) -> void:
	if ResourceLoader.exists(path):
		rect.texture = load(path) as Texture2D

func _load_button_icon(btn: Button, path: String) -> void:
	if ResourceLoader.exists(path):
		btn.icon = load(path) as Texture2D

func bind(state: GameState, overlay_root: Node = null) -> void:
	if not state:
		return
	
	_state = state
	_research_seen.clear()
	for id: String in state.tech.done:
		_research_seen[id] = true # Binding a restored save never replays completion.
	_ensure_research_controls()
	var scene: Node = overlay_root
	if scene == null and is_inside_tree():
		scene = get_tree().current_scene
	if scene:
		_overlay_root = scene
		_selection = scene.get_node_or_null("World/Selection") as SelectionController
		_camera = scene.get_node_or_null("World/Camera2D") as CameraController
		var toggle: Button = scene.get_node_or_null("RosterPanel/ToggleButton") as Button
		if _survivors_button and _survivors_button.item_rect_changed.is_connected(_layout_research_row):
			_survivors_button.item_rect_changed.disconnect(_layout_research_row)
		_survivors_button = toggle
		if _survivors_button:
			_survivors_button.item_rect_changed.connect(_layout_research_row)
	_layout_research_row()
	
	if state.resources:
		for kind: String in ResourceStore.KINDS:
			_update_label(kind, state.resources.get_amount(kind))
		state.resources.changed.connect(_on_resources_changed)
	
	if state.clock:
		state.clock.dawn.connect(_on_dawn)
		state.clock.phase_changed.connect(_on_phase_changed)
		state.clock.speed_changed.connect(_on_speed_changed)
		_refresh_day()
		_refresh_phase()
		_refresh_forecast()
		_refresh_rain_tag()
		_refresh_ammo_warning()
		_on_speed_changed(state.clock.paused, state.clock.speed)

	state.survivor_unsheltered.connect(_on_survivor_unsheltered)
	state.survivors.survivor_added.connect(_on_survivors_changed)
	state.survivors.survivor_removed.connect(_on_survivors_changed)
	state.expeditions.run_returned.connect(_on_run_returned)
	_ensure_toast_box()

func _on_resources_changed(kind: String, amount: int) -> void:
	_update_label(kind, amount)

func _update_label(kind: String, amount: int) -> void:
	if _labels.has(kind):
		(_labels[kind] as Label).text = str(amount)

func _process(delta: float) -> void:
	if not _state or not _state.clock:
		return
	_refresh_day()
	_refresh_ammo_warning()
	_refresh_research()
	_position_toasts()
	_tick_toasts(delta)

	if _shelter_warning_timer > 0.0:
		var step: float = delta
		if not _state.clock.paused:
			step = _state.clock.scale(delta)
		_shelter_warning_timer = maxf(0.0, _shelter_warning_timer - step)
		if _shelter_warning_timer <= 0.0:
			_shelter_warning_names.clear()
			_refresh_shelter_warning()
		
	var left: int = ceili(_state.clock.time_left())
	var text: String
	if _state.clock.phase == GameClock.Phase.DAY:
		text = "Nightfall in %d:%02d" % [left / 60, left % 60]
	else:
		text = HudText.night_text(_state.hostiles_remaining(), left)
	if text != _last_displayed_text:
		_last_displayed_text = text
		time_label.text = text

func _on_survivor_unsheltered(s: Survivor) -> void:
	if not s:
		return
	if not _shelter_warning_names.has(s.name):
		_shelter_warning_names.append(s.name)
	_shelter_warning_timer = 5.0
	_refresh_shelter_warning()

func _refresh_shelter_warning() -> void:
	if not shelter_warning_label:
		shelter_warning_label = get_node_or_null("ShelterWarning") as Label
	if not shelter_warning_label:
		return
	if _shelter_warning_names.is_empty():
		shelter_warning_label.visible = false
		shelter_warning_label.text = ""
		return
	if _shelter_warning_names.size() == 1:
		shelter_warning_label.text = "%s can't reach shelter" % _shelter_warning_names[0]
	else:
		shelter_warning_label.text = "%s can't reach shelter" % ", ".join(_shelter_warning_names)
	shelter_warning_label.visible = true

func _on_run_returned(s: Survivor, result: Dictionary) -> void:
	var survivor_name: String = s.name if s != null else "A survivor"
	show_scavenge_toast(survivor_name, result)
	_play_return_sfx(result)

func show_scavenge_toast(survivor_name: String, result: Dictionary) -> void:
	_ensure_toast_box()
	_toast_queue.append({"text": ScavengeToast.text(survivor_name, result)})
	_pump_toasts()

func _ensure_toast_box() -> void:
	if _toast_box != null:
		return
	# Top-left, just below the night-forecast line: readable whether or not the
	# right-side roster is open, and clear of the build bar and info card.
	_toast_box = VBoxContainer.new()
	_toast_box.name = "ScavengeToasts"
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_toast_box.offset_left = 8.0
	_toast_box.offset_right = 520.0
	_toast_box.offset_top = 140.0
	_toast_box.offset_bottom = 140.0
	_toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	var toast_layer := CanvasLayer.new()
	toast_layer.name = "ToastLayer"
	toast_layer.layer = 19 # Above Research, below pause/report/menu modals.
	add_child(toast_layer)
	toast_layer.add_child(_toast_box)

func _position_toasts() -> void:
	if not _toast_box:
		return
	var research: TechTreeScreen = _overlay_root.get_node_or_null("TechTreeScreen") as TechTreeScreen if _overlay_root else null
	_toast_box.position = Vector2(340, 80) if research and research.visible else Vector2(8, 140)
	if _overlay_root and not (research and research.visible):
		var hints: HintPanel = _overlay_root.get_node_or_null("Hints") as HintPanel
		if hints and hints.is_showing():
			var panel: Control = hints.get_node("PanelContainer") as Control
			_toast_box.position.y = panel.position.y + panel.size.y + 8.0

func _pump_toasts() -> void:
	if _toast_box == null:
		return
	while not _toast_queue.is_empty() and _active_toasts.size() < TOAST_MAX_VISIBLE:
		var item: Dictionary = _toast_queue.pop_front()
		var panel := PanelContainer.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var label := Label.new()
		label.text = str(item["text"])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", UiFont.BODY)
		label.add_theme_color_override("font_color", MenuStyle.CREAM)
		panel.add_child(label)
		_toast_box.add_child(panel)
		_active_toasts.append({"panel": panel, "timer": TOAST_LIFETIME})

func _tick_toasts(delta: float) -> void:
	if _active_toasts.is_empty():
		return
	var done: Array[int] = []
	for i in range(_active_toasts.size()):
		var toast: Dictionary = _active_toasts[i]
		toast["timer"] = float(toast["timer"]) - delta
		var panel: PanelContainer = toast["panel"]
		if not is_instance_valid(panel):
			done.append(i)
			continue
		var remaining: float = float(toast["timer"])
		if remaining <= 0.0:
			if panel.get_parent() == _toast_box:
				_toast_box.remove_child(panel)
			panel.queue_free()
			done.append(i)
		elif remaining < TOAST_FADE:
			panel.modulate.a = maxf(0.0, remaining / TOAST_FADE)
	for i in range(done.size() - 1, -1, -1):
		_active_toasts.remove_at(done[i])
	if not _toast_queue.is_empty():
		_pump_toasts()

func _play_return_sfx(result: Dictionary) -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	var managers: Array[Node] = get_tree().get_nodes_in_group(&"audio_managers")
	if managers.is_empty():
		return
	if bool(result.get("lost", false)) or bool(result.get("hurt", false)):
		managers[0].call("play", "survivor_hurt")
	else:
		managers[0].call("play", "build_complete")

func _refresh_ammo_warning() -> void:
	var has_shooters: bool = false
	_idle_uids.clear()
	for s: Survivor in _state.survivors.all():
		if s.job == Survivor.Job.IDLE and not s.away:
			_idle_uids.append(s.uid)
		if s.job == Survivor.Job.GUARD:
			has_shooters = true
	if not has_shooters:
		for b: Building in _state.buildings.all():
			if b.type_id == "turret" and b.complete:
				has_shooters = true
				break
	var warning: bool = HudText.ammo_warning(_state.resources.get_amount("ammo"), has_shooters)
	_refresh_idle_button()
	ammo_label.modulate = COLOR_AMMO_WARN if warning else Color.WHITE
	var label: Label = get_node("TopBar/Margin/HBox/Resources/AmmoBox/AmmoWarning") as Label
	label.visible = warning

func _on_survivors_changed(_survivor: Survivor) -> void:
	_refresh_ammo_warning()

func _refresh_idle_button() -> void:
	if not idle_button or not _state or not _state.clock:
		return
	var show_button: bool = _state.clock.phase == GameClock.Phase.DAY and not _idle_uids.is_empty()
	idle_button.visible = show_button
	if show_button:
		idle_button.text = "Idle: %d" % _idle_uids.size()

func select_next_idle() -> void:
	if not _state or not _selection or not _camera or _idle_uids.is_empty() or _selection_blocked():
		return
	var current_index: int = _idle_uids.find(_selection.selected_uid) if _selection.selected_kind == "survivor" else -1
	for offset: int in range(1, _idle_uids.size() + 1):
		var index: int = (current_index + offset) % _idle_uids.size()
		var survivor: Survivor = _state.survivors.get_by_uid(_idle_uids[index])
		if survivor == null or survivor.away or survivor.sheltered:
			continue
		_selection.select_survivor(survivor.uid)
		_camera.center_on(survivor.pos)
		return

func _selection_blocked() -> bool:
	var scene: Node = _overlay_root
	if scene == null and is_inside_tree():
		scene = get_tree().current_scene
	if scene == null:
		return false
	for path: String in ["MainMenu", "PauseMenu", "DawnReport", "GameOverScreen", "VictoryScreen", "HowToPlay", "SettingsScreen", "CreditsScreen"]:
		var overlay: Node = scene.get_node_or_null(path)
		if overlay and overlay.get("visible") == true:
			return true
	var roster: RosterPanel = scene.get_node_or_null("RosterPanel") as RosterPanel
	return roster != null and roster.is_open()

func _ensure_research_controls() -> void:
	if _research_button:
		return
	var row := HBoxContainer.new()
	row.name = "ResearchControls"
	row.offset_left = 8
	row.offset_right = 390
	row.custom_minimum_size.y = 44
	row.add_theme_constant_override("separation", 8)
	_research_row = row
	add_child(row)
	row.item_rect_changed.connect(_on_top_left_stack_changed)
	row.minimum_size_changed.connect(_on_top_left_stack_changed)
	row.visibility_changed.connect(_on_top_left_stack_changed)
	_research_button = Button.new()
	_research_button.text = "[T]"
	_research_button.focus_mode = Control.FOCUS_NONE
	_research_button.custom_minimum_size = Vector2(88, 40)
	_research_button.icon = load("res://assets/pixel/ui/icon_research.png") as Texture2D
	_research_button.expand_icon = true
	_research_button.add_theme_constant_override("icon_max_width", 32)
	_research_button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_research_button.add_theme_font_size_override("font_size", UiFont.BODY)
	_research_button.tooltip_text = "Research [T]"
	_research_button.pressed.connect(func() -> void: research_requested.emit())
	row.add_child(_research_button)
	_research_readout = Label.new()
	_research_readout.add_theme_font_size_override("font_size", UiFont.BODY)
	_research_readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var backing := PanelContainer.new()
	backing.name = "ResearchReadoutPanel"
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(backing)
	backing.add_child(_research_readout)
	_refresh_research()

## Layout consumers use the rendered controls, including theme-driven height.
func top_left_stack_bottom() -> float:
	if _research_row and _research_row.visible:
		return _research_row.position.y + maxf(_research_row.size.y, _research_row.get_combined_minimum_size().y)
	if _survivors_button:
		return _survivors_button.get_rect().end.y
	return (get_node("TopBar") as Control).get_rect().end.y

func _layout_research_row() -> void:
	if _research_row:
		var bottom: float = _survivors_button.get_rect().end.y if _survivors_button else (get_node("TopBar") as Control).get_rect().end.y
		_research_row.position.y = bottom + 4.0
	_on_top_left_stack_changed()

func _on_top_left_stack_changed() -> void:
	top_left_stack_changed.emit()

func take_research_toasts() -> Array[String]:
	var texts: Array[String] = []
	if _state:
		for id: String in _state.tech.done:
			if not _research_seen.has(id):
				_research_seen[id] = true
				texts.append("Research done: %s" % _state.tech.data.upgrades[id].name)
	return texts

func _refresh_research() -> void:
	if not _state or not _research_button:
		return
	var visible_research: bool = _state.clock.day >= int(_state.data.get_building("field_lab").unlock_day)
	_research_button.get_parent().visible = visible_research
	_research_readout.text = HudText.research_text(_state)
	_research_readout.modulate = Color("a5cf8a") if _state.tech.active == "" else MenuStyle.CREAM
	for text: String in take_research_toasts():
		_toast_queue.append({"text": text})
	_pump_toasts()

func _refresh_phase() -> void:
	if not phase_icon:
		phase_icon = get_node_or_null("TopBar/Margin/HBox/DayArea/PhaseIcon") as TextureRect
	if not phase_icon or not _state or not _state.clock:
		return
	if _state.clock.phase == GameClock.Phase.DAY:
		phase_icon.texture = ICON_DAY
	else:
		phase_icon.texture = ICON_NIGHT

func _on_phase_changed(_phase: int, _day: int) -> void:
	_refresh_phase()
	_refresh_day()
	_refresh_idle_button()
	_refresh_forecast()
	_refresh_rain_tag()

func _refresh_forecast() -> void:
	if not night_forecast_panel or not night_forecast_label or not _state or not _state.clock:
		return
	var visible_forecast: bool = _state.clock.phase != GameClock.Phase.NIGHT
	night_forecast_panel.visible = visible_forecast
	if not visible_forecast:
		return
	var forecast: Dictionary = WaveSpawner.forecast(_state.data, _state.clock.day, _state.difficulty_multipliers, _state.map_seed)
	night_forecast_label.text = HudText.forecast_text(forecast)
	night_forecast_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3) if bool(forecast["final"]) else MenuStyle.CREAM)

func _refresh_day() -> void:
	var day: int = _state.clock.day
	_refresh_phase()
	if day == _shown_day:
		return
	day_label.text = "Day %d" % day
	_shown_day = day
	_refresh_rain_tag()

func _refresh_rain_tag() -> void:
	if not rain_tag or not _state or not _state.clock:
		return
	var is_rain: bool = _state.clock.phase == GameClock.Phase.DAY and _state.weather_day() == "rain"
	rain_tag.visible = is_rain
	if is_rain:
		var rain: Dictionary = _state.data.weather_config().get("rain", {})
		var farm_bonus: int = roundi((float(rain.get("farm_mult", 1.0)) - 1.0) * 100.0)
		rain_tag.text = "Rain: farms +%d%%" % farm_bonus

func _on_dawn(_day: int) -> void:
	_refresh_day()
	_shelter_warning_timer = 0.0
	_shelter_warning_names.clear()
	_refresh_shelter_warning()

func _on_speed_changed(paused: bool, speed: int) -> void:
	if paused:
		btn_pause.button_pressed = true
	else:
		if speed == 1:
			btn_1x.button_pressed = true
		elif speed == 2:
			btn_2x.button_pressed = true
		elif speed == 3:
			btn_3x.button_pressed = true

func _on_btn_pause() -> void:
	if _state and _state.clock:
		_state.clock.set_paused(true)

func _on_btn_1x() -> void:
	if _state and _state.clock:
		_state.clock.set_speed(1)

func _on_btn_2x() -> void:
	if _state and _state.clock:
		_state.clock.set_speed(2)

func _on_btn_3x() -> void:
	if _state and _state.clock:
		_state.clock.set_speed(3)

func _unhandled_input(event: InputEvent) -> void:
	if not _state or not _state.clock:
		return
		
	if event.is_action_pressed("pause"):
		_state.clock.toggle_pause()
	elif event.is_action_pressed("speed_1"):
		_state.clock.set_speed(1)
	elif event.is_action_pressed("speed_2"):
		_state.clock.set_speed(2)
	elif event.is_action_pressed("speed_3"):
		_state.clock.set_speed(3)
	elif event.is_action_pressed("select_idle") and not event.is_echo():
		select_next_idle()
		var viewport: Viewport = get_viewport()
		if viewport:
			viewport.set_input_as_handled()
