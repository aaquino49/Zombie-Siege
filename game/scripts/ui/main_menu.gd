class_name MainMenu extends CanvasLayer

var _state: GameState
var _screens: Array[MenuScreen] = []
var records_path: String = Records.PATH

func _ready() -> void:
	MenuStyle.apply(get_node("Dim/Center/Panel/Margin/Content"), MenuStyle.CREAM, true)
	if not visibility_changed.is_connected(_sync_title_scene):
		visibility_changed.connect(_sync_title_scene)
	_sync_title_scene()

func _sync_title_scene() -> void:
	get_node("TitleScene").set_active(visible)

func bind(state: GameState, screens: Array[MenuScreen] = []) -> void:
	_state = state
	_screens = screens
	var names: Array[String] = ["HowToPlay", "Settings", "Credits"]
	for i: int in range(_screens.size()):
		get_node("Dim/Center/Panel/Margin/Content/Buttons/" + names[i]).pressed.connect(_screens[i].open.bind(self))
	get_node("Dim/Center/Panel/Margin/Content/Buttons/NewGame").pressed.connect(_new_game)
	get_node("Dim/Center/Panel/Margin/Content/Buttons/Continue").pressed.connect(_continue_game)
	get_node("Dim/Center/Panel/Margin/Content/Buttons/Quit").pressed.connect(_quit)

func open(state: GameState) -> void:
	if not _state:
		_state = state
	
	_state.clock.set_paused(true)
	_state.clock.locked = true
	
	var tagline := get_node("Dim/Center/Panel/Margin/Content/Tagline")
	var nights: int = _state.data.balance("nights_to_win", 20)
	tagline.text = "Survive %d nights. Build the Radio Tower. Get rescued." % nights
	
	visible = true
	_refresh_continue()
	_refresh_records()
	
	var parent := get_parent()
	if parent:
		if parent.has_node("World"):
			parent.get_node("World").process_mode = Node.PROCESS_MODE_DISABLED
		if parent.has_node("HUD"):
			var n = parent.get_node("HUD")
			n.visible = false
			n.process_mode = Node.PROCESS_MODE_DISABLED
		if parent.has_node("BuildBarLayer"):
			var n = parent.get_node("BuildBarLayer")
			n.visible = false
			n.process_mode = Node.PROCESS_MODE_DISABLED
		if parent.has_node("RosterPanel"):
			var n = parent.get_node("RosterPanel")
			n.visible = false
			n.process_mode = Node.PROCESS_MODE_DISABLED
		if parent.has_node("InfoPanel"):
			var n = parent.get_node("InfoPanel")
			n.visible = false
			n.process_mode = Node.PROCESS_MODE_DISABLED

func _new_game() -> void:
	Game.prepare_new_game_preview()
	get_node("DifficultyPicker").open(_state.data)

func _continue_game() -> void:
	Game.continue_game()

func _refresh_continue(save_service: Node = Game) -> void:
	var button: Button = get_node("Dim/Center/Panel/Margin/Content/Buttons/Continue") as Button
	var day: int = save_service.save_day()
	button.visible = day > 0
	button.text = "Continue (Day %d)" % day if button.visible else "Continue"
	if button.visible and button.is_inside_tree():
		button.grab_focus()

func _refresh_records() -> void:
	var line: Label = get_node("Dim/Center/Panel/Margin/Content/BestRecords") as Label
	line.text = Records.menu_line(records_path)
	line.visible = not line.text.is_empty()

func _quit() -> void:
	Game.request_quit()
