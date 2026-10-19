extends RefCounted

static func setup(main: Node) -> void:
	preload("res://dev/scenarios/ui_roster.gd").setup(main)
	for frame: int in range(30):
		await main.get_tree().process_frame
	var selection: SelectionController = main.get_node("World/Selection")
	selection.select_at_world(Vector2(-100, -100))
	await main.get_tree().process_frame
	print("QA clear: kind='%s' uid=%d info_visible=%s" % [selection.selected_kind,
		selection.selected_uid, main.get_node("InfoPanel").visible])
