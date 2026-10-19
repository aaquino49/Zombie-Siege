extends RefCounted

static func setup(main: Node) -> void:
	load("res://dev/scenarios/tech_tree.gd").setup(main)
	var state: GameState = Game.state
	var ids: Array[String] = []
	for id: String in state.tech.data.upgrades:
		ids.append(id)
	state.tech.restore({"done": ids, "banked": 6.5})
	for id: String in state.tech.done:
		main.get_node("HUD")._research_seen[id] = true
	main.get_node("TechTreeScreen").refresh()
