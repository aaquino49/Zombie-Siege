extends RefCounted

static func setup(main: Node2D) -> void:
	var state: GameState = Game.state
	
	var bm: BuildMode = main.get_node("World/BuildMode") as BuildMode
	bm.select("shelter")
	bm.preview_at(state.map.command_center_origin())
