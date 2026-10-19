extends RefCounted

static func setup(main: Node) -> void:
	var menu: MainMenu = main.get_node("MainMenu") as MainMenu
	menu.open(Game.state)
	var picker: DifficultyPicker = menu.get_node("DifficultyPicker") as DifficultyPicker
	picker.open(Game.state.data, "hard")
