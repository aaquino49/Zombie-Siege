extends RefCounted

static func setup(main: Node2D) -> void:
	preload("res://dev/scenarios/buildings_placed.gd").setup(main)
	var state: GameState = Game.state
	var o: Vector2i = state.map.command_center_origin()
	var bm: BuildMode = main.get_node("World/BuildMode") as BuildMode
	bm.select("wooden_wall")
	bm.preview_at(o + Vector2i(2, 3))
