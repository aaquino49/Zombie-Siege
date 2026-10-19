class_name VictoryScreen extends CanvasLayer

var _state: GameState
var _helicopter: RescueHelicopter
var records_path: String = Records.PATH
var _submitted: bool = false

func _ready() -> void:
	MenuStyle.apply(get_node("Dim/Center/Panel/Margin/Content"), MenuStyle.CREAM)
	(get_node("Dim/Center/Panel/Margin/Content/RecordLine") as Label).add_theme_color_override("font_color", MenuStyle.BLOOD)

func bind(state: GameState, helicopter: RescueHelicopter = null) -> void:
	_state = state
	_helicopter = helicopter
	visible = false
	_state.game_won.connect(_on_game_won)
	if _helicopter:
		_helicopter.rescue_finished.connect(_show_panel)
	get_node("Dim/Center/Panel/Margin/Content/Buttons/Restart").pressed.connect(_restart)
	get_node("Dim/Center/Panel/Margin/Content/Buttons/MainMenu").pressed.connect(_main_menu)
	get_node("Dim/Center/Panel/Margin/Content/Buttons/KeepFighting").pressed.connect(_keep_fighting)
	if state.won and not state.endless:
		_on_game_won()

func _on_game_won() -> void:
	_state.clock.set_paused(true)
	_state.clock.locked = true
	if not _helicopter:
		_show_panel()

func _show_panel() -> void:
	var content: Node = get_node("Dim/Center/Panel/Margin/Content")
	content.get_node("Title").text = "RESCUED!"
	var stats := _state.stats()
	var nights: int = stats.get("nights_survived", 0)
	content.get_node("Reason").text = "The helicopter got you out after %d nights." % nights
	content.get_node("Difficulty").text = "Difficulty: " + _state.difficulty.capitalize()
	MenuStyle.fill_stats(content.get_node("Stats"), GameOverScreen.stat_rows(stats))
	var beaten: Dictionary = {"best_nights": false, "fastest_win": false, "first_win": false}
	if not _submitted:
		beaten = Records.submit(_state.difficulty, nights, true, float(stats.get("time_played", 0.0)), records_path)
		_submitted = true
	var record_line: Label = content.get_node("RecordLine") as Label
	record_line.text = Records.new_record_lines(beaten, _state.difficulty, nights,
		float(stats.get("time_played", 0.0)))
	record_line.visible = not record_line.text.is_empty()
	visible = true
	ScreenFade.reveal_panel(get_node("Dim/Center/Panel"))

func _restart() -> void:
	Game.restart()

func _main_menu() -> void:
	Game.quit_to_menu()

func _keep_fighting() -> void:
	_state.endless = true
	_state.game_over = false
	if is_inside_tree():
		for audio: Node in get_tree().get_nodes_in_group(&"audio_managers"):
			if audio.has_method("resume_after_endless_continue"):
				audio.call("resume_after_endless_continue")
	_state.clock.locked = false
	_state.clock.set_paused(false)
	visible = false
