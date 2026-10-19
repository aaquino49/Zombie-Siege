class_name PauseMenu extends CanvasLayer

const CONTENT := "Dim/Center/Panel/Margin/Content/"

var _state: GameState
var _build_mode: BuildMode
var _selection: SelectionController
var _main_menu: CanvasLayer
var _dawn_report: CanvasLayer
var _settings: SettingsScreen
var _was_paused: bool = false

func _ready() -> void:
	MenuStyle.apply(get_node("Dim/Center/Panel/Margin/Content"), MenuStyle.NEUTRAL)
	get_node(CONTENT + "SaveNoteMargin/SaveNote").add_theme_font_size_override("font_size", UiFont.BODY)

func bind(state: GameState, build_mode: BuildMode, selection: SelectionController,
		main_menu: CanvasLayer, dawn_report: CanvasLayer, _hints: HintPanel = null, settings: SettingsScreen = null) -> void:
	_state = state
	_build_mode = build_mode
	_selection = selection
	_main_menu = main_menu
	_dawn_report = dawn_report
	_settings = settings
	visible = false
	get_node(CONTENT + "Difficulty").text = "Seed %d · %s" % [state.map_seed, state.difficulty.capitalize()]
	get_node(CONTENT + "Buttons/Resume").pressed.connect(close)
	get_node(CONTENT + "Buttons/ReloadDay").pressed.connect(_reload_day)
	get_node(CONTENT + "Buttons/Restart").pressed.connect(_restart)
	get_node(CONTENT + "Buttons/MainMenu").pressed.connect(_main_menu_pressed)
	if _settings:
		get_node(CONTENT + "Buttons/Settings").pressed.connect(_settings.open.bind(self))

static func can_open(game_over: bool, menu_open: bool, report_open: bool,
		build_active: bool, has_selection: bool) -> bool:
	return not (game_over or menu_open or report_open or build_active or has_selection)

static func blocks_action(event: InputEvent) -> bool:
	if event == null:
		return false
	return event.is_action("pause") \
		or event.is_action("speed_1") \
		or event.is_action("speed_2") \
		or event.is_action("speed_3") \
		or event.is_action("build_menu") \
		or event.is_action("roster")

func _input(event: InputEvent) -> void:
	# Space also maps to ui_accept: consume it before a focused button can fire.
	# Also swallow hotkeys (build_menu, roster, speeds) while the pause menu is visible.
	if visible and blocks_action(event):
		var vp := get_viewport()
		if vp:
			vp.set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if _settings and _settings.visible:
		return
	if not event.is_action_pressed("cancel") or event.is_echo():
		return
	if visible:
		close()
		get_viewport().set_input_as_handled()
	elif _state and can_open(_state.game_over, _main_menu.visible, _dawn_report.visible,
			_build_mode.active_type != "", _selection.selected_kind != ""):
		open()
		get_viewport().set_input_as_handled()

func open() -> void:
	if visible:
		return
	get_node(CONTENT + "Buttons/ReloadDay").visible = Game.has_save_for(_state)
	_was_paused = _state.clock.paused
	_state.clock.set_paused(true)
	_state.clock.locked = true
	visible = true

func close() -> void:
	if not visible:
		return
	visible = false
	_state.clock.locked = false
	_state.clock.set_paused(_was_paused)

func _restart() -> void:
	close()
	Game.restart()

func _reload_day() -> void:
	close()
	Game.reload_day()

func _main_menu_pressed() -> void:
	close()
	Game.quit_to_menu()
