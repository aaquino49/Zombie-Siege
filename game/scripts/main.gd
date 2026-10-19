extends Node2D

static func scenario_arg(args: PackedStringArray) -> String:
	for arg in args:
		if arg.begins_with("--scenario="):
			return arg.trim_prefix("--scenario=")
	return ""

func _ready() -> void:
	Game.new_game(Game.next_seed)
	$World.bind(Game.state)
	$World/YSort/Units.bind(Game.state)
	$World/YSort/Zombies.bind(Game.state)
	$World/CombatFx.bind(Game.state)
	$World/FloatingText.bind(Game.state)
	$World/BuildMode.bind(Game.state)
	$World/Selection.bind(Game.state)
	$HUD.bind(Game.state, self)
	$TechTreeScreen.bind(Game.state, self)
	$HUD.research_requested.connect($TechTreeScreen.toggle)
	$BuildBarLayer/BuildInfoCard.state = Game.state
	$CCAlarm.bind(Game.state)
	$World/DayNightTint.bind(Game.state)
	$World/WeatherLayer.bind(Game.state, $World/Camera2D)
	$World/NightLights.bind(Game.state)
	$HUD/PhaseBanner.bind(Game.state)
	$BuildBarLayer.bind(Game.state)
	$InfoPanel.bind(Game.state, $World/Selection)
	$RosterPanel.bind(Game.state, $World/Selection)
	$GameOverScreen.bind(Game.state)
	if has_node("World/RescueHelicopter"):
		$World/RescueHelicopter.bind(Game.state, $World/Camera2D)
		$VictoryScreen.bind(Game.state, $World/RescueHelicopter)
	else:
		$VictoryScreen.bind(Game.state)
	
	$DawnReport.bind(Game.state)
	
	if has_node("MainMenu"):
		var screens: Array[MenuScreen] = [$HowToPlay, $SettingsScreen, $CreditsScreen]
		$MainMenu.bind(Game.state, screens)
	$HowToPlay.bind(Game.state.data)
		
	$Hints.bind(Game.state)
	$Hints.set_shown(Game.continued_extra.get("hints", {}))
	$SettingsScreen.bind($Hints)
	$PauseMenu.bind(Game.state, $World/BuildMode, $World/Selection, $MainMenu, $DawnReport, $Hints, $SettingsScreen)
	$Audio.bind(Game.state, $World/BuildMode)
	Game.state.dawn_processed.connect(_on_dawn_processed)
	Game.state.game_lost.connect(_on_game_lost)
	Game.state.game_won.connect(_on_game_won)

	$BuildBarLayer.building_selected.connect($World/BuildMode.select)
	$World/BuildMode.mode_changed.connect($BuildBarLayer.set_active_type)

	var scenario := scenario_arg(OS.get_cmdline_args() + OS.get_cmdline_user_args())
	if scenario != "":
		$Hints.set_enabled(false)
	if Game.show_menu and scenario == "":
		$MainMenu.open(Game.state)

func _on_dawn_processed(_report: Dictionary) -> void:
	if Game.state and not Game.state.game_over and (not Game.state.won or Game.state.endless):
		Game.save_now({"hints": $Hints.get_shown()})

func _on_game_lost(_reason: String) -> void:
	Game.delete_save()

func _on_game_won() -> void:
	Game.delete_save()
