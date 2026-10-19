extends RefCounted
## Supplement the existing digit capture with every requested letter and ligature.

static func setup(main: Node) -> void:
	preload("res://dev/scenarios/font_check.gd").setup(main)
	var panel: Node = main.find_child("FontCheckPanel", true, false)
	var samples: Node = panel.get_child(0).get_child(0)
	for label: Label in samples.get_children():
		label.text = "v w y g  0123456789 S s  finish flag"
