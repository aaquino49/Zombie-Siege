extends RefCounted

static func setup(main: Node) -> void:
	load("res://dev/scenarios/main_menu.gd").setup(main)
	main.get_node("HowToPlay").open(main.get_node("MainMenu"))
