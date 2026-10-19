class_name GameOverScreen extends CanvasLayer

var _state: GameState
var records_path: String = Records.PATH
var _submitted: bool = false

func _ready() -> void:
	MenuStyle.apply(get_node("Dim/Center/Panel/Margin/Content"), MenuStyle.BLOOD)
	(get_node("Dim/Center/Panel/Margin/Content/RecordLine") as Label).add_theme_color_override("font_color", MenuStyle.BLOOD)

func bind(state: GameState) -> void:
	_state = state
	visible = false
	_state.game_lost.connect(_on_game_lost)
	get_node("Dim/Center/Panel/Margin/Content/Buttons/Restart").pressed.connect(_restart)
	get_node("Dim/Center/Panel/Margin/Content/Buttons/MainMenu").pressed.connect(_main_menu)
	if state.game_over and (not state.won or state.endless):
		_on_game_lost(state.lose_reason)

static func stat_rows(values: Dictionary) -> Array[Array]:
	var seconds: int = maxi(0, int(values.get("time_played", 0.0)))
	return [
		["Nights survived", str(values.get("nights_survived", 0))],
		["Zombies killed", str(values.get("zombies_killed", 0))],
		["Survivors lost", str(values.get("survivors_lost", 0))],
		["Buildings built", str(values.get("buildings_built", 0))],
		["Time played", "%d:%02d" % [seconds / 60, seconds % 60]],
	]

func _on_game_lost(reason: String) -> void:
	if _state.won and not _state.endless: return
	_state.clock.set_paused(true)
	_state.clock.locked = true
	var content: Node = get_node("Dim/Center/Panel/Margin/Content")
	content.get_node("Reason").text = "The Command Center was destroyed." if reason == "command_center" else "No survivors remain."
	content.get_node("Difficulty").text = "Difficulty: " + _state.difficulty.capitalize()
	var stats: Dictionary = _state.stats()
	MenuStyle.fill_stats(content.get_node("Stats"), stat_rows(stats))
	var beaten: Dictionary = {"best_nights": false, "fastest_win": false, "first_win": false}
	if not _submitted:
		# A post-victory endless loss updates nights, never the run's win count.
		beaten = Records.submit(_state.difficulty, int(stats.get("nights_survived", 0)), false,
			float(stats.get("time_played", 0.0)), records_path)
		_submitted = true
	var record_line: Label = content.get_node("RecordLine") as Label
	record_line.text = Records.new_record_lines(beaten, _state.difficulty,
		int(stats.get("nights_survived", 0)), float(stats.get("time_played", 0.0)))
	record_line.visible = not record_line.text.is_empty()
	visible = true
	ScreenFade.reveal_panel(get_node("Dim/Center/Panel"))

func _restart() -> void:
	Game.restart()

func _main_menu() -> void:
	Game.quit_to_menu()
